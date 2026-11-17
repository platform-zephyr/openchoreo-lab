# agentgateway : notes de portage (pas de descripteur)

Statut : **aucun `app.yaml`**. Le service ne tient pas dans le schéma v2alpha1 (cause ci-dessous). Ne pas forcer. Aucun manifest rendu.

## Source
- kube-ops `origin/main` @ef50472 : `k8s/applications/platform/agentgateway/{resources.yaml,secrets.yaml,kustomization.yaml}`.
- Digest kube-ops `cr.agentgateway.dev/agentgateway@sha256:60216aaf…` : **index** contenant linux/arm64 (`4562330c…`) et linux/amd64. Candidat d'épinglage valide.
- Attention : le tag `v1.6.0` pointe aujourd'hui vers un autre index (`9d3e6044…`, arm64 présent). Choisir le digest à épingler est une décision de Paul (continuité avec kube-ops ou tag courant).

## Causes de non-portage (ordre de blocage)

1. **Configuration par fichier** : `/config/config.yaml` (ConfigMap) porte gateways, `llm`, modèles, budgets par consommateur, politique `apiKey`, tracing. Le schéma n'a ni fichier monté, ni ConfigMap (seulement `runtime.env` scalaire). Extension requise : `runtime.files[]` (chemin, contenu non secret, lecture seule) ou un champ `configFiles`.
2. **Ingress depuis 5 consommateurs** sur le port 4000 : `mastra-factory`, `factory-platform`, `gpt-researcher`, `hindsight-personal`, `librechat`. Le schéma ne sait que `network.egress` (sortant). Extension requise : E4 `network.ingress[]` avec `fromApp`/`fromNamespace`.
3. **Egress `api.minimax.io:443`** : règle FQDN, refusée sur k3d (pas de Cilium). Acceptable seulement après le gate OKE, ou avec `--allow-unenforced-fqdn` (labo, flux bloqués). Interdit : remplacer par `public-internet`.
4. **Tracing** vers `alloy.monitoring:4318` : pas d'egress vers un service in-cluster sans CIDR privé. `capabilities.privateEgressCIDRs` est vide sur k3d et OKE.
5. **Noms de secrets** : `MINIMAX_API_KEY`, `GPT_RESEARCHER_API_KEY`, `HINDSIGHT_AGENTGATEWAY_KEY`, `LIBRECHAT_AGENTGATEWAY_KEY` ne portent pas le préfixe `AGENTGATEWAY_` requis par la CI. Renommage du store nécessaire, ou un autre modèle.
6. **Rôle plateforme** : c'est une passerelle LLM partagée par d'autres apps (budgets, clés par consommateur). Elle relève plutôt d'un composant plateforme (`platform/`, hors périmètre) que d'une `apps/<nom>`. Recommandation : trancher avant toute extension.

## Points à vérifier
- Chemin de sonde : kube-ops n'a qu'une `tcpSocket` readiness sur 4000. `healthPath` est requis par le schéma : `/healthz` non vérifié **[S]**.
- Sécurité : uid 1000 (≥ 1000 OK), rootfs RO, drop ALL, token SA désactivé : équivalent ou plus strict que kube-ops.
- Stockage : SQLite `sqlite://data.db` sur PVC 1 Gi, `Recreate`. Compatible `block-rwo` une fois `storage` admis.
- Clés d'accès clients : les clés des consommateurs sont des secrets du store. Ne jamais les reproduire dans Git.

## Ce qu'il faut pour un descripteur
E4 (ingress), fichiers de config montés (E-config), FQDN validé sur OKE après le gate, renommage des secrets, et décision de rôle (app ou plateforme).
