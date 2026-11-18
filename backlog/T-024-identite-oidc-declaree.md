---
id: T-024
title: "Identité : ThunderID retiré, `identity.mode: oidc | proxy | none`"
status: todo
phase: P2
adr: [0007]
depends_on: [T-023]
class: AUTONOME
github_issue: null
---
# T-024 — Identité : ThunderID retiré, `identity.mode: oidc | proxy | none`

## Intention
Client OIDC Authentik généré (blueprint) avec secret dans OpenBao ; mode proxy par l'outpost ; accès par groupe.

## Périmètre de fichiers
docs/schema/, tools/appgen/, platform/identity/, clusters/*/capabilities.yaml

## Critères de fin
- [ ] ThunderID absent du contrat et du chart
- [ ] k3d : client créé sans geste, hors groupe → refus
- [ ] preuve sur une app réelle
