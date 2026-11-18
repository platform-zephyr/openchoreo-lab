#!/usr/bin/env python3
"""Contrôle STATIQUE des manifests rendus (helm template) contre la baseline OKE et PSA.

Usage : python3 -I tools/oke/psa_check.py <niveau PSA attendu: restricted|baseline> <fichier.yaml>...
Vérifie pour chaque objet portant un PodSpec (Pod, Deployment, StatefulSet, DaemonSet, ReplicaSet, Job,
CronJob) :
  - baseline-pod-hardening (VAP kube-ops #1620) : ni privileged, ni hostNetwork/hostPID/hostIPC, ni hostPath ;
  - PSA baseline : pas de capabilities ajoutées hors liste baseline, pas d'AppArmor Unconfined,
    pas de seccomp Unconfined, pas de hostPort ;
  - PSA restricted (si demandé) : runAsNonRoot, seccomp RuntimeDefault/Localhost, drop ALL,
    allowPrivilegeEscalation=false, capabilities ajoutées ⊆ {NET_BIND_SERVICE}, volumes autorisés ;
  - images épinglées par digest (@sha256:) ; requests cpu/mémoire présentes (sinon LimitRange).
Sortie : une ligne par écart ; code 1 si au moins un écart bloquant (VAP, PSA demandé).
Ne contacte aucun cluster. Ne remplace pas une preuve runtime (dry-run serveur sur OKE).
"""
import sys

import yaml

BASELINE_CAPS = {"AUDIT_WRITE", "CHOWN", "DAC_OVERRIDE", "FOWNER", "FSETID", "KILL", "MKNOD",
                 "NET_BIND_SERVICE", "SETFCAP", "SETGID", "SETPCAP", "SETUID", "SYS_CHROOT"}
RESTRICTED_VOLUMES = {"configMap", "csi", "downwardAPI", "emptyDir", "ephemeral",
                      "persistentVolumeClaim", "projected", "secret"}


def pod_spec(obj):
    kind = obj.get("kind")
    spec = obj.get("spec") or {}
    if kind == "Pod":
        return spec
    if kind == "CronJob":
        return (((spec.get("jobTemplate") or {}).get("spec") or {}).get("template") or {}).get("spec")
    if kind in ("Deployment", "StatefulSet", "DaemonSet", "ReplicaSet", "Job"):
        return (spec.get("template") or {}).get("spec")
    return None


def check(obj, level):
    """Orchestre les règles par pod puis par conteneur ; l'ordre des écarts est celui de l'ancienne fonction."""
    errs, warns = [], []
    ps = pod_spec(obj)
    if not ps:
        return errs, warns
    psc = ps.get("securityContext") or {}
    rule_vap_pod(ps, errs)
    rule_pod_unconfined(psc, errs)
    for c in list(ps.get("containers") or []) + list(ps.get("initContainers") or []):
        check_container(c, psc, level, errs, warns)
    if level == "restricted":
        rule_restricted_volumes(ps, errs)
    return errs, warns


def rule_vap_pod(ps, errs):
    """VAP baseline-pod-hardening : ni hostNetwork/hostPID/hostIPC, ni hostPath."""
    for f in ("hostNetwork", "hostPID", "hostIPC"):
        if ps.get(f):
            errs.append(f"VAP: {f}")
    for v in ps.get("volumes") or []:
        if "hostPath" in v:
            errs.append(f"VAP: hostPath ({v.get('name')})")


def rule_pod_unconfined(psc, errs):
    """PSA baseline (niveau pod) : ni AppArmor ni seccomp Unconfined."""
    if (psc.get("appArmorProfile") or {}).get("type") == "Unconfined":
        errs.append("PSA baseline: appArmorProfile Unconfined (pod)")
    if (psc.get("seccompProfile") or {}).get("type") == "Unconfined":
        errs.append("PSA baseline: seccomp Unconfined (pod)")


def check_container(c, psc, level, errs, warns):
    """Règles d'un conteneur : VAP, PSA baseline, avertissements, puis PSA restricted si demandé."""
    n = c.get("name")
    sc = c.get("securityContext") or {}
    rule_image_digest(c, n, warns)
    rule_vap_privileged(sc, n, errs)
    rule_baseline_hostport(c, n, errs)
    rule_baseline_unconfined(sc, n, errs)
    add = set((sc.get("capabilities") or {}).get("add") or [])
    rule_baseline_caps(add, n, errs)
    rule_requests(c, n, warns)
    if level == "restricted":
        rule_restricted_container(sc, psc, add, n, errs)


def rule_image_digest(c, n, warns):
    """Avertissement : image épinglée par digest."""
    img = c.get("image", "")
    if "@sha256:" not in img:
        warns.append(f"image sans digest: {n} {img}")


def rule_vap_privileged(sc, n, errs):
    """VAP : pas de conteneur privileged."""
    if sc.get("privileged"):
        errs.append(f"VAP: privileged ({n})")


def rule_baseline_hostport(c, n, errs):
    """PSA baseline : pas de hostPort."""
    for p in c.get("ports") or []:
        if p.get("hostPort"):
            errs.append(f"PSA baseline: hostPort ({n})")


def rule_baseline_unconfined(sc, n, errs):
    """PSA baseline (conteneur) : ni AppArmor ni seccomp Unconfined."""
    if (sc.get("appArmorProfile") or {}).get("type") == "Unconfined":
        errs.append(f"PSA baseline: appArmorProfile Unconfined ({n})")
    if (sc.get("seccompProfile") or {}).get("type") == "Unconfined":
        errs.append(f"PSA baseline: seccomp Unconfined ({n})")


def rule_baseline_caps(add, n, errs):
    """PSA baseline : capabilities ajoutées dans la liste baseline seulement."""
    if add - BASELINE_CAPS:
        errs.append(f"PSA baseline: capabilities ajoutées {sorted(add - BASELINE_CAPS)} ({n})")


def rule_requests(c, n, warns):
    """Avertissement : requests cpu et mémoire présentes (sinon LimitRange)."""
    req = (c.get("resources") or {}).get("requests") or {}
    if not req.get("cpu") or not req.get("memory"):
        warns.append(f"requests absentes (LimitRange appliquera ses défauts): {n}")


def rule_restricted_container(sc, psc, add, n, errs):
    """PSA restricted (conteneur) : un seul message agrégé, comme avant."""
    caps = sc.get("capabilities") or {}
    bad = []
    if sc.get("allowPrivilegeEscalation") is not False:
        bad.append("allowPrivilegeEscalation!=false")
    if "ALL" not in (caps.get("drop") or []):
        bad.append("drop ALL absent (casse exacte)")
    if add - {"NET_BIND_SERVICE"}:
        bad.append(f"add {sorted(add)}")
    if sc.get("runAsNonRoot", psc.get("runAsNonRoot")) is not True:
        bad.append("runAsNonRoot absent")
    if sc.get("runAsUser", psc.get("runAsUser")) == 0:
        bad.append("runAsUser=0")
    pod_seccomp = (psc.get("seccompProfile") or {}).get("type")
    if (sc.get("seccompProfile") or {}).get("type", pod_seccomp) not in ("RuntimeDefault", "Localhost"):
        bad.append("seccompProfile absent")
    if bad:
        errs.append(f"PSA restricted ({n}): " + ", ".join(bad))


def rule_restricted_volumes(ps, errs):
    """PSA restricted : types de volumes autorisés."""
    for v in ps.get("volumes") or []:
        kinds = set(v) - {"name"}
        if kinds - RESTRICTED_VOLUMES:
            errs.append(f"PSA restricted: volume {v.get('name')} de type {sorted(kinds)}")


def main():
    level, files = sys.argv[1], sys.argv[2:]
    rc = 0
    for f in files:
        with open(f, encoding="utf-8") as fh:
            for obj in yaml.safe_load_all(fh):
                if not isinstance(obj, dict) or "kind" not in obj:
                    continue
                errs, warns = check(obj, level)
                ident = f"{f}: {obj['kind']}/{obj.get('metadata', {}).get('name')}"
                for e in errs:
                    print(f"FAIL {ident}: {e}")
                    rc = 1
                for w in warns:
                    print(f"WARN {ident}: {w}")
    print(f"psa_check niveau={level} rc={rc}")
    return rc


if __name__ == "__main__":
    sys.exit(main())
