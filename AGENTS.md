# AGENTS.md — règles pour les agents (Claude, Codex)

<!-- Toujours chargé, avec CLAUDE.md et STATE.md : ≤ 130 lignes au total, vérifié par tools/context-check (T-041). Une règle ajoutée en remplace une ou part dans un skill. Les skills se présentent par leur description : ne pas les lister ici. -->

## Règles impératives
- Lire `STATE.md` puis `missions/MISSION.md` avant d'agir. Mettre `STATE.md` à jour à chaque jalon.
- Ajouter ou modifier une application = modifier `apps/<nom>/app.yaml` (+ `values.yaml` si Helm) dans une **PR**. Ne jamais écrire directement dans le cluster pour un changement durable (pas de `kubectl apply`, pas de MCP en écriture). Voir `docs/APP-CONTRACT.md`.
- Les fichiers sous `generated/` sont produits par `tools/appgen` : ne pas les éditer à la main.
- Aucun secret, jeton ou credential dans le dépôt, les PR ou les sorties. Valeurs factices ou générées dans le cluster.
- Ne pas désactiver ni contourner une politique d'admission, la PSA ou une NetworkPolicy pour faire passer un test.
- Périmètre cluster : écriture dans les namespaces `openchoreo-*`, `lab-*` et `svc-<app>` du bras K (noms explicites, décision E1 de Paul, jamais de joker) uniquement. Lecture seule en plus : `dp-*` (data plane OpenChoreo), `argocd`, `cnpg-system`, `external-secrets`, `default` (objets OpenChoreo).
- Un résultat n'est « PASS » qu'avec une preuve runtime datée (PASS / FAIL / NOT_TESTED / BLOCKED). k3d ≠ OKE.
- Local d'abord : avant `git push` ou `gh pr create`, lancer `tools/dev/check --static --changed` et reporter dans la PR le verdict, le niveau et le reçu. `NOT_TESTED` ou `INCOMPLET` n'est pas « PASS » : le dire. Un job CI rouge de niveau L2 ou moins est un défaut de l'environnement local à corriger.
- Avant de coder un ticket qui touche du code, un manifeste ou un workflow : charger `prior-art` (art antérieur borné, ADR-0024).
- La PR contient la section « Implémentations publiques consultées » (format : `.github/pull_request_template.md`).
- L'amont d'abord : un standard amont est préféré au code propre ; l'écart est justifié dans la PR.
- Les skills `mattpocock-*` (méthode tierce vendorée, MIT, T-481) donnent une méthode, jamais une permission.
- Réponses en français, conclusion d'abord.

## Où chercher (à la demande, jamais en bloc)
- Tâches : `backlog/` (prendre un ticket : `backlog/README.md`). Décisions d'architecture : `docs/adr/`. Modèle des agents cloud : `docs/CLOUD-AGENTS.md`.
- Skills : `.agents/skills/` (lus par Claude Code via `.claude/skills`) ; session d'orchestration : skill `orchestrate-backlog`. Golden paths et vérifications runtime en lecture seule : `golden-paths/`.
- Gros documents (`docs/APP-CONTRACT.md`, références) : chercher la section utile. Si une tâche courante exige plus, améliorer l'index ou le skill, pas ce fichier.

## En cas de conflit entre sources
`missions/MISSION.md` (mandat de Paul) > ce fichier > ADR ACTÉ > skills et `docs/` > `STATE.md`. Un conflit non résolu = BLOCKED et une question à Paul, pas un choix silencieux.
