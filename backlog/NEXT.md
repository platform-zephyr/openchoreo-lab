# Prochaines étapes (tenu à la main par le coordinateur — dernière mise à jour 2026-11-18)

Point d'entrée pour reprendre : lire ce fichier, puis `docs/state/HANDOFF-COORDINATEUR.md`. Ce fichier dit **quoi lancer maintenant** ;
`ROADMAP.md` (généré) donne l'ordre complet ; `python3 tools/backlog/next.py` calcule les tickets prêts (dépendances `done` seulement).
Pendant S0/S1, beaucoup de dépendances sont `in-progress` (implémentées) : lancer à la main les tickets ci-dessous.

## État en une ligne
L'usine est prouvée en vrai sur un lot de 2 issues en parallèle (run 44338002716 : PASS/PASS, 0,51 $ et 0,37 $, auto-merge par le bot). Il reste à
prouver `factory/PAUSE`, le disjoncteur de quota et un lot de 5 issues (T-311), à clore T-313/T-411, puis le pilote 24 h (T-322).

## Prérequis du pilote T-322 encore ouverts (voir la ligne « Reste » dans chaque ticket)
| Ticket | Reste | Qui |
|---|---|---|
| T-303 | même script `leak-guard.sh` en local, en CI et dans le hook Stop : à cocher après relecture (T-331 livré) | coordinateur |
| T-305 | tag `core-baseline` : annoté mais non signé ; Paul l'accepte ou le repose | Paul |
| T-311 | run avec `factory/PAUSE` posé (désarmement d'un auto-merge déjà armé) ; 5 dispatchs terminés sans annulation | coordinateur |
| T-313 | N PR parallèles prouvées (run 44338002716) : cocher les critères restants après relecture des tickets | coordinateur |
| T-411 | essai daté sur un ticket `complet` (section « Implémentations publiques consultées » rendue) | coordinateur (dispatch d'un ticket de test) |

## Lot suivant (à lancer en arrivant, voir `priority.py --top 10` et `overlap.py`)
- **Petits tickets, sous-agents locaux Sonnet en lot** (rapide, sans coût de démarrage) : T-041 (contexte en couches), T-100 (contrat d'alerte),
  T-050 (verdicts kube-ops), T-420 (revue hebdomadaire de maintenabilité), T-479/T-480 à clôturer (livrés par l'usine).
- **Sujets longs ou sensibles** : T-214 (découper `appgen`, score 72), T-001 (fusionner la PR #8 security bundle, score 86, vérifier si c'est un geste de Paul),
  T-201 (ingestion GitHub vers Parquet), T-215 (pack identité, FINAL0).
- **Suites de l'usine** : arbitrer le mode de permission de l'action (`auto` n'est pas une liste blanche), finalisation déterministe par le workflow
  (étude T-477, R4), durcir le garde Bash (`git -c core.hooksPath`, `commit-tree`), motif `usage_limit`/`budget_cap_exceeded` dans `mission-result.v1`,
  empreintes linux-amd64 de `toolchain.lock` (T-332, bloque T-470), cases T-471/T-472, T-469 (triage k3d), T-458 (classer les FAIL de `gitops-k3d`).

## Vague B : après la vague A
T-461 (SL-7, dépend de T-460), T-462 (devcontainer), T-465 (nuit k3d, dépend de T-461, T-451, T-452), T-451 (reste : alerte k3d, fin de S1), T-452 (critère 3, fin de S1).

## Dispatch multi-issues (preuve de T-311, T-313 et début du pilote)
1. Créer N issues de tickets réels sans conflit de fichiers (`gh issue create` ou l'outil GitHub) avec le contenu du ticket.
2. Lancer : `gh workflow run claude-agent.yml -f tickets="101,102,103" -f model=claude-sonnet-5-5 -f effort=high` (matrice `max-parallel: 3`).
3. Relever pour chaque issue : branche, PR, coût, tours (artefact `mission-result-<n>`, `permission_denials`), fusion par la file.
4. `factory/PAUSE` : poser le fichier sur `main` par PR puis relancer pour prouver le désarmement (T-311).
Journaux complets : `-f debug=true` (dépôt public : seulement sur une issue sans donnée sensible).

## Après le pilote (ordre, voir ROADMAP.md)
T-322 (pilote 24 h, N=3 puis 6 puis 10, palier décidé par Paul) → porte ADR-0020 (S2/S3 puis PORTE) → FINAL0 → I1-I8 → FINAL.
Backlog des suites k3d : T-452/T-465 (réactivation nocturne à la fin de S1 avant T-364), T-435 (requis) en FINAL0.

## Gestes de Paul encore attendus
- Script de setup de l'environnement cloud des agents : `tools/dev/cloud-setup.sh` (interface), sorties autorisées `get.helm.sh`, `github.com`.
- T-305 : accepter le tag `core-baseline` (annoté, non signé) ou le reposer ; signature avant FINAL0.
- T-434 : réglages d'organisation GitHub (`docs/research/GITHUB-CONFIG.md` §7) ; preuves à relever après.
- Confirmer les dates réelles du registre `docs/state/identities.yaml` (`created_is_estimate`).
- Pause du moteur horaire d'Atlas et homelab-infra pendant le pilote ; relevé `/usage` à 0, 24 et 48 h ; palier N ; Max ou Ultra après le pilote.
- Dire si `lab.internal` est fictif.
- FINAL0 : App(s) définitives (T-215), retrait du contournement admin (T-400), signature du tag.
