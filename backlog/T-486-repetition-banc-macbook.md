---
id: T-486
title: "Répétition non comptée du banc A/B sur le MacBook (k3d, deux bras l'un après l'autre)"
status: todo
phase: P1
adr: [0025, 0022]
depends_on: [T-485, T-212]
class: AUTONOME + MANDAT
velocity: true
lane: banc-ab
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-486 — Répétition non comptée du banc A/B sur le MacBook

## Intention
Déboguer le harnais, les graders et le bootstrap des deux bras sur un k3d local (Colima) avant d'engager les runs comptés sur OKE. Aucun résultat de cette répétition ne compte pour la porte 1 (k3d ≠ OKE).

## Périmètre de fichiers
tests/bench-ab/rehearsal/, docs/research/POC-AB-REHEARSAL.md

## Critères de fin
- [ ] MANDAT Paul : architecture du MacBook confirmée et usage de Colima pour ce dépôt consigné (portée de l'interdit « VM Linux du Mac » du journal de homelab-infra précisée)
- [ ] chaque tâche T1-T5 et chaque piège joué une fois par bras ; le grader rend le verdict attendu (rapport daté, niveau RUNTIME k3d)
- [ ] T2 (base PostgreSQL) prouvée en local avec CNPG, en repli si aucun volume OKE n'est libéré
- [ ] Job de publication `app-status.v1` vers GitHub exécuté depuis le k3d local (preuve datée)
- [ ] empreinte relevée (requests, pods) des deux bras, pour borner T-487

## Notes
Exécuté par le coordinateur sur le Mac (skill `openchoreo-setup`, KUBECONFIG dédié) ; les agents n'ont pas de kubeconfig. Dimension proposée : Colima 6 vCPU / 14 Gio [E].
