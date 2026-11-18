---
owner: paul
updated: 2026-11-18
review_days: 30
---
# Mission — OpenChoreo Lab (IDP opérationnel sur OKE)

Objectif : un IDP OpenChoreo 1.3.3 réellement utilisable sur `oracle-a1` : Claude utilise le portail et les API pour déployer un service par PR GitOps, puis prouve qu'il fonctionne (preuves runtime). Le laboratoire reste jetable (`CLEANUP.md`), mais la plateforme doit être exploitable. Détail de l'état : `STATE.md`.

Services : whoami d'abord (cycle complet : intention → contrat → PR → CI → merge → Argo CD → OpenChoreo → Ready → test HTTP → preuve → rollback) ; puis Miniflux (PostgreSQL) et AIOStreams ; pas d'Immich/Polyfin.
Identité : Authentik externe, unique issuer OIDC. Clients distincts (portail, service backend, agent-reader, agent-operator, CLI). Pas de ThunderID.

Primitives à prouver en runtime : default-deny réseau (ingress+egress), PSA restricted, rien de cluster-scoped créable par une app, secrets sans token admin partagé, isolation SQL, refus d'admission, IMDS bloqué, authz MCP (lecteur ne peut pas écrire), Git = source de vérité (PR + CI), moindre privilège du cluster-agent.
Budget : OpenChoreo ≤ 1,5 GiB et ≤ 0,3 vCPU au repos = OBJECTIF d'optimisation. Seuil dur : requests ≤ 70 % de l'allocatable réel (1830m / 8,4 GiB). On ne dégrade jamais les requests pour masquer la consommation ; si le portail ne tient pas, mesurer et proposer une cible réaliste.

## Autorisations explicites de Paul (mandat du 2026-11-17) — elles PRIMENT sur les anciennes interdictions, sans devenir un droit général
- Préparer et intégrer toutes les PR nécessaires dans `openchoreo-lab` (après CI, revue, tests, protections GitHub).
- Préparer des PR ciblées dans `kube-ops` : correctif C1 (kube-ops #1629) et blueprints Authentik. L'APPLICATION sur des ressources de production n'a lieu qu'après vérification du périmètre, de l'impact et d'un rollback éprouvé.
- Accès OKE par session bastion (ouverte avec l'accord de Paul) : un seul exécutant, le coordinateur.
- Namespaces `dp-*` générés par OpenChoreo (avec labels de propriété, quotas, admission, nettoyage) ; label `openchoreo.dev/control-plane=true` sur `default` UNIQUEMENT si OpenChoreo 1.3.3 l'exige, sans élargir les permissions sur les autres ressources de `default`.
## Décisions de Paul du 2026-11-18 (agents cloud, `docs/CLOUD-AGENTS.md`)
- Backlog du labo : `backlog/` dans ce dépôt (ADR-0012), une issue GitHub seulement pour lancer un agent. Pas Linear tant que l'adoption d'OpenChoreo n'est pas tranchée.
- Dev et prod sur le **même** OKE (un nœud, pas de HA) : Environments OpenChoreo `development` et `production`. Le dev doit rester frugal (`docs/CLOUD-AGENTS.md` §2).
- **Exception d'exposition** : le MCP OpenChoreo, et lui seul, peut être publié par Cloudflare Tunnel **derrière Cloudflare Access** (service token dédié, aucun accès anonyme, aucun bypass), en plus de l'authz OpenChoreo. La configuration Cloudflare et Authentik reste un geste de Paul (MANDAT) ; l'agent prépare la PR `platform/` (NetworkPolicy) et la documentation.

## Décisions de Paul du 2026-11-18 (suite)
- Placement : homelab par défaut ; OKE seulement sur demande explicite de Paul (ADR-0003).
- IdP : Authentik en GitOps ; arrivée et départ d'un utilisateur = golden paths (ADR-0007).
- Secrets : OpenBao pour tout secret interne (clés d'API LLM comprises), Doppler pour les primitives externes ; tâche d'init depuis Doppler puis nettoyage et réduction des ~50 jetons Doppler (ADR-0014).
- Atlas est le point d'arrivée ; les agents cloud ont accès aux dépôts (ADR-0012).
- Chantiers ajoutés : observabilité (Grafana Cloud) et alerting, exploitation, montées de version automatisées, agent de remédiation déclenché sur échec avec escalade ntfy, coût dans le free tier, services IA en sandbox derrière un gateway (agentgateway), data platform légère sur le homelab pour mesurer la plateforme (DORA, maturité sécurité et cloud native). Vitesse maximale : un maximum d'agents en parallèle, les tickets qui accélèrent les suivants d'abord.

## Faits et décisions de Paul du 2026-11-18 (fin de journée)
- Le dépôt **reste public** : aucune donnée sensible (secret, identifiant de compte, IP, hôte interne, donnée personnelle, détail de faille) n'y entre ; audit et garde CI à mettre en place.
- Homelab : mini-PC AMD Ryzen 7 PRO 8845HS, 64 Go de RAM, 1 To SSD, 14 To HDD ; Proxmox + VM Talos ; kube-ops y est entièrement déployé avec Argo CD.
- Oracle : compte **PAYG**. Paul indiquait 4 OCPU / 24 Go gratuits ; la doc Oracle lue le 2026-11-18 donne **1 500 OCPU-h + 9 000 Go-h/mois = 2 OCPU / 12 Go gratuits pour tous les tenancies**, 4/24 étant un plafond de service facturé au-delà (`docs/research/VERIFICATION-2026-11-18.md`). On retient **2/12** tant que la facturation de Paul ne prouve pas le contraire ; toute dépense reste un MANDAT.
- LLM : agents externes = mélange Claude Code (plan Max, ajustable au besoin réel) et DeepSeek ; services IA internes = DeepSeek (via le gateway). Choisir pour chaque tâche le modèle le moins cher qui suffit.
- Vitesse : Claude doit pouvoir travailler **24 h/24**, avec le minimum d'interventions de Paul et autant d'agents en parallèle que le plan le permet.
- Accès réseau complet donné aux sessions.

## Mode développement (arbitrage de Paul, 2026-11-18)
Sécurité allégée acceptée pendant le développement (droits étendus, accès admin, revue des code owners désactivée, Doppler élargi) ; seule compte la sécurité FINALE, vérifiée à l'étape FINAL du backlog. Les interdits ci-dessous qui ne concernent que le processus de revue sont suspendus pendant le dev ; ceux qui protègent les données, les secrets et les coûts restent en vigueur.

## Toujours INTERDIT (sans nouvelle autorisation écrite de Paul)
Création du volume PostgreSQL OCI de 50 Go (`--confirm-storage`) ; toute exposition publique (Tunnel, Ingress, LoadBalancer) hors l'exception MCP ci-dessus ; LoadBalancer OCI facturable ; migration Talos ; modification de `kube-system`, de ressources de production ou de politiques cluster-wide non vérifiées ; `tofu apply`, Doppler, Cloudflare ; migration Authentik ; création par un agent d'une identité/clé/token d'accès ; secret affiché ou committé ; TLS désactivé ; contournement d'admission ; suppression de ressources hors du labo ; nouvelle étude comparative.
Périmètre cluster : écriture dans `openchoreo-*`, `lab-*` (+ les namespaces de prérequis que l'installation crée et marque `part-of=openchoreo-lab`) et `dp-*` ; lecture seule ailleurs. Les noms imposés par OpenChoreo (`dp-*`, label sur `default`) sont des exceptions acquittées ci-dessus.

### Exceptions IMPOSÉES par OpenChoreo 1.3.3 : détail technique À ACQUITTER PAR PAUL (revue B3, 2026-11-17)
Le principe est acquitté ci-dessus ; ce qui suit est ce que le pack `tools/oke/` fait réellement, à confirmer ligne à ligne :
- `dp-*` : créés et écrits par le contrôleur OpenChoreo via le CPT `cell-restricted` (préfixe codé dans le contrôleur), jamais par les scripts. VAP-1 n'autorise le cluster-agent qu'à des `Namespace dp-*` en PSA `restricted` (ou `baseline` par cellule), `enforce-version: latest`, label `platform.smadja.dev/cell=restricted`. Au nettoyage, `uninstall.sh` supprime les `dp-*` portant ce label (et eux seuls). — **à acquitter par Paul**
- `default` : `install.sh --step 9` pose le label `openchoreo.dev/control-plane=true` (exigé par OpenChoreo 1.3.3 : `tools/appgen` génère les objets dans `default`) et y écrit des objets `openchoreo.dev` seulement (Environment, DeploymentPipeline, puis les apps par Argo), aucun pod ; label retiré par `uninstall.sh --step 9`. — **à acquitter par Paul**
- Plus aucune autre exception : l'opérateur CNPG passe de `cnpg-system` à `lab-cnpg`. Le namespace `cnpg-system` créé vide par l'étape 1 du 2026-11-17 se supprime par `tools/oke/uninstall.sh --migrate-cnpg-system --apply` (refus s'il n'est pas vide ou ne porte pas `part-of=openchoreo-lab`).

## Coordination
- Charts OpenChoreo : installation uniquement avec le security bundle privé et temporaire (`docs/SECURITY-BUNDLE.md`) ; jamais de `helm upgrade`/`helm rollback` direct sur ces releases.
- Un SEUL exécutant sur OKE (le coordinateur). Les agents parallèles travaillent sur des périmètres de fichiers distincts, sans accès OKE, et produisent du code, des tests et des PR intégrables.
- Le coordinateur intègre, résout les conflits, fait passer la CI, vérifie les résultats runtime. `STATE.md` est mis à jour à chaque jalon.
- BLOCKED sur un contrôle de sécurité = jalon non validable. MEASUREMENT_UNAVAILABLE = jamais PASS.

## Reprise par une nouvelle session
1. Lire `STATE.md` (état réel, accès, étapes, flux, bloquants, prochaines actions) puis ce fichier.
2. `git log`, `gh pr list`, état CI ; relire l'état du cluster en lecture seule avec `tools/oke/preflight.sh` (kubeconfig `~/.cache/oke-access/kubeconfig`, session bastion éventuellement expirée : rouvrir avec `open-oke-access.sh open 10800`).
3. Vérifier la liste des agents encore actifs avant de relancer un flux (éviter les doublons).
4. Reprendre la première « prochaine action exacte » ; tout PASS référence un fichier de preuve daté.
