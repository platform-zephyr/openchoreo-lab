# AGENTS.md — règles pour les agents (Claude, Codex)

- Lire `STATE.md` puis `missions/MISSION.md` avant d'agir. Mettre `STATE.md` à jour à chaque jalon.
- Ajouter ou modifier une application = modifier `apps/<nom>/app.yaml` (+ `values.yaml` si Helm) dans une **PR**. Ne jamais écrire directement dans le cluster pour un changement durable (pas de `kubectl apply`, pas de MCP en écriture). Voir `docs/APP-CONTRACT.md`.
- Les fichiers sous `generated/` sont produits par `tools/appgen` : ne pas les éditer à la main.
- Aucun secret, jeton ou credential dans le dépôt, les PR ou les sorties. Valeurs factices ou générées dans le cluster.
- Ne pas désactiver ni contourner une politique d'admission, la PSA ou une NetworkPolicy pour faire passer un test.
- Périmètre cluster : namespaces `openchoreo-*` et `lab-*` uniquement.
- Un résultat n'est « PASS » qu'avec une preuve runtime datée (PASS / FAIL / NOT_TESTED / BLOCKED). k3d ≠ OKE.
- Réponses en français, conclusion d'abord.
