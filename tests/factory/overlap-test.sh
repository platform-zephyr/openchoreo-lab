#!/usr/bin/env bash
# Tests hors ligne de la garde de recouvrement (T-467). Aucun reseau, aucun cluster, aucun secret.
# Usage : tests/factory/overlap-test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec python3 -I -B "$ROOT/tests/factory/overlap_test.py"
