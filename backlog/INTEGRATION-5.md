# Intégration 5 du backlog : qualité (QA) et configuration GitHub (GH)

Conclusion : 23 tickets créés (12 QA, 11 GH), 5 propositions fusionnées ou traitées en note, 1 ticket de nettoyage
(T-450). `check.py` : 0 erreur, profondeur 11. Statut : PROPOSITION (STATIC). Source : patch « Intégration 5 » de `tools/backlog/seed.py`.
Entrées : `backlog/proposals/quality.yaml` (ADR-0024 : `docs/adr/0024-art-anterieur-maintenabilite.md`, PROPOSÉ) et `github.yaml`.

## Correspondance clé → ticket
| Clé | Ticket | Étape | Remarque |
|---|---|---|---|
| QA-0 | fusionné dans T-061b | S0 | l'ADR-0024 est versionné ; T-061b l'acte (pas de T-410) |
| QA-1 | T-411 | S0 | skill `prior-art`, gabarit de PR ; après T-313 (même gabarit) |
| QA-3, QA-4 | T-413, T-414 | S0 | `pyproject`/ruff/shellcheck ; cliquet de qualité |
| QA-2 | T-412 | S1 | vérificateur CI + hook Stop (après T-331, T-332) |
| QA-5, QA-8 | T-415, T-418 | S1 | sous-agent (après T-341) ; tests (T-008 en a déjà livré 24) |
| QA-6 | fusionné dans T-214 | S1 | découpage d'appgen ; T-214 dépend de T-413 et T-414 (pas de T-416) |
| QA-9 | T-419 | S1 | retrait de `seed.py`, APRÈS T-412, T-414, T-415, T-418 et T-214 |
| QA-7, QA-10, QA-12, QA-13 | T-417, T-420, T-422, T-423 | S2 | T-423 : Opus (R1-sensible, `argo_guard.py`) |
| QA-11 | T-421 | S3 | dépendance T-323 retirée (gelé) |
| GH-1 | T-430 | S0 | rulesets as code ; corrige l'écart du script (voir ci-dessous) |
| GH-2, GH-3, GH-4, GH-5 | T-431, T-432, T-433, T-434 | S0 | réglages ; SECURITY.md (aucun n'existait) ; tags (après T-305) ; gestes d'organisation |
| GH-6, GH-7, GH-8 | T-435, T-436, T-437 | S1 | `k3d-ok` requis ; labels ; T-437 complète T-313 sans l'alourdir |
| GH-9 | T-438 | après-porte (`deferred`) | miroir Project : aucun geste de Paul supprimé |
| GH-10, GH-14 | T-439, T-443 | S3, FINAL | essai dependency review ; provenance (conditionnel) |
| GH-11 | note de T-215 (+ T-121) | FINAL0 | décision de Paul : une ou deux Apps (pas de T-440) |
| GH-12 | fusionné dans T-400 | FINAL0 | `main-final.json`, CODEOWNERS par étapes (pas de T-441) |
| GH-13 | fusionné dans T-401 | FINAL | essais négatifs GitHub (pas de T-442) |
| (coordinateur) | T-450 | S1 | nettoyage de `.gitleaksignore` (129 emplacements) ; T-303 passe `in-progress`, 4 critères cochés |

## Mode dev (arbitrages de Paul)
`tools/apply-branch-protection.sh` contient `"require_code_owner_review": true` : contraire à l'arbitrage 7. T-430 le corrige (`false`, test hors
ligne) ; la revue des code owners revient seulement avec T-400 (FINAL0, sur `platform/authz/`, `platform/policies/`, `security/`) puis FINAL.
Les protections de CODEOWNERS (T-414, T-411, T-430) ne jouent donc qu'à partir de FINAL0 ; d'ici là seule `ci-ok` garde.

## Composition de S0 et S1
- S0 (20 actifs, dont 3 en cours : T-303, T-306, T-311) : T-061, T-061b, T-210, T-301, T-302, T-304, T-305, T-313, T-326, T-008 et T-330 `done`, +
  **T-411, T-413, T-414** (qualité), **T-430, T-431, T-432, T-433, T-434** (GitHub). Les 11 prérequis du pilote restent ; seul **T-413** s'y ajoute (T-214 en dépend).
- S1 (40 actifs, +8) : +T-412, T-415, T-418, T-419, T-435, T-436, T-437, T-450. T-419 passe en dernier des QA de S1.

## Décisions à faire prendre par Paul
1. **Deux Apps ou une** (T-215) : `openchoreo-agents` sans `workflows`, `openchoreo-renovate` avec ; texte actuel de T-215 = une seule App.
2. **Prérequis du pilote** : accepter T-413 (déjà ajouté) ; T-411 et T-414 (S0) avant l'heure 0 ou en parallèle du pilote.
3. **Retrait de `seed.py`** (T-419) : accepter l'édition directe des tickets ensuite. Les 4 fichiers édités à la main (T-008, T-330, T-306, T-311) divergent déjà de `seed.py` ; T-303 est porté par le patch.
4. **Routage** : T-411 sort en Haiku (tous ses fichiers sont du texte) alors qu'il touche AGENTS.md ; relever en Sonnet ?
5. Gestes MANDAT en S0 (T-431, T-433, T-434 ; `--apply` avec jeton admin) : les garder en S0 ou les passer en S1.
6. T-438 (Project v2) laissé gelé ; T-443 (provenance) conditionnel à un artefact publié.
