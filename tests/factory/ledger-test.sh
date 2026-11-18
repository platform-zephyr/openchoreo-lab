#!/usr/bin/env bash
# Tests hors ligne du ledger et du disjoncteur (T-326). Aucun reseau, aucun cluster, aucun secret.
# Usage : tests/factory/ledger-test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec python3 -I "$ROOT/tests/factory/ledger_test.py"
