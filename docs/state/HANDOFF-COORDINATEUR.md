# Reprise du coordinateur (session cloud) — 2026-11-18, fin d'après-midi

À lire en premier après une compaction ou par une nouvelle session coordinatrice. Ne contient aucun secret. Dépôt PUBLIC : aucune IP, OCID,
e-mail, hôte interne ni détail de faille nulle part. **Point d'entrée opérationnel : le skill `orchestrate-backlog`** (`.agents/skills/`) ; ce
document donne l'état, les décisions de Paul et les pièges. Les prochaines étapes : `backlog/NEXT.md` ; l'état de chaque ticket : `python3 tools/backlog/status.py`
(statut dérivé des cases et des PR fusionnées ; `STATUS.md` n'est plus versionné) ; l'ordre de travail : `python3 tools/backlog/priority.py --top 10`.

## Où on en est
- **Mode dev** (arbitrage de Paul) : sécurité allégée, les agents fusionnent après `ci-ok`, revue des code owners suspendue jusqu'à FINAL0.
  Seule compte la sécurité finale (FINAL0 puis FINAL). Plan : `docs/adr/` (0001-0024), `docs/review/CONSENSUS*.md` (arbitrages de Paul en fin de
  fichier, ils priment), `backlog/ROADMAP.md`.
- **L'usine d'agents (`.github/workflows/claude-agent.yml`) est prouvée en vrai** : lot `86,87` (run 44338002716) = 2 agents en parallèle, les deux PASS
  (28 et 17 tours, 0,51 $ et 0,37 $, aucun refus de permission), PR ouvertes par le bot (`openchoreo-worker`), auto-merge armé, fusion par la file.
  Chaîne : plan (garde de recouvrement, disjoncteur de quota, PAUSE) → job `dev` (hook git des trailers, issue dans le prompt, plafonds de tours
  et de coût) → Verdict → job `report`. Preuves datées dans `backlog/evidence/` et dans les lignes « Reste » de T-311, T-313, T-466, T-467, T-474, T-478.
- **Fusionné aujourd'hui** (PR #64 à #91) : exécutant durci (T-466 Verdict, T-467 garde de recouvrement et disjoncteur, T-474 trailers par hook,
  T-478 plafonds natifs), hooks Claude Code (T-331), pre-commit (T-459), CI consolidée (T-475 : `--only`, `status.py --check`, tests de l'usine,
  historique de qualité), tests des outils backlog (T-418), identités (T-183), gestes de Paul (T-325), qualité (T-421, T-461), vue `STATUS.md` et score
  de priorité (T-473, T-476), étude des usines existantes (T-477 : `docs/research/FACTORY-PRIOR-ART.md`), k3d (T-456, T-457, T-458 en partie).
- **En file ou en cours au moment du handoff** : PR #89 (T-480, garde de taille des tickets, agent de l'usine, dans la file de fusion). Après sa
  fusion et celle de la PR #90 (T-479, `stats.py`, déjà fusionnée), **cocher T-479 et T-480** (les agents de l'usine ne mettent pas le ticket à jour :
  statut resté `todo`) puis régénérer `STATUS.md`.
- **Backlog** : ~132 actifs, 0 erreur de `check.py`. Les `in-progress` portent chacun une ligne « Reste » (T-002, T-210, T-303, T-305, T-311, T-313,
  T-332, T-411, T-451, T-452, T-458, T-460, T-461, T-466, T-467, T-470, T-478, T-479, T-480…).

## Reprise : ce qu'il faut faire en arrivant
1. Charger le skill `orchestrate-backlog` ; lire ce document, `backlog/NEXT.md`, la sortie de `python3 tools/backlog/status.py`.
2. `git fetch origin main && git checkout -B claude/cool-hamilton-r7aa5k origin/main` (la branche du coordinateur est supprimée à chaque fusion :
   `delete_branch_on_merge` est actif ; la repousser recrée la branche).
3. Vérifier la PR #89 (file de fusion) ; clôturer T-479 et T-480 ; relever le coût réel des runs avec `python3 tools/factory/stats.py` (T-479).
4. Choisir le prochain lot avec `priority.py --top 10` et `overlap.py` ; **mélanger** : petits tickets en lot de sous-agents locaux Sonnet (rapide,
   sans coût de démarrage), sujets longs ou sensibles à l'usine ou en Opus local.
5. Arbitrer avant FINAL0 (ticket à créer) : le mode de permission de l'action (`auto` par défaut = `allowedTools` n'est pas une liste blanche stricte).

## Pièges résolus aujourd'hui (à ne pas redécouvrir)
- **Tester aussi hors root** : la session coordinatrice est root, les runners ne le sont pas (fichiers en lecture seule non effaçables, permissions).
  Reproduire avec `runuser -u nobody -- env HOME=/tmp/x bash tests/...` sur une copie (`git ls-files | cp --parents`).
- **`tools/dev/check` affiche d'abord les lignes `FAIL`** des tests de l'usine (avant : les `PASS` suivants les noyaient). `jsonschema` doit être
  installé dans les jobs qui valident `mission-result.v1` (job `dev-factory`).
- **Le cliquet de qualité** (`python3 tools/quality/check.py`) refuse une fonction neuve de complexité > 15 et toute dégradation ruff/mypy : un agent
  qui l'ignore voit sa PR rouge (cas : PR #84, corrigée par un agent local puis livrée par la branche du coordinateur). Le prompt de l'exécutant
  impose maintenant de le lancer avant de livrer (T-478).
- **Trailers de commit** : ne jamais compter sur le modèle ; `tools/factory/commit-trailers.sh` les injecte par hook git (T-474) ; `check-trailers`
  juge. Un `git -c core.hooksPath=…` ou `commit-tree` reste un contournement possible (suite : durcir le garde Bash, T-331).
- **Échecs réseau de la CI** (`platform-render` : téléchargement de chart `connection reset`) : relancer les jobs en échec **une fois**
  (`actions_run_trigger` méthode `rerun_failed_jobs` avec l'id du run `ci` de la PR, trouvé par `gh api actions/runs?head_sha=…`).
- **PR d'agent rouge pour un vrai défaut** : ne pas pousser sur sa branche ; un agent local reprend la branche (`git merge origin/claude/issue-…`),
  corrige, livre par la branche du coordinateur ; fermer la PR du bot.
- **Branche d'une PR fermée non supprimée** : le nom `claude/issue-<n>-<slug>` reste ; l'agent en choisit un autre au relancement (ok) ; sinon Paul la supprime.
- **`STATUS.md` en conflit** : n'existe plus ; le fichier n'est plus versionné (vue publiée par le job CI `backlog`).
- **Ticket resté `in-progress` cases cochées et PR fusionnée** (cas T-214) : le statut se dérive (cases + trailer `Ticket:`) ;
  `check.py` signale l'en-tête périmé (`STATUT-DÉRIVÉ`), `priority.py` et `next.py` suivent le calcul.
- **Agents de recherche** : `git clone` d'un dépôt tiers est refusé ; un contournement (assembler la commande pour passer le filtre) a été refusé à
  juste titre : un refus d'une garde n'est jamais à contourner, il se signale. WebFetch et `curl` sur `raw.githubusercontent.com` fonctionnent.
- Détails de la procédure de fusion, d'intégration d'une branche d'agent, du brief type et de l'usine : voir le skill `orchestrate-backlog`
  (§3 à §6) et `docs/AGENT-RUNNERS.md`.

## Usine : repères rapides
- Lancer : `actions_run_trigger` (`claude-agent.yml`, `ref: main`, `inputs: {tickets: "<issues>", model: claude-sonnet-5-5, effort: high}`) ou
  `gh workflow run`. Une issue = un agent = branche `claude/issue-<n>-<slug>` = une PR avec `Closes #<n>`. Prérequis : issue créée, `github_issue: <n>`
  dans le ticket, fusionné dans `main` ; lot validé par `python3 tools/factory/overlap.py --tickets <n1>,<n2>`.
- Plafonds (T-478) : Sonnet 3 $, Opus 6 $, Haiku 1 $ par run ; tours 100 (Sonnet/Haiku), 200 (Opus) ; `timeout-minutes` ≤ 55 hors Opus (jeton d'App 1 h).
- Disjoncteur de quota (`factory/LIMIT.json`, jamais déclenché en vrai) et `factory/PAUSE` (désarmement d'un auto-merge déjà armé non prouvé) : à prouver.
- Identité : GitHub App `openchoreo-worker` ; jeton Claude `CLAUDE_CODE_OAUTH_TOKEN` (Max, `claude setup-token`, un an) ; registre `docs/state/identities.yaml`.
- Mesurer : `python3 tools/factory/stats.py --dir <artefacts mission-result>` ; ligne par run dans le commentaire de l'issue.

## Décisions de Paul à connaître (elles priment sur les anciens documents)
- Control plane OpenChoreo sur le homelab (VM Talos « lab »), OKE optionnel ; mono-cluster pour la porte ; **pas de fork d'OpenChoreo** : tag stable
  1.3.3 épinglé + couche « security bundle » privée et temporaire (`docs/SECURITY-BUNDLE.md`, ADR-0016/0020).
- k3d **désactivé** (lancement manuel ou label `k3d`) pendant le dev : D-1 à D-6 (ADR-0002 §4 amendé, T-435 en FINAL0, réactivation nocturne à la fin de S1).
  Triage des échecs préexistants de la suite `k3d` : T-469. Étude : `docs/research/K3D-REACTIVATION.md`.
- Dev uniquement avec Claude (DeepSeek plus tard). Routage ADR-0023 : R1-sensible Opus, R2 texte Haiku + revue Sonnet, R3 Sonnet.
- Setup « shift-left » : `docs/research/SHIFT-LEFT-DEV-ENV.md` (commande unique `tools/dev/check`, `tools/dev/setup` pour pre-commit).
- Art antérieur obligatoire avant de coder (ADR-0024, skill `prior-art`) ; maintenabilité par le cliquet `tools/quality/check.py`.
- Backlog 100 % technique : le score de priorité (`priority.py`) ordonne ; tout sera traité.

## Gestes attendus de Paul
Liste maintenue dans `backlog/NEXT.md` : script de setup cloud (`tools/dev/cloud-setup.sh`), tag `core-baseline` (annoté, à signer avant FINAL0),
réglages d'organisation GitHub (T-434), dates du registre des identités, pause du moteur horaire Atlas pendant le pilote, `/usage` à 0/24/48 h,
palier N et Max ou Ultra après le pilote, `lab.internal` fictif ou non, hôte `awesomeclaude.ai` à autoriser si on veut lire ces pages, FINAL0
(App définitive T-215, retrait du contournement admin T-400, signature du tag).

## Points de vigilance
- `.claude/settings.json` (T-330) et les hooks `.claude/hooks/` (T-331) refusent `kubectl`, `helm`, `tofu`, la lecture d'identifiants, `env`, le push forcé,
  `--no-verify`. Dépôt public : jamais de valeur sensible dans un commit, une PR, un journal ou un rapport ; `leak-guard` tourne en CI et en local.
- Ne pas désactiver ni contourner admission, PSA ou NetworkPolicy pour faire passer un test. Périmètre cluster : `openchoreo-*` et `lab-*`.
- Un statut « PASS » exige une preuve runtime datée ; STATIC n'est pas RUNTIME ; k3d n'est pas OKE ; `NOT_TESTED` et `INCOMPLET` se disent.
- Ne jamais régénérer le backlog avec `tools/backlog/seed.py` (obsolète). `STATE.md` et `ROADMAP.md` : seul le coordinateur les écrit.
- Le force-push est refusé : ne jamais en faire ; une branche coordinateur repartie de `main` se réconcilie par `git merge -s ours FETCH_HEAD`
  quand le dépôt distant l'a encore.
