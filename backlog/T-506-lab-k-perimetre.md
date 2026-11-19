---
id: T-506
title: "AppProject lab-k : svc-<app> par noms explicites (E1), kinds */* de kube-ops et lab-pg (E5)"
status: in-progress
phase: P1
adr: [0025]
depends_on: [T-502]
class: REVUE
velocity: false
lane: socle-oke
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-506 — périmètre de lab-k (E1, E5)

## Intention
Revue de fidélité du bras K (`tests/bench-ab/arm-k/FIDELITY-REVIEW.md`, PR #171) : E1 (echo-bench sort de son
namespace) et E5 (kinds trop étroits pour miniflux, M2) bloquent la passe 0. Décision de Paul (« oui » du
2026-11-19, transmise par le coordinateur) : `lab-k` admet svc-echo-bench, svc-miniflux, svc-ntfy par NOMS
EXPLICITES (jamais `svc-*`), les kinds `*/*` du projet `applications` de kube-ops, la destination lab-pg ; la
blacklist reste. `lab-k-root` ne change pas. Argo écrit, pas un agent : AGENTS.md ne change pas.

## Périmètre de fichiers
platform/install/argocd/project-lab.yaml, tools/oke/verify.sh, tools/oke/argo_guard_k.py, tools/oke/argo_guard.py, tests/argo-guard/, backlog/T-506-lab-k-perimetre.md, backlog/T-502-lab-o-liste-par-cluster.md

## Critères de fin
- [x] `lab-k` : destinations lab-k-*, svc-echo-bench, svc-miniflux, svc-ntfy, lab-pg ; Namespace lab-k-* et les
  trois svc-<app> ; kinds `*/*` ; blacklist inchangée — STATIC, 2026-11-19
- [x] argo_guard L1/L2 et P2 alignés (joker de kinds admis pour lab-k seul) ; cas négatifs : `svc-*` en
  destination ou Namespace refusé, `*/*` dans lab-o refusé, blacklist vidée refusée — STATIC, 2026-11-19
- [x] `tools/oke/verify.sh` B11-lab-k-dest aligné sur les cinq destinations — STATIC (jq contre le manifeste), 2026-11-19
- [ ] Preuve OKE : l'AppProject lab-k lu dans lab-argocd est conforme après synchro (lecture seule)

## Notes
- Reprise 2026-11-19 (passation vers l'orchestrateur du Mac) :
  - Fait : branche `claude/t-506-lab-k-perimetre` (empilée sur T-502), PR en brouillon ; run.sh 71 PASS, unittest OK.
  - Reste : (1) fusionner #174 (T-502) d'abord, puis `git merge origin/main` ici ; (2) aligner `tools/oke/verify.sh`
    l.449-450 (B11 attend `svc-*`), sinon B11 FAIL sur OKE ; (3) sortir du brouillon, `ci-ok`, squash.
  - Commandes : `python3 -I tools/oke/argo_guard.py .` ; `tests/argo-guard/run.sh` ;
    `python3 -I -m unittest discover -s tests/argo-guard` ; `PYTHONDONTWRITEBYTECODE=1 tools/dev/check --static --changed`.
  - Pièges : cliquet de 600 lignes (`argo_guard.py` = 600 pile) ; `golden.json.gz` à régénérer
    (`python3 -I tests/argo-guard/corpus.py | gzip -9n > tests/argo-guard/golden.json.gz`) après contrôle du diff.
  - Risque à arbitrer (Paul) : `*/*` + lab-pg = l'Argo du bras K peut écrire tout kind namespacé non blacklisté dans
    lab-pg (NetworkPolicy, Cluster CNPG de la plateforme). Un AppProject ne borne pas les kinds par destination.
- Décision de Paul (2026-11-19, transmise par l'orchestrateur) : risque accepté ; `postgresql.cnpg.io/Cluster`
  ajouté à la blacklist de lab-k ; `*/*` gardé ; NetworkPolicy NON blacklistée. Garde L1 (exiger le Cluster) et
  son test négatif : NON faits ici (action refusée par le classifieur de permissions de la session) ; à faire.
