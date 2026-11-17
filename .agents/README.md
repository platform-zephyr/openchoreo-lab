# Expérience agent : skills du labo

Les skills sont au format `SKILL.md` (frontmatter `name` + `description`, puis des instructions courtes). Ils vivent dans **un seul** dossier, `.agents/skills/`, et servent à Claude Code comme à Codex. Les règles du dépôt restent dans `AGENTS.md` ; les golden paths et les vérifications dans `golden-paths/`.

| Skill | Quand | Écrit ? |
|---|---|---|
| `platform-guardrails` | avant toute action ; classes AUTONOME, REVUE, MANDAT, INTERDIT | non |
| `add-app` | « déploie X » | PR `apps/<nom>` |
| `fix-app` | app en erreur, check FAIL | PR de correctif ou revert |
| `diagnose-app` | « pourquoi X ne marche pas ? » | non (lecture seule) |
| `promote-or-rollback` | bump, promotion, rollback | PR |
| `migrate-to-openchoreo` | « peut-on migrer X ? » : verdict A à F | non |
| `openchoreo-developer-gitops` | comprendre les objets générés | non |
| `openchoreo-platform-engineer-gitops` | modifier `platform/` | PR (REVUE) |
| `openchoreo-setup` | (ré)installer OpenChoreo sur k3d | cluster k3d local seulement |

## Chargement par Claude Code

Claude Code découvre les skills de projet dans `.claude/skills/<nom>/SKILL.md` et lit `CLAUDE.md` (pas `AGENTS.md`). Deux gestes, **à faire par le coordinateur** (hors du périmètre de ce dossier) :

```bash
mkdir -p .claude && ln -s ../.agents/skills .claude/skills     # lien relatif, versionné par git
printf '@AGENTS.md\n' > CLAUDE.md                               # CLAUDE.md importe AGENTS.md
```

Vérification : dans une session Claude Code ouverte à la racine du dépôt, `/skills` (ou la liste des skills disponibles) affiche `add-app`, `fix-app`, etc. Le skill se déclenche quand la demande correspond à sa `description`, ou quand il est appelé par son nom (`/add-app`).

## Chargement par Codex

Codex lit `AGENTS.md` nativement : à la racine, puis dans les sous-dossiers. Pour les skills, la découverte de `.agents/skills/` dépend de la version de Codex CLI [S, à vérifier avec `codex --version` et sa doc]. Si elle ne les voit pas : lien `.codex/skills -> ../.agents/skills`, créé par le coordinateur comme pour Claude Code.

Repli indépendant de l'outil, recommandé dans tous les cas : un index dans `AGENTS.md`, à ajouter par le coordinateur.

```markdown
## Skills (lire le SKILL.md correspondant avant d'agir)
- Toujours : `.agents/skills/platform-guardrails/SKILL.md`
- Déployer : `.agents/skills/add-app/SKILL.md` ; corriger : `fix-app` ; diagnostiquer : `diagnose-app`
- Mettre à jour / revenir : `promote-or-rollback` ; éligibilité : `migrate-to-openchoreo`
- Plateforme : `openchoreo-platform-engineer-gitops` ; installation k3d : `openchoreo-setup`
- Golden paths et preuves : `golden-paths/README.md`, `golden-paths/DEPLOY-AND-FIX-FLOW.md`
```

## Pré-requis d'exécution des skills

- `gh` authentifié sur le dépôt, avec le droit d'ouvrir une PR. Un merge autonome n'a lieu que si la protection de `main` est active (`platform-guardrails` §4).
- `python3` avec PyYAML et jsonschema (`tools/appgen/requirements.txt`).
- `kubectl` et un `KUBECONFIG` **dédié au labo** (k3d : `k3d kubeconfig write openchoreo --output <fichier>`). Le contexte est nommé à chaque commande. Aucun droit d'écriture n'est nécessaire : un rôle `view` suffit, et il est souhaitable [à mettre en place, voir le compte rendu].
- `docker buildx` pour lire les digests d'images.

## Attribution (pour `NOTICE`)

Les fichiers suivants sont adaptés de **openchoreo/skills** (<https://github.com/openchoreo/skills>), commit `cefd81bc16b79bd2de0f6284e6fa06d6c15825b7`, Apache License 2.0. Chacun porte en tête (champ `license` du frontmatter et commentaire) la source et la liste des modifications :

| Fichier du dépôt | Source upstream |
|---|---|
| `.agents/skills/openchoreo-platform-engineer-gitops/SKILL.md` | `skills/openchoreo-platform-engineer-gitops/SKILL.md`, `references/recipes/author-componenttype.md`, `references/recipes/verify-and-recover-drift.md` |
| `.agents/skills/openchoreo-developer-gitops/SKILL.md` | `skills/openchoreo-developer-gitops/SKILL.md`, `references/recipes/use-a-resource.md` |
| `.agents/skills/migrate-to-openchoreo/SKILL.md` | `skills/migrate-to-openchoreo/SKILL.md` |
| `.agents/skills/openchoreo-setup/SKILL.md` | `skills/openchoreo-setup/SKILL.md`, `references/on-k3d-locally.md` |
| `.agents/skills/diagnose-app/SKILL.md` | `skills/openchoreo-developer-gitops/references/recipes/verify-and-debug.md` |
| `.agents/skills/promote-or-rollback/SKILL.md` | `skills/openchoreo-developer-gitops/references/recipes/promote.md` |

Aucun script upstream n'est copié ni exécuté (`fetch-page.sh`, `extract-resources.sh`, `list-versions.sh`, `preview.sh`, `server.cjs`), ni aucun asset (HTML, CSS, JS). Les skills `openchoreo-developer` et `openchoreo-platform-engineer` (écriture via MCP) ne sont pas repris.
