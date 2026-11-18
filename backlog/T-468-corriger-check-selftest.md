---
id: T-468
title: "Corriger le FAIL de check-selftest (test périmé après T-460)"
status: done
phase: P0
adr: [0022]
depends_on: [T-460]
class: REVUE
velocity: false
lane: dev-factory
stage: S2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---

# T-468 — Corriger le FAIL de check-selftest (test périmé après T-460)

## Intention
L'étape `check-selftest` échoue : `tests/dev-factory/check-test.sh` (section 4f) cherche `gitleaks git --config` et `useDefault = true` dans `.github/workflows/ci.yaml`. T-460 (commit 3f8aa02) a remplacé la commande inline du job `secrets` par `CHECK_ONLY="gitleaks" tools/dev/check --static --strict`. Le workflow est correct, le test est périmé. Le test vérifie maintenant l'appel strict dans `ci.yaml` et l'appel `gitleaks git --config` avec `useDefault = true` dans `tools/dev/check`.

## Périmètre de fichiers
tests/dev-factory/check-test.sh, backlog/T-468-corriger-check-selftest.md

## Critères de fin
- [x] `bash tests/dev-factory/check-test.sh` : `CHECK-TEST: PASS`, aucun `FAIL` sur la ligne « job secrets de ci.yaml » (preuve : 2026-11-18, local)
- [x] `tools/dev/check --static` : l'étape `check-selftest` n'est plus FAIL (preuve : 2026-11-18, local)

## Notes
Cause : test périmé, pas régression du workflow (`git log -S'gitleaks git --config' -- .github/workflows/ci.yaml` : 3f8aa02 retire, dc935d8 ajoute). Le contrôle de fond (même appel gitleaks, règles par défaut) est conservé et déplacé vers `tools/dev/check`. `tools/dev/check` n'est pas modifié.
