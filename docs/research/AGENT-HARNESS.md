---
owner: paul
updated: 2026-11-18
review_days: 30
---
# Environnements de dev des agents et « harness engineering »

Date : 2026-11-18. Proposition seulement (aucun cluster touché, aucun secret ; dépôt PUBLIC). Légende des sources : **[V]** lu le 2026-11-18 sur la source primaire ; **[NV]** non vérifié (hôte bloqué ou non lu : à relire avant de décider) ;
**[E]** estimation de l'auteur. Tickets proposés : `backlog/proposals/harness.yaml` (clés HAR-n).

## 0. Conclusion
1. Trois niveaux d'environnement suffisent : **N0 statique** (sans cluster, partout), **N1 k3d jetable en CI** (runner arm64 hébergé), **N2 cluster dev homelab**
   (réel, x86_64, atteint seulement par GitOps). Chaque niveau a une preuve de niveau STE80 différent (STATIC, CI, RUNTIME) ; aucun n'est « OKE » (§3).
2. Le **harness** (hooks, permissions, `check` unique, definition of done exécutable) doit rendre l'erreur impossible ou bruyante **avant** la PR ; la vraie
   frontière reste côté GitHub (CODEOWNERS, ruleset, `ci-ok`), car les hooks ne tournent pas dans tous les contextes cloud (§2.1).
3. Le dépôt n'a **aucun** `.claude/settings.json`, aucun hook, aucun sous-agent : tout le « harness » repose sur du texte (AGENTS.md) alors que la doc dit
   qu'une règle sans exception doit être un hook ou une règle `deny` [V][S1]. C'est l'écart n°1.
4. Le workflow `claude-agent.yml` autorise `Bash(python3:*)` et `Bash(git:*)` : l'un exécute du code arbitraire avec les variables du job, l'autre élargit la
   surface d'écriture. La doc de l'action déconseille les règles larges [V][S9]. À resserrer (HAR-3).
5. Sans **banc d'essai** de tâches de développement, on ne sait ni quel modèle confier à quel ticket, ni si un changement du harness améliore ou dégrade
   (Anthropic : 20 à 50 tâches issues d'échecs réels suffisent pour commencer [V][S7]). C'est l'écart n°2 (HAR-16).
6. DeepSeek : Anthropic **ne supporte pas** le routage de Claude Code vers des modèles non-Claude [V][S10] ; DeepSeek documente un point d'accès compatible (`/anthropic`,
   `mcp_servers` ignoré, noms `claude-*` remappés vers ses modèles) [V][S21] : voie à part, admise par le banc, jamais sur le noyau (HAR-20).
7. Piège d'architecture : le homelab est **x86_64**, OKE et les runners GitHub ARM sont **arm64**, la VM cloud Claude Code est **x86_64** [V][S3]. Une preuve
   homelab ne prouve pas l'arm64 : le N1 arm64 reste la preuve de référence des images.

## 1. Environnements reproductibles
### 1.1 Cloud Claude Code (sessions et environnements) [V][S3][S4]
- VM neuve par session : Ubuntu 24.04 **x86_64**, 4 vCPU, 16 Go RAM, 30 Go disque ; Docker, `gh`, Postgres/Redis préinstallés. Pas de frais de VM, mais les
  quotas de l'abonnement sont partagés entre sessions parallèles.
- **Script d'installation** : Bash root, avant le lancement de Claude ; mis en cache (instantané du disque) s'il finit en ~5 min ; rejoué à chaque changement du
  script ou des hôtes autorisés, et à l'expiration (~7 jours). Les processus (`docker compose up`, k3d démarré) ne sont **pas** conservés ; images et fichiers, si.
- **Réseau** : « Limited » par défaut (registres de paquets, GitHub), liste d'hôtes par environnement, pas de liste d'organisation. **Secrets réseau** : le proxy
  injecte la clé sur l'hôte voulu, la VM ne la voit pas ; les variables d'environnement, elles, sont lisibles par tout utilisateur de l'environnement.
  GitHub passe par un proxy qui porte le jeton hors de la VM.
- **Réglages** : `.claude/settings.json` n'est lu que dans une session à un seul dépôt ; **jamais** dans un thread de projet (permissions, hooks, env) ; les
  fichiers `~/.claude` et `settings.local.json` ne sont pas lus. Seuls les réglages gérés par le serveur traversent [V][S5].
- Expiration d'inactivité : l'historique revient, pas les commandes en cours → **push fréquents** (§2.5).
- `claude -p --bare` ne lit ni hooks ni CLAUDE.md ; sans `--bare`, `-p` exécute hooks et MCP du dépôt même non approuvé [V][S6].
### 1.2 Conteneur de dev (`.devcontainer/`, `tools/dev/dev`)
Déjà : base par digest, outils épinglés par sha256, 1 vCPU/1 Go, `--cap-drop=ALL`, aucun identifiant monté (`docs/DEV-FACTORY.md`). Écarts : image jamais
construite (NON EXÉCUTÉ), agent hors du conteneur (seules les commandes y sont), dépend de Colima/Mac. Parité à garantir : **une seule liste d'outils** (versions +
sha) lue par Dockerfile, `ci.yaml` et script du cloud (HAR-2), vérifiée par test (la concordance Dockerfile-CI existe déjà).
### 1.3 Runners GitHub
| Option | Faits | Usage |
|---|---|---|
| Hébergés `ubuntu-24.04-arm` | Déjà utilisés par `ci.yaml`. Dépôt public : 4 vCPU, 16 Go RAM, 14 Go SSD, arm64 [V][S17] (2 vCPU/8 Go en privé) ; tarif arm64 2 cœurs 0,005 USD/min, hors quota public [V][S18] ; Docker présent donc k3d possible. Disque 14 Go : images à compter | N1 (k3d, CI) |
| Auto-hébergés ARC (scale set) | Contrôleur Helm + listener ; pods runner éphémères à jeton JIT ; réduction à zéro pod [V][S11]. Modes `dind`/`kubernetes` : détail non lu [NV] | **Par défaut : non** (voir ci-dessous) |
| Risque dépôt public | GitHub : les runners auto-hébergés « ne devraient presque jamais être utilisés pour des dépôts publics » (PR de n'importe qui, compromission persistante possible) ; recommande des runners JIT éphémères [V][S19] | Spike HAR-13 : groupe restreint aux workflows de `main`, JIT, sans secret ; sinon pas de runner homelab |
Contrainte : **k3d exige Docker** [V][S12] donc `dind` privilégié, contraire à la PSA restricted du homelab → k3d reste sur runners hébergés. Le N2 se pilote sans
runner : Job PostSync/CronJob dans le cluster qui publie la preuve (T-005). Coût : frais de plateforme auto-hébergés (0,002 USD/min) annoncés puis **reportés** par
GitHub, gratuits en dépôt public [V][S20] ; électricité du homelab. Inspiration : ARC déjà exploité par homelab-infra (un groupe de concurrence par état,
workflows de `main`) ; ne pas partager le scale set d'OpenTofu (frontière de dépôt).
### 1.4 Cluster jetable
| Outil | Faits | Rôle ici |
|---|---|---|
| k3d | k3s dans Docker, multi-nœuds, Docker ≥ 20.10.5 [V][S12] | N1 : un cluster par job PR, détruit à la fin |
| vcluster | API server/CRD/RBAC propres ; mode « nœuds partagés » pour dev/test ; `--driver docker` pour CI [V][S13]. Surcoût mesuré : aucun chiffre publié | N2 : isolation par agent/PR sur le cluster dev (à mesurer, HAR-12) |
Mémoire d'un cluster OpenChoreo complet en k3d : **NON MESURÉ** (voir tests/k3d/RESULTS.md) ; budget [E] ≤ 3 Go.
### 1.5 Fixtures, mocks, données synthétiques
Règle : **vrai si léger, factice si lourd**. ntfy : vrai (image minuscule). Authentik : serveur OIDC factice (découverte + jeton, claims de test). Grafana/Loki :
API factice rejouant des réponses enregistrées. OpenChoreo : CRD seules sur k3d (le MCP lit des réponses enregistrées) ; le vrai plan de contrôle reste N2/OKE.
Données : générateur déterministe (graine fixe), aucune donnée personnelle, utilisé par fixtures et banc (HAR-8). Un fixture = `up.sh`, `health.sh`, `README` ;
un test qui dépend d'un fixture le déclare dans le registre de suites (T-216).

## 2. Harness engineering
### 2.1 Ce qui est déterministe, ce qui ne l'est pas [V][S1][S2][S6]
| Mécanisme | Garantie | Limite |
|---|---|---|
| `CLAUDE.md`/AGENTS.md | contexte, « presque toujours suivi » | l'agent peut décider qu'une ligne ne s'applique pas ; < 200 lignes recommandé |
| Hook `command`/`http` PreToolUse, exit 2 | bloque l'appel (même si JSON dit « allow ») | non lu en thread de projet cloud ; `deny` seul, jamais d'approbation silencieuse |
| Hook PostToolUse | feedback (stderr vu par Claude) | **ne peut pas bloquer** : l'outil a déjà tourné |
| Hook Stop, exit 2 | empêche de finir : « definition of done » | débloqué après 8 blocs consécutifs (`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`) |
| Hooks `prompt`/`agent` | un autre modèle décide : non déterministe | jamais pour une règle sans exception |
| `permissions.deny`, mode `dontAsk`, sandbox (bubblewrap) | OS ou moteur de règles | hooks, MCP locaux et outils Read/Edit/WebFetch hors sandbox ; `dangerouslyDisableSandbox` à interdire (`allowUnsandboxedCommands:false`) |
| CODEOWNERS + ruleset + `ci-ok` | frontière imposée par GitHub | seule garantie valable quel que soit le client (Claude, DeepSeek, Codex) |
Conséquence : **trois couches** — (a) hooks locaux pour le retour rapide, (b) CI pour la preuve, (c) GitHub pour la frontière. Le noyau `.claude/` est protégé par
CODEOWNERS et restauré depuis `main` par l'action sur les PR [V][S9] : un agent ne réécrit pas son propre harness.
### 2.2 Hooks à poser (HAR-1)
- **PreToolUse `Bash`** : refus `kubectl|helm|oc|occ` vers un cluster, `curl|sh`, `git push --force`, `git commit --no-verify`, `rm -rf` hors worktree.
- **PreToolUse `Edit|Write`** : refus hors périmètre du ticket (`Périmètre de fichiers`), refus de `generated/**`, du noyau CODEOWNERS sans ticket REVUE.
- **PostToolUse `Edit|Write`** : yamllint/`appgen validate` sur le fichier touché (retour en < 5 s).
- **Stop** : `tools/dev/check --static` ; échec → exit 2 avec la sortie en stderr. Journal long : rediriger vers fichier, lire par morceaux (profil Atlas).
- **SessionStart** : affiche ticket, branche, dernier CI, `git log -5`, `guard-check` ; calqué sur le « routine de démarrage » d'Anthropic [V][S8].
Chaque hook a un test (`tests/hooks/` : JSON sur stdin → code de sortie) en CI.
### 2.3 Definition of done exécutable (HAR-7)
Les critères de fin sont aujourd'hui des cases prose. Ajouter par critère `verify:` (commande, code 0 = PASS, sortie JSON datée) ; `tools/backlog/done.py T-NNN`
écrit `backlog/evidence/T-NNN.json` ; la CI refuse `status: done` sans preuve PASS. Un critère sans commande est `NOT_TESTED`, jamais PASS. Même idée que la liste
de fonctionnalités JSON d'Anthropic, dont seul le champ `passes` est modifiable par l'agent [V][S8].
### 2.4 Skills, sous-agents, contexte
- Skills : 9 existent ; ajouter `fix-ci`, `new-fixture`, `run-bench`, `resume-ticket` (HAR-17), descriptions courtes (chargées en permanence).
- Sous-agents (`.claude/agents/`, YAML : `tools`, `model`, `isolation: worktree`, `hooks`, `maxTurns`) [V][S14] : `reviewer` (lecture seule, contexte neuf, compare
  diff, critères du ticket et garde-fous ; boucle évaluateur-optimiseur [V][S15]), `ci-triager` (haiku : lit les journaux, rend une cause). Un sous-agent de plugin
  ignore hooks et `permissionMode` : définir en projet. Profondeur par défaut 3, 20 en parallèle : plafonner à 1 niveau.
- Contexte : T-041 (≤ 130 lignes). Rien de plus dans AGENTS.md : hooks et skills.
### 2.5 Échecs et reprise
Modèle Anthropic : agent d'initialisation + fichier de progression + une fonctionnalité par session + commits fréquents [V][S8]. Ici : ticket = liste de
fonctionnalités ; PR brouillon = journal de progression (STE80 : Objective/Status/Changes/Evidence/Blockers/NextAction) ; **push WIP à chaque jalon** (la VM cloud
peut expirer) ; `max_attempts: 2` (contrat Atlas) ; reprise par `claude --resume <id>` ou relance qui lit PR + branche. Classes d'échec : CI rouge (réparable),
hors périmètre (refus du hook), outil indisponible (BLOCKED), ambiguïté (question dans la PR, jamais de supposition). Une 2e tentative échouée → `blocked`
avec `Bloqué par :` (HAR-10).
### 2.6 Évaluation et amélioration (HAR-16, 19, 21, 22) [V][S7]
- **Banc** : 20 à 30 tâches tirées de vrais tickets/échecs (correctif appgen, check CI, doc, diagnostic d'incident, changement `platform/`), chacune avec solution
  de référence, **grader par code** (tests, `appgen check`, `kubeconform`), cas où l'agent **ne doit pas** agir (noyau, secret). Environnement neuf par essai
  (worktree + conteneur) : l'historique git laissé par un essai a déjà faussé un score chez Anthropic. 0 % sur beaucoup d'essais = tâche cassée, pas agent faible.
- **Mesures** : pass@1, **pass^3** (fiabilité), coût (`total_cost_usd` en sortie JSON [V][S16]), tours, durée ; par type de ticket, étape et modèle.
- **Boucle** : échec réel → lire la transcription → classer (contexte, outil, hook manquant, test faible, tâche mal posée) → corriger **au bon étage** (hook > test >
  skill > AGENTS.md) → ajouter la tâche au banc. Une faute vue 2 fois devient un hook ou un test. Revue mensuelle (HAR-22).
- **Canari** : banc réduit chaque nuit sur `main` ; version de Claude Code et de l'action épinglées, montée de version conditionnée au banc (HAR-19).
### 2.7 Isolation et sécurité des agents
1. Identité : compte Write + GitHub App (T-215) ; aucun agent avec le compte de Paul. 2. Réseau : environnement cloud « Limited » + secrets réseau ; aucun kubeconfig,
Doppler, OCI. 3. Permissions : `deny` + `dontAsk` + sandbox ; liste d'outils étroite (`Bash(python3 tools/appgen/*)`, pas `python3:*`). 4. Entrées non fiables :
corps d'issue et PR de tiers = injection (l'action nettoie mal HTML/Unicode caché, « nouveaux contournements possibles ») [V][S9] ; seul Paul pose `agent:dev` (déjà).
5. Sorties : `show_full_output` désactivé (journaux publics), transcriptions non publiées, garde de fuite gitleaks + motifs internes (HAR-6).
6. Budget : `--max-turns`, `--max-budget-usd`, plafond 4 sessions (T-145). 7. Runner homelab éventuel : JIT, sans secret, `main` seulement.

## 3. Architecture recommandée (un environnement par niveau)
| Niveau | Où | Contenu | Qui l'utilise | Preuve | Budget |
|---|---|---|---|---|---|
| **N0 statique** | cloud Claude Code, conteneur dev, runner hébergé | `tools/dev/check --static` : yamllint, appgen, kubeconform, gitleaks, tests unitaires, hooks | tout agent, boucle interne et Stop | STATIC | < 3 min, 0 cluster |
| **N1 k3d CI** | runner `ubuntu-24.04-arm` hébergé ; aussi cloud x86 pour itérer | cluster jetable + fixtures + CRD ; suites choisies par chemins (registre T-216) | PR touchant `platform/`, `tools/`, golden path | CI (arm64) | ≤ 15 min, 1 cluster/PR, détruit |
| **N2 dev homelab** | Talos x86_64, namespaces `lab-*`, vcluster par PR (si le spike le confirme) | OpenChoreo réel, Argo, previews TTL, banc nocturne | `main`, previews ; **agents en lecture seule**, écriture par GitOps | RUNTIME (homelab) | ≤ 2 previews, TTL 24 h |
| OKE prod | Oracle A1 | environnements development/production (ADR-0004) | preuve PostSync (T-005) | RUNTIME (OKE) | 70 % de l'allocatable |
Règles : un PASS cite son niveau ; **k3d ≠ homelab ≠ OKE**, x86 ≠ arm64 (digests multi-arch obligatoires) ; N2 n'ouvre aucun accès kubectl aux agents (lecture par
sondes publiées, comme T-005) ; promotion N0 → N1 → N2 → OKE par PR, jamais par commande.
Parallélisme sans casse : 1 ticket = 1 branche = 1 worktree ; chevauchement refusé par le dispatcher (HAR-5) ; couloirs T-210 ; appgen modulaire (T-214) ; point chaud
`lab-apps.yaml` supprimé + file de fusion (HAR-14) ; `generated/` régénéré après rebase.
Modèles : **haiku** (triage de CI, exploration, lint de doc), **sonnet** (implémentation courante), **opus** (spikes d'architecture, noyau, sécurité) ; DeepSeek
seulement N0, hors noyau, après admission par le banc.

## 4. Ce qui manque au backlog (→ tickets HAR)
Hooks et permissions (HAR-0, 1), `check` unique (2), workflow durci (3), environnement cloud (4), chevauchement de périmètres (5), garde de fuite (6), DoD exécutable (7),
fixtures (8), k3d par PR (9), échec/reprise (10), sous-agents (11), cluster dev et runners (12, 13), fin du point chaud (14), agent en conteneur (15), banc (16), skills
(17), previews (18), canari (19), DeepSeek (20), scorecard (21), boucle d'amélioration (22). Liens : T-145, T-167, T-168, T-201 ; T-044/T-077 couvrent les tâches
*utilisateur*, le banc HAR-16 mesure les tâches de *développement*.

## 5. Proposition d'ADR (à copier en `docs/adr/0021-harness-environnements-agents.md` après approbation de Paul)
```markdown
# ADR-0021 — Harness et environnements de dev des agents
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0004, ADR-0011, ADR-0012, ADR-0018 ; consensus du 2026-11-18

## Contexte
- Des agents Claude Code (cloud, runners GitHub) et à terme DeepSeek développent la plateforme ; le dépôt est public ; un seul cluster OKE.
- Le dépôt ne contient aucun hook ni réglage `.claude/` ; le workflow d'agent autorise des commandes larges ; aucune mesure de réussite par type de ticket.
- Le homelab est x86_64 ; OKE, les runners GitHub ARM et l'objectif d'images sont arm64 ; la VM cloud est x86_64.

## Décision
1. Trois niveaux d'environnement : N0 statique (sans cluster), N1 k3d jetable en CI (runner arm64 hébergé), N2 cluster dev homelab. Un PASS cite son niveau ;
   aucun niveau ne vaut OKE.
2. Une commande unique `tools/dev/check` est la definition of done technique : même code dans le hook Stop, la CI, le conteneur et l'environnement cloud.
3. Trois couches de garde : hooks locaux (retour rapide), CI (preuve), GitHub CODEOWNERS/ruleset (frontière). Une règle sans exception est un hook ou une règle
   `deny`, jamais une phrase d'AGENTS.md. `.claude/` et le workflow d'agent font partie du noyau.
4. Les agents n'ont aucun accès kubectl, Doppler ou OCI ; le N2 s'atteint par GitOps et se lit par sondes publiées. Pas de runner auto-hébergé sur ce dépôt public,
   sauf runners JIT éphémères sans secret, limités aux workflows de `main` (GitHub : « presque jamais » en dépôt public) ; k3d reste sur runners hébergés.
5. Un ticket est `done` seulement avec une preuve générée par `done.py` (commandes `verify:` des critères).
6. Un banc de tâches de développement (graders par code, essais en environnement neuf) décide du modèle par type de ticket et garde le harness ; toute montée de
   Claude Code, de l'action ou du harness passe par le banc. Une voie modèle non-Claude (DeepSeek) n'est admise que sur critère du banc, hors noyau.
7. Un périmètre de fichiers par ticket, vérifié avant lancement (chevauchement refusé) et pendant l'exécution (hook).

## Conséquences
- Coûts : écrire hooks et tests de hooks, maintenir un banc (~25 tâches), un cluster dev homelab (RAM à mesurer), minutes CI.
- Les agents perdent des commandes (python3 large, git large) ; ils gagnent un retour rapide et moins d'aller-retours de revue.
- Hooks non garantis en thread de projet cloud : la CI reste la preuve ; le harness local est un accélérateur.

## Alternatives écartées
- Tout en texte (AGENTS.md) : suivi non garanti. Cluster partagé unique : collisions. k3d sur le homelab : Docker privilégié (PSA). kind : redondant. Hooks `prompt` : non déterministes.

## Vérification
- `tests/hooks/` (entrées → sorties), `done.py` en CI, banc : pass@1 et pass^3 par type publiés ; chevauchement refusé par `next.py` (cas négatif) ;
  `check` identique dans les 4 contextes (test de concordance) ; aucun `kubectl` autorisé dans `.claude/settings.json` (test).

## Références : docs/research/AGENT-HARNESS.md, backlog/proposals/harness.yaml
```

## 6. Sources
- [S1] https://code.claude.com/docs/en/hooks — événements, types, codes de sortie, `permissionDecision` [V]
- [S2] https://code.claude.com/docs/en/best-practices — vérification, hook Stop, CLAUDE.md court, parallélisme [V]
- [S3] https://code.claude.com/docs/en/cloud-environments — VM, script, cache, réseau, secrets réseau, Docker [V]
- [S4] https://code.claude.com/docs/en/claude-code-on-the-web — isolation, proxy GitHub, limites, expiration [V]
- [S5] https://code.claude.com/docs/en/settings — « Settings in cloud sessions », précédence [V]
- [S6] https://code.claude.com/docs/en/headless et /sandboxing — `-p`, `--bare`, JSON, bubblewrap, limites [V]
- [S7] https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents — graders, pass^k, 20-50 tâches, environnement neuf [V]
- [S8] https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents — initialiseur, progression, JSON de fonctionnalités [V]
- [S9] https://github.com/anthropics/claude-code-action/blob/main/docs/security.md — droits, `.claude/` restauré, règles larges, journaux [V]
- [S10] https://code.claude.com/docs/en/llm-gateway — passerelles ; modèles non-Claude non supportés [V]
- [S11] https://github.com/actions/actions-runner-controller (scale sets) — éphémères, zéro pod [V]
- [S12] https://github.com/k3d-io/k3d ; [S13] https://github.com/loft-sh/vcluster ; [S14] https://code.claude.com/docs/en/sub-agents [V]
- [S15] https://www.anthropic.com/engineering/building-effective-agents ; [S16] https://www.anthropic.com/engineering/writing-tools-for-agents [V]
- Repo : `docs/DEV-FACTORY.md`, `docs/AGENT-RUNNERS.md`, `claude-agent.yml`, Atlas `dispatcher/`, homelab-infra `docs/operations/plt-163-arc-apply-promotion.md`.
- [S17] https://docs.github.com/en/actions/reference/runners/github-hosted-runners ; [S18] .../billing/reference/actions-runner-pricing ; [S19] .../actions/reference/security/secure-use [V]
- [S20] https://github.blog/changelog/2025-12-16-coming-soon-simpler-pricing-and-a-better-experience-for-github-actions/ [V]
- [S21] https://api-docs.deepseek.com/guides/anthropic_api et /quick_start/ (Claude Code) [V, lus par curl]
- **Non lus** : modes `dind`/`kubernetes` d'ARC, article OpenAI « harness engineering » (WebFetch bloqué ; le shell a un accès réseau : à relire).
