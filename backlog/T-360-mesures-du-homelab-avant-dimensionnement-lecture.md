---
id: T-360
title: "Mesures du homelab avant dimensionnement (lecture seule)"
status: in-progress
phase: P0
adr: [0003, 0017]
depends_on: []
class: AUTONOME + MANDAT
velocity: true
lane: hybride
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-360 — Mesures du homelab avant dimensionnement (lecture seule)

## Intention
Relever p95 sur 14 jours du CPU et de la RAM de la VM kube-ops, usage NVMe et miroir HDD, température Tctl, plafond ARC ZFS ; fixer le budget RAM/CPU/disque des VM.

## Périmètre de fichiers
docs/state/homelab-capacity.yaml, docs/research/, tools/homelab/, tests/homelab/

## Critères de fin
- [x] script de relevé en lecture seule livré : `tools/homelab/measure.sh`, test `tests/homelab/measure_test.sh` (commandes simulées : forme, anonymisation, lecture seule), procédure `docs/research/HOMELAB-MESURES.md` (preuve STATIC, 2026-11-18)
- [ ] tableau daté (p50/p95/pic) CPU, RAM, disque, Tctl ; sources Prometheus et commandes de lecture
- [ ] budget 64 Gio versionné avec seuils d'alerte 80 %
- [ ] décision chiffrée : taille cible de la VM kube-ops et de la VM lab

## Notes
MANDAT = Paul lance les commandes sur l'hôte Proxmox (l'agent n'y a pas accès). Aucune IP ni nom d'hôte dans le dépôt public.

Proposé par la recherche `homelab` (clé HOME-0) ; intégration 2 du 2026-11-18.

Passé de S0 à S1 (consensus n°2 et arbitrages de Paul, 2026-11-18) : pas nécessaire au pilote 24 h (voie parallèle).

(consensus n°2 et arbitrages de Paul, 2026-11-18) : mesurer aussi la RAM libérable en désactivant des services de kube-ops (arbitrage 3).

## Avancement (2026-11-18)
Livré (niveau STATIC, aucune exécution sur l'hôte Proxmox) : `tools/homelab/measure.sh`, `tests/homelab/measure_test.sh`, `docs/research/HOMELAB-MESURES.md`. Le test passe avec des commandes simulées ; shellcheck propre. Le tableau `docs/state/homelab-capacity.yaml` n'existe pas : aucune valeur n'a été relevée, les trois critères ci-dessus restent `NOT_TESTED`.

Reste : lancement par Paul (MANDAT), une commande, voir `docs/research/HOMELAB-MESURES.md` ; puis l'agent remplit `docs/state/homelab-capacity.yaml`, versionne le budget 64 Gio (seuils 80 %) et chiffre la taille cible des VM kube-ops et lab.
