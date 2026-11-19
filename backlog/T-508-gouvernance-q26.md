---
id: T-508
title: "Gouvernance : ADR-0025 accepté, amendements 0020/0003/0022, règle d'adoption anticipée (Q26), règle M3, gel appgen et argo_guard"
status: in-progress
phase: P1
adr: [0025, 0020, 0003, 0022]
depends_on: []
class: REVUE
velocity: true
lane: gouvernance
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-508 — Gouvernance de la porte 1 (Q26)

## Intention
Consigner les décisions de Paul du 2026-11-19, relayées par le coordinateur (formulation exacte : PR de ce ticket) :
ADR-0025 accepté (Q7, Q8, Q9 : deux portes, banc A/B minimal, seuils S1-S7 et règle de verdict) ; cap « OpenChoreo au
plus près de l'implémentation native, sans complexité inutile ». Écrire les amendements promis aux ADR-0020, 0003 et
0022. Ajouter la règle d'adoption anticipée dès la passe 0 (Q26), la règle sur M3 sans non-prod côté bras K (E6) et le
gel des couches maison.

## Périmètre de fichiers
docs/adr/0025-validation-en-deux-portes.md, docs/adr/0020-porte-adoption-openchoreo.md, docs/adr/0003-topologie-hybride.md, docs/adr/0022-harness-environnements-agents.md, docs/research/POC-AB-PASS-0.md, docs/research/FIDELITE-JOURNAL.md, backlog/T-508-gouvernance-q26.md

## Critères de fin
- [x] ADR-0025 au statut ACCEPTÉ, source citée, points 8 (Q26), 9 (M3) et 10 (gel) — STATIC, 2026-11-19
- [x] Amendements datés dans ADR-0020, ADR-0003 et ADR-0022 ; contenu absent d'ADR-0025 marqué « à préciser par Paul » — STATIC, 2026-11-19
- [x] Q26 et règle M3 dans `docs/research/POC-AB-PASS-0.md` — STATIC, 2026-11-19
- [x] Gel écrit dans `docs/research/FIDELITE-JOURNAL.md` (section datée, proposition 2) et dans ce ticket — STATIC, 2026-11-19
- [ ] Paul approuve la PR (ADR du noyau, classe REVUE)
- [ ] Paul précise les points ouverts : répartition de C2, C3, C4, C7 entre les portes et date de la porte 2 (ADR-0020) ; niveau d'environnement OKE (ADR-0022)

## Notes
- **GEL (décision de Paul, 2026-11-19)** : aucune ligne nouvelle dans `tools/appgen/` ni `tools/oke/argo_guard*`
  jusqu'à la décision « façade `app.yaml` ou objets natifs », prise juste après la porte 1. Suppression bienvenue.
  Un besoin réel passe par un champ amont (AppProject, VAP, objet natif) ou attend la décision.
- Aucun code touché : `prior-art` non chargé.
