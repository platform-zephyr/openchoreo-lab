---
id: T-050
title: "Verdict A-F pour chaque app de kube-ops"
status: in-progress
phase: P1
adr: [0005]
depends_on: [T-008]
class: AUTONOME
velocity: false
lane: migration
stage: S3
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-050 — Verdict A-F pour chaque app de kube-ops

## Intention
Passer le catalogue kube-ops dans `migrate-to-openchoreo` pour mesurer la couverture du contrat.

## Périmètre de fichiers
docs/KUBE-OPS-VERDICTS.md (tableau app → archétype → manques, évolutions de contrat), apps/ (brouillons)

## Critères de fin
- [x] tableau app → archétype → manques (`docs/KUBE-OPS-VERDICTS.md` §1 ; STATIC, kube-ops @ ef50472bc427)
- [x] liste des évolutions de contrat nécessaires (`docs/KUBE-OPS-VERDICTS.md` §2 : E1-E16 + E17 KEDA, état schéma/cluster)
- [ ] rendu `kustomize build` / `helm template` des 14 apps classées A, B et C, inventaire exhaustif du skill `migrate-to-openchoreo` refait sur le rendu : verdicts confirmés ou corrigés dans `docs/KUBE-OPS-VERDICTS.md` (aujourd'hui NOT_TESTED, verdicts provisoires)
- [ ] cas non prouvés levés : SQLite de K04, K13 et K27, Chrome de K33, chart de K26

## Notes
Preuves (2026-11-18, STATIC) : 35 entrées classées A 3, B 5, C 6, D 2, E 9, F 10 ; lecture des sources du checkout local kube-ops @ `ef50472bc427` (même commit que `docs/KUBE-OPS-APP-MAP.md`) ; contrat lu dans `docs/schema/app.schema.json` et `clusters/*/capabilities.yaml`. Nouveauté : K16 et K28 (MySQL) et K32 (uid 0) passent en F par la table du skill ; E17 (KEDA scale-to-zero d'it-tools) ajouté.

État des preuves (2026-11-18, STATIC) : RUNTIME NOT_TESTED partout ; le ticket passe `done` quand les deux cases ci-dessus sont cochées.
