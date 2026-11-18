# AGENTS.md — règles pour les agents (Claude, Codex)

- Lire `STATE.md` puis `missions/MISSION.md` avant d'agir. Mettre `STATE.md` à jour à chaque jalon.
- Décisions d'architecture : `docs/adr/`. Tâches : `backlog/` (prendre un ticket : `backlog/README.md`). Modèle des agents cloud : `docs/CLOUD-AGENTS.md`.
- Ajouter ou modifier une application = modifier `apps/<nom>/app.yaml` (+ `values.yaml` si Helm) dans une **PR**. Ne jamais écrire directement dans le cluster pour un changement durable (pas de `kubectl apply`, pas de MCP en écriture). Voir `docs/APP-CONTRACT.md`.
- Les fichiers sous `generated/` sont produits par `tools/appgen` : ne pas les éditer à la main.
- Aucun secret, jeton ou credential dans le dépôt, les PR ou les sorties. Valeurs factices ou générées dans le cluster.
- Ne pas désactiver ni contourner une politique d'admission, la PSA ou une NetworkPolicy pour faire passer un test.
- Périmètre cluster : namespaces `openchoreo-*` et `lab-*` uniquement.
- Un résultat n'est « PASS » qu'avec une preuve runtime datée (PASS / FAIL / NOT_TESTED / BLOCKED). k3d ≠ OKE.
- Local d'abord : avant `git push` ou `gh pr create`, lancer `tools/dev/check --static --changed` et reporter dans la PR le verdict, le niveau et le reçu. `NOT_TESTED` ou `INCOMPLET` n'est pas « PASS » : le dire. Un job CI rouge de niveau L2 ou moins est un défaut de l'environnement local à corriger.
- Réponses en français, conclusion d'abord.
- Avant de coder un ticket qui touche du code, un manifeste ou un workflow : charger `prior-art` (art antérieur borné, ADR-0024).
- La PR contient la section « Implémentations publiques consultées » (format : `.github/pull_request_template.md`).
- L'amont d'abord : un standard amont est préféré au code propre ; l'écart est justifié dans la PR.

## Skills disponibles (`.agents/skills/`, lus par Claude Code via `.claude/skills`)
- `add-app` : intention → archétype → `app.yaml` → PR → CI → preuves.
- `fix-app` : diagnostic en lecture seule → correctif par PR → vérification → rollback par `git revert`.
- `diagnose-app`, `promote-or-rollback`, `platform-guardrails` (classes AUTONOME / REVUE / MANDAT / INTERDIT).
- Adaptés d'OpenChoreo : `openchoreo-platform-engineer-gitops`, `openchoreo-developer-gitops`, `migrate-to-openchoreo`, `openchoreo-setup`.
- `orchestrate-backlog` : reprise d'un orchestrateur (état, score `tools/backlog/priority.py`, dispatch, fusion REST, suivi des PR).
Golden paths et vérifications runtime en lecture seule : `golden-paths/`.

## Périmètre de lecture
Écriture : namespaces `openchoreo-*` et `lab-*` uniquement. Lecture seule autorisée en plus : `dp-*` (data plane OpenChoreo), `argocd`, `cnpg-system`, `external-secrets`, `default` (objets OpenChoreo).
