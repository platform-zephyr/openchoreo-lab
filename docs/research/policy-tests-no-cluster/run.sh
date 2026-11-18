#!/usr/bin/env bash
# Prototype T-463 : tests des VAP natives de platform/policies/ sans cluster, par `kyverno test`.
# Usage : docs/research/policy-tests-no-cluster/run.sh [chemin/vers/kyverno]   (défaut : $KYVERNO_BIN, puis PATH)
# Codes : 0 PASS, 1 FAIL, 2 outil absent. Aucun accès réseau, aucun cluster.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
kyv="${1:-${KYVERNO_BIN:-kyverno}}"
command -v "$kyv" >/dev/null 2>&1 || { echo "kyverno introuvable : $kyv" >&2; exit 2; }
# `version` sans `| head -1` : sous pipefail, head ferme le tube et le CLI sort en 141 (SIGPIPE).
"$kyv" version >/dev/null
"$kyv" test "$here" --detailed-results --remove-color --require-tests
