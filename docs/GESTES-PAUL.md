<!-- Généré par tools/factory/gestes.sh (T-325) : ne pas éditer à la main. Régénérer : tools/factory/gestes.sh generate --stage S0 --out docs/GESTES-PAUL.md -->
# Gestes de Paul : séance S0

Conclusion : 4 gestes, 29 min estimées pour un budget de 30 min (dans le budget).

Règles : Paul fait chaque geste. Aucune valeur de secret dans ce document ni dans la sortie du script. Le script relit l'effet en lecture seule (`tools/factory/gestes.sh check`, ou `seance` pour la séance guidée) et marque chaque geste `PASS`, `FAIL` ou `NOT_TESTED` avec un horodatage. La durée est une estimation : 3 min par ticket sauf mention « environ N minutes » ou « Durée : N min » dans le ticket.

## Séance, dans l'ordre

### 1. T-305 : Tag `core-baseline` du noyau avant le pilote

- Durée estimée : 3 min
- Classe : MANDAT
- Dépend de : T-302, T-303, T-304, T-326, T-330
- Intention : Fixer une référence de confiance du noyau (chemins CODEOWNERS) avant que les agents fusionnent eux-mêmes leurs PR du noyau ; le diff depuis ce tag est relu à FINAL (T-401).
- Vérification en lecture seule : git ls-remote --tags origin core-baseline (objet de tag annoté présent)

Reste (2026-11-18) : le ticket reste `in-progress` car le tag précède la fin de S0 (T-303, T-306… encore ouverts à sa pose) et n'est pas signé. Geste de Paul : soit accepter explicitement ce tag comme référence (les PR du noyau d'agents viennent après lui), soit le re-poser annoté (signé si possible) à la fin de S0, avant l'heure 0.

### 2. T-431 : Réglages du dépôt, d'Actions et de sécurité as-code (repo, actions, security JSON)

- Durée estimée : 3 min
- Classe : REVUE + MANDAT
- Dépend de : T-430
- Intention : Versionner et appliquer : squash seul, auto-merge, suppression des branches fusionnées, wiki/Discussions/Pages coupés ; GITHUB_TOKEN en lecture, PR par Actions interdites, allowlist d'actions, SHA complet obligatoire, approbation des workflows de forks pour tous les externes ; secret scanning, push protection, Dependabot alerts et security updates, signalement privé, CodeQL default setup (python, actions).
- Vérification en lecture seule : tools/github/apply.sh --check dev (lecture API, sans jeton affiché)

À obtenir (critères non cochés du ticket) :

- [ ] --check dev PASS après application par Paul (lecture datée, sans jeton affiché)
- [ ] champs sha_pinning_required et fork-pr-contributor-approval validés sur l'API réelle, sinon repli documenté (NOT_TESTED levé)
- [ ] CodeQL default setup actif sur python et actions ; une alerte factice ou un run vert prouvé
- [ ] un workflow qui utilise une action hors allowlist échoue (essai daté)
- [ ] aucun dependabot.yml de version updates (Renovate seul)

### 3. T-433 : Protection des tags : core-baseline et v* (ruleset de type tag)

- Durée estimée : 3 min
- Classe : REVUE + MANDAT
- Dépend de : T-305, T-430
- Intention : Interdire suppression et déplacement du tag core-baseline (référence du diff de T-401) et des tags v*. Paul applique le ruleset juste après T-305.
- Vérification en lecture seule : gh api repos/<dépôt>/rulesets (un ruleset de cible tag existe)

À obtenir (critères non cochés du ticket) :

- [ ] tags.json : cibles refs/tags/core-baseline* et refs/tags/v*, règles deletion et update (et non_fast_forward)
- [ ] essai daté : suppression et déplacement du tag refusés pour une identité Write
- [ ] --check dev couvre aussi tags.json

### 4. T-434 : Gestes d'organisation de Paul : 2FA, permissions de base, création de dépôts, PAT, Apps tierces, Actions

- Durée estimée : 20 min
- Classe : MANDAT
- Intention : Une séance d'environ 20 minutes, une action par ligne : 2FA obligatoire, permission de base « aucune », création de dépôts interdite, jetons fins avec approbation et durée 30 jours, classiques restreints, accès tiers restreint, politiques Actions de l'organisation. Chaque réglage a sa commande de lecture (gh api) pour la preuve.
- Vérification en lecture seule : gh api orgs/<org> : 2FA exigée, permission de base none, création de dépôts coupée

À obtenir (critères non cochés du ticket) :

- [ ] runbook rédigé, une action par ligne, sans valeur secrète
- [ ] preuve datée de chaque réglage par lecture API (2FA, base permission, repo creation, PAT policy), 2FA lue dans l'interface car l'API est en lecture seule
- [ ] chaque geste est listé dans `docs/GESTES-PAUL.md` quand T-325 l'aura généré (jusque-là : dans le runbook)

## Hors séance (geste de Paul, moment de son choix, hors chemin critique)

- T-301 : Réécriture de l'historique par Paul avec un agent Claude local (hors chemin critique) (3 min, non comptées dans le total)
