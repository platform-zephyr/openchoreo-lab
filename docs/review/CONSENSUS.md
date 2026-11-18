# Consensus coordinateur ↔ revue adverse (2026-11-18)

Entrées : `docs/review/ADVERSARIAL-REVIEW.md` (revue adverse) et la réponse du coordinateur. Un tour d'échange a suffi :
toutes les divergences sont tranchées ci-dessous. **Ce consensus est une proposition à Paul** : il devient effectif quand
Paul approuve la PR qui le porte (ADR et `missions/` sont dans le noyau).

## Constat partagé
1. Le backlog initial était un inventaire, pas un plan : **aucune porte de décision OpenChoreo**, alors qu'une vingtaine de
   tickets ne servent qu'à lui.
2. Environ 70 tickets sur 124 attendaient Paul : **la latence humaine** était le vrai chemin critique.
3. Le noyau d'ADR-0002 laissait des trous exploitables : scripts de garde de la CI requise, scripts exécutés par le
   coordinateur sur OKE, ProjectTypes (default-deny), consignes `.agents/`, et identité réelle des agents.
4. La cible OKE dépassait le nœud A1 : il faut une **nomenclature figée** (≤ 33 pods, ≤ 70 %).

## Décisions
| # | Sujet | Décision |
|---|---|---|
| 1 | Noyau | Règle générale : tout script de garde d'un job requis et tout script exécuté par le coordinateur avec droits cluster est noyau ; plus `.agents/`, `tools/backlog/`, `platform/project-types/`, `users/`, `groups/`, `identities/`, `platform/secrets/`, `ops/`, `tools/metrics/`. `appgen.py` reste libre. |
| 2 | Identité des agents | T-215 « pack identité » (MANDAT, S0) : compte agent rôle Write + une GitHub App ; aucun agent avec le compte admin de Paul ; essai réel en T-007. |
| 3 | Default-deny | VAP de noyau qui refuse une cellule sans default-deny (T-217). |
| 4 | Porte OpenChoreo | ADR-0020, critères C1-C5, décision de Paul le 2026-12-04 (T-211). Échec d'une voie = pas d'app A Ready + PASS après 3 jours, ou MANDAT non obtenu sous 48 h. T-030 échoue / T-212 réussit → abandon par défaut ; l'inverse → C1-C4 sans C5 ; les deux échouent → un report d'une semaine, puis **Paul choisit** (aucune décision automatique). |
| 5 | Moteur | Contrat indépendant du moteur (ADR-0001 §6) ; backend « plain » en spike de 3 jours (T-212). |
| 6 | Actage des ADR | T-061 acte 0001-0006, 0010-0013, 0020 et réaligne MISSION sur le homelab ; prérequis explicite des tickets. T-218 acte 0014-0019 après la porte. |
| 7 | OKE | Nomenclature figée, un seul Argo (T-213), Backstage hors OKE, emplacement d'Authentik tranché, **aucun service IA sur OKE** (T-169 supprimé). |
| 8 | Crossplane | **Différé, pas supprimé** : v1 = Access wildcard + routes déclarées ; déclencheurs (a) groupes différents, (b) client non navigateur, (c) > 3 apps publiques avec politique propre ; T-029/T-076 `blocked`. |
| 9 | OpenBao | Cible de **tous** les secrets internes, en I2 ; mots de passe de bases par rôles gérés CNPG ; seal statique proposé avec mise en garde, **décision à Paul** ; aucune migration avant un drill perte + restauration daté ; pod compté dans la nomenclature OKE avant installation ; clés LLM lues par le seul gateway ; panne OKE = nouveaux déploiements BLOCKED, pods en cours intacts. |
| 10 | Boucles | Un seul propriétaire du revert automatique (T-106) ; pas de seconde PR d'agent sur une même (app, env) sans humain ; fichier de refus de versions pour Renovate ; pas d'automerge des digests d'actions ni d'apps avant T-124. |
| 11 | Dispatcher | T-210 réduit, en S0 **après** le noyau et T-215 : déclenché par Paul avec une liste d'ID, classe recalculée depuis les chemins, plafond 4, contrat de mission d'Atlas. |
| 12 | Vélocité | T-214 (appgen modulaire) avant le couloir contrat ; T-216 (CI extensible par registre). |
| 13 | Fusions | T-140+141+142 ; T-143→T-026 ; T-186+187 ; T-181+182+191 (séance Doppler) ; T-201+202 ; T-101+102+103 ; T-100+104+108 ; T-105→T-005 ; T-110→T-106. |
| 14 | Suppressions | T-112, T-144, T-146, T-169, T-170. |
| 15 | Gel jusqu'à la porte | MCP via Access (T-006, dégel si adoption + preuve d'injection), Atlas (T-042), montées OpenChoreo et bundle, Talos/Tofu/Scorecard/verifyImages, veille, archétype E (T-014, en tête d'I1bis après mesure par T-050), G11/G12, Garage et jobs data, migration kube-ops, banc complet, DR plateforme. |
| 16 | MVP | S0 socle de confiance → S1 preuve automatique → S2 deux moteurs (T-030 et T-212) → S3 golden path (T-003, T-010, T-015, T-043, 5 recettes, 5 intentions A, T-050) ; puis porte ; puis I1-I8. |

## Points restant à Paul
- Approuver ce consensus (PR), la date de la porte, le **seal statique** d'OpenBao, l'emplacement d'Authentik.
- Gestes MANDAT de S0 : actage des ADR (T-061), pack identité (T-215).

## Incertitudes reconnues des deux côtés
Identité réelle des sessions cloud et sémantique de la revue des code owners à 0 approbation ; seal statique d'OpenBao,
rôles gérés CNPG, gVisor arm64 (non vérifiés, web bloqué) ; limites de l'Access wildcard ; budget OKE estimé, pas mesuré ;
réactivité de Paul ; MVP en ~14 tickets si T-030 ou T-212 aboutit en moins de 3 jours.
