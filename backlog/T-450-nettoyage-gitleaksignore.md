---
id: T-450
title: "Nettoyer la dette de .gitleaksignore (129 emplacements) et le vider"
status: done
phase: P0
adr: [0002, 0006]
depends_on: [T-303]
class: REVUE
velocity: false
lane: ci
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-450 — Nettoyer la dette de .gitleaksignore (129 emplacements) et le vider

## Intention
Remplacer les IP privées réelles de docs/ et des `apps/*/NOTES.md` par des valeurs documentaires (plages réservées RFC 5737/3849) et les chemins locaux `/Users/...` de `tests/*/evidence` par des chemins génériques, puis vider `.gitleaksignore`. Aucune valeur réelle n'est recopiée dans la PR.

## Périmètre de fichiers
docs/, apps/*/NOTES.md, tests/*/evidence, .gitleaksignore

## Critères de fin
- [x] les 129 emplacements de `.gitleaksignore` sont traités (IP réelles → valeurs documentaires, chemins locaux → chemins génériques)
- [x] `.gitleaksignore` vidé (ou supprimé) ; la garde `leak-guard` (T-303) reste verte sur tout l'arbre — `.gitleaksignore` ramené à 2 lignes de commentaire ; job `leak-guard` vert sur les runs `ci` 44295354121 (PR #59) et les PR suivantes
- [x] aucune preuve datée n'a perdu son sens (les `evidence` gardent leur structure et leurs dates)
- [x] garde T-303 verte sur la PR ; aucune valeur réelle dans le diff — job `leak-guard` vert sur la PR #58 (run 44291535887 et suivants)

## Notes
Demande du coordinateur (intégration 5, 2026-11-18) : dette initiale laissée par T-303. Ne touche pas l'historique git (réécrit par Paul, T-301).
