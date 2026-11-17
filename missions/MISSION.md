# Mission — OpenChoreo Lab

Objectif : mesurer, sur le cluster OKE oracle-a1, ce qu'OpenChoreo 1.3.3 apporte en simplicité et en autonomie agentique, avec les mêmes primitives de sécurité que la plateforme maison. Essai jetable : si le résultat ne convient pas, on supprime ce dépôt et les namespaces d'essai (`CLEANUP.md`).

Services de test : whoami, Miniflux 2.3.x (CNPG éphémère `lab-pg` + OIDC ThunderID), AIOStreams (SQLite sur PVC, egress contrôlé). Pas d'Immich, pas de Polyfin.

Primitives à conserver (preuve runtime obligatoire, jamais « CI verte » seule) : default-deny réseau ingress+egress, PSA restricted, rien de cluster-scoped créable par une app, secrets générés sans token admin partagé, isolation SQL base/rôle avec refus inter-apps, refus d'admission (privilégié, hostPath, image non épinglée), blocage IMDS, authz MCP, audit, Git = source de vérité (PR + CI).

Budget OKE : OpenChoreo ≤ 1,5 GiB RAM et ≤ 0,3 vCPU au repos. Dépassement ⇒ arrêt et rapport.

## Interdits
Toucher kube-ops, homelab-infra, le homelab, Doppler, Cloudflare, Authentik, un namespace d'OKE autre que `openchoreo-*` / `lab-*` ; OpenTofu apply ; secret affiché ou committé ; TLS désactivé ; contournement d'admission ; exposition publique sans accord de Paul ; création d'accès (bastion, token, clé NetBird) par un agent.

## Reprise par une nouvelle session
1. Lire `STATE.md` (statut, gate, prochaines actions).
2. Relire l'état du gate dans OKE-EXEC.md (chemin dans STATE.md) avant toute action sur OKE.
3. Vérifier `git status`, les PR ouvertes (`gh pr list`) et la CI.
4. Reprendre la première « prochaine action exacte » ; mettre à jour `STATE.md` à chaque jalon.
5. Tout résultat k3d est étiqueté `k3d`.
