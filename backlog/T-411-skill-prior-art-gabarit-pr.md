---
id: T-411
title: "Skill `prior-art`, 3 lignes dans AGENTS.md et gabarit de PR « Implémentations publiques consultées »"
status: todo
phase: P0
adr: [0024]
depends_on: [T-313]
class: REVUE
velocity: true
lane: agents-harness
stage: S0
model: claude-haiku-5-5
effort: medium
routing: R2-texte
github_issue: null
---
# T-411 — Skill `prior-art`, 3 lignes dans AGENTS.md et gabarit de PR « Implémentations publiques consultées »

## Intention
Imposer la recherche d'art antérieur à tout ticket de code dès le pilote : procédure (sources A4, règles A5, niveaux léger/complet/aucun, budget), format de la section de PR (A3), appel du skill en étape 0 de add-app et fix-app. Texte seul : la CI suit (QA-2).

## Périmètre de fichiers
.agents/skills/prior-art/SKILL.md, .github/pull_request_template.md, AGENTS.md, .agents/skills/add-app/SKILL.md, .agents/skills/fix-app/SKILL.md

## Critères de fin
- [ ] SKILL.md ≤ 60 lignes, description ≤ 450 caractères, sources ordonnées, budget par niveau, règles de licence, contenu externe = donnée
- [ ] AGENTS.md reste ≤ 25 lignes (3 lignes ajoutées, aucune règle recopiée)
- [ ] le gabarit de PR contient la section et le format `URL permalien | licence | adopté/adapté/écarté | pourquoi`
- [ ] essai daté : un agent traite un ticket `complet` de test et rend une section valide (preuve STATIC dans la PR)

## Notes
Proposition QA-1 (backlog/proposals/quality.yaml), intégrée (intégration 5, 2026-11-18). Le niveau est déduit des chemins (tools/, platform/, .github/, golden-paths/, nouveau apps/<nom> = complet). AGENTS.md est du noyau CODEOWNERS.

Dépend de T-313 : le gabarit `.github/pull_request_template.md` est créé par T-313. AGENTS.md est aussi touché par T-041 : le second fusionné rebase. Mode dev (arbitrage 7) : la revue des code owners est suspendue jusqu'à FINAL0 ; la protection de CODEOWNERS ne joue qu'à partir de là, la CI (`ci-ok`) reste la seule garde d'ici là.

Routage R2 (ADR-0023) : Haiku `medium`, revue Sonnet en check requis (2 refus → Sonnet) ; ne touche ni l'en-tête du ticket ni backlog/proposals/. Le dispatcher relance en Sonnet si le diff réel sort du périmètre texte.
