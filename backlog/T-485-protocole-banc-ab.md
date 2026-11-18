---
id: T-485
title: "Protocole du banc A/B préenregistré (5 tâches, 5 pièges, graders, seuils S1-S7)"
status: todo
phase: P1
adr: [0025, 0020]
depends_on: [T-072]
class: AUTONOME
velocity: true
lane: banc-ab
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-485 — Protocole du banc A/B préenregistré (5 tâches, 5 pièges, graders, seuils S1-S7)

## Intention
Figer, avant toute mesure, ce qui compare le chemin kube-ops (bras K) et le chemin OpenChoreo (bras O) : consignes identiques orientées résultat, graders par code sur `app-status.v1` et l'état Git, pièges, seuils et gabarit de rapport (`docs/research/POC-OPENCHOREO-STRATEGY.md` §2).

## Périmètre de fichiers
tests/bench-ab/, tools/bench-ab/

## Critères de fin
- [ ] 5 consignes T1-T5 et 5 pièges dans `tests/bench-ab/tasks/`, texte identique pour les deux bras (test : seul le champ `repo` diffère)
- [ ] un grader par tâche, testé hors cluster avec des fixtures `app-status.v1` PASS, FAIL, PENDING et UNKNOWN ; UNKNOWN rend NOT_TESTED, jamais PASS
- [ ] seuils S1-S7 et règle de verdict dans `tests/bench-ab/thresholds.yaml`, commité avant le premier run compté
- [ ] agrégateur : lit les artefacts `mission-result.v1` (via `tools/factory/stats.py`) et les graders, rend S1-S7 par bras en JSON ; test sur un jeu synthétique
- [ ] images arm64 vérifiées pour `it-tools`, `vikunja`, `ntfy` (sortie de `docker manifest inspect` datée dans la PR)
- [ ] `tools/dev/check --static --changed` et `python3 tools/quality/check.py` PASS

## Notes
Les transcriptions restent locales (dépôt public) ; seuls les compteurs sont publiés. Art antérieur : skill `prior-art` niveau `complet` (`tools/`).
