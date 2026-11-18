# Reprise du coordinateur (session cloud) — 2026-11-18

À lire en premier après une compaction ou par une nouvelle session coordinatrice. Ne contient aucun secret.

## Où on en est
- Plan acté : `docs/adr/` (0001-0024), `docs/review/CONSENSUS.md`, `CONSENSUS-2.md` (arbitrages de Paul en fin, ils priment),
  `FABLE-ARBITRAGE.md`. Ordre de travail : `backlog/ROADMAP.md`. Prochains tickets prêts : voir « Calcul des tickets prêts ».
- **Mode dev** (arbitrage de Paul) : sécurité allégée, les agents fusionnent après `ci-ok`, revue des code owners suspendue
  jusqu'à FINAL0. Seule compte la sécurité finale (étapes FINAL0 puis FINAL).
- PR #54 fusionnée (squash) : ADR actés (T-061, T-061b `done`). **PR ouverte : #55** (branche `claude/cool-hamilton-r7aa5k`).
- **Vague 1 de S0 intégrée dans #55** : T-008 `done`, T-330 `done`, T-303/T-306/T-311 `in-progress` (implémentés, attendent
  une preuve CI/runtime ou un ticket suivant).
- **Vague 2 de S0 en cours** (7 sous-agents, worktrees `.claude/worktrees/agent-*`, branches `worktree-agent-*`, non poussées) :
  T-210 dispatcher, T-302 corrections de l'arbre (Opus), T-413 pyproject/ruff, T-430 rulesets as-code, T-072 app-status,
  T-332 `tools/dev/check`, T-002 corrections CI k3d.

## Intégrer une vague (procédure)
1. Pour chaque branche terminée : `git merge --no-ff worktree-agent-<id>` dans `claude/cool-hamilton-r7aa5k`.
   Conflits connus : `.github/workflows/ci.yaml` (liste `needs` de `ci-ok` : garder l'union des jobs), `backlog/README.md`
   (garder les deux sections), fichier du ticket (garder la version la plus avancée).
2. Contrôles : `python3 tools/backlog/check.py` (0 erreur), `python3 -m unittest discover -s tests/backlog`, tests du ticket,
   `python3 -c "import yaml;yaml.safe_load(open('.github/workflows/ci.yaml'))"`.
3. `python3 tools/backlog/roadmap.py`, commit, `git push origin claude/cool-hamilton-r7aa5k`.
4. Ne **jamais** régénérer le backlog avec `tools/backlog/seed.py` : les statuts et cases cochées sont maintenant édités à la
   main dans les tickets (seed.py sera retiré par T-419). Modifier les tickets directement.
5. `.claude/worktrees/`, `__pycache__/`, `.coverage` sont exclus (`.git/info/exclude`, `.gitignore`).

## Calcul des tickets prêts (jusqu'à ce que T-210 `next.py` soit intégré)
Un ticket est prêt si `status: todo`, étape la plus basse (S0, puis S1…), et toutes ses dépendances `done` ou
`in-progress` implémentées. Lancer un sous-agent par ticket, en worktree (`isolation: worktree`), modèle = champ `model:`
du ticket, avec : lire AGENTS.md + backlog/README.md + le ticket ; rester dans le périmètre ; **chercher d'abord une
implémentation publique et la citer (« Art antérieur »)** ; tests ; commit `noreply@anthropic.com` avec trailers ; ne pas
pousser ; `done` seulement si tous les critères sont prouvés. Éviter deux tickets sur les mêmes fichiers dans une vague.
Prochains candidats après la vague 2 : T-313 (exécutant) → T-411 (skill art antérieur) → T-304 (essai réel) → pilote T-322 ;
T-450 (dette `.gitleaksignore`), T-325, T-360, T-041, T-001 (PR #8), T-414, T-432, T-434.

## Gestes attendus de Paul
- Créer le secret `LEAK_GUARD_EXTRA_PATTERNS` (motifs personnels, une regex par ligne).
- Dire si `lab.internal` est fictif.
- Identité avec permission `workflows` pour l'exécutant (T-304), tag `core-baseline` (T-305), pause du moteur horaire
  Atlas/homelab-infra pendant le pilote, gestes d'organisation GitHub (T-434, `docs/research/GITHUB-CONFIG.md` §7).
- Fuite résiduelle d'historique (OCID et IP privées dans `docs/storage/*` et 71 IP dans d'autres fichiers) : réécriture
  optionnelle par l'agent local de Paul ; l'arbre est géré par T-450.
- Décisions : une ou deux GitHub Apps (à FINAL0) ; Max ou Ultra (après le pilote).

## Points de vigilance
- `.claude/settings.json` (T-330) refuse `kubectl`, `helm`, `tofu`, la lecture d'identifiants et le push forcé dans ce dépôt.
- Le force-push est refusé par la politique de la session : en cas de divergence d'historique, rejouer ses commits et
  rattacher par une fusion `-s ours`, comme fait le 2026-11-18.
- Dépôt public : aucune IP, OCID, e-mail, hôte interne ni détail de faille dans un commit, une PR ou un rapport.
