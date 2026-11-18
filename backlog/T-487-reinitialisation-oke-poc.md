---
id: T-487
title: "OKE vierge pour le POC : installation depuis Git, un seul Argo, AppProjects lab-o et lab-k, mesure C2-OKE"
status: todo
phase: P1
adr: [0025, 0003, 0017]
depends_on: [T-001, T-490, T-494]
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
  - Non coché : le contrôleur ApplicationSet est encore à 0/0 (`T-487-empreinte-et-verify-all.md`, 2026-11-18T23:05Z) ; B11-projects cite `lab-o` mais pas `lab-k` (`T-487-etape11.md`, 23:18:08Z) ; aucune preuve CI `argo_guard.py` dans le dossier.
- [ ] installation depuis Git sur OKE vierge, `verify.sh` PASS par étape (0 à 11), durée totale mesurée (preuve datée)
  - Non coché : durée mesurée (30 min murale, ~21 min cumulées ; `T-487-empreinte-et-verify-all.md`) mais `verify.sh` n'est pas PASS partout : B1-vap-digest FAIL (`T-487-etape1.md`, 2026-11-18T22:41:45Z) et B6-sa-effective FAIL (`T-487-etape6.md`, 22:52:23Z), deux écarts connus.
- [ ] un seul Argo CD dans le cluster ; test de refus d'une destination hors périmètre (preuve datée)
  - Non coché : aucune preuve du dossier ne couvre le refus d'une destination hors périmètre ni le comptage d'un seul Argo CD (B11-argo, B11-default-locked : `T-487-etape11.md`, 23:18Z, ne le prouvent pas).
- [ ] mesure datée : requests CPU et RAM, pods ; FAIL si > 70 % ou > 33 pods avec un bras actif
  - Non coché : mesure de la plateforme seule PASS (CPU 32 %, RAM 23 %, 26 pods ; `T-487-empreinte-et-verify-all.md`, 2026-11-18T23:09:43Z), mais sans bras actif ; la mesure avec un bras reste à faire.
- [x] Cilium en chaining et la règle `deny-imds` réinstallés AVANT toute charge du POC (le cluster recréé par T-490 ne les a plus) ; `verify.sh` le contrôle (preuve datée)
  - Preuve : `T-487-2026-11-18T2237Z-etape0.md` (étape 0 à 22:35:23Z-22:36:08Z, `verify.sh --step 0` FAIL=0 à 22:36Z : B0-cilium-chaining, B0-ccnp-*, B0-vap-deny), avant l'étape 1 (22:40:46Z).
- [ ] `lab-pg` Ready sur un volume de bloc ≤ 50 Go ; bloc OCI total ≤ 200 Go
  - Non coché : `lab-pg` Ready, PVC 50 Gi Bound (`T-487-etape10.md`, 2026-11-18T23:17:59Z ; `T-487-empreinte-et-verify-all.md`, 23:09:43Z), mais aucune preuve du total de bloc OCI (≤ 200 Go).

## Notes
Exécutant unique sur OKE : la session locale, par session bastion ouverte par Paul. Aucune écriture hors `openchoreo-*` et `lab-*`. Coût attendu : 0 € ; tout dépassement est un MANDAT (ADR-0017).

Décision de Paul (2026-11-18) : T-487 réinstalle Cilium et `deny-imds` ; aucun risque accepté sans cela. Les volumes orphelins du drill du 17/11 (100 Go) sont libérés avant l'installation (MANDAT côté homelab-infra), pour que `lab-pg` tienne dans le quota.

Accéléré (arbitrages de Paul n°3, 2026-11-18) : plus de gel de 3 semaines ni d'inventaire préalable ; OKE n'a aucune donnée importante et est recréé vierge par homelab-infra (T-490).

Note datée (2026-11-18, preuves RUNTIME OKE sous `backlog/evidence/T-487-*.md`) : plateforme seule installée sur OKE, étapes 0 à 11, durée d'environ 30 min (22:35Z à 23:05Z). Empreinte mesurée à 23:09:43Z : 32 % CPU, 23 % RAM, 26 pods (seuils 70 % et 33 pods). Deux écarts connus : B1-vap-digest (FAIL, binding `baseline-image-digest` de kube-ops en Warn/Audit, non modifié) et B6-sa-effective (FAIL accepté par Paul, SA kgateway). Correctif de `verify.sh --all` (6b) : l'étape 6b (portail Backstage, `--with-portal`) n'est pas installée ; sans correctif, `--all` l'inclut et rend 7 FAIL et 1 BLOCKED (B6b-*) à tort. Dernier passage `--all` (23:09:52Z à 23:20:38Z) : 99 PASS, 8 FAIL, 1 BLOCKED. Le correctif lui-même n'est pas prouvé dans le dossier de preuves.
