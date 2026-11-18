# Reprise du coordinateur (session cloud) — 2026-11-18, soir

À lire en premier après une compaction ou par une nouvelle session coordinatrice. Ne contient aucun secret. Les prochaines étapes
sont dans `backlog/NEXT.md` (tenu à la main). Dépôt PUBLIC : aucune IP, OCID, e-mail, hôte interne ni détail de faille nulle part.

## Où on en est
- **Mode dev** (arbitrage de Paul) : sécurité allégée, les agents fusionnent après `ci-ok`, revue des code owners suspendue jusqu'à
  FINAL0. Seule compte la sécurité finale (FINAL0 puis FINAL). Plan : `docs/adr/` (0001-0024), `docs/review/CONSENSUS*.md`
  (arbitrages de Paul en fin de fichier, ils priment), `FABLE-ARBITRAGE.md`, ordre dans `backlog/ROADMAP.md`.
- **Fusionné dans `main`** : PR #54 (ADR), #55 (vague 1 de S0), #56 (CI plus rapide), #58 (quota, dette gitleaks, cliquet qualité),
  #59, #60, #61, #62 (exécutant, T-451, T-455, études), #63 (essai de l'exécutant, fusionnée par le bot).
- **PR ouverte : #64** (brouillon, branche `claude/cool-hamilton-r7aa5k`) : clôture de T-304, clôtures de tickets, T-459 à T-465, NEXT.md,
  ce handoff. La fusionner dès que `ci-ok` est vert (voir « Procédure de fusion »).
- **Exécutant prouvé de bout en bout (T-304, 2026-11-18)** : `claude-agent.yml` → jeton d'App → branche → PR par le bot → auto-merge →
  file de fusion → fusion. Preuve : `backlog/evidence/T-304-essai-executant-2026-11-18.md`.
- **Backlog** : 140 actifs, 0 erreur de `check.py`. Faits (`done`) : T-008, T-061/061b, T-072, T-302, T-304, T-306, T-326, T-330, T-413,
  T-414, T-430, T-450, T-453, T-454, T-455. En cours (`in-progress`, avec ligne « Reste » dans le ticket) : T-002, T-210, T-303, T-305,
  T-311, T-313, T-332, T-411, T-451, T-452.
- **Agents de développement en cours au moment du handoff** (worktrees `.claude/worktrees/agent-*`, branches `worktree-agent-<id>`, non poussées) :
  **T-331 hooks Claude Code** (branche `worktree-agent-a355401da01d8d28f`) : son rapport arrive à la session, l'intégrer comme ci-dessous.
  Déjà intégré (2026-11-18, commit `158bfe2`) : le reste de T-313 (job `agent-trailers` dans `ci.yaml` et `ci-ok`, commentaire de PR avec modèle,
  tours, coût, durée, refus ; résolution de la branche de l'agent ; tableau des runs dans la preuve de T-304). Non joué en vrai : tout dépend du
  prochain dispatch. Constat : la sortie `branch_name` de l'action est vide quand l'agent ouvre lui-même sa PR (branche `agent/…`), d'où `no_branch` ;
  le workflow retrouve maintenant la branche par la PR qui cite l'issue.

## Reprise : ce qu'il faut faire en arrivant
1. Lire `backlog/NEXT.md`. 2. `git fetch origin && git checkout claude/cool-hamilton-r7aa5k && git merge origin/main`.
3. Vérifier la PR #64 (`ci-ok`) et la fusionner. 4. Intégrer les deux agents en cours. 5. Lancer la **vague A** de NEXT.md en parallèle
(un sous-agent par ticket, voir « Brief type »), et le dispatch multi-issues de l'usine pour prouver T-311/T-313. 6. Mettre à jour les
tickets, `NEXT.md`, `ROADMAP.md` (`python3 tools/backlog/roadmap.py`), pousser.
Le modèle Sonnet suffit pour orchestrer ; déléguer à Opus les tickets R1-sensibles (authz, VAP, cluster-agent, secrets, FINAL) et les arbitrages.

## Procédure de fusion (outils de cette session)
- Les outils GitHub MCP fonctionnent ; **GraphQL est bloqué** (`gh pr checks`, `gh pr view --json` échouent) : utiliser REST
  (`gh api repos/platform-zephyr/openchoreo-lab/...`). L'API des secrets et des paramètres Actions est refusée par le proxy.
- État de `ci-ok` d'un commit : `gh api "repos/platform-zephyr/openchoreo-lab/commits/<sha>/check-runs?per_page=50" --jq '[.check_runs[]|select(.name=="ci-ok")|.conclusion // "pending"]|first // "none"'`
  (`none` tant que les autres jobs tournent). Surveillance : outil Monitor avec une boucle `until` (jamais `sleep` seul).
- Fusionner une PR : `update_pull_request` (`draft: false`) puis `merge_pull_request` (`merge_method: squash`). Après un squash, la
  branche `claude/cool-hamilton-r7aa5k` repart de `origin/main` : `git fetch origin main && git merge origin/main` puis continuer.
  Le force-push est refusé par la session : ne jamais en faire.
- Le ruleset impose la file de fusion (`merge_group`) : une PR d'agent avec auto-merge entre en file, la CI de la file tourne, puis fusion.
- Une PR par lot de travail, créée en brouillon (règle de la session), corps = gabarit `.github/pull_request_template.md` + « Implémentations publiques consultées ».

## Intégrer une branche d'agent
1. `git merge --no-ff worktree-agent-<id>` dans `claude/cool-hamilton-r7aa5k`. Conflits connus : `.github/workflows/ci.yaml` (liste `needs` de
   `ci-ok` : garder l'union), `backlog/README.md`, fichier du ticket (version la plus avancée).
2. `python3 tools/backlog/check.py` (0 erreur), `python3 -m unittest discover -s tests/backlog`, `python3 tools/quality/check.py` (cliquet),
   tests du ticket, `python3 tools/backlog/roadmap.py`, commit, `git push origin claude/cool-hamilton-r7aa5k`.
3. **Ne jamais régénérer le backlog avec `tools/backlog/seed.py`** (statuts édités à la main ; seed.py sera retiré par T-419).
4. Avant de pousser, lancer en local ce que la CI lance : `tools/dev/check --static --jobs 4` (outils : `tools/dev/cloud-setup.sh` puis
   `tools/dev/doctor`), et `python3 tools/quality/check.py`. Le cliquet refuse tout code neuf trop complexe et toute dégradation d'un
   fichier gelé (lignes, erreurs ruff/mypy) : garder les changements minimaux dans `tools/appgen/appgen.py` (1481 lignes max, ruff 8, mypy 12).

## Brief type d'un sous-agent de développement (parallélisation)
Un sous-agent par ticket, `isolation: worktree`, modèle = champ `model:` du ticket (Sonnet par défaut, Opus pour R1-sensible), en arrière-plan.
Le brief contient : dépôt public (aucune valeur sensible) ; `git fetch origin && git merge origin/claude/cool-hamilton-r7aa5k` d'abord ;
lire `AGENTS.md`, `backlog/README.md`, le ticket ; rester dans le périmètre ; charger le skill `prior-art` (art antérieur cité dans le commit) ;
tests avec cas négatifs ; ne toucher ni `STATE.md` ni `ROADMAP.md` ; `check.py` à 0 erreur ; `done` seulement si chaque critère est prouvé,
sinon `in-progress` avec les cases réellement cochées et une ligne « Reste » ; commit en français, auteur `noreply@anthropic.com`,
trailers `Co-Authored-By: Claude <modèle> <noreply@anthropic.com>` et `Claude-Session: <url de la session>` ; ne pas pousser ;
rendre compte (branche, commit, preuves, NOT_TESTED, gestes de Paul). Éviter deux tickets sur les mêmes fichiers dans une vague
(`ci.yaml`, `tools/dev/check`, `AGENTS.md` sont des points chauds). Plafond pratique : 5 à 7 agents locaux en parallèle ; l'usine (matrice
`max-parallel: 3`) s'y ajoute. Les agents ne peuvent pas lire les dépôts tiers avec `gh api` (refusé) : `git ls-remote` et `curl` sur
`raw.githubusercontent.com` fonctionnent.

## Usine 24/7 : lancer et comprendre l'exécutant
- Lancer : `gh workflow run claude-agent.yml -f tickets="<issues>" -f model=claude-sonnet-5-5 -f effort=high` (`-f debug=true` pour les journaux
  complets, jamais par défaut : journaux publics). Modèles : claude-haiku-5-5, claude-sonnet-5-5, claude-opus-5-5 ; efforts low…max (Sonnet ≤ xhigh).
- Une issue = un agent = une branche `agent/…` ou `claude/…` = une PR ; le résultat de chaque run : artefact `mission-result-<issue>`
  (modèle observé, tours, coût, `permission_denials` : noms d'outils seulement) ; un run sans branche sort `NOT_TESTED`. L'agent commente
  l'issue avec son compte rendu. Garde-fous : `factory/PAUSE`, plafonds par modèle, ledger de quota `tools/factory/ledger.py`.
- **Identité** : GitHub App `openchoreo-worker` (secrets `APP_ID`, `APP_PRIVATE_KEY`, jeton d'installation généré à chaque run, permission
  `workflows`) ; repli `FACTORY_GH_TOKEN` ; jeton Claude `CLAUDE_CODE_OAUTH_TOKEN` (abonnement Max, `claude setup-token`, valable un an).
  Registre : `docs/state/identities.yaml` (noms seulement).
- **Pièges résolus** : (1) un jeton fin personnel ne peut pas écrire dans le dépôt d'une organisation → App d'organisation ; (2) `actions/checkout`
  persiste le `GITHUB_TOKEN` dans un fichier `includeIf` que `claude-code-action` ne nettoie pas, il prime sur le jeton de l'App et le push d'un
  fichier de workflow est refusé → `persist-credentials: false` (issue amont anthropics/claude-code-action#1510) ; (3) le prompt de l'exécutant est
  aligné sur le mode dev ; outils autorisés : `gh issue view/comment`, `gh pr create/view/checks`, `gh pr merge --auto --squash`.
- Preuves restantes de l'usine : dispatch de plusieurs issues en parallèle, `factory/PAUSE` posé, `check-trailers` dans `ci.yaml`, essai du skill
  `prior-art` sur un ticket `complet` (T-311, T-313, T-411).

## Décisions de Paul à connaître (elles priment sur les anciens documents)
- Control plane OpenChoreo sur le homelab (VM Talos « lab »), OKE optionnel ; mono-cluster pour la porte ; **pas de fork d'OpenChoreo** : tag stable
  1.3.3 épinglé + couche « security bundle » privée et temporaire (sortie du bundle quand l'amont corrige ; `docs/SECURITY-BUNDLE.md`, ADR-0016/0020).
- k3d **désactivé** (lancement manuel) pendant le dev : D-1 à D-6 acceptées (ADR-0002 §4 amendé, T-435 en FINAL0, T-339 réduit, réactivation
  nocturne non bloquante à la fin de S1 avant T-364, alerte par le dispatcher T-314 sans issue GitHub, B-09 en KNOWN_FAIL, label `k3d` autorisé).
  Corrections ouvertes : T-456 (clé ESO `lab-pg-roles/<nom>`, vrai défaut de l'archétype B), T-457, T-458. Étude : `docs/research/K3D-REACTIVATION.md`.
- Dev uniquement avec Claude (DeepSeek plus tard). Routage ADR-0023 : R1-sensible Opus, R2 texte Haiku + revue Sonnet, R3 Sonnet.
- Setup de dev « shift-left » : `docs/research/SHIFT-LEFT-DEV-ENV.md` (niveaux L0-L6, commande unique `tools/dev/check` avec `--file`, `--fast`,
  `--changed`, `--jobs`, reçu). Tickets restants : T-459 (pre-commit), T-460 (parité CI), T-461, T-462, T-463, T-464, T-465 ; SL-5 = T-331.
- Art antérieur obligatoire avant de coder (ADR-0024, skill `prior-art`) ; maintenabilité par le cliquet `tools/quality/check.py`.
- Pas de réponse sur les sujets réseau/secrets dans le dépôt : ntfy, Doppler/OpenBao, etc. restent dans les ADR.

## Gestes attendus de Paul
Liste maintenue dans `backlog/NEXT.md` (section « Gestes de Paul ») : script de setup cloud (`tools/dev/cloud-setup.sh`), tag `core-baseline`
(annoté, à signer avant FINAL0), réglages d'organisation GitHub (T-434, `docs/research/GITHUB-CONFIG.md` §7), dates du registre des identités,
pause du moteur horaire Atlas pendant le pilote, `/usage` à 0/24/48 h, palier N et Max ou Ultra après le pilote, `lab.internal` fictif ou non,
FINAL0 (Apps définitives T-215, retrait du contournement admin T-400).

## Points de vigilance
- `.claude/settings.json` (T-330) refuse `kubectl`, `helm`, `tofu`, la lecture d'identifiants, `env` et le push forcé dans ce dépôt.
- Dépôt public : jamais de valeur sensible dans un commit, une PR, un journal ou un rapport ; la dette historique (anciennes valeurs dans l'historique
  git) n'est purgée que par la réécriture d'historique de Paul (T-301). `leak-guard` (T-303) tourne en CI et en local (`tools/dev/leak-guard.sh`).
- Ne pas désactiver ni contourner admission, PSA ou NetworkPolicy pour faire passer un test. Périmètre cluster : `openchoreo-*` et `lab-*`.
- Un statut « PASS » exige une preuve runtime datée ; STATIC n'est pas RUNTIME ; k3d n'est pas OKE.
