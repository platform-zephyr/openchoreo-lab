---
id: T-498
title: "Étudier la démo native OpenChoreo (objets, exposition, IdP) et la comparer à app.yaml"
status: in-progress
phase: P1
adr: [0020, 0001, 0007]
depends_on: []
class: AUTONOME
velocity: false
lane: recherche
stage: S1
model: claude-haiku-5-5
effort: medium
routing: R2-texte
github_issue: null
---
# T-498 — Démo native OpenChoreo : objets, exposition, écarts avec `app.yaml`

## Intention
Principe de Paul : adopter les primitives natives d'OpenChoreo, ne pas le déformer. Lire comment l'amont présente et
déploie une application complète (catalogue d'exemples, `samples/gcp-microservices-demo`, fork du playground, doc de
l'IdP intégré et du MCP). Comparer avec notre contrat `apps/<nom>/app.yaml` et `tools/appgen`. Estimer ce qui serait
déployable tel quel sous la limite de 33 pods d'OKE (32 utilisés). Ne rien déployer.

## Périmètre de fichiers
docs/research/OPENCHOREO-DEMO-NATIVE.md, backlog/T-498-demo-native-openchoreo.md

## Critères de fin
- [x] Note `docs/research/OPENCHOREO-DEMO-NATIVE.md` (≤ 2 pages) : objets natifs, exposition et authentification,
  écarts avec avis, estimation pods/CPU/RAM, questions à Paul — STATIC, 2026-11-19
- [ ] Paul répond aux 5 questions du §5 de la note (cible homelab, types amont ou portage `app.yaml`, ThunderID,
  délégation à `occ`, console de démo) ; réponses reportées dans `## Notes`

## Notes
- Console de démo en lecture seule : 403 et défi Cloudflare anti-robot le 2026-11-19 ; non contourné, aucune connexion.
- Suites possibles selon les réponses : portage de la démo en `app.yaml` (homelab), T-074 (retrait de ThunderID),
  exposition de `ReleaseBinding.spec.workloadOverrides` dans le contrat.
