---
id: T-212
title: "Backend « plain » d'appgen (spike 3 jours) : chart commun + Argo par cluster"
status: todo
phase: P1
adr: [0001, 0020]
depends_on: [T-061, T-214]
class: AUTONOME
velocity: false
lane: moteur-plain
stage: S2
github_issue: null
---
# T-212 — Backend « plain » d'appgen (spike 3 jours) : chart commun + Argo par cluster

## Intention
Rendre le même `app.yaml` sans OpenChoreo (inspiré de `platform-app` et `apps-generated` de kube-ops) pour comparer à la porte (C5).

## Périmètre de fichiers
tools/appgen/ (backend séparé), platform/plain/

## Critères de fin
- [ ] une app A sur le homelab via le backend plain, PASS runtime daté
- [ ] même suite `_checks`
- [ ] mesures : délai, lignes et tickets propres au moteur

## Notes
Échec = pas d'app A Ready avec PASS après 3 jours d'agent (ADR-0020 §3).
