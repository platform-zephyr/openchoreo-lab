---
id: T-491
title: "ApplicationSet par app pour generated/ (modèle apps-generated de kube-ops), remplace la liste manuelle de lab-apps"
status: todo
phase: P1
adr: [0025, 0002]
depends_on: [T-061b]
class: REVUE
velocity: true
lane: socle-oke
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-491 — ApplicationSet par app pour `generated/`

## Intention
`lab-apps` liste chaque projet à la main dans ses sources : une nouvelle app exige d'éditer `platform/`, et la santé Argo est globale. Reprendre le modèle de l'ApplicationSet `apps-generated` de kube-ops (une Application par app, projet fixe jamais tiré du dépôt applicatif, `preserveResourcesOnDeletion`, `missingkey=error`) sur `generated/namespaces/default/projects/*`, pour une santé et un check run par app (`docs/research/POC-OPENCHOREO-STRATEGY.md` §3).

## Périmètre de fichiers
platform/install/argocd/apps/lab-apps.yaml, platform/install/argocd/project-lab.yaml, tools/oke/argo_guard.py, tests/argo-escalation/

## Critères de fin
- [ ] ApplicationSet `lab-o` (générateur Git par répertoire), projet `lab-o` fixe, Applications nommées par app ; ligne `NOTICE` pour le modèle repris de kube-ops (MIT, SHA noté)
- [x] `argo_guard.py` refuse un projet ou une destination tirés du dépôt applicatif (test de refus)
- [ ] suite `tests/argo-escalation/` verte sur Argo CD v3.5.1 en CI k3d avec l'ApplicationSet (preuve datée)
- [ ] ajout d'une app par `apps/<app>/app.yaml` seul, sans modification de `platform/` (test sur une app témoin)

## Notes
Contrôleur ApplicationSet aujourd'hui à 0 réplica (`platform/install/values/argocd.yaml`) : activé par T-487. Sert aussi le bras K (copie de l'ApplicationSet de kube-ops, T-212).
