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
    errs, warns = [], []
    ps = pod_spec(obj)
    if not ps:
        return errs, warns
    psc = ps.get("securityContext") or {}
    ctrs = [("c", c) for c in ps.get("containers") or []] + \
           [("init", c) for c in ps.get("initContainers") or []]
    # VAP baseline-pod-hardening (kube-ops #1620)
    for f in ("hostNetwork", "hostPID", "hostIPC"):
        if ps.get(f):
            errs.append(f"VAP: {f}")
    for v in ps.get("volumes") or []:
        if "hostPath" in v:
            errs.append(f"VAP: hostPath ({v.get('name')})")
    pod_seccomp = (psc.get("seccompProfile") or {}).get("type")
    pod_nonroot = psc.get("runAsNonRoot")
    if (psc.get("appArmorProfile") or {}).get("type") == "Unconfined":
        errs.append("PSA baseline: appArmorProfile Unconfined (pod)")
    if pod_seccomp == "Unconfined":
        errs.append("PSA baseline: seccomp Unconfined (pod)")
    for _, c in ctrs:
        n = c.get("name")
        sc = c.get("securityContext") or {}
        img = c.get("image", "")
        if "@sha256:" not in img:
            warns.append(f"image sans digest: {n} {img}")
        if sc.get("privileged"):
            errs.append(f"VAP: privileged ({n})")
        for p in c.get("ports") or []:
            if p.get("hostPort"):
                errs.append(f"PSA baseline: hostPort ({n})")
        if (sc.get("appArmorProfile") or {}).get("type") == "Unconfined":
            errs.append(f"PSA baseline: appArmorProfile Unconfined ({n})")
        if (sc.get("seccompProfile") or {}).get("type") == "Unconfined":
            errs.append(f"PSA baseline: seccomp Unconfined ({n})")
        caps = sc.get("capabilities") or {}
        add = set(caps.get("add") or [])
        if add - BASELINE_CAPS:
            errs.append(f"PSA baseline: capabilities ajoutées {sorted(add - BASELINE_CAPS)} ({n})")
        req = (c.get("resources") or {}).get("requests") or {}
        if not req.get("cpu") or not req.get("memory"):
            warns.append(f"requests absentes (LimitRange appliquera ses défauts): {n}")
        if level == "restricted":
            bad = []
            if sc.get("allowPrivilegeEscalation") is not False:
                bad.append("allowPrivilegeEscalation!=false")
            if "ALL" not in (caps.get("drop") or []):
                bad.append("drop ALL absent (casse exacte)")
            if add - {"NET_BIND_SERVICE"}:
                bad.append(f"add {sorted(add)}")
            nonroot = sc.get("runAsNonRoot", pod_nonroot)
            if nonroot is not True:
                bad.append("runAsNonRoot absent")
            if sc.get("runAsUser", psc.get("runAsUser")) == 0:
                bad.append("runAsUser=0")
            seccomp = (sc.get("seccompProfile") or {}).get("type", pod_seccomp)
            if seccomp not in ("RuntimeDefault", "Localhost"):
                bad.append("seccompProfile absent")
            if bad:
                errs.append(f"PSA restricted ({n}): " + ", ".join(bad))
    if level == "restricted":
        for v in ps.get("volumes") or []:
            kinds = set(v) - {"name"}
            if kinds - RESTRICTED_VOLUMES:
                errs.append(f"PSA restricted: volume {v.get('name')} de type {sorted(kinds)}")
    return errs, warns


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
