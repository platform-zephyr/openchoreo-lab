"""Rendu du parcours helm : Application Argo CD multi-source et garde-fous du namespace, sans OpenChoreo.

Role : pour chaque environnement, une Application Argo CD (chart epingle par digest + values.yaml du depot +
ressources de garde) et les ressources de garde elles-memes (default-deny, DNS, quota sans Service expose, egress,
ExternalSecret).
Entrees : document app.yaml (source.chart), politique du cluster.
Sorties : {chemin relatif sous generated/: objet} (helm/<nom>/<env>/..., catalog/<nom>/catalog-info.yaml).
"""
from __future__ import annotations

from appgenlib.catalog import catalog_entity
from appgenlib.config import ARGO_NAMESPACE, ARGO_PROJECT_HELM, GITOPS_REPO, GITOPS_REVISION, PRIVATE_NETS, ROOT
from appgenlib.egress import egress_objects, egress_project_params
from appgenlib.model import egress_spec, load_capabilities

PSA_LABELS = {
    "pod-security.kubernetes.io/enforce": "restricted",
    "pod-security.kubernetes.io/enforce-version": "latest",
    "pod-security.kubernetes.io/warn": "restricted",
    "pod-security.kubernetes.io/audit": "restricted",
}


def helm_namespace(name: str, env: str) -> str:
    return f"lab-{name}-{env}"


def _guard_resources(ns: str) -> list[dict]:
    """Garde-fous toujours rendus : default-deny, DNS et trafic intra-namespace, aucun Service LB/NodePort."""
    return [
        {"apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
         "metadata": {"name": "default-deny", "namespace": ns},
         "spec": {"podSelector": {}, "policyTypes": ["Ingress", "Egress"]}},
        {"apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
         "metadata": {"name": "allow-dns-and-namespace", "namespace": ns},
         "spec": {"podSelector": {}, "policyTypes": ["Ingress", "Egress"],
                  "ingress": [{"from": [{"podSelector": {}}]}],
                  "egress": [{"to": [{"podSelector": {}}]},
                             {"to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "kube-system"}},
                                      "podSelector": {"matchLabels": {"k8s-app": "kube-dns"}}}],
                              "ports": [{"protocol": "UDP", "port": 53}, {"protocol": "TCP", "port": 53}]}]}},
        {"apiVersion": "v1", "kind": "ResourceQuota", "metadata": {"name": "no-exposed-services", "namespace": ns},
         "spec": {"hard": {"services.loadbalancers": "0", "services.nodeports": "0"}}},
    ]


def _public_internet_policy(ns: str) -> dict:
    return {"apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
            "metadata": {"name": "egress-public-internet", "namespace": ns},
            "spec": {"podSelector": {}, "policyTypes": ["Egress"],
                     "egress": [{"to": [{"ipBlock": {"cidr": "0.0.0.0/0", "except": [str(p) for p in PRIVATE_NETS]}}],
                                 "ports": [{"protocol": "TCP", "port": 80}, {"protocol": "TCP", "port": 443}]}]}}


def _external_secret(name: str, ns: str, store: str, secrets: list[dict]) -> dict:
    return {"apiVersion": "external-secrets.io/v1", "kind": "ExternalSecret",
            "metadata": {"name": f"{name}-secrets", "namespace": ns},
            "spec": {"refreshInterval": "1h",
                     "secretStoreRef": {"kind": "ClusterSecretStore", "name": store},
                     "target": {"name": f"{name}-secrets", "creationPolicy": "Owner"},
                     "data": [{"secretKey": s["env"], "remoteRef": {"key": s["key"],
                               **({"property": s["property"]} if "property" in s else {})}}
                              for s in secrets]}}


def _application(name: str, env: str, ns: str, chart: dict, rdir: str) -> dict:
    oci = chart["repo"].startswith("oci://")
    return {
        "apiVersion": "argoproj.io/v1alpha1", "kind": "Application",
        # Pas de finalizer resources-finalizer : supprimer l'Application CONSERVE les ressources
        # (equivalent de preserveResourcesOnDeletion, qui n'existe que sur ApplicationSet).
        "metadata": {"name": f"{name}-{env}", "namespace": ARGO_NAMESPACE,
                     "labels": {"platform.smadja.dev/app": name, "platform.smadja.dev/delivery": "helm"},
                     "annotations": {"platform.smadja.dev/chart-digest": chart["digest"],
                                     "platform.smadja.dev/managed-by": "argocd (hors OpenChoreo)"}},
        "spec": {
            "project": ARGO_PROJECT_HELM,
            "sources": [
                {"repoURL": chart["repo"][len("oci://"):] if oci else chart["repo"], "chart": chart["name"],
                 "targetRevision": chart["version"],
                 "helm": {"releaseName": name, "valueFiles": [f"$values/apps/{name}/values.yaml"]}},
                {"repoURL": GITOPS_REPO, "targetRevision": GITOPS_REVISION, "ref": "values"},
                {"repoURL": GITOPS_REPO, "targetRevision": GITOPS_REVISION, "path": f"generated/{rdir}"},
            ],
            "destination": {"server": "https://kubernetes.default.svc", "namespace": ns},
            "syncPolicy": {
                "automated": {"prune": False, "selfHeal": True},
                "managedNamespaceMetadata": {"labels": dict(PSA_LABELS)},
                "syncOptions": ["CreateNamespace=true", "FailOnSharedResource=true", "PruneLast=true",
                                "ServerSideApply=true"],
            },
        },
    }


def render_helm(doc: dict, caps: dict | None = None) -> dict[str, object]:
    """Application Argo CD multi-source (chart epingle + values.yaml + garde-fous), sans OpenChoreo."""
    meta, spec = doc["metadata"], doc["spec"]
    name = meta["name"]
    caps = caps if caps is not None else load_capabilities(ROOT / "clusters", spec["cluster"])
    chart = spec["source"]["chart"]
    files: dict[str, object] = {}
    profile, rules = egress_spec(spec)
    for env in spec["environments"]:
        ns = helm_namespace(name, env)
        rdir = f"helm/{name}/{env}/resources"
        res = _guard_resources(ns)
        if profile == "public-internet":
            res.append(_public_internet_policy(ns))
        if rules:
            res += egress_objects(name, env, ns, egress_project_params(doc, caps, {}), rules, caps["cilium"], {})
        if spec.get("secrets"):
            res.append(_external_secret(name, ns, caps["secretStore"], spec["secrets"]))
        for obj in res:
            files[f"{rdir}/{obj['kind'].lower()}-{obj['metadata']['name']}.yaml"] = obj
        files[f"helm/{name}/{env}/application.yaml"] = _application(name, env, ns, chart, rdir)
    files[f"catalog/{name}/catalog-info.yaml"] = catalog_entity(doc, {
        "argocd/app-name": ",".join(f"{name}-{e}" for e in spec["environments"]),
        "platform.smadja.dev/chart": f"{chart['repo']}/{chart['name']}:{chart['version']}",
    })
    return files
