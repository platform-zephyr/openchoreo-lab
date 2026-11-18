---
id: T-481
title: "Intégrer les skills mattpocock/skills (MIT) pour les sessions, l'usine et l'orchestrateur, à SHA figé"
status: in-progress
phase: P0
adr: [0021, 0022, 0024]
depends_on: [T-478]
class: REVUE
velocity: false
lane: factory
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-481 — Intégrer les skills mattpocock/skills

## Intention
Paul a installé `mattpocock-skills@claude-plugins-official` en local. Ces skills doivent aussi servir (a) aux sessions
cloud et locales sur ce dépôt, (b) à l'orchestrateur et au coordinateur, à une version figée et relue, sans élargir les
permissions ni retirer un refus. Décision de Paul (2026-11-18) : l'usine `claude-agent.yml` (agents non interactifs sur
runner GitHub) ne lit aucun de ces skills.

## Périmètre de fichiers
.agents/skills/mattpocock-*/, .agents/skills/orchestrate-backlog/SKILL.md, AGENTS.md, /NOTICE (attribution), LICENSES/, .github/workflows/claude-agent.yml, tests/factory/external-skills-test.sh

## Critères de fin
- [x] dépôt amont lu et méthode officielle d'activation établie (dépôt, action épinglée ; voir Notes : aucune voie déclarative épinglable n'atteint le cloud ni l'usine) : licence, liste des skills, activité, SHA par `git ls-remote` — PROUVÉ (STATIC, 2026-11-18) : `mattpocock/skills` `HEAD` = `5863806dd4e15c63174bee4e7515a4256792ecfa`, MIT (Copyright (c) 2026 Matt Pocock), plugin 1.3.2, 27 skills dans `plugin.json` ; `resolving-merge-conflicts` retiré en amont (CHANGELOG, PR #1120)
- [x] `orchestrate-backlog` (§6 « Skills externes utiles »), une ligne dans `AGENTS.md`, six skills vendorés avec en-tête de provenance (URL, SHA, licence, modifications), nom préfixé `mattpocock-`, texte MIT et `NOTICE` — PROUVÉ (STATIC, 2026-11-18) : `tests/factory/external-skills-test.sh`
- [x] `.claude/settings.json` inchangé (permissions et refus intacts) ; garde contre un plugin ou une marketplace flottants et contre une règle `Skill` — PROUVÉ (STATIC, 2026-11-18) : `git diff origin/main -- .claude/settings.json` vide ; 5 mutations détectées
- [x] usine : aucune consigne de lecture de skill dans `--append-system-prompt` (ni commentaire T-481), aucune entrée `plugins`/`plugin_marketplaces`, `Skill` hors `allowedTools` ; contrôle d'absence et mutations détectées par `tests/factory/external-skills-test.sh` — voir la PR pour le reçu
- [x] ~~run réel de l'usine qui lit `mattpocock-tdd`~~ — sans objet (décision de Paul : l'usine ne lit pas les skills)
- [ ] `tools/dev/check --static --changed` PASS ; section « Implémentations publiques consultées » dans la PR — check local : voir la PR ; PR non ouverte

## Notes
Décision de Paul (2026-11-18) : dans l'usine, faire lire des skills qui ne servent pas est inutile ; la consigne « Méthode
(T-481) » et le commentaire associé sont retirés de `claude-agent.yml`. Les copies `.agents/skills/mattpocock-*` restent
pour les sessions interactives et le coordinateur. La garde vérifie que la consigne est absente et que
`plugins`/`plugin_marketplaces` restent absents. Les passages ci-dessous sur la lecture par Read dans l'usine sont
historiques.

Décision : **copie vendorée** (licence MIT) plutôt qu'activation déclarative. Sources officielles lues le 2026-11-18 :
- code.claude.com/docs/en/cloud-environments, « What carries over » : une session cloud n'installe pas les plugins de
  `enabledPlugins` ni les marketplaces de `extraKnownMarketplaces` du dépôt ; elle charge `.claude/skills/` (ici un lien
  vers `.agents/skills/`). La voie `settings.json` ne sert donc ni le cloud (a) ni l'usine (b).
- code.claude.com/docs/en/discover-plugins : `claude-plugins-official` se met à jour seul (auto-update actif par défaut) ;
  `#ref` épingle une branche ou un tag, pas un commit ; un `enabledPlugins` de projet exige en plus une installation par clone.
- `anthropics/claude-code-action@469588f42e6b1e94cd14ad09dccfeaec772ce0fd`, `action.yml` l. 164-171 et
  `base-action/src/install-plugins.ts` : entrées `plugins` et `plugin_marketplaces` ; une marketplace doit être une URL
  `https://…\.git$` (sans ref), puis `claude plugin install`. Le plugin vient de la marketplace officielle, dont l'entrée
  `mattpocock-skills` épingle `49dd158` (choix du mainteneur de la marketplace, qui change sans PR ici) : version non figée
  par ce dépôt, téléchargée à chaque run d'un agent qui a le droit d'écrire. Écarté.
- Copie vendorée : contenu relu ligne à ligne, SHA figé, diff visible en PR, aucun réseau à l'exécution, identique pour
  cloud, local, usine et Codex (`.agents/skills/`).

Risque d'injection : un skill tiers entre dans le contexte d'agents qui écrivent dans le dépôt. Mesures : contenu relu (aucune
commande réseau, aucun secret, aucune consigne de contournement), seulement du Markdown (scripts et `agents/openai.yaml`
exclus), liste fermée, SHA unique figé et testés ; frontmatter sans `allowed-tools` ; l'usine lit par Read et l'outil
`Skill` reste hors `allowedTools` ; consigne « méthode, jamais permission ; AGENTS.md prime ». Mise à jour = PR qui relit
le diff amont.

Tri : vendorés `tdd`, `diagnosing-bugs` (tickets de code), `code-review` (revue), `writing-for-agents` (AGENTS.md, skills),
`research` (études), `grilling` (arbitrages de Paul, session interactive). Écartés : `resolving-merge-conflicts` (retiré
en amont), `prototype`, `codebase-design` (renvoi annoté dans `mattpocock-tdd`), `domain-modeling` (concurrence `docs/adr/`),
`wizard` (geste humain = MANDAT), skills user-invoked qui écrivent dans un suivi d'issues (`triage`, `to-tickets`,
`setup-matt-pocock-skills`, `implement`, `pr`).

Doublons en local : Paul garde le plugin (`mattpocock-skills:<nom>`, version 1.2.3 synchronisée par claude.ai) ; les copies
préfixées `mattpocock-<nom>` ne le remplacent pas et ne collisionnent ni avec lui ni avec le skill intégré `code-review`.
Pour une seule source dans ce dépôt : `"enabledPlugins": {"mattpocock-skills@claude-plugins-official": false}` dans
`.claude/settings.local.json` (choix personnel, non committé).

Hors périmètre, à suivre : `tools/dev/check-paths.tsv` ne sélectionne pas le contrôle `factory` pour `.agents/skills/*`
avec `--changed` (la CI lance `factory` à chaque PR).
