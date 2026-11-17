# STATE — OpenChoreo Lab (reprise après interruption)

Dernière mise à jour : 2026-11-17 (Phase A mergée ; pack d'installation OKE prêt, accès à obtenir)
Mission : essai OpenChoreo 1.3.3 sur OKE, jetable. Voir `missions/MISSION.md` pour l'objectif et les règles.

## Où on en est
| Phase | Statut | Preuve |
|---|---|---|
| A0 Conception (base, contrat) | FAIT | `docs/BASE-CHOICE.md`, `docs/APP-CONTRACT.md`, `docs/schema/app.schema.json` |
| A1 Objets plateforme durcis + tests de refus sur **k3d** | FAIT (k3d) : 51 PASS, 1 NOT_TESTED (IMDS) | `platform/`, `tests/k3d/RESULTS.md` |
| A2 Générateur d'apps + CI + extensions de schéma | FAIT (statique) : 102 tests OK, 0 dérive, gitleaks propre ; CI GitHub non encore exécutée | `tools/`, `apps/`, `generated/`, `.github/`, `tests/appgen/RESULTS.md` |
| A2b Golden paths + skills agents + cartographie kube-ops | FAIT (statique) | `golden-paths/`, `.agents/`, `docs/KUBE-OPS-APP-MAP.md` |
| A3 Argo CD synchronisant les CRD sur **k3d** | À FAIRE | — |
| B Installation minimale sur OKE | BLOQUÉ (gate) | voir « Gate OKE » |
| C whoami / Miniflux / AIOStreams sur OKE | À FAIRE | — |
| D RAPPORT.md, CLEANUP.md testé, verdict | À FAIRE | — |

## Couverture des apps kube-ops (statique, aucun runtime)
10 descripteurs valides : whoami, miniflux, aiostreams (pilote) + idp-e2e, searxng, open-connector, mealie, rustical-pilot, ntfy.
Sans descripteur (cause dans `apps/<nom>/NOTES.md`) : it-tools (port 80 < 1024, scratch nginx), vikunja (mapping de secrets, backup cnpg non admis), agentgateway, romm, bookorbit, polyfin (extensions E4 ingress, FQDN, Authentik, RWX, capabilities). Hindsight rangé dans `apps/_kube-ops-helm/` (reste au homelab). Détail : `docs/KUBE-OPS-APP-MAP.md`.
Extensions de schéma encore manquantes : `network.ingress` (E4), fichiers/ConfigMap montés, sondes (E10), tailles > medium, add-capabilities, hostAliases/CIDR privés, extensions PostgreSQL, backup cnpg et IdP authentik admis par cluster.

## Gate OKE (à re-vérifier avant toute action sur OKE)
Source : `…/side-session-notes/local_35b37a0a-…/idp/agents/OKE-EXEC.md`.
**Atteint le 2026-11-17 (Jalon 4)** : cluster nu qualifié (Cilium 1.20.4 chaining, VAP baseline x3, CCNP `allow-egress-unisolated` + `deny-imds`, refus IMDS prouvé, acceptance.sh PASS, prevent_destroy rétabli via homelab-infra #616). Pas d'Argo/ESO/cert-manager sur le cluster. kube-ops #1620 non mergée : ne pas appliquer son bootstrap.
**Accès opérateur : FERMÉ.** Ouverture = `bash …/idp/agents/open-oke-access.sh open 10800` (session bastion 3 h, identité OCI de Paul) ; fermeture = `… close`. Accord de Paul requis avant exécution (demandé le 2026-11-17, en attente).
Conflit connu C1 : la CCNP allow-all de #1620 neutralise le default-deny egress de nos namespaces ; correctif côté kube-ops (hors périmètre, accord de Paul) : exclure les namespaces `platform.smadja.dev/egress-isolated`.

## Règle d'étiquetage des preuves
Tout résultat obtenu sur le cluster k3d local est étiqueté `k3d`. Rien n'est une preuve OKE tant qu'il n'a pas été rejoué sur OKE.

## Environnement local de test
- VM colima `openchoreo` (`colima start -p openchoreo`), `DOCKER_CONTEXT=colima-openchoreo`.
- Cluster k3d `openchoreo` (OpenChoreo v1.3.3, ThunderID, ESO, cert-manager). KUBECONFIG dédié, jamais celui de Paul.

## Prochaines actions exactes
0. Phase B : obtenir l'accord de Paul pour `open-oke-access.sh`, puis `docs/PHASE-B.md` (`tools/oke/preflight.sh`, puis `install.sh --step N` ; dry-run par défaut, `--apply` explicite, arrêt si > 1,5 GiB ou 300m). ThunderID non installé (3 PVC ~150 Go) : à trancher en Phase C.
1. Merger la PR socle une fois la CI verte ; appliquer la protection de branche (`tools/apply-branch-protection.sh`).
1b. Corriger `docs/APP-CONTRACT.md` avec les 7 écarts de tests/k3d/RESULTS.md ; réduire les requests d'OpenChoreo (850m mesurés vs 250m visés).
1c. Lots d'`apps/<nom>/app.yaml` pour les apps kube-ops éligibles (ordre dans docs/KUBE-OPS-APP-MAP.md) ; livrer les types `worker`/`cronjob`/`statefulset` et le CPT étendu (tests/appgen/fixtures/platform-ext/).
2. Protection de branche (script `tools/apply-branch-protection.sh`, à exécuter après la CI verte).
3. A3 : Argo CD sur k3d, parcours PR → merge → réconciliation, `autoDeploy=false`.
4. Demande groupée d'accès OKE à Paul quand A est terminé.

## Décisions ouvertes
- DECISION.md (maturity-mandate) §4 écartait OpenChoreo d'OKE ; cet essai est un pilote borné décidé par Paul le 17/11 : à réconcilier dans le rapport final.
- Budget : OpenChoreo ≤ 1,5 GiB RAM et ≤ 0,3 vCPU au repos sur OKE (dépassement ⇒ arrêt et rapport).

## Journal
- 2026-11-17 18:40 : pack d'installation OKE livré (docs/PHASE-B.md, platform/install/, tools/oke/) : statique, jamais exécuté. Requests visées 55m/304Mi pour OpenChoreo (850m/1088Mi mesurés sur k3d).
- 2026-11-17 18:13 : PR #1 mergée (CI 7/7, ruleset main-protection actif : PR + ci-ok). CI : binaires arm64 et noms de schémas en minuscules corrigés (bug révélé par le FS sensible à la casse de Linux).
- 2026-11-17 : dépôt vide cloné ; conception livrée ; k3d démarré ; agents A1/A2 lancés.
- 2026-11-17 18:08 : socle statique intégré (platform/ testé k3d, appgen+extensions, golden paths, skills, 3 apps pilotes + 3 apps kube-ops) ; PR ouverte.
