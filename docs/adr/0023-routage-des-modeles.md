# ADR-0023 — Routage des modèles par tâche (3 règles)
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0012, ADR-0017, ADR-0018, ADR-0021 ; `docs/review/CONSENSUS-2.md` (décisions 7, 8, 9 et arbitrage 5)

## Contexte
- Les agents utilisent un abonnement Claude (quota hebdomadaire commun). Sur Terminal-Bench 4.1, Opus 5.5 et Sonnet 5.5 sont
  proches ; Sonnet coûte moins au token mais consomme plus de tokens (`docs/research/MODEL-ROUTING.md` §1).
- Le plancher de sécurité ne vient pas du modèle qui écrit mais des gardes déterministes et d'une revue par un autre modèle.
- La grille à 16 règles proposée n'est pas mesurée ; la revue adverse n°2 recommande une grille courte jusqu'aux données du pilote.
- Paul : tous les agents de dev sont Claude ; DeepSeek vient après le chantier (arbitrage 5).

## Décision
1. **Trois règles**, première qui s'applique, jusqu'aux données du pilote :
   - **R1 noyau** : le périmètre touche un chemin de CODEOWNERS, `docs/adr/` ou `docs/review/` → Opus, effort `high` ;
   - **R2 texte** : texte de tickets et documentation hors noyau, sans toucher les en-têtes ni `backlog/proposals/` → Haiku,
     effort `medium`, avec une revue Sonnet en check requis ; deux refus → Sonnet ;
   - **R3 défaut** : tout le reste → Sonnet, effort `high`.
2. Le dispatcher **recalcule** le modèle depuis les chemins réellement touchés ; il ignore un `model:` d'en-tête sous le
   plancher. Si le diff d'un ticket R2 sort du périmètre texte, il relance en Sonnet.
3. Les règles, `factory/`, `docs/state/model-prices.yaml` et `docs/state/homelab-capacity.yaml` sont noyau (CODEOWNERS).
4. **Alias** `opus | sonnet | haiku`, résolus par le registre au dispatch, plutôt que des ID figés ; les en-têtes gardent l'ID
   complet tant que `check.py` l'exige.
5. **Escalade** d'un cran (Sonnet → Opus) seulement sur un échec de capacité prouvé : deux échecs sur des critères de fin,
   CI verte par ailleurs (T-317). Un échec de CI ou d'environnement ne déclenche pas d'escalade.
6. **DeepSeek après le chantier** : aucun agent de dev non-Claude pendant le chantier ; les tickets DeepSeek (T-350, T-389,
   T-390) sont `deferred`. Après le chantier, les conditions de la décision 9 du consensus n°2 s'appliquent (règle docs
   seulement, runner sans secret, banc pass^3 ≥ 0,8, MANDAT de dépense).
7. Différés après le pilote : `route.py` (T-382), étalonnage (T-386), registre des tarifs (T-388), garde de confidentialité
   (T-390), revue trimestrielle (T-392).
8. Toute dépense à l'API au token est un MANDAT avec plafond mensuel.

## Conséquences
- `model`, `effort` et `routing` (`R0-geste-humain`, `R1-noyau`, `R2-texte`, `R3-defaut`) sont recalculés par
  `tools/backlog/seed.py` pour chaque ticket actif.
- Le noyau est large : une majorité de tickets actifs passe en Opus. Le pilote mesure si le quota tient ; le repli à 70 %
  du quota hebdomadaire (Opus → Sonnet `high` hors noyau) est fixé dans T-322.

## Alternatives écartées
- Grille à 16 règles avant mesure : hypothèses non vérifiées, plancher modifiable par un agent.
- Opus partout : quota épuisé plus vite. Haiku partout : trop faible en codage agentique.
- DeepSeek pendant le chantier : tout le contexte de session partirait chez un tiers dont les conditions autorisent
  l'entraînement sur les entrées.

## Vérification
- `check.py` refuse un `model` ou un `effort` inconnu ; un ticket actif sans `model` est une erreur.
- T-210 : test qui ignore un `model:` sous le plancher. Chaque PR d'agent porte les trailers `Model:` et `Effort:` (T-313).

## Références
`docs/research/MODEL-ROUTING.md` §1, §5-§7, `backlog/proposals/model-routing.yaml` (grille d'origine, conservée comme
hypothèses), `docs/review/ADVERSARIAL-REVIEW-2.md` §4, `docs/review/CONSENSUS-2.md`.
