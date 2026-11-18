---
id: T-318
title: "Travailleur homelab en tirage sortant (claude -p) sur VM isolée, sans runner GitHub ni secret"
status: todo
phase: P1
adr: [0003, 0021]
depends_on: [T-002, T-061, T-313, T-360]
class: REVUE + MANDAT
velocity: true
lane: hybride
stage: S2
model: claude-opus-5-5
effort: high
routing: R08-manifestes-k8s-openchoreo
github_issue: null
---
# T-318 — Travailleur homelab en tirage sortant (claude -p) sur VM isolée, sans runner GitHub ni secret

## Intention
VM Proxmox dédiée (environ 8 vCPU, 32 Go, VLAN isolé) ; un travailleur interroge GitHub en sortant, prend un ticket affecté, exécute claude -p dans un worktree conteneurisé détruit après le job ; aucun kubeconfig, aucun identifiant de production ; pas de runner Actions enregistré sur ce dépôt public.

## Périmètre de fichiers
ops/workers/ (compose, scripts de bootstrap), docs/AGENT-RUNNERS.md

## Critères de fin
- [ ] aucune connexion entrante ; un job conteneurisé fait un cycle complet puis le conteneur disparaît (preuve datée)
- [ ] mesure : mémoire et CPU pour N jobs simultanés, N maximal consigné
- [ ] preuve que claude -p avec CLAUDE_CODE_OAUTH_TOKEN s'authentifie par l'abonnement (/status) : PASS/FAIL daté
- [ ] taille de la VM dans le budget du homelab (T-360) ; concurrence plafonnée par la RAM et la température (Tctl)

## Notes
MANDAT : création de la VM et du réseau (homelab-infra possède Proxmox : suivre ses règles). GitHub déconseille les runners auto-hébergés sur dépôt public (docs secure-use, lue le 2026-11-18) et les minutes hébergées y sont gratuites : gain faible, risque élevé. Les environnements auto-hébergés officiels sont Team/Enterprise.

Proposé par la recherche `factory` (clé FAC-9) ; intégration 2 du 2026-11-18.

Conflit à trancher par Paul : la proposition visait 8 vCPU / 32 Go alors que le budget homelab (64 Gio) laisse 6-8 Gio de marge après la VM lab ; la taille vient de T-360.
