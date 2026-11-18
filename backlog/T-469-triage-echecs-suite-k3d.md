---
id: T-469
title: "Triage des cas FAIL préexistants de la suite k3d"
status: in-progress
phase: P0
adr: [0002]
depends_on: [T-456]
class: REVUE
velocity: false
lane: ci
stage: S2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---

# T-469 — Triage des cas FAIL préexistants de la suite k3d

## Intention
La suite `k3d` (`tests/k3d/run.sh`) a des cas FAIL préexistants : T01g, T02, T03a, T04a, T05, T06a, T06b, T06c, T06e, T03f (source : run 44313941923 ; contexte : `docs/CI-K3D.md`). Pour chaque cas : trouver la cause, puis corriger le cas ou le déclarer `KNOWN_FAIL` avec un motif écrit. Un cas ne reste jamais FAIL sans décision.

## Périmètre de fichiers
tests/k3d/run.sh, tests/k3d/fixtures/10-projects.yaml, docs/CI-K3D.md, backlog/T-469-triage-echecs-suite-k3d.md

## Critères de fin
- [x] Tableau cas par cas dans `## Notes` : cause prouvée (log du run 44313941923 ou d'un run plus récent), décision (corrigé ou KNOWN_FAIL)
- [x] Chaque cas est corrigé ou marqué `KNOWN_FAIL` avec un motif écrit dans `tests/k3d/run.sh` et `docs/CI-K3D.md`
- [ ] Un dispatch daté de la suite `k3d` ne montre aucun FAIL non motivé (lien du run et date ; k3d ≠ OKE)
- [ ] `tools/dev/check --static --changed` : verdict reporté dans la PR

## Notes
Dépend de T-456 (correctif T12, `done`). Un correctif qui touche `platform/` sort du périmètre : ouvrir un ticket séparé. Ne pas désactiver ni contourner une politique d'admission, la PSA ou une NetworkPolicy pour faire passer un cas.

### Triage (2026-11-18, source : journal et artefact `k3d-k3d` du run 44313941923, PR #69)

Le run compte 24 FAIL, pas 10 : PASS=28 FAIL=24 NOT_TESTED=1. Preuves : `diagnostic.txt` de l'artefact (journal du controller-manager : `DeploymentPipeline "default" not found` pour chaque Component) et `tests/k3d/evidence/<id>.txt`.

Cause racine R1 (classe : défaut de fixture, environnement CI) : `10-projects.yaml` citait le pipeline `default`, que seul l'installateur d'exemple crée ; la CI installe `standard` (`platform/install/manifests/40-openchoreo-env.yaml`, `promotionPaths: []`). Aucun ReleaseBinding, aucun pod, `sondes : A= B=` vides. Décision : corrigé (pipeline de fixture `t-pipeline` development vers production, modèle `tests/mcp/fixtures/lab-mcp-target.yaml`). Statut : NOT_TESTED (pas de k3d dans le conteneur de l'agent).

| Cas | Classe | Cause prouvée | Décision |
|---|---|---|---|
| T01g | fixture (R1) | 0 pod Running, attendu 5 | corrigé |
| T02, T03a, T04a, T05, T06a, T06b | fixture (R1) | `releasebindings ... NotFound` | corrigé |
| T06c | fixture (R1) | aucun PVC, `Bound` absent | corrigé |
| T06e | fixture (R1) | `t-second-pvc created` : aucun PVC existant, quota `pvcs=1` non atteint | corrigé |
| T07b-d, T08a-d, T09a, T09-* (3), T09b, T10 | fixture (R1) | `error: pod, type/name or --filename must be specified` : sondes `PA`/`PB` vides | corrigé |
| T03f | test périmé | VAP `lab-cluster-agent-scope` R3 exige labels PSA et `platform.smadja.dev/cell` (`reçu enforce=`). Refus voulu | corrigé (Namespace avec labels) |
| T03i | test périmé | VAP R6 : `hors du gabarit cnpg-lab-db`. Refus voulu | corrigé (Job au gabarit du CRT, témoin de `tests/vap/run.sh` V1-P08) |

Total : 22 cas R1 + 2 tests périmés = 24. Aucun défaut produit trouvé, aucun `KNOWN_FAIL`, `platform/` inchangé. T12a-e restent PASS.

Reste (critère 3) : dispatch daté de `k3d-integration` sur la branche `claude/t-469-triage-k3d`. Tant qu'il n'est pas fait, le ticket reste `in-progress`.
