---
id: T-487
title: "OKE vierge pour le POC : installation depuis Git, un seul Argo, AppProjects lab-o et lab-k, mesure C2-OKE"
status: todo
phase: P1
adr: [0025, 0003, 0017]
depends_on: [T-001, T-490]
class: REVUE + MANDAT
velocity: true
lane: socle-oke
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-487 — OKE vierge pour le POC

## Intention
Sur le cluster OKE recréé vierge par homelab-infra (T-490), installer depuis Git OpenChoreo (bundle 1.0.1 arm64), un seul Argo CD, CNPG `lab-pg` et les AppProjects `lab-o` et `lab-k`, puis mesurer l'empreinte. Exécuté par la session locale du Mac (brief `docs/research/POC-BRIEF-SESSION-LOCALE.md`).

## Périmètre de fichiers
tools/oke/install.sh, tools/oke/verify.sh, platform/install/argocd/project-lab.yaml, platform/install/values/argocd.yaml, backlog/evidence/, docs/state/journal/

## Critères de fin
- [ ] AppProjects `lab-o` et `lab-k` versionnés, bornés à leurs namespaces, contrôleur ApplicationSet activé ; `argo_guard.py` PASS en CI
- [ ] installation depuis Git sur OKE vierge, `verify.sh` PASS par étape (0 à 11), durée totale mesurée (preuve datée)
- [ ] un seul Argo CD dans le cluster ; test de refus d'une destination hors périmètre (preuve datée)
- [ ] mesure datée : requests CPU et RAM, pods ; FAIL si > 70 % ou > 33 pods avec un bras actif
- [ ] `lab-pg` Ready sur un volume de bloc ≤ 50 Go ; bloc OCI total ≤ 200 Go

## Notes
Exécutant unique sur OKE : la session locale, par session bastion ouverte par Paul. Aucune écriture hors `openchoreo-*` et `lab-*`. Coût attendu : 0 € ; tout dépassement est un MANDAT (ADR-0017).

Accéléré (arbitrages de Paul n°3, 2026-11-18) : plus de gel de 3 semaines ni d'inventaire préalable ; OKE n'a aucune donnée importante et est recréé vierge par homelab-infra (T-490).
