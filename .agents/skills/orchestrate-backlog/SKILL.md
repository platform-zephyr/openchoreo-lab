---
name: orchestrate-backlog
description: Reprendre seul l'orchestration du backlog du labo après une compaction ou dans une session neuve — lire l'état, choisir les tickets par score, les dispatcher (sessions cloud, sous-agents locaux ou usine claude-agent.yml), intégrer, fusionner par REST, suivre les PR jusqu'à la preuve OKE. Référence : docs/ORCHESTRATION.md. À charger pour « reprends le backlog », « lance la prochaine vague », « orchestre », « intègre les agents ».
---

# orchestrate-backlog

**Tu délègues systématiquement ; voir `docs/ORCHESTRATION.md` § « Rôle de l'orchestrateur ».** Règle STOP : chercher,
lire un script, lancer une vérification, poser un secret, coder ou diagnostiquer = lancer un agent. Toute écriture OKE
va à UN agent « opérateur OKE » local. Cadence : relevé toutes les 15 à 30 min ; réflexion toutes les 2 à 3 h sur
`docs/research/FRICTIONS-ORCHESTRATION.md` (regrouper les frictions à 2 occurrences ou plus, proposer 3 améliorations
au plus à Paul, les déléguer).

Charger `platform-guardrails`. Tu orchestres ; tu ne codes pas les tickets toi-même. Dépôt PUBLIC : aucune valeur sensible nulle part.
Réponses en français, conclusion d'abord.

**Référence : `docs/ORCHESTRATION.md`** (topologie, cycle d'un ticket, découpage, capacités et limites mesurées,
recettes, anti-patterns). Ce skill donne la procédure ; en cas d'écart, `docs/ORCHESTRATION.md` fait foi.
Un seul orchestrateur, sur le Mac de Paul ; il DÉLÈGUE les écritures OKE à un seul agent « opérateur OKE » local à la
fois (seul écrivain cluster), et n'exécute jamais lui-même. Les couloirs de développement sont
des sessions cloud (`create_session` ou `claude --cloud`), des sous-agents en worktree ou l'usine.

## 1. Lire l'état (dans cet ordre, 5 minutes)
1. `git fetch origin && git merge origin/<ta branche>` puis `git merge origin/main` ; `git status` propre.
2. `docs/state/HANDOFF-COORDINATEUR.md` (procédures, décisions de Paul), `backlog/NEXT.md` (quoi lancer), `python3 tools/backlog/status.py` (vue d'état, non versionnée ; aussi dans le résumé du job CI `backlog`).
3. `python3 tools/backlog/priority.py --top 10` (file par score), `python3 tools/backlog/next.py` (prêts, classe, modèle recalculés).
4. PR et issues ouvertes (REST, voir §5) ; branches `worktree-agent-*` non intégrées : `git branch -a --no-merged`.
Statut dérivé (`backlog/README.md` § « Statut dérivé ») : cases + PR fusionnée (`Ticket: T-NNN`) ; il fait foi sur l'en-tête.
`python3 tools/backlog/priority.py --diff` liste les écarts ; le reste à faire d'un ticket = ses cases décochées.

## 2. Choisir
- Score (`tools/backlog/priority.py`) = tickets non terminés débloqués, directement ou transitivement ; départage : étape, petit périmètre, id. Un ticket `human` ou MANDAT passe après les tickets exécutables.
- `next.py` ne liste que les tickets dont les dépendances sont `done` et dont l'étape est ouverte. Pendant S0/S1 beaucoup de dépendances sont `in-progress` : compléter à la main avec `priority.py --all` et le jugement de `NEXT.md`.
- Garde de recouvrement avant tout lot : `python3 tools/factory/overlap.py --tickets T-a,T-b,...` (code 4 = recouvrement, 3 = périmètre non résolu). Points chauds jamais en parallèle : `ci.yaml`, `tools/dev/check`, `ci-map.tsv`, `CODEOWNERS`, `AGENTS.md`, `STATE.md`, `ROADMAP.md`.
- Classes (`platform-guardrails`) : AUTONOME et REVUE se délèguent (mode dev : merge après `ci-ok`) ; MANDAT = geste de Paul, rien à dispatcher, le dire dans le rapport.
- Modèles (ADR-0023) : R1 noyau/sensible (authz, VAP, secrets, cluster-agent, FINAL) = Opus `high` ; R2 texte hors noyau = Haiku `medium` + revue Sonnet ; R3 défaut = Sonnet `high`. Suivre le champ `model:` du ticket ; Sonnet suffit pour orchestrer.

## 3. Dispatcher
Numéros de tickets attribués avant le lancement ; branche `claude/t-NNN-<sujet>` (jamais `claude/issue-*` hors usine).
**Couloirs cloud (défaut pour paralléliser)** : un `create_session` par ticket (tag `t-NNN`, modèle du ticket, prompt
standard de `docs/ORCHESTRATION.md` §6). Suivi en mode tirer : `list_sessions`, `list_events`, `subscribe_pr_activity`
(une session « appareils de confiance » ne reçoit pas les `send_message` des sessions cloud).
**Petit lot disjoint sur ce dépôt (≤ 5 à 7 sous-agents)** : un sous-agent par ticket, `isolation: worktree`, en arrière-plan, modèle du ticket. Brief type : `docs/state/HANDOFF-COORDINATEUR.md` § « Brief type » (périmètre, `prior-art`, tests négatifs, ne pas pousser, trailers de commit, rapport). Ajouter la liste des fichiers interdits au brief.
**Sujet long ou parallélisme élevé : usine** (`.github/workflows/claude-agent.yml`, matrice `max-parallel: 3`, doc : `docs/CLOUD-AGENTS.md`).
1. Créer l'issue (label `agent:dev`) avec le contenu du ticket et un renvoi vers `backlog/T-NNN-*.md`.
2. Renseigner `github_issue: <n>` dans l'en-tête du ticket (même PR).
3. Vérifier `factory/PAUSE` absent, puis `gh workflow run claude-agent.yml -f tickets="<n1>,<n2>" -f model=<id> -f effort=<niveau>` (ou l'outil `actions_run_trigger`).
4. Relever par issue : branche, PR, coût, tours (artefact `mission-result-<n>`). Le planificateur refuse un lot en recouvrement.

## 4. Intégrer et fusionner
1. Une PR par ticket (branche du couloir). Lot de sous-agents seulement : `git merge --no-ff worktree-agent-<id>` dans la branche coordinateur. Conflits connus : liste `needs` de `ci-ok` (garder l'union), `backlog/README.md`, fichier du ticket (version la plus avancée).
2. Avant de pousser : `python3 tools/backlog/check.py` (0 erreur), `python3 -m unittest discover -s tests/backlog`, `python3 tools/quality/check.py` (cliquet), `python3 tools/backlog/roadmap.py`, puis `tools/dev/check --static --changed`. Jamais `seed.py`.
3. Pousser (jamais de force-push), PR en brouillon (gabarit `.github/pull_request_template.md`, section « Implémentations publiques consultées », verdict et niveau du check local).
4. Quand `ci-ok` est vert sur la tête courante : `update_pull_request` (`draft: false`) puis `merge_pull_request` (`squash`). La file de fusion ne lance pas les suites k3d tant que `K3D_REQUIRED` n'est pas posée : dispatcher `k3d-integration` avant de fusionner un changement de `platform/`, `tools/appgen/` ou des fixtures.
5. Effet sur le cluster : section « Preuve OKE demandée » dans la PR ; l'orchestrateur l'exécute après la fusion et archive la preuve datée.
5. Après la fusion : `git fetch origin main && git merge origin/main` ; la branche coordinateur repart de `main`.

## 5. Suivre
- Pas de boucle `gh api` (quota atteint une fois) : `git fetch`, abonnement aux PR, relevé toutes les 15 à 30 min.
- REST seulement : GraphQL est bloqué (`gh pr checks`, `gh pr view --json` échouent). `ci-ok` d'un commit : `gh api "repos/<owner>/<repo>/commits/<sha>/check-runs?per_page=50" --jq '[.check_runs[]|select(.name=="ci-ok")|.conclusion // "pending"]|first // "none"'`. Attendre avec l'outil Monitor et une boucle `until` espacée (≥ 60 s), jamais `sleep` seul.
- Abonner la session aux PR ouvertes (`subscribe_pr_activity`) ; se désabonner à la fusion ; `archive_session` du couloir terminé.
- Après chaque jalon : lignes « Reste » des tickets, `NEXT.md`, `docs/state/HANDOFF-COORDINATEUR.md` si une procédure change.

## 6. Skills externes utiles (T-481)
Copies vendorées de `mattpocock/skills` (MIT, SHA figé dans chaque en-tête, garde `tests/factory/external-skills-test.sh`) ; méthode, jamais permission : AGENTS.md et `platform-guardrails` priment.
- Brief d'un ticket de code : « lis `mattpocock-tdd` ; devant un échec, `mattpocock-diagnosing-bugs` ». L'usine ne lit aucun skill (décision de Paul) : ce brief ne s'applique qu'aux sous-agents locaux ; l'outil Skill n'y est pas autorisé.
- Revue d'une branche intégrée : `mattpocock-code-review` (axes Standards et Spec ; spec = fichier du ticket).
- Ticket qui touche `AGENTS.md`, un skill ou un prompt : `mattpocock-writing-for-agents`. Étude ou art antérieur long : `mattpocock-research` (en plus de `prior-art`). Arbitrage à poser à Paul : `mattpocock-grilling` (session interactive seulement).
- Conflits de fusion : pas de skill (retiré en amont, CHANGELOG 1.3.x) ; garder les règles du §4.
- Non vendorés : `prototype`, `domain-modeling` (conflit avec `docs/adr/`), `codebase-design`, `wizard` (les gestes de Paul passent par MANDAT), et les skills qui écrivent dans un suivi d'issues (`triage`, `to-tickets`, `setup-matt-pocock-skills`). Mise à jour : une PR qui relit le diff amont et change le SHA.

## 7. Pièges résolus
- Jeton fin personnel : écriture impossible dans le dépôt d'une organisation ; l'usine utilise une GitHub App.
- `actions/checkout` : `persist-credentials: false`, sinon le push d'un fichier de workflow est refusé.
- La sortie `branch_name` de l'action est vide quand l'agent ouvre sa PR : retrouver la branche par la PR qui cite l'issue.
- Les agents ne lisent pas les dépôts tiers avec `gh api` ; `git ls-remote` et `curl` sur `raw.githubusercontent.com` fonctionnent. Art antérieur indisponible = `NOT_TESTED`, jamais « aucune trouvée ».
- Un résultat n'est `PASS` qu'avec une preuve runtime datée ; STATIC n'est pas RUNTIME ; `NOT_TESTED` et `INCOMPLET` se disent.
- Un sous-agent qui rend « terminé » sans preuve par critère : ticket `in-progress`, ligne « Reste », case non cochée.
- Tester aussi hors root (`runuser -u nobody`), les runners ne sont pas root ; `jsonschema` à installer dans les jobs qui valident `mission-result.v1`.
- PR d'agent rouge pour un vrai défaut (ex. cliquet de qualité) : ne pas pousser sur sa branche ; un agent local la reprend, livre par ta branche ; fermer la PR du bot. Échec réseau : relancer une fois (`rerun_failed_jobs`).
- Les agents de l'usine ne mettent pas le ticket à jour : cocher les critères après leur fusion ; le statut suit seul (trailer `Ticket:`).
- `backlog/STATUS.md` n'est plus versionné : plus de conflit de fusion sur ce fichier.
- Un refus d'une garde n'est jamais à contourner : le signaler.
