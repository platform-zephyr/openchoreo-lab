# polyfin : notes de portage (pas de descripteur)

Statut : **aucun `app.yaml`**. Exclu du pilote OKE. `cluster` du schéma n'admet que `k3d` et `oke` : une capabilities homelab n'existe pas, donc aucun descripteur ne peut être valide au schéma. Conformément à la mission, `NOTES.md` seul.

## Source
- kube-ops `origin/main` @ef50472 : `k8s/applications/media/polyfin/` (Deployment 65532, PVC `polyfin-data` 20 Gi longhorn-fast, CNPG `polyfin-db` avec WAL R2, CNP `polyfin-pilot`, ConfigMap `polyfin-free-radios` monté sur `/iptv`, ExternalSecret `polyfin-bootstrap`). Route `polyfin-media-route.yaml`.
- Overlay OKE existant : `k8s/clusters/oracle-a1/media/polyfin-db-external-secret.yaml` pointe vers `pg-shared-rw` (**non admis sur OKE**, D-2026-11-14-03). À ne pas reprendre.

## Image : signal à traiter
- kube-ops épingle `ghcr.io/moodiness/polyfin:0.61.1@sha256:1e55720e…`. Ce digest est un **manifest linux/amd64 seul**, pas un index. Il ne tournera pas sur arm64.
- Index multi-arch vérifié **[C]** : `fdeb10f8…` (linux/amd64 `1e55720e…`, linux/arm64 `84e99be7…`). Digest à épingler si un descripteur est écrit.
- Config de l'image : `User 65532:65532` **[C]**. Variables `NVIDIA_*` et `POLYFIN_TESSERACT`. Aucun GPU demandé en kube-ops : sans effet sans runtime NVIDIA.

## Écart avec la mission
La mission dit que Polyfin dépend du media-share 2 Ti. **kube-ops ne le monte pas** : la fiche K12 et le Deployment (volumes `data`, `tmp`, `radio-playlist`) n'utilisent que `polyfin-data` 20 Gi. La dépendance à confirmer avec Paul.

## Causes de non-portage (si descripteur plus tard)
1. Pas de cluster homelab dans le schéma (`cluster: k3d|oke`).
2. **Base** : `polyfin-db` CNPG avec WAL R2. `lab-pg` sans sauvegarde, `cnpg` non admis.
3. **OIDC Authentik** (`auth.smadja.dev`, issuer natif) : non admis.
4. **Egress FQDN** ≥ 10 hôtes (addons Eclipse, TorBox, Tidal, GitHub raw, Authentik) : refus k3d, gate Cilium sur OKE. Pas de wildcard. `public-internet` interdit.
5. **IP privée** `192.0.2.192/32` (AIOStreams via gateway, `hostAliases`) : `privateEgressCIDRs` vide, E16 absent.
6. **ConfigMap monté** (liste de radios, `/iptv` en lecture seule) : pas de fichier monté dans le schéma.
7. **Sondes** `/healthz` et `/readyz` : E10 absent.
8. Le contrôle AIOStreams (`egress app: aiostreams`) est plausible via E3, mais AIOStreams lui-même n'est pas encore un descripteur validé.

Sécurité kube-ops : uid 65532, rootfs RO, drop ALL, `automountServiceAccountToken: false`. Équivalent ou plus strict que le profil restricted.

## Ce qu'il faut pour un descripteur homelab
Une capabilities homelab (PR plateforme), CNPG admis avec sauvegarde, Authentik admis, FQDN et CIDR privés admis, ConfigMap monté, sondes (E10), et confirmation du media-share.
