---
id: T-343
title: "Spike runners homelab pour le dépôt public : ARC JIT sans secret limité à `main`, ou aucun runner (preuve par Job PostSync)"
status: todo
phase: P1
adr: [0022]
depends_on: [T-061, T-342]
class: REVUE + MANDAT
velocity: false
lane: hybride
stage: S2
model: claude-sonnet-5-5
effort: high
routing: R08-manifestes-k8s-openchoreo
github_issue: null
---
# T-343 — Spike runners homelab pour le dépôt public : ARC JIT sans secret limité à `main`, ou aucun runner (preuve par Job PostSync)

## Intention
GitHub déconseille « presque toujours » les runners auto-hébergés pour un dépôt public (PR de tiers, compromission persistante) et recommande des runners JIT éphémères. Décider : (a) aucun runner homelab, le N2 est piloté par Job PostSync/CronJob dans le cluster qui publie la preuve (T-005), ou (b) scale set ARC dédié (pas celui d'OpenTofu), JIT, zéro à N pods, non privilégié, sans secret, default-deny, groupe réservé aux workflows de `main` et à workflow_dispatch. Défaut : (a). Relire les modes ARC (non lus) [NV].

## Périmètre de fichiers
docs/AGENT-RUNNERS.md, platform/ (si le scale set vit ici), PR cross-dépôt vers homelab-infra / kube-ops

## Critères de fin
- [ ] décision (a) ou (b) écrite avec le risque GitHub cité ; si (b) : essai prouvant qu'une PR de fork ne peut pas planifier de job sur ce groupe (preuve datée)
- [ ] si (b) : pod runner securityContext restricted, aucun volume hôte, aucun Secret monté
- [ ] coût : frais de plateforme (0,002 USD/min annoncés puis reportés, gratuits en dépôt public) vérifiés à la source à la date de la décision
- [ ] le propriétaire du déploiement (kube-ops ou homelab-infra) est nommé ; aucune écriture hors périmètre
- [ ] (repris de FAC-9) décision écrite : runner Actions sur le homelab seulement si le dépôt devient durablement privé (T-300 n'est que temporaire)

## Notes
Frontière de dépôt : homelab-infra possède l'ARC d'OpenTofu ; ne pas mélanger. MANDAT : la création de l'objet côté homelab est un geste de Paul.

Proposé par la recherche `harness` (clé HAR-13) ; intégration 2 du 2026-11-18.
