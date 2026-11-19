---
id: T-060
title: "Résidu kgateway : SA avec lecture des Secrets cluster-wide (B6-sa-effective FAIL)"
status: todo
phase: P2
adr: [0006]
depends_on: [T-001, T-061, T-061b]
class: REVUE
velocity: false
lane: socle-oke
stage: I2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-060 — Résidu kgateway : SA avec lecture des Secrets cluster-wide (B6-sa-effective FAIL)

## Intention
Fermer le résidu de moindre privilège accepté (STATE.md §1) avant tout credential réel.

## Périmètre de fichiers
platform/install/values/kgateway.yaml, tools/oke/verify.sh, tools/oke/render-check.sh, tests/k3d/

## Critères de fin
- [ ] `verify.sh` : B6-sa-effective PASS daté sur OKE
- [ ] test de non-régression en CI k3d

## Notes
2026-11-18 — La PR #138 (post-traitement RBAC kgateway) est FERMÉE sans fusion. Décision de Paul (Q12, 2026-11-18) : le résidu « kgateway lit et écrit les Secrets de tout le cluster » (B6-sa-effective) est ACCEPTÉ et documenté jusqu'à FINAL0 (OKE jetable). Reprise à FINAL0 avec kgateway v2.5 (`rbac.create=false` + ClusterRole versionné dans Git, PR amont kgateway #14105). Source : docs/research/OPENCHOREO-FIDELITE-ECARTS.md. Aucun critère de fin n'est coché.

### Reprise (2026-11-19, T-510)
- Fait : décision de Paul (résidu accepté jusqu'à FINAL0) ; PR #169 en brouillon, NON appliquée, NON fusionnée. Les 2 cases restent décochées ; `verify.sh` rend toujours B6-sa-effective FAIL (2026-11-19, `T-487-bras-o-applicationset-2026-11-19.md`).
- Reste : à FINAL0, kgateway v2.5 (`rbac.create=false`, ClusterRole versionné), puis B6-sa-effective PASS sur OKE et test de non-régression k3d.
- Prochaine action : aucune avant FINAL0 ; ne pas fusionner #169 sans décision de Paul.
- Qui : Paul (levée du risque), puis agent Opus ou Sonnet en REVUE.
- Pièges : un credential réel posé dans OKE n'est admis que par décision explicite de Paul (déjà prise pour l'App `openchoreo-status`, révocable).
