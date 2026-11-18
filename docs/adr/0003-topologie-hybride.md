# ADR-0003 — Topologie hybride : un control plane, deux data planes
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : D-2026-11-11-17 (hybride homelab + OKE), D-2026-11-15-01 (deux Argo), D-2026-11-15-05 (70 %),
ADR-0004, ADR-0008 ; `docs/architecture/MULTI-DATAPLANE.md`

## Contexte
- Deux clusters : homelab (Talos sur Proxmox, nœud unique, Cilium, Longhorn, Kyverno) et OKE `oracle-a1` (A1 Always
  Free, 1 nœud arm64, 1830m / 8,4 GiB, 31 IP de pods, CNI OCI VCN-native + **Cilium 1.20.4 en chaining**, PSA + VAP,
  pas de Kyverno, pas de LB, pas de Workload Identity) (HOMELAB-INFRA-REQUIREMENTS §1).
- Réseau standardisé : mêmes CRD Cilium des deux côtés, donc mêmes NetworkPolicy rendues par la plateforme.
- Flux réseau **homelab → OKE uniquement** ; OKE n'a aucune route vers le LAN.
- OpenChoreo : un agent par data plane ouvre une connexion **sortante** mTLS vers le control plane ; le control plane
  n'a aucun kubeconfig des data planes. Ce modèle colle exactement au sens du flux réseau.

## Décision
1. **Un seul control plane OpenChoreo, sur OKE** (toujours allumé, joignable depuis les deux sites).
2. **Deux `ClusterDataPlane`** : `oke` et `homelab`, chacun avec son agent sortant, son `planeID`, sa CA. Le homelab
   joint OKE par un chemin L4 sans terminaison TLS (NetBird recommandé ; Cloudflare Tunnel HTTP exclu).
3. **Une app choisit sa cible** par `spec.cluster: oke | homelab` ; `appgen` refuse ce que
   `clusters/<cluster>/capabilities.yaml` ne déclare pas (stockage, Kyverno, exposition…).
4. **Placement (décision de Paul, 2026-11-18)** :
   - **par défaut, une app va sur `homelab`** (cluster local), sans question ;
   - **`oke` seulement sur demande explicite de Paul**, pour un service peu gourmand en trafic et en compute qu'il veut
     plus disponible (ex. stack de streaming média). Un autre demandeur ne peut pas choisir `oke` ;
   - la plateforme elle-même (control plane, identité, OpenBao) → `oke`.
5. **Mêmes Environments** (`development`, `production`) sur chaque data plane ; un DeploymentPipeline par chemin.
6. **GitOps** : Argo CD sur OKE applique les objets OpenChoreo (control plane) ; l'agent OpenChoreo pousse aux data
   planes. L'Argo du homelab reste pour son socle (stockage, Cilium, opérateurs) et, dans un projet borné, pour les CR de
   ressources externes générées par `appgen` (Crossplane, ADR-0009) ; jamais pour les apps du golden path.
7. **Interface standard** : ce qui diffère entre clusters (stockage, admission, edge) est caché par les capacités et
   les types de la plateforme ; l'app ne connaît que `cluster`.

8. **Nomenclature OKE figée** (consensus du 2026-11-18) : ≤ 33 pods et requests ≤ 70 % ; liste fermée : control plane
   OpenChoreo (si adopté), **un seul Argo CD** (T-213), cloudflared, chemin NetBird, OpenBao, Alloy, et les rares apps
   demandées par Paul. **Backstage hors OKE.** L'emplacement d'Authentik est tranché par T-213. Aucun service IA sur OKE.

## Conséquences
- Chantiers : enregistrement du data plane homelab, chemin NetBird + SAN du cluster-gateway, capacités homelab, preuve
  du comportement quand le homelab est coupé (les workloads tournent, les changements attendent).
- Budget OKE serré (~260m de marge avant 70 %, OpenChoreo non compté) : tout composant lourd (Kyverno, opérateurs de
  sauvegarde, Crossplane, observabilité) va de préférence sur le homelab.
- Exception assumée : OpenBao tourne sur OKE malgré son poids, car les nouveaux déploiements des deux clusters en
  dépendent et OKE est toujours allumé (ADR-0014).
- Une app ne peut pas dépendre d'une app de l'autre cluster par le réseau interne sans route explicite.

## Alternatives écartées
- **Un OpenChoreo complet par cluster** : deux plateformes à opérer, deux catalogues.
- **Control plane sur le homelab** : OKE devrait joindre le LAN (contraire au sens du flux) et le CP disparaîtrait
  quand le homelab est coupé.

## Vérification
- CI : `cluster: oke` refusé si la PR ne porte pas la mention de la demande de Paul (champ `placement.requestedBy`).
- Preuve datée : la même app (A) déployée sur `oke` puis sur `homelab` par simple changement de `cluster`, mêmes
  NetworkPolicy rendues, même statut `app-status.v1`.
- Test de coupure : homelab isolé 10 min → apps homelab Ready, CP Ready, reprise sans action.

## Références
`docs/research/HOMELAB-INFRA-REQUIREMENTS.md` §1, `docs/architecture/MULTI-DATAPLANE.md`, `docs/reference/openchoreo/dataplanes-multicluster.md`.
