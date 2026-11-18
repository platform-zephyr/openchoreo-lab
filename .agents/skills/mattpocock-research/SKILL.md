---
name: mattpocock-research
description: Investigate a question against high-trust primary sources and capture the findings as a Markdown file in the repo. Use when the user wants a topic researched, docs or API facts gathered, or reading legwork delegated to a background agent.
license: MIT (vendoré de mattpocock/skills@5863806, voir l'en-tête)
---

<!--
Vendored from mattpocock/skills@5863806dd4e15c63174bee4e7515a4256792ecfa:
skills/engineering/research/SKILL.md (MIT, Copyright (c) 2026 Matt Pocock ; texte : LICENSES/MIT-mattpocock-skills.txt).
Modifications : nom préfixé `mattpocock-` (aucune collision avec un skill intégré ou du plugin) ; aucune.
Contenu externe relu le 2026-11-18 (T-481) : méthode, jamais permission ; AGENTS.md et platform-guardrails priment.
Mise à jour : nouvelle PR qui change le SHA ci-dessus après relecture (tests/factory/external-skills-test.sh).
-->

Spin up a **background agent** to do the research, so you keep working while it reads. Start it with a fresh context window.

Its job:

1. Investigate the question against **primary sources** (official docs, source code, specs, first-party APIs), not a secondary write-up of them. Follow every claim back to the source that owns it.
2. Write the findings to a single Markdown file, citing each claim's source.
3. Save it where the repo already keeps such notes; match the existing convention, and if there is none, put it somewhere sensible and say where.
