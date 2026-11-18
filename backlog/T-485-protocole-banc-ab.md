---
id: T-485
title: "Protocole minimal du banc A/B préenregistré (4 tâches, 3 pièges, graders, seuils, arrêt anticipé)"
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
# T-485 — Protocole minimal du banc A/B préenregistré

## Intention
Figer, avant toute mesure, ce qui compare le chemin kube-ops (bras K) et le chemin OpenChoreo (bras O) : 4 consignes identiques orientées résultat (M1-M4), 3 pièges, graders par code sur le check run publié et l'état Git, seuils S1, S2, S3, S5, S6, S7, verdict sans zone grise et arrêt anticipé (`docs/research/POC-OPENCHOREO-STRATEGY.md` §2).

## Périmètre de fichiers
tests/bench-ab/, tools/bench-ab/

## Critères de fin
- [ ] 4 consignes M1-M4 et 3 pièges dans `tests/bench-ab/tasks/`, texte identique pour les deux bras (test : seul le champ `repo` diffère)
- [ ] tirage de la panne de M4 enregistré à l'avance, identique pour les deux bras au même rang (test)
- [ ] un grader par tâche, testé hors cluster avec des fixtures de check run `success`, `failure`, `neutral` et absent ; absent ou `neutral` rend NOT_TESTED, jamais PASS
- [ ] seuils et règle de verdict dans `tests/bench-ab/thresholds.yaml` (2 runs par tâche et par bras ; verdict à 2 sur 3 parmi S2, S3, S5)
- [ ] agrégateur : lit `mission-result.v1` (via `tools/factory/stats.py`) et les graders, rend S1-S7 par bras en JSON et signale l'arrêt anticipé dès qu'un seuil devient inatteignable ; test sur 3 jeux synthétiques (valeur prouvée, arrêt par S6, arrêt anticipé)
- [ ] images arm64 vérifiées pour `it-tools`, `vikunja`, `ntfy` (sortie de `docker manifest inspect` datée dans la PR) ; `tools/dev/check --static --changed` et `python3 tools/quality/check.py` PASS

## Notes
Les transcriptions restent locales (dépôt public) ; seuls les compteurs sont publiés. Art antérieur : skill `prior-art` niveau `complet` (`tools/`).

Accéléré (arbitrages de Paul n°3, 2026-11-18) : 5 tâches × 3 runs et 10 pièges ramenés à 4 tâches × 2 runs et 6 pièges ; S4 retiré (couvert par S3).
