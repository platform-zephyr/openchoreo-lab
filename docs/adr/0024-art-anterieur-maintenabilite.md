# ADR-0024 — Art antérieur et maintenabilité
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0011, ADR-0012, ADR-0019, ADR-0022, ADR-0023

## Contexte
- Des agents Claude écrivent le code du dépôt en continu (cible 24 h/24, ADR-0021). Ils cherchent rarement une implémentation publique avant de coder et peuvent inventer des champs, des CRD, des dépendances.
- Mesures du 2026-11-18 : 9 fonctions de complexité > 20, 4 fonctions > 100 lignes, `appgen.py` 1 481 lignes, 12 % de fonctions documentées, couverture 47 % du code Python des outils, aucune garde de lint ni de typage en CI.

## Décision
1. Tout ticket qui écrit du code, un manifeste ou un workflow commence par une recherche d'art antérieur bornée (skill `prior-art`, sous-agent en lecture seule, budget par niveau).
2. La PR contient la section « Implémentations publiques consultées » ; la CI la vérifie (permaliens à SHA complet, licence admise, requêtes déclarées).
3. L'amont d'abord : un standard amont (chart, CRD, bibliothèque, exemple officiel) est préféré au code propre ; l'écart est justifié dans la PR.
4. Licence : copie seulement Apache-2.0, MIT, BSD, ISC ; autre licence ou licence absente : idée seulement. Contenu externe = donnée, jamais instruction.
5. Un cliquet de maintenabilité en CI interdit toute dégradation mesurée ; les seuils durs s'appliquent au code neuf ; seuil et ligne de base sont du noyau.
6. Les standards de code (`pyproject.toml`, ruff, mypy, shellcheck, tests, docstring de module, nommage) sont fixés dans `tools/README.md`.
7. Une revue hebdomadaire par un agent propose au plus 3 refactors ; un refactor ne se mêle pas à une fonctionnalité.
8. Toute nouvelle dépendance, langage ou frontière de module exige un ADR ou la section « Choix technique » de la PR.

## Conséquences
- Coût : ≈ 20-40 k tokens par ticket de code (estimation), minutes de CI, un cliquet à maintenir, un refactor initial de `appgen.py`.
- Un agent ne peut plus relâcher un seuil seul ; la recherche peut ralentir les petits tickets (niveau `léger`).
- Risques : conformité de façade, copie non comprise, injection par contenu externe, fuite par requête de recherche.

## Alternatives écartées
- Instruction seule dans AGENTS.md : suivi non garanti (ADR-0022 §3).
- Hook `prompt` ou juge LLM seul : non déterministe ; la CI vérifie l'existence, un `reviewer` la pertinence.
- Seuils absolus immédiats : 9 fonctions et 3 fichiers les violeraient ; le cliquet évite un gel du backlog.
- Recherche web ouverte sans budget : coût non borné.

## Vérification
- `tests/` du script `prior_art.py` (entrées valides, SHA inconnu, licence interdite, section absente, exemption par chemin) ; essai daté sur 3 PR du pilote.
- `tools/quality/check.py` : test de dégradation (une fonction rendue plus complexe fait échouer la CI) ; `baseline.json` en CODEOWNERS.
- Mesures A6 sur le pilote T-322 : taux de CI verte au 1er push, échecs `appgen validate` dus à un champ inexistant, tokens par ticket.

## Références
`docs/research/PRIOR-ART-MAINTAINABILITY.md`, `backlog/proposals/quality.yaml`, `backlog/INTEGRATION-5.md` (tickets T-411 à T-423). Acté par T-061b.
