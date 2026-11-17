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
## Toujours INTERDIT (sans nouvelle autorisation écrite de Paul)
Création du volume PostgreSQL OCI de 50 Go (`--confirm-storage`) ; toute exposition publique (Tunnel, Ingress, LoadBalancer) ; LoadBalancer OCI facturable ; migration Talos ; modification de `kube-system`, de ressources de production ou de politiques cluster-wide non vérifiées ; `tofu apply`, Doppler, Cloudflare ; migration Authentik ; création par un agent d'une identité/clé/token d'accès ; secret affiché ou committé ; TLS désactivé ; contournement d'admission ; suppression de ressources hors du labo ; nouvelle étude comparative.
Périmètre cluster : écriture dans `openchoreo-*`, `lab-*` (+ les namespaces de prérequis que l'installation crée et marque `part-of=openchoreo-lab`) et `dp-*` ; lecture seule ailleurs. Les noms imposés par OpenChoreo (`dp-*`, label sur `default`) sont des exceptions acquittées ci-dessus.

## Coordination
- Un SEUL exécutant sur OKE (le coordinateur). Les agents parallèles travaillent sur des périmètres de fichiers distincts, sans accès OKE, et produisent du code, des tests et des PR intégrables.
- Le coordinateur intègre, résout les conflits, fait passer la CI, vérifie les résultats runtime. `STATE.md` est mis à jour à chaque jalon.
- BLOCKED sur un contrôle de sécurité = jalon non validable. MEASUREMENT_UNAVAILABLE = jamais PASS.

## Reprise par une nouvelle session
1. Lire `STATE.md` (état réel, accès, étapes, flux, bloquants, prochaines actions) puis ce fichier.
2. `git log`, `gh pr list`, état CI ; relire l'état du cluster en lecture seule avec `tools/oke/preflight.sh` (kubeconfig `~/.cache/oke-access/kubeconfig`, session bastion éventuellement expirée : rouvrir avec `open-oke-access.sh open 10800`).
3. Vérifier la liste des agents encore actifs avant de relancer un flux (éviter les doublons).
4. Reprendre la première « prochaine action exacte » ; tout PASS référence un fichier de preuve daté.
