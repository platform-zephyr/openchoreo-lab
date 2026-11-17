# STATE — OpenChoreo Lab (reprise après interruption)

Dernière mise à jour : 2026-11-17 (Phase A en cours)
Mission : essai OpenChoreo 1.3.3 sur OKE, jetable. Voir `missions/MISSION.md` pour l'objectif et les règles.

## Où on en est
| Phase | Statut | Preuve |
|---|---|---|
| A0 Conception (base, contrat) | FAIT | `docs/BASE-CHOICE.md`, `docs/APP-CONTRACT.md`, `docs/schema/app.schema.json` |
| A1 Objets plateforme durcis + tests de refus sur **k3d** | EN COURS | `platform/`, `tests/k3d/RESULTS.md` (à venir) |
| A2 Générateur d'apps + CI | EN COURS | `tools/`, `apps/`, `.github/`, `tests/appgen/RESULTS.md` (à venir) |
| A3 Argo CD synchronisant les CRD sur **k3d** | À FAIRE | — |
| B Installation minimale sur OKE | BLOQUÉ (gate) | voir « Gate OKE » |
| C whoami / Miniflux / AIOStreams sur OKE | À FAIRE | — |
| D RAPPORT.md, CLEANUP.md testé, verdict | À FAIRE | — |

## Gate OKE (à re-vérifier avant toute action sur OKE)
Source : `…/side-session-notes/local_35b37a0a-…/idp/agents/OKE-EXEC.md` (écrit par l'agent OKE).
Requis : Cilium (chaining) + baseline kube-ops #1620 en place, refus IMDS prouvé depuis un pod non privilégié, accès opérateur ouvert, `prevent_destroy` rétabli (#611).
Constat 2026-11-17 17:35Z : cluster oracle-a1 `ACTIVE` (OCI VCN-native, API privée 10.0.2.65:6443) mais **nu** ; aucun accès API (bastion OCI + kubeconfig de Paul requis). **Gate non atteint.**

## Règle d'étiquetage des preuves
Tout résultat obtenu sur le cluster k3d local est étiqueté `k3d`. Rien n'est une preuve OKE tant qu'il n'a pas été rejoué sur OKE.

## Environnement local de test
- VM colima `openchoreo` (`colima start -p openchoreo`), `DOCKER_CONTEXT=colima-openchoreo`.
- Cluster k3d `openchoreo` (OpenChoreo v1.3.3, ThunderID, ESO, cert-manager). KUBECONFIG dédié, jamais celui de Paul.

## Prochaines actions exactes
1. Intégrer les résultats des agents A1 et A2, corriger la conception sur preuve, committer.
2. Protection de branche (script `tools/apply-branch-protection.sh`, à exécuter après la CI verte).
3. A3 : Argo CD sur k3d, parcours PR → merge → réconciliation, `autoDeploy=false`.
4. Demande groupée d'accès OKE à Paul quand A est terminé.

## Décisions ouvertes
- DECISION.md (maturity-mandate) §4 écartait OpenChoreo d'OKE ; cet essai est un pilote borné décidé par Paul le 17/11 : à réconcilier dans le rapport final.
- Budget : OpenChoreo ≤ 1,5 GiB RAM et ≤ 0,3 vCPU au repos sur OKE (dépassement ⇒ arrêt et rapport).

## Journal
- 2026-11-17 : dépôt vide cloné ; conception livrée ; k3d démarré ; agents A1/A2 lancés.
