---
id: T-061
title: "Acter les ADR 0001-0006, 0010-0013, 0020-0023 (+ amendements homelab), réaligner MISSION sur le homelab"
status: todo
phase: P0
adr: [0002, 0012]
depends_on: []
class: MANDAT
velocity: false
lane: gouvernance
stage: S0
model: claude-opus-5-5
effort: high
routing: R01-noyau-securite
github_issue: null
---
# T-061 — Acter les ADR 0001-0006, 0010-0013, 0020-0023 (+ amendements homelab), réaligner MISSION sur le homelab

## Intention
Lever les contradictions : MISSION interdit encore exposition publique, création d'identité, Cloudflare ; services visés obsolètes ; ADR tous PROPOSÉ.

## Périmètre de fichiers
missions/MISSION.md, AGENTS.md, STATE.md, docs/adr/, docs/architecture/

## Critères de fin
- [ ] ADR 0001-0006, 0010-0013, 0020 actés (ou amendés)
- [ ] MISSION.md réaligné : homelab par défaut, OKE sur demande, interdits réécrits en classes, critère « plateforme finie »
- [ ] AGENTS.md et STATE.md sans contradiction
- [ ] ADR-0021/0022/0023 (usine 24/7), ADR-0022 (harness), ADR-0023 (routage des modèles) rédigés au gabarit depuis docs/research/ et actés (ou amendés)
- [ ] amendements homelab (HOMELAB-CAPACITY-DATAPLANE §5) : ADR-0003 et ADR-0020 (C1, C2, C4) amendés et actés ; texte d'ADR-0017 amendé (acté avec T-218) ; TARGET-ARCHITECTURE, MULTI-DATAPLANE, DECISIONS-OPEN (D1 reformulée, D11-D14) à jour
- [ ] D11 (emplacement définitif du CP) laissé ouvert jusqu'à la porte
- [ ] Paul a tranché pour ADR-0023 : plancher Opus du noyau, Fable sur demande seulement, DeepSeek Flash sur données publiques (MANDAT de dépense)
- [ ] aucun ticket ne cite encore « Talos éteint la nuit » ou « CP sur OKE » comme prérequis
- [ ] MISSION.md et STATE.md : A1 = 2/12, plus de « 4/24 »

## Notes
Intégration 2 : absorbe HOME-13 et MOD-1 pour garder un seul geste de Paul. Ticket lourd sur le chemin critique : Paul peut le scinder (question dans INTEGRATION-2.md).
