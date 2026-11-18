---
owner: paul
updated: 2026-11-18
review_days: 30
---
# AGENTS.md — openchoreo-lab (règles pour les agents : Claude, Codex)

<!-- Maintenance : ce fichier est toujours chargé. Max 60 lignes / 5 Ko (tools/context-check). Toute nouvelle règle = en remplacer une ou la mettre dans un skill. Ces commentaires ne sont pas injectés dans le contexte de Claude Code. -->

## Règles impératives
1. Lire `STATE.md` (court, ≤ 60 lignes) au démarrage ; le mettre à jour à chaque jalon. Le détail des autorisations de Paul est dans `missions/MISSION.md` : le lire avant toute action qui écrit ou touche le cluster.
2. Ajouter ou modifier une application = modifier `apps/<nom>/app.yaml` (+ `values.yaml` si Helm) dans une **PR** (`docs/APP-CONTRACT.md`). Jamais d'écriture directe dans le cluster pour un changement durable : pas de `kubectl apply`, pas de MCP en écriture.
3. `generated/` est produit par `tools/appgen` : ne pas l'éditer à la main.
4. Aucun secret, jeton ou credential dans le dépôt, les PR ou les sorties. Valeurs factices ou générées dans le cluster.
5. Ne pas désactiver ni contourner une politique d'admission, la PSA ou une NetworkPolicy pour faire passer un test.
6. Périmètre cluster : écriture dans `openchoreo-*` et `lab-*` uniquement ; lecture seule en plus : `dp-*`, `argocd`, `cnpg-system`, `external-secrets`, `default` (objets OpenChoreo).
7. Un résultat n'est « PASS » qu'avec une preuve runtime datée (PASS / FAIL / NOT_TESTED / BLOCKED ; `NOT_PROVEN` accepté pour une hypothèse non testée). k3d ≠ OKE.
8. Réponses en français, conclusion d'abord, puis preuves.

## Toujours INTERDIT sans autorisation écrite de Paul (détail : `missions/MISSION.md`)
Volume OCI PostgreSQL de 50 Go ; toute exposition publique (Tunnel, Ingress, LoadBalancer) hors MCP derrière Cloudflare Access ; `tofu apply`, Doppler, Cloudflare ; création d'une identité, clé ou jeton d'accès ; modification de `kube-system` ou de politiques cluster-wide ; TLS désactivé ; suppression hors du labo ; nouvelle étude comparative.

## Quel point d'entrée pour quelle demande
Les skills sont dans `.agents/skills/` (leur `description` est déjà chargée : ne pas les recopier ici). Charger `platform-guardrails` avant toute action qui écrit.

| Demande | Entrée |
|---|---|
| « déploie / installe X » | skill `add-app` (recette `recipes/<app>.yaml` si elle existe) |
| « peut-on migrer X ? » (chart, compose, YAML) | skill `migrate-to-openchoreo` |
| X est cassé, Argo Degraded, check FAIL | skill `diagnose-app` puis `fix-app` |
| bump d'image, promotion dev → prod, rollback | skill `promote-or-rollback` |
| modifier `platform/` (types, quotas, authz, VAP) | skill `openchoreo-platform-engineer-gitops` (classe REVUE) |
| comprendre les objets générés | skill `openchoreo-developer-gitops` |
| installer / réinstaller sur k3d | skill `openchoreo-setup` (OKE : hors de portée de l'agent) |
| archétypes A à F, checks runtime | `golden-paths/README.md` |
| pourquoi cette règle / cette architecture | `docs/adr/README.md` (un ADR PROPOSÉ n'est pas une règle) |
| référence OpenChoreo 1.3.x | `docs/reference/openchoreo/README.md` |
| agents cloud, issues, rôles | `docs/CLOUD-AGENTS.md` |

## En cas de conflit entre sources
`missions/MISSION.md` (mandat de Paul) > ce fichier > ADR ACTÉ > skills et `docs/` > `STATE.md` (l'état change, les règles non). Un conflit non résolu = BLOCKED et une question à Paul, pas un choix silencieux.

## Discipline de contexte
Charge ce fichier, `STATE.md`, un skill et le sous-arbre que tu modifies. Ne lis pas `docs/` en bloc (`APP-CONTRACT.md` fait ~15 000 tokens : chercher la section utile). Si une tâche normale exige plus, améliore l'index ou le skill au lieu d'allonger ce fichier.
