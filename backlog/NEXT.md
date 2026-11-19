# Prochaines étapes (tenu à la main par le coordinateur — dernière mise à jour 2026-11-19, passation T-510)

Point d'entrée : ce fichier, puis `docs/state/HANDOFF-COORDINATEUR.md`. Passation à un orchestrateur unique sur le Mac. L'état se calcule : `python3 tools/backlog/status.py`.

## État en une ligne (2026-11-19)
OpenChoreo est installé sur OKE (plateforme et bras O : whoami, ntfy, echo-demo, searxng ; 52 % CPU, 32 pods sur 33). Check runs GitHub lus sans identifiant (T-489, T-497, T-507). searxng est en échec (T-499 case 4). T-060 : résidu kgateway accepté jusqu'à FINAL0, PR #169 brouillon non appliquée. T-006 : `cloudflared` livré en Git (#162), bloqué par la géorestriction Cloudflare et l'absence du client `reader`.

## Stratégie (décision de Paul, 2026-11-19, T-521)
Le banc A/B est abandonné (plus long et plus cher qu'un déploiement jetable réel sur OKE ; il ne mesure pas l'IDP). Paul fait lui-même un **test d'usage sur un déploiement réel d'OpenChoreo** (T-520, en cours, ne pas y toucher). La PR #177 (ADR-0025) est obsolète : elle sera remplacée par une décision courte « banc A/B abandonné », rédigée **après** le rapport T-520 (aucun ADR touché d'ici là).

## Chemin critique, dans l'ordre
1. Test d'usage de Paul sur le déploiement réel (T-520) et son rapport.
2. Preuves OKE des couloirs utiles au déploiement réel : T-515 (searxng, probes, `verify.sh --all`, `lab-o`, `maxPods`) ; T-499 case 4 ; T-487 cases 2, 3, 6 ; T-498 case 2 (réponses de Paul).
3. Décision courte « banc A/B abandonné » (remplace la PR #177), puis décision de porte ADR-0020 (façade ou objets natifs) fondée sur le rapport T-520, GEL levé ou confirmé.

## Couloirs en cours (propriétaires ; ne pas toucher leurs tickets)
T-502 (`lab-o`), T-505 (`argo-escalation`), T-507, T-508 (gouvernance), T-509 (documentation d'orchestration). Gelés `deferred` (T-521) : T-486, T-501, T-504, T-212, T-485, T-488, T-495 ; T-506 (`lab-k`) à geler par son propriétaire.

## Tickets de suite ouverts par T-510
- T-511 `lab-store` renommé `default` à la prochaine réinstallation OKE ; T-512 alignements textuels de T-502 ; T-513 `K3D_REQUIRED` (fusion ne prouve pas k3d) ; T-514 mesure `argo-escalation` et k3d après T-505 ; T-515 preuves OKE en attente d'un opérateur.

## GEL
Aucune ligne nouvelle dans `tools/appgen/` ni dans `tools/oke/argo_guard*` jusqu'à la décision « façade ou objets natifs ». Un correctif qui s'y rattache attend la décision (cas T-499, T-511).

## Gestes de Paul
- Test d'écriture négatif de l'App `openchoreo-status` : permissions Checks et Commit statuses en écriture, Metadata en lecture (T-489 case 4, T-515).
- Test d'usage sur le déploiement réel d'OpenChoreo (T-520) et son rapport.
- Certificat de sauvegarde du state de homelab-infra.
- MANDAT #626.
- 2FA.
- Signature du tag `core-baseline` (T-305, avant FINAL0).
- Réponses aux 5 questions de `docs/research/OPENCHOREO-DEMO-NATIVE.md` §5 (T-498) ; client Authentik `reader` et application Access (T-006) ; `K3D_REQUIRED` (T-513).

## Pièges
- Un check run `success` prouve la synchro GitOps, pas la santé de l'app (searxng).
- La sandbox cloud sort par les États-Unis : 403 Cloudflare, ne pas contourner ; le canal des agents cloud = check runs GitHub.
- Fusion d'une PR ≠ preuve k3d tant que `K3D_REQUIRED` n'est pas posée (T-513).
- Marge de 1 pod sur OKE : toute app nouvelle doit être mesurée avant.

---

## Historique : état du 2026-11-18 (usine, pilote T-322)

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
