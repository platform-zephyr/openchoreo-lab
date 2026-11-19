---
id: T-518
title: "Limite de 33 pods levée pour les apps de test ; étude du plafond maxPods"
status: todo
phase: P1
adr: []
depends_on: []
class: AUTONOME
velocity: false
lane: docs
stage: S1
model: claude-sonnet-5-5
effort: medium
routing: R3-defaut
github_issue: null
---
# T-518 — Limite de 33 pods levée pour les apps de test ; étude du plafond `maxPods`

## Intention
Décision de Paul (chat, 2026-11-19) : « enlève cette limite durant la phase de test ». La limite de 33 pods est le critère C2 de la porte (ADR-0020, plateforme seule), pas un plafond pour les apps de test. Écrire la règle dans la documentation active et étudier, en lecture seule, comment relever le plafond physique (`maxPods`).

Règle : de maintenant à la décision de porte, les 33 pods ne limitent pas les apps de test ; ils restent un critère de mesure de la plateforme seule (C2). Le seul plafond est celui du kubelet. Les 70 % de requests ne sont pas concernés par cette décision et restent inchangés.

## Périmètre de fichiers
docs/research/OKE-MAXPODS.md, docs/research/POC-BRIEF-SESSION-LOCALE.md, docs/ORCHESTRATION.md, docs/architecture/TARGET-ARCHITECTURE.md, docs/research/HOMELAB-CAPACITY-DATAPLANE.md, backlog/T-487-reinitialisation-oke-poc.md, backlog/T-498-demo-native-openchoreo.md, backlog/T-515-preuves-oke-operateur.md, backlog/T-518-limite-pods-phase-test.md

## Critères de fin
- [x] règle énoncée dans les documents actifs qui citent les 33 pods (brief du POC, orchestration, architecture cible, capacité, tickets T-487, T-498, T-515) — STATIC, 2026-11-19
- [x] aucun contrôle automatisé n'échoue à 33 pods (`measure.sh`, `verify.sh`, `lib.sh` relus) : rien à modifier — STATIC
- [x] `docs/research/OKE-MAXPODS.md` : options pour relever le plafond, coût, recommandation — STATIC (lecture seule de homelab-infra, rien appliqué)
- [ ] PAUL : choisir l'option pour le plafond physique (voir la note), seulement si la marge de pods devient bloquante
- [ ] relevé `maxPods` réel du kubelet (T-515)

## Notes
Hors périmètre, volontairement : ADR (périmètre GOV), `thresholds.yaml`, `tools/appgen` et `tools/oke/argo_guard*` (GELÉS), homelab-infra (lecture seule). Documentation seulement. Aucune valeur secrète, OCID, IP ni hôte interne.
