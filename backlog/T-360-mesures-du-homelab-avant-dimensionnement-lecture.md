---
id: T-360
title: "Mesures du homelab avant dimensionnement (lecture seule)"
status: todo
phase: P0
adr: [0003, 0017]
depends_on: []
class: AUTONOME + MANDAT
velocity: true
lane: hybride
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R08-manifestes-k8s-openchoreo
github_issue: null
---
# T-360 — Mesures du homelab avant dimensionnement (lecture seule)

## Intention
Relever p95 sur 14 jours du CPU et de la RAM de la VM kube-ops, usage NVMe et miroir HDD, température Tctl, plafond ARC ZFS ; fixer le budget RAM/CPU/disque des VM.

## Périmètre de fichiers
docs/state/homelab-capacity.yaml, docs/research/

## Critères de fin
- [ ] tableau daté (p50/p95/pic) CPU, RAM, disque, Tctl ; sources Prometheus et commandes de lecture
- [ ] budget 64 Gio versionné avec seuils d'alerte 80 %
- [ ] décision chiffrée : taille cible de la VM kube-ops et de la VM lab

## Notes
MANDAT = Paul lance les commandes sur l'hôte Proxmox (l'agent n'y a pas accès). Aucune IP ni nom d'hôte dans le dépôt public.

Proposé par la recherche `homelab` (clé HOME-0) ; intégration 2 du 2026-11-18.
