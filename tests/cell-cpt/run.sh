#!/usr/bin/env bash
# Contrôle STATIQUE de cell-restricted (≠ preuve runtime : celle-ci vient de tests/phase2-whoami sur k3d, puis de OKE).
# Exige : label egress-isolated=true en constante, RoleBinding du cluster-agent borné à la cellule (ClusterRole
# lab-cluster-agent-cell, sujet unique, juste après le Namespace), aucun ClusterRoleBinding dans le type.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
python3 -I - platform/project-types/cell-restricted.yaml <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
res = d["spec"]["resources"]
ids = [r["id"] for r in res]
bad = []
ns = res[0]["template"]
if ns["kind"] != "Namespace" or '"platform.smadja.dev/egress-isolated": "true"' not in ns["metadata"]["labels"]:
    bad.append("label-egress-isolated")
if ids[1] != "cluster-agent-rolebinding":
    bad.append("order-after-namespace")
rb = res[1]["template"]
ok = (rb["kind"] == "RoleBinding" and rb["roleRef"] == {"apiGroup": "rbac.authorization.k8s.io", "kind": "ClusterRole", "name": "lab-cluster-agent-cell"}
      and len(rb["subjects"]) == 1 and rb["subjects"][0]["name"] == "cluster-agent-dataplane"
      and rb["subjects"][0]["namespace"] == "openchoreo-data-plane" and rb["metadata"]["namespace"] == "${metadata.namespace}")
if not ok:
    bad.append("rolebinding-bounded")
if any(r["template"]["kind"] == "ClusterRoleBinding" for r in res):
    bad.append("no-clusterrolebinding")
for n in ("label-egress-isolated", "order-after-namespace", "rolebinding-bounded", "no-clusterrolebinding"):
    print(("FAIL " if n in bad else "PASS ") + n)
sys.exit(1 if bad else 0)
PY
