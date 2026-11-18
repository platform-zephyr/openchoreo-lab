---
id: T-361
title: "VM Talos « lab » dédiée sur Proxmox (cluster séparé de kube-ops)"
status: todo
phase: P0
adr: [0003]
depends_on: [T-061, T-061b, T-360, T-488]
class: MANDAT
velocity: false
lane: hybride
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-361 — VM Talos « lab » dédiée sur Proxmox (cluster séparé de kube-ops)

## Intention
Créer une VM Talos mono-nœud (6 vCPU, 8 Gio puis 16, disque système 64 Gio, volume de données NVMe + HDD) avec ses propres secrets machine, sans kube-proxy, Cilium, extension gVisor et qemu-guest-agent ; kubeconfig distribué par Doppler.

## Périmètre de fichiers
dépôt homelab-infra (hors de ce dépôt) : seconde instance du module talos ; ici : demande exacte et critères

## Critères de fin
- [ ] plan OpenTofu ARC montrant uniquement des créations (aucun changement de la VM kube-ops)
- [ ] nœud Ready, preuve runtime datée, kubeconfig lab dans Doppler sans valeur affichée
- [ ] poids CPU (cpuunits) et cpulimit posés ; RAM de la VM kube-ops inchangée tant que T-360 n'a pas conclu

## Notes
Racine proxmox existante ou racine dédiée proxmox-lab : décision de Paul. L'agent de ce dépôt prépare la demande ; l'application se fait dans homelab-infra via ARC.

Proposé par la recherche `homelab` (clé HOME-1) ; intégration 2 du 2026-11-18.

Passé de S0 à S1 (consensus n°2 et arbitrages de Paul, 2026-11-18) : pas nécessaire au pilote 24 h (voie parallèle).

(consensus n°2 et arbitrages de Paul, 2026-11-18) : contraintes thermique et NVMe levées (arbitrage 3). Des services de kube-ops peuvent être désactivés pour faire de la place à la VM lab : liste et gain mesurés par T-360, désactivation par PR dans kube-ops, geste de Paul.

Retardé par ADR-0025 (2026-11-18) : dépend de la porte 1 (T-488) ; aucun geste sur le homelab avant une valeur prouvée pour les agents.

Inchangé (arbitrages de Paul n°3, 2026-11-18) : reste derrière la porte 1 (T-488).
