---
id: T-515
title: "Preuves OKE en attente d'un opérateur : lab-o, searxng, probes, verify --all, test d'écriture de l'App, maxPods"
status: todo
phase: P1
adr: [0025, 0011]
depends_on: []
class: MANDAT
velocity: false
lane: preuve
stage: S1
model: human
effort: none
routing: R0-geste-humain
github_issue: null
---
# T-515 — Preuves OKE en attente d'un opérateur : lab-o, searxng, probes, verify --all, test d'écriture de l'App, maxPods

## Intention
Plusieurs critères de couloirs fusionnés ne se prouvent que sur OKE, par la session locale ou par Paul. Les regrouper pour qu'un seul opérateur les joue dans l'ordre, puis cocher les tickets d'origine. `model: human` : gestes de Paul ; les relevés en lecture peuvent être faits par la session OKE locale.

## Périmètre de fichiers
backlog/evidence/T-515-*.md

## Critères de fin
- [ ] `lab-o` : liste des Applications générées par cluster relevée (T-502), preuve datée
- [ ] searxng : Secret `searxng-secret` (clé `SEARXNG_SECRET`, valeur aléatoire générée par tube, jamais affichée) dans `lab-secrets` ; ExternalSecret et pod Ready (T-499 case 4)
- [ ] probes `healthPath` : pods Ready avec probes sur OKE ; `open-connector` non prouvé à ce jour (T-010)
- [ ] `verify.sh --all` rejoué : verdict par contrôle, écarts connus B1-vap-digest et B6-sa-effective listés (T-487 case 2) ; total de bloc OCI et comptage d'un seul Argo CD (T-487 cases 3 et 6)
- [ ] PAUL : test d'écriture négatif de l'App `openchoreo-status` (permissions Checks et Commit statuses en écriture, Metadata en lecture ; l'écriture de contenu est refusée), preuve datée (T-489 case 4)
- [ ] `maxPods` du kubelet et marge CPU relevés (marge actuelle : 1 pod, T-487) ; décision si > 33 pods

## Notes
Ordre conseillé : searxng, probes, `verify.sh --all`, `lab-o`, `maxPods`, puis le test de l'App par Paul. Aucune valeur de secret dans les preuves (noms seulement). Écriture dans `openchoreo-*` et `lab-*` seulement. Cocher aussi les tickets d'origine après chaque preuve.
