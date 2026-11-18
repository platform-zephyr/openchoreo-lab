# Verdicts A-F des apps de kube-ops (T-050)

Conclusion : sur 35 entrées, répartition **A 3, B 5, C 6, D 2, E 9, F 10**. Aucun verdict n'est prouvé au runtime : **RUNTIME = NOT_TESTED** pour toutes les lignes. Les verdicts reposent sur la lecture des sources (niveau STATIC), pas sur un rendu `kustomize build` ni `helm template` (NOT_TESTED : l'inventaire exhaustif du skill `migrate-to-openchoreo` §2 n'est pas fait) ; chaque verdict est donc provisoire.

Date : 2026-11-18. Référence : kube-ops `main` @ `ef50472bc427bbb5fb342cebf2f4db408157f5b3` (checkout local lu en lecture seule, même commit que [KUBE-OPS-APP-MAP.md](KUBE-OPS-APP-MAP.md)). Contrat : `docs/schema/app.schema.json`, `clusters/*/capabilities.yaml` de ce dépôt à la même date. Méthode : table de verdict du skill `migrate-to-openchoreo` §3 (premier signal rencontré). Aucun secret, aucun hôte interne : les noms de clés ne sont pas recopiés.

Légende des preuves : **STATIC-lu** = signal lu dans un manifeste de kube-ops (fiche de [KUBE-OPS-APP-MAP.md](KUBE-OPS-APP-MAP.md) §2 ou relecture de ce ticket, marquée « relu T-050 »). **NOT_TESTED** = signal supposé (la carte le marque `[S]`) ; le verdict est une hypothèse. Le manifeste présent n'est pas l'état déployé (CLAUDE.md de kube-ops).

## 1. Tableau app → archétype → manques

Les manques renvoient aux extensions E1 à E16 de la carte (§4.2) ; leur état dans le contrat est au §2.

| ID | App | Verdict | Preuve du verdict | Manques (contrat) | Port dans `apps/` |
|---|---|---|---|---|---|
| K01 | idp-e2e | A | STATIC-lu (relu T-050 : image à digest, port 80, 2 réplicas) ; sécurité NOT_TESTED | aucun | `apps/idp-e2e` existe |
| K02 | it-tools | A | STATIC-lu (relu T-050 : uid 1000, rootfs RO, drop ALL, port 80) | digest à épingler (tag seul) ; **perte** : KEDA `InterceptorRoute` + `ScaledObject` (mise à zéro) sans équivalent (E17 ci-dessous) | `apps/it-tools/NOTES.md` seul |
| K03 | searxng | A | STATIC-lu | digest à épingler ; ingress `fromEntities` (E4) | `apps/searxng` existe |
| K04 | mealie | C | STATIC-lu ; SQLite NOT_TESTED (aucune clé SQLite relue) | E2 (OIDC Authentik) ; probes (E10) | `apps/mealie` existe |
| K05 | vikunja | B | STATIC-lu | E1 (pg-shared), E2, E15 (hôtes) ; PVC + base | `apps/vikunja/NOTES.md` seul |
| K06 | ntfy | C | STATIC-lu | E14 (initContainer qui lance `ntfy serve` pour écrire `auth.db`) ; stratégie Recreate | `apps/ntfy` existe |
| K07 | paperless | E | STATIC-lu | E6 (Valkey), E7 (2 CronJobs restic), E9, E1 | aucun |
| K08 | sure | E | STATIC-lu | E6 (web + worker + Redis), E1, E2 | aucun |
| K09 | stirling-pdf | F | STATIC-lu (uid 0, CHOWN) | E12 `run-as-root` ou retrait des privilèges ; E14 | aucun |
| K10 | romm | B | STATIC-lu | E3 (FQDN), E8 (4 PVC dont 100 Gi hors schéma : `Gi` ≤ 4 chiffres OK, RWX non), E1, E2 | `apps/romm/NOTES.md` seul |
| K11 | bookorbit | B | STATIC-lu | E8 `rwx-shared` (refusé sur k3d et OKE), E1, E2 | `apps/bookorbit/NOTES.md` seul |
| K12 | polyfin | B | STATIC-lu ; capabilities NOT_TESTED | E3 (≥ 10 FQDN + CIDR LAN : E16 gated `privateEgressCIDRs`), E1, E2 | `apps/polyfin/NOTES.md` seul |
| K13 | aiostreams | C | STATIC-lu ; base SQLite NOT_TESTED (grep : aucune clé SQLite) | E3 (≥ 30 FQDN), E16 ; OIDC dormant | `apps/aiostreams` existe |
| K14 | immich | E | STATIC-lu | E6 (StatefulSet + ML + Redis), E7, E8, E9, E1 ; CNPG 17 avec extension vecteur NOT_TESTED | aucun |
| K15 | media-layout-job | D | STATIC-lu (Job, pas de HTTP) | hors produit : mute la bibliothèque média RW ; BLOCKED jusqu'à besoin réel | aucun |
| K16 | invoice-ninja | F | STATIC-lu (MySQL interne, base non PostgreSQL) | `database.engine` = postgres seulement ; E6, E7 | aucun |
| K17 | pinepods | F | STATIC-lu (uid 0, rootfs RW, caps) | E12, E13 | aucun |
| K18 | trilium | F | STATIC-lu (uid 0, escalation, init chown) | E12, E13, E14 | aucun |
| K19 | mqtt | D | STATIC-lu (relu T-050 : 1883 TCP, `TCPRoute`, StatefulSet, probes présentes) | E5 (port TCP), E4 ; BLOCKED G1 (hors HTTP) | aucun |
| K20 | hassio | F | STATIC-lu (hostNetwork, NET_ADMIN, PolicyException) | non éligible | aucun |
| K21 | open-connector | C | STATIC-lu (relu T-050 : uid 10001, rootfs RO, port 3000, PVC) | aucun | `apps/open-connector` existe |
| K22 | agentgateway | C | STATIC-lu (relu T-050 : uid 1000, drop ALL, port nommé `llm` 4000, PVC 1 Gi) | E3 (1 FQDN) ; fichier de config (ConfigMap) à porter | `apps/agentgateway/NOTES.md` seul |
| K23 | factory-platform | E | STATIC-lu | E6, E7 (2 CronJobs), E1 (2 bases), E3 | aucun |
| K24 | mastra-factory | B | STATIC-lu ; dépendance au sandbox NOT_TESTED | E3 + entité `kube-apiserver` (E4, non exprimée), E1, E2 | aucun |
| K25 | mastra-sandbox | F | STATIC-lu (gVisor, CRD, RBAC) | non éligible | aucun |
| K26 | matrix | E | chart NOT_TESTED (valeurs seules lues) ; 2 CNPG STATIC-lu | E1 ×2, E15, E4 | aucun |
| K27 | rustical-pilot | C | STATIC-lu (relu T-050 : base `optional/rustical`, uid 1000, rootfs RO, port 4000, Recreate) ; SQLite NOT_TESTED | E2 (OIDC en `.staged`) | `apps/rustical-pilot` existe |
| K28 | fleet | F | STATIC-lu (MySQL interne) | base non PostgreSQL | aucun |
| K29 | sparkyfitness | E | STATIC-lu (chart amont) ; rendu NOT_TESTED | CNPG R2 (E1, E9) ; FQDN multiples (E3) | aucun |
| K30 | librechat | E | STATIC-lu (chart `3.0.0`) ; rendu NOT_TESTED | E3, E16 ; route dormante | aucun |
| K31 | hindsight | E | STATIC-lu ; rendu NOT_TESTED | CNPG (E1, E9) ; deux déploiements (homelab et OKE) à confirmer ; `apps/_kube-ops-helm/hindsight` existe | brouillon Helm |
| K32 | gpt-researcher | F | STATIC-lu (`ws-rewriter` uid 0) | E12 ou retrait de l'init root ; multi-workload (E6) | aucun |
| K33 | karakeep | E | STATIC-lu ; Chrome NOT_TESTED | E6 (3 workloads), E13 (escalation à retirer) | aucun |
| K34 | opencode | F | STATIC-lu (uid 0, PolicyException) | non éligible | aucun |
| K35 | netbird-router (OKE) | F | STATIC-lu (NET_ADMIN, SYS_ADMIN, hostPath) | non éligible ; accès admin OKE | aucun |

Décompte : A 3 (K01, K02, K03) ; B 5 (K05, K10, K11, K12, K24) ; C 6 (K04, K06, K13, K21, K22, K27) ; D 2 (K15, K19) ; E 9 (K07, K08, K14, K23, K26, K29, K30, K31, K33) ; F 10 (K09, K16, K17, K18, K20, K25, K28, K32, K34, K35). Total 35.

Écarts avec la carte du 2026-11-17 (même commit kube-ops), dus à la table du skill (premier signal) : K16 invoice-ninja et K28 fleet passent de « E à compenser » à **F** (base non PostgreSQL) ; K32 gpt-researcher passe à **F** (uid 0) ; K19 mqtt reste **D** (BLOCKED G1) au lieu de « chart ». Ces trois changements sont des conséquences de la règle, pas de nouvelles preuves.

## 2. État des évolutions de contrat (E1 à E16) à la date du dépôt

Lu dans `docs/schema/app.schema.json` et `clusters/*/capabilities.yaml`. « Schéma » = le champ existe ; « Cluster » = admis par `capabilities`.

| E | Besoin | Schéma | Cluster (k3d / OKE) | Reste |
|---|---|---|---|---|
| E1 | pg-shared | oui (`database.instance`) | non / non | admettre `pg-shared` après restauration hors Oracle prouvée (D-2026-11-14-03) ; `engine` reste postgres seul |
| E2 | OIDC Authentik | oui (`provider`) | non / non | lister `authentik` dans `identityProviders` |
| E3 | egress déclaratif | oui (`fqdn`, `fqdnPattern`, `cidr`, `app`) | Cilium absent / gate OKE | gate Cilium ; `cidr` privé seulement si `privateEgressCIDRs` (vide) |
| E4 | ingress `fromEntities`, `fromApp` | non | n/a | à ajouter au schéma |
| E5 | ports multiples, TCP/UDP | non | n/a | à ajouter (bloque K19) |
| E6 | workloads annexes | oui (`workloads`, ≤ 4, 1 conteneur, pas de sidecar) | n/a | sidecar impossible (v1.3.3) |
| E7 | CronJobs | oui (`jobs`, ≤ 4) | n/a | — |
| E8 | multi-volumes | oui (`storage[]`) | `rwx-shared` refusé / aucun volume sur OKE | RWX et quota Block Volume |
| E9 | mécanisme de sauvegarde | oui (`mechanism`) | `none` seulement | admettre `cnpg`, `velero` ; restic absent |
| E10 | probes liveness/readiness | non (`healthPath` seul) | n/a | à ajouter |
| E11 | taille au-delà de `medium` | non | n/a | immich, romm, sure |
| E12 | exceptions de sécurité | oui (`securityExceptions`, règles `run-as-root`, `writable-rootfs`, 90 jours) | n/a | pas de règle pour hostNetwork, capabilities |
| E13 | rootfs, `fsGroup` | partiel (via E12) | n/a | `fsGroup` absent |
| E14 | initContainers | non | n/a | à ajouter (K06, K09, K17, K18) |
| E15 | hôtes multiples, visibilité | non (`host` unique) | n/a | à ajouter |
| E16 | egress LAN (CIDR privé) | oui mais gated | `privateEgressCIDRs` vide | décision plateforme |
| **E17** (nouveau) | scale-to-zero HTTP (KEDA) | non | non | relu T-050 : `it-tools` seul l'utilise ; à écarter ou à décider (perte acceptée à documenter) |

## 3. Conséquences

- **Migrable aujourd'hui sans extension** : K01, K02 (avec perte KEDA et digest), K03 (digest), K21, K22 (après E3 et Cilium), K27. Déjà présents dans `apps/` : idp-e2e, searxng, mealie, ntfy, aiostreams, rustical-pilot, open-connector. Leur déploiement runtime reste NOT_TESTED.
- **Bloqué par une décision plateforme, pas par du code** : E1, E2, E9 (`capabilities`), E3 (gate Cilium sur OKE), E8 RWX.
- **À ajouter au schéma** : E4, E5, E10, E11, E14, E15 (et E13 `fsGroup`).
- **Hors portage** : les 10 F et 2 D restent sur GitOps kube-ops, ou demandent une exception (E12) ou un retrait de privilèges préalable.

## 4. À prouver ensuite (NOT_TESTED)

1. `kustomize build --enable-helm` de chaque app A/B/C et inventaire exhaustif (skill §2) : aucun document n'a été rendu ici.
2. SQLite de K04, K13, K27 (aucune clé de base relue) ; Chrome de K33 ; chart de K26 ; CNPG d'immich.
3. Confirmer que K31 hindsight est un produit ou deux déploiements.
4. État déployé : `just inventory` côté kube-ops pour vérifier que chaque app est importée (relu T-050 : la racine `k8s/applications/kustomization.yaml` importe les 9 catégories ; `optional/` est importé app par app).
