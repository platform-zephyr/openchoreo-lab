# Apps kube-ops sur chart tiers : portage Helm GitOps (archetype E)

Date : 2026-11-17. Source : kube-ops `origin/main` @ ef50472 (lecture seule, aucun secret lu).
Seul dossier porte : `apps/hindsight/`. Les autres apps sont ecartees ci-dessous.

## Perimetre reel

Seules les apps dont le **deploiement repose sur un chart tiers** (`helmCharts` ou `source.chart`) entrent ici.
Les apps E de la carte (paperless, sure, immich, invoice-ninja, factory-platform, karakeep, gpt-researcher, fleet)
sont des manifests kube-ops, pas des charts tiers : hors parcours H. Charts d'infrastructure (argo-cd, cert-manager,
cnpg, kube-state-metrics, prometheus, etc.) : hors apps, plateforme.

## Verdicts

| App | Chart (source, version exacte) | Digest verifie | Verdict |
|---|---|---|---|
| hindsight | `oci://ghcr.io/vectorize-io/charts` hindsight 1.2.1 | tgz sha256 `967438cf...ecca` [C] ; OCI `4781a117...8258` [C] (helm pull, 2026-11-17) | **Porte** (`apps/hindsight/`), validate OK hors gate OKE ; bloquants ci-dessous |
| matrix | `oci://ghcr.io/element-hq/ess-helm` matrix-stack 26.10.2 | tgz `14d803c3...952` [C] ; OCI `3597302e...95ab` [C] | Ecarte : exposition publique 4 hotes (HTTPRoute hors chart, refusee en helm), 2 CNPG longhorn-fast, OIDC Authentik (MAS), kube-apiserver |
| librechat | `oci://ghcr.io/librechat-ai/librechat-chart` librechat 3.0.0 | tgz `0da311a5...36ff` [C] ; OCI `5d50ecaf...5775` [C] | Ecarte : OIDC Authentik (non admis OKE), MongoDB sous-chart longhorn-bulk |
| sparkyfitness | git `https://github.com/CodeWithCJ/SparkyFitness.git` tag v1.11.0, path helm/chart | [S] non telecharge | Ecarte : source git (schema exige oci/https et digest), OIDC Authentik, CNPG externe, egress FQDN Garmin |
| immich (redis) | sous-chart bitnami `redis` (repo https) | [S] | Ecarte : app manifests (StatefulSet, ML, CNPG, restic, 100 Gi bulk), chart Redis accessoire |
| lasuite/collabora | `collabora-online` (repo https, optional) | [S] | Ecarte : optional, hors carte d'apps |

## Hindsight : bloquants (validate OK, deploiement NON sur)

1. **Cluster** : `cluster: oke` refuse tant que le gate OKE n'est pas franchi (validate ECHEC volontaire). `--allow-oke` (diagnostic seulement) donne validate OK.
2. **Secret `postgres-password`** (exige par le chart, `existingSecret`) : appgen genere les cles ExternalSecret a partir de `secrets[].env`, qui doit respecter `^[A-Z][A-Z0-9_]*$`. Impossible de produire la cle `postgres-password`. Extension : `secrets[].secretKey` libre, ou ExternalSecret rendu avec cle brute.
3. **Base CNPG `hindsight-db`** (kube-ops : instance dediee, PG 17.7, 50 Gi oci-bv, sauvegarde WAL R2) : appgen ne rend que NetworkPolicy, quota, egress et ExternalSecret dans `resources/`. Il faut un `resources/` extensible (Cluster CNPG + ObjectStore) ; la NP `allow-dns-and-namespace` n'autorise que le meme namespace (`lab-hindsight-production`), ce qui est le bon perimetre.
4. **Sauvegarde** : `backup.class: none` (kube-ops : CNPG quotidienne vers R2). `irreplaceable` est refuse par la CI. Perte de sauvegarde tant qu'un mecanisme helm (E9) n'existe pas.
5. **Noms de cles Doppler** : le prefixe `HINDSIGHT_` est impose par la CI. kube-ops utilise `APP_HINDSIGHT_*` : creer de nouvelles cles (MANDAT, valeurs hors Git).
6. **Ecritures hors rootfs** (`readOnlyRootFilesystem: true`) : `/tmp` et `/home/hindsight/.cache` montes en emptyDir [S] : a prouver au runtime (uid 1000 du chart, image non inspectee au niveau config).
7. **Egress** : `api.minimax.io:443` seulement (CNP FQDN, Cilium requis). Le trafic vers `agentgateway` (homelab) n'est pas exprimable en helm (`egress app` refuse) : non utilise sur OKE (provider direct, D-2026-11-11-17).
8. **Image** : tag `1.2.1@sha256:662109ec...` (index multi-arch, `linux/arm64` present [C] `imagetools inspect`). Le chart construit `repository:tag` : valide par construction, [S] au runtime.
9. **Convention digest** : `digest` = sha256 du .tgz (CI « helm pull + sha256 »). Le digest OCI reste disponible ci-dessus. A confirmer avec la CI.

Autres ecarts: `profile: stateless` (le schema impose database ou storage pour `stateful`, interdits en helm). L'etat reel est dans la base externe.

## Extensions manquantes (pour le parcours helm)

- E-H1 `secrets[].secretKey` (cle libre) ou ExternalSecret brut dans `resources/`.
- E-H2 `resources/` : CNPG Cluster + ObjectStore + ScheduledBackup, ou reference a une base admise.
- E-H3 Sauvegarde en helm : `backup.mechanism` (cnpg/restic) rendu dans `resources/`.
- E-H4 Egress inter-namespace (agentgateway) en helm, ou interdiction explicite.
- E-H5 Exposition publique helm (HTTPRoute) pour les charts type matrix, librechat.
- E-H6 Pilotage OAuth/Authentik (E2) : non admis sur OKE ; bloque librechat et sparkyfitness.

## Points non verifies

- [S] Runtime : rendu Argo, PSA restricted, probes et ecritures (hindsight) : aucune preuve, rien n'est deploye.
- [S] Chart git sparkyfitness : pas de telechargement, version et chemin lus dans kube-ops uniquement.
- [S] Chemin exact de la base CNPG hors namespace : non teste.
