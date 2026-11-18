# ADR-0025 — Validation d'OpenChoreo en deux portes : valeur pour les agents sur OKE, puis exploitation hybride
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0003 (amendé), ADR-0017, ADR-0020 (amendé), ADR-0021 ; `docs/research/POC-OPENCHOREO-STRATEGY.md`

## Contexte
- Paul propose (2026-11-18) de valider d'abord qu'OpenChoreo simplifie le modèle opérationnel des agents, en utilisant
  OKE comme environnement de dev jetable, puis de migrer les clusters existants vers un déploiement hybride, sans
  aucune perturbation du homelab ni de kube-ops pendant la validation.
- ADR-0020 (amendement Fable, point 7) interdit toute mesure sur OKE et place la porte sur la VM lab du homelab. Cette
  voie exige 4 gestes MANDAT (T-360, T-361, T-362, T-366) avant la première mesure de valeur.
- OpenChoreo tourne déjà sur OKE avec le bundle de sécurité arm64 (pilote `whoami` PASS le 2026-11-17).
- Le comparateur prévu (backend « plain » à écrire, T-212) n'est pas le chemin réel : kube-ops a déjà un contrat à un
  fichier (`apps-generated`, chart `platform-app`, `app-status.v1`) et un chemin Kustomize pour le reste.

## Décision
1. **Porte 1 « valeur pour les agents »** : banc A/B préenregistré (5 tâches, 5 pièges, 3 runs par tâche et par bras,
   seuils S1-S7 de `POC-OPENCHOREO-STRATEGY.md` §2.4) sur **OKE réinitialisé**, après une répétition non comptée sur le
   MacBook. Bras K = chemin kube-ops reproduit dans un dépôt bac à sable figé ; bras O = ce dépôt. Même cluster, même
   Argo, même canal d'observation (statut publié dans GitHub), même agent et mêmes plafonds.
2. **Seuils figés avant la première mesure** ; Paul peut les ajuster avant, jamais après. Verdict : « valeur prouvée »
   si S1, S6 et S7 passent et au moins 3 de S2-S5 ; **arrêt** (on garde kube-ops) si S1 ou S6 échoue ou si moins de 2
   de S2-S5 passent ; zone grise à 2 : Paul choisit, sans second banc sur la même hypothèse.
3. **Porte 2 « exploitation hybride »** (T-211) : seulement si la porte 1 est positive. Elle reprend C2 (VM lab), C3,
   C4 « jour 2 », C7 et ajoute la règle de routage des agents entre OpenChoreo et kube-ops. Aucune migration d'app de
   kube-ops avant la porte 2.
4. **OKE pendant la porte 1** : environnement de dev du POC, réservé au banc pendant une fenêtre de 3 semaines inscrite
   par Paul dans le journal de homelab-infra. Le CP OpenChoreo y tourne **à titre de banc**, pas comme cible. Coût :
   0 € (2 OCPU / 12 Go, ≤ 200 Go de bloc) ; tout dépassement est un MANDAT.
5. **Ce qui ne change pas** : D11 (CP cible sur la VM lab du homelab) reste la décision par défaut ; Paul peut la rouvrir
   en porte 2 avec la mesure C2 faite sur OKE. Aucune écriture sur le homelab ni sur kube-ops pendant la porte 1.

## Amendements proposés
- **ADR-0020** : le point 7 de l'amendement Fable (« aucune mesure sur OKE ») est remplacé par le point 1 ci-dessus pour
  C1, C5 et C6. C5 compare OpenChoreo au chemin kube-ops reproduit (bras K) au lieu d'un backend plain écrit pour la
  porte. La décision « adopter / abandonner » se prend en deux temps (porte 1, porte 2).
- **ADR-0003** (amendement du consensus n°2, point 2) : « OKE devient optionnel » est complété par « OKE sert
  d'environnement de dev du POC pendant la porte 1 » ; la nomenclature OKE du §8 s'applique au banc.

## Conséquences
- Tickets ajoutés : T-485 (protocole), T-486 (répétition MacBook), T-487 (réinitialisation d'OKE), T-488 (banc compté et
  décision de la porte 1). T-212 devient le bras K ; T-005 vise OKE ; T-361 et T-366 attendent la porte 1.
- La pile kube-ops d'OKE (Hindsight et `pg-shared` de drill, observabilité, cloudflared) est arrêtée pendant la fenêtre,
  après un inventaire en lecture seule. Son retrait est fait côté homelab-infra ou kube-ops, hors périmètre de ce dépôt.
- Un PASS de la porte 1 ne prouve ni l'amd64, ni le multi-cluster, ni les données réelles, ni le jour 2.

## Alternatives écartées
- **VM lab d'abord** (ADR-0020 actuel) : mesure la topologie avant la valeur ; 4 gestes MANDAT engagés à l'aveugle.
- **OKE sans répétition** : les graders se déboguent sur les runs comptés.
- **MacBook seul** : k3d ≠ OKE ; un Mac non permanent ne prouve pas l'observation asynchrone des agents cloud.
- **Garder la pile kube-ops sur OKE à côté du banc** : deux Argo, budget de 35 pods, mesures impures.

## Vérification
- Seuils du §2.4 présents dans `tests/bench-ab/` avant le premier run compté (horodatage du commit antérieur aux runs).
- Rapport daté `docs/research/POC-AB-RESULTS.md` : S1-S7 par bras, avec preuves ; décision de Paul consignée ici par
  amendement.
