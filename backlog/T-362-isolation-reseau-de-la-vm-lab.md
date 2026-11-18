---
id: T-362
title: "Isolation réseau de la VM lab (UniFi, pare-feu)"
status: todo
phase: P0
adr: [0003]
depends_on: [T-061, T-361]
class: MANDAT
velocity: false
lane: hybride
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R08-manifestes-k8s-openchoreo
github_issue: null
---
# T-362 — Isolation réseau de la VM lab (UniFi, pare-feu)

## Intention
Le lab sort vers Internet mais n'atteint ni l'hôte Proxmox, ni le NAS, ni le réseau de gestion ; accès admin par le chemin NetBird existant.

## Périmètre de fichiers
dépôt homelab-infra terraform/unifi (hors de ce dépôt)

## Critères de fin
- [ ] règles versionnées ; test depuis un pod lab : Internet OK, hôte Proxmox et LAN de gestion refusés, preuve datée
- [ ] aucune règle ne contourne une NetworkPolicy

## Notes
Proposé par la recherche `homelab` (clé HOME-2) ; intégration 2 du 2026-11-18.
