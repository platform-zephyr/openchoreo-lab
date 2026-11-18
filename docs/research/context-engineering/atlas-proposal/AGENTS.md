---
owner: paul
updated: 2026-11-18
review_days: 30
---
# Atlas — routeur de contexte des agents

Atlas dit **quel dépôt, quelle règle, quel skill** pour une demande. Ce n'est ni un daemon, ni une file de tickets, ni un lieu de décisions. Il ne contient que de la connaissance transversale et stable. Dépôt privé : jamais de secret, `.env`, état ou plan sensible.

## Démarrer (3 étapes, dans cet ordre)
1. Une demande en langage naturel ? Charge le skill `skills/route-intent/SKILL.md` : il lit `context/index.yaml` (seul fichier à ouvrir) et rend dépôt, skill, documents.
2. Ouvre dans le dépôt cible seulement : son `AGENTS.md`, son état court (`STATE.md` ou équivalent), le skill désigné. Le `AGENTS.md` du dépôt fait foi pour build, tests, CI et règles locales.
3. N'ouvre un document d'Atlas que s'il est cité par l'index : `policies/change-risk.md` (risque), `policies/coordination.md` (propriété, reprise), `policies/communication-style.md` (STE80), `dispatcher/mission-contract.md` et `workflows/issue-to-pr.md` (mission d'un ticket), `dispatcher/headless-profile.md` (session automatisée), `prompts/director.md` (coordinateur).

## Autorité (une source par sujet, déclarée dans l'index, jamais recopiée)
- Chaque domaine déclare dans `context/index.yaml` son dépôt propriétaire, son suivi des tâches (`tracker`) et son registre de décisions (`decisions`). Atlas ne recopie aucune décision ni aucun statut.
- Règle locale plus stricte que la politique d'Atlas : **la plus stricte gagne** ; un assouplissement exige une décision de Paul dans le registre du domaine.
- Un document sans `owner` ni `updated` récent (voir en-tête) est un indice, pas une autorité : vérifie le dépôt réel avant d'agir.

## Avant toute action
1. Relis le ticket ou l'issue actuel (état, commentaires, dépendances, critère de fin), les PR, branches et verrous `wip:*` du domaine.
2. Un ticket = un exécutant = une branche (`claude/<ticket>-<slug>`) = une PR. Plusieurs agents peuvent examiner ; un seul écrit au même endroit.
3. Avant une relance, vérifie les effets de la tentative précédente (PR, run, mutation) ; ne duplique jamais un dispatch.
4. Une PR par changement cohérent ; mission de 45 minutes au plus ; liens du fournisseur vérifiés avant toute suppression. Plusieurs dépôts touchés : une PR par dépôt, ordre de merge noté dans le ticket.

## Communication (STE80)
Comptes rendus, handoffs, commentaires et PR : [policies/communication-style.md](policies/communication-style.md). Conclusion d'abord, puis preuves ; statuts `PASS / FAIL / BLOCKED / NOT_TESTED / NOT_PROVEN` ; niveaux `STATIC < CI < RECONCILED < RUNTIME < USER` ; champs `Objective`, `Status`, `Changes`, `Evidence`, `Blockers`, `NextAction`. Code, identifiants, logs et contrats machine restent verbatim. Comptes rendus à Paul en français.

## Secrets
Ne copie jamais secret, cookie, clé, `.env`, sortie `tofu state` ou plan sensible vers Atlas, un tracker, un log ou un prompt. Un worktree sépare les fichiers, pas les permissions : un worker non fiable ne reçoit ni credential de production ni socket Docker hôte.

## Entretien d'Atlas
Max 60 lignes pour ce fichier ; une entrée d'index = un dépôt, une intention ou une règle ; en-tête `owner/updated/review_days` sur chaque document ; check CI : taille, liens, fraîcheur, chemins de l'index (`scripts/check-context.py`).
