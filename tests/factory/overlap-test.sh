#!/usr/bin/env bash
# Tests hors ligne de la garde de recouvrement (T-467). Aucun reseau, aucun cluster, aucun secret.
# Usage : tests/factory/overlap-test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec env PYTHONDONTWRITEBYTECODE=1 python3 -I "$ROOT/tests/factory/overlap_test.py"
