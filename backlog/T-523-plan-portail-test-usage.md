---
id: T-523
title: "Plan : portail OpenChoreo sur OKE avec ThunderID pour un test d'usage jetable de Paul"
status: in-progress
phase: P1
adr: []
depends_on: []
class: AUTONOME
velocity: false
lane: docs
stage: S1
model: claude-opus-5-5
effort: low
routing: R2-texte
github_issue: null
---
# T-523 — Plan du portail pour le test d'usage de Paul

## Intention
Critère de Paul : seules comptent les fonctions et la simplicité d'exploitation, pas les briques (Flux ou Argo CD,
ThunderID ou Authentik). Écrire le plan d'installation du portail (étape 6b) sur OKE avec l'identité par défaut
d'OpenChoreo (ThunderID), pour un test jetable sans geste Authentik ; l'accès en une commande ; une table des fonctions
d'OpenChoreo face à kube-ops ; la checklist du test. Rédaction seule : aucune écriture cluster, aucun développement.

## Périmètre de fichiers
docs/research/PLAN-PORTAIL-TEST-USAGE.md, backlog/T-523-plan-portail-test-usage.md

## Critères de fin
- [x] Note ≤ 3 pages, français, STE80, affirmations marquées [L], [D] ou [H] avec lien vers la source primaire
- [x] Plan (valeurs minimales, ordre, risques, retour arrière, empreinte CPU, pods et disque), accès en une commande,
      table des fonctions, checklist de 30 à 45 min
- [x] Aucune valeur secrète, OCID, IP ni hôte interne
- [ ] `tools/dev/check --static --changed` et `python3 tools/backlog/check.py` : verdict reporté dans la PR
- [ ] PAUL : décisions D1 (écart d'identité pour le test), D2 (libérer 150 Go de disque), D3 (durée de vie)
- [ ] Exécution du plan et test de Paul (ticket séparé, après D1-D3)

## Notes
Constat clé : ThunderID 1.0.1 crée 3 volumes persistants ; sur OKE, 3 × 50 Go minimum, soit tout le disque libre du
free tier. Hors périmètre : `tools/appgen/`, `tools/oke/argo_guard*`, ADR, cluster. Dépend de T-520 (PR #196, non
fusionnée au moment de la rédaction).
