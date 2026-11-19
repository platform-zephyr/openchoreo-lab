---
id: T-501
title: "Prérequis du harnais de la passe 0 du banc A/B (collecteur d'observations, mot de passe M2, images, SHA du bras O)"
status: in-progress
phase: P1
adr: [0025]
depends_on: [T-485]
class: AUTONOME
velocity: true
lane: banc-ab
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-501 — Prérequis du harnais de la passe 0

## Intention
Que la passe 0 (T-486) s'exécute dès qu'une session cluster existe, sans autre développement : les graders M1/M2 lisent `http_status` et `api_row_found`, que rien ne produisait ; M2 a besoin du mot de passe administrateur de miniflux ; les images et le SHA figé du bras O doivent être vérifiables.

## Périmètre de fichiers
tests/bench-ab/pass-0/observe.py, tests/bench-ab/pass-0/test_observe.py, tests/bench-ab/pass-0/admin-password*.sh, tests/bench-ab/pass-0/check-frozen-sha*.sh, tests/bench-ab/pass-0/dispatch-test.sh, tests/bench-ab/fixtures/observe/, tests/bench-ab/arm64-images.md, tests/registry.yaml (une entrée)

## Critères de fin
- [x] STATIC : collecteur `observe.py` (`http-status`, `api-row`, fixtures, `--run-file`), sortie JSON stable, valeur `null` si la mesure est impossible ; `test_observe.py` 11 tests OK, sans réseau externe
- [x] STATIC : `admin-password.sh seed|exec` pose la clé `MINIFLUX_ADMIN_PASSWORD` (Secret `miniflux-admin-password` de `lab-secrets`, valeur aléatoire par tube, jamais affichée ni écrite, Secret existant conservé) ; `admin-password-test.sh` OK avec un faux client
- [x] STATIC : `check-frozen-sha.sh` refuse un SHA dont l'arbre contient `apps/echo-bench` ou `apps/miniflux` (ou leur sortie `generated/`) ; test sur dépôt jetable OK
- [x] STATIC : `arm64-images.md` (echo-bench, miniflux, ntfy : digests lus au registre le 2026-11-19, linux/arm64 présent) ; suite `bench-ab-pass-0` branchée dans `tests/registry.yaml` (point d'entrée `dispatch-test.sh`, qui lance aussi les trois autres tests)
- [ ] RUNTIME OKE (session cluster, opérateur de Paul) : `admin-password.sh seed` puis `observe.py` sur les vraies apps, observations jointes au premier run de la passe 0
- [ ] Lever par Paul ou T-485 avant le gel : `origin/main` contient déjà `apps/miniflux` et sa sortie `generated/` (`check-frozen-sha.sh` = FAIL le 2026-11-19) ; la consigne M2 nomme la variable `ADMIN_PASSWORD` alors que le harnais pose la clé `MINIFLUX_ADMIN_PASSWORD`

## Notes
- Hors périmètre (autres lots) : `docs/research/POC-AB-PASS-0.md` (étape 1 « SHA de O = origin/main » à corriger, ajouter la commande `check-frozen-sha.sh`), `tests/bench-ab/thresholds.yaml` (après la passe 0), `tests/bench-ab/arm-k/`.
- Chaîne attendue en session cluster : `admin-password.sh exec --context CTX -- observe.py api-row --base-url URL --title T --run-file runs/M2.O.r0.json`.

### Reprise (2026-11-19)
- Fait (STATIC, fusionné #172 et #175) : `observe.py`, `admin-password.sh`, `check-frozen-sha.sh`, `arm64-images.md`, suite `bench-ab-pass-0`, règle M3/K (README + gabarit des seuils).
- Reste : preuve OKE (case ouverte) ; décisions de Paul ci-dessus (SHA de O, `ADMIN_PASSWORD`) et S2/`occ` (non défini).
- Commandes : `tests/bench-ab/pass-0/dispatch-test.sh` (toute la suite, hors ligne) ; `check-frozen-sha.sh <SHA40>` ; en session cluster : `admin-password.sh seed --context CTX`, puis `exec` + `observe.py` (voir Notes).
- Pièges : `origin/main` contient `apps/miniflux` (le SHA de O ne peut pas être `origin/main`) ; le garde Bash refuse toute commande contenant « kubectl » (écrire les scripts avec l'outil Write) ; ruff et radon exigés par la CI `quality`.
- Prochaine action : session cluster de l'opérateur, puis cocher la case RUNTIME OKE avec les sorties datées.
