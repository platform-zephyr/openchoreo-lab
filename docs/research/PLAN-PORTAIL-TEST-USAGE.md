---
owner: paul
updated: 2026-11-19
review_days: 30
---
# Plan : portail OpenChoreo sur OKE pour un test d'usage jetable de Paul

Date : 2026-11-19 · Ticket : T-523 · Niveau : `STATIC` (doc, code amont et dépôt lus ; aucun cluster touché).
Légende : **[L]** lu le 2026-11-19 ; **[D]** déduit ; **[H]** hypothèse à vérifier. Base : [USAGE-NORMAL](OPENCHOREO-USAGE-NORMAL.md)
(T-520, PR #196), [PORTAL](../PORTAL.md), [OKE-MAXPODS](OKE-MAXPODS.md).

## Conclusion d'abord

1. Pour le test, l'option la plus simple est l'identité par défaut d'OpenChoreo, **ThunderID** (le serveur de
   connexion livré par l'amont). Paul ne fait **aucun geste dans Authentik**. Cela s'écarte de MISSION et
   d'ADR-0007 **pour le test seulement** [L](../adr/0007-identite-oidc.md). Paul choisit Authentik ou ThunderID après le test.
2. **Bloquant à lever avant l'installation : le disque.** ThunderID 1.0.1 crée 3 volumes persistants (base SQLite,
   certificats, secrets) [L][tpvc]. Sur OKE, un volume coûte au moins 50 Go ; le free tier donne 200 Go en tout, dont
   50 Go de disque système [L](COST-FREE-TIER.md). Il faut donc 150 Go libres, soit **aucun autre volume** (`lab-pg`
   compris). Décision de Paul (§1.1, D2).
3. Empreinte du portail et de ThunderID : **+110m CPU, +370 Mi, +2 pods** permanents (§1.3). Le CPU tient sous 90 %.
   Les pods non : il faut libérer 1 pod (maxPods 35).
4. Accès : une seule commande ouvre le bastion et trois tunnels ; le lien est http://localhost:7007 (§2).
5. Le GitOps n'intervient pas dans le test : le portail écrit par l'API [L](OPENCHOREO-USAGE-NORMAL.md). Flux est le
   GitOps documenté par l'amont, Argo CD ne l'est pas [L][flux]. Ce choix se décide aussi après le test (§3).

## 1. Plan d'installation (étape 6b, variante de test)

### 1.1 Décisions de Paul avant de commencer

- D1. Accepter l'écart d'identité (ThunderID) et les écritures par l'API pendant le test (exception AGENTS.md, test jetable).
- D2. Libérer 150 Go de disque : supprimer `lab-pg` (base de test, inutile au test ; réinstallable par `install.sh --step 10`)
  et tout volume d'essai restant. Sinon : **BLOCKED** ; repli au §1.6.
- D3. Durée de vie : 48 h au plus, puis retour arrière (§1.5).

### 1.2 Principe et valeurs minimales

Tout passe par une **branche de test jamais fusionnée** (`test/t-523-thunderid`). Elle change des valeurs, pas les
scripts. ThunderID va dans le namespace `openchoreo-identity` (un namespace est un espace isolé du cluster) : l'amont
utilise `thunder`, hors du périmètre d'écriture d'AGENTS.md [L][inst][D].

Le navigateur de Paul et les pods doivent voir le même émetteur de jetons. Le navigateur passe par `localhost` ; les
pods passent par le nom interne du service. Les URL OIDC du chart sont séparées [L](../PORTAL.md), donc [D][H] :

| Valeur | Où | Contenu minimal |
|---|---|---|
| `configuration.server.publicUrl`, `gateClient` | ThunderID | `http://localhost:8090` (vue du navigateur) |
| Application « Backstage », `redirectUris` | ThunderID | `http://localhost:7007/api/auth/openchoreo-auth/handler/frame` |
| Mots de passe des comptes de test, secret du client | ThunderID | générés à l'installation ; jamais dans le dépôt [L][tval] |
| `httproute.enabled` | ThunderID | `false` : aucune exposition, port-forward seulement |
| Image | ThunderID | `thunderid:1.0.1` épinglée par digest (le chart met `latest`) [L][tvals] |
| `security.oidc.issuer`, `authorizationUrl` | CP | `http://localhost:8090`, `…/oauth2/authorize` |
| `security.oidc.tokenUrl`, `jwksUrl` | CP | `http://thunder-service.openchoreo-identity.svc.cluster.local:8090/oauth2/token`, `…/oauth2/jwks` |
| `backstage.baseUrl` | CP | `http://localhost:7007` |
| `bootstrap.mappings` | CP | liaisons par défaut du chart pour les groupes ThunderID (`developers`, `admins`…) [L][tval] |
| Quota `openchoreo-identity` | dépôt (étape 1) | requests 200m / 256 Mi, 3 pods, 3 volumes ; défaut « tout refuser » + 2 règles d'entrée |
| Règle réseau | `openchoreo-control-plane` | sortie de `backstage` et `openchoreo-api` vers ThunderID, port 8090 |

### 1.3 Empreinte (ressources)

| Élément | Requests | Limites | Pods |
|---|---|---|---|
| Portail `backstage` | 10m / 320 Mi [L](../PORTAL.md) | 1000m / 768 Mi | 1 |
| ThunderID | 100m / 50 Mi [L][tvals] | 200m / 100 Mi | 1 |
| Job de configuration ThunderID (pendant l'installation) | 100m / 50 Mi [L][tvals] | 200m / 100 Mi | 1, transitoire |
| **Total permanent** | **110m / 370 Mi** | | **2** |

- CPU : avant, 950m à 1140m sur ~1830m (52 à 62 %, à relever) [L](OKE-MAXPODS.md). Après : 1060m à 1250m (58 à 68 %) ;
  1350m (74 %) pendant le Job. Marge ≤ 90 % (~1647m) respectée [D].
- Pods : 33 présents, maxPods 35 [L](OKE-MAXPODS.md). +2 permanents = 35, et le Job en demande un 36e. **Libérer
  au moins 1 pod avant** (par exemple une app de test arrêtée), sinon le Job reste en attente [D].
- Disque : 3 × 50 Go (§ conclusion 2). Mémoire : +370 Mi sur 8650 Mi, sans risque [D].

### 1.4 Ordre (opérateur ; ~60 min)

1. Lire l'état : `tools/oke/measure.sh` (CPU, pods) ; liste des volumes OCI. Arrêter si D2 ou la marge de pods manque.
2. Branche de test : valeurs du §1.2, namespace, quota et règles réseau.
3. `tools/oke/install.sh --step 1 --apply` : namespace `openchoreo-identity` et son quota.
4. `helm install` de ThunderID 1.0.1 (chart `oci://ghcr.io/thunder-id/helm-charts/thunderid`) [L][inst]. Attendre le Job
   et le Deployment ; 3 volumes `Bound`.
5. Créer le Secret `backstage-secrets` (4 clés, [L](../PORTAL.md)) avec le secret du client généré à l'étape 4.
6. `install.sh --step 6b` (essai à blanc), puis `--step 6b --apply` ; `verify.sh --step 6b`. Le contrôle B6b-login
   attend Authentik : son FAIL est **attendu** ; vérifier à la main la redirection vers `localhost:8090`.
7. Connexion test par l'opérateur avec le compte développeur ; `measure.sh`. Puis remettre les accès à Paul.

### 1.5 Risques et retour arrière

| # | Risque | Parade |
|---|---|---|
| R1 | Disque : 150 Go exigés [L][tpvc] | D2 ; vérifier en fin de test qu'aucun volume orphelin ne reste |
| R2 | maxPods 35 atteint | Libérer 1 pod avant l'étape 4 |
| R3 | L'API ou le portail refuse l'émetteur `localhost` vu par le navigateur et `svc` vu des pods [H] | Arrêter ; noter l'erreur ; repli §1.6 |
| R4 | Le Job ThunderID ne s'exécute qu'à la 1re installation [L][inst] : une erreur de valeur oblige à tout réinstaller | Relire les valeurs avant l'étape 4 |
| R5 | ThunderID non conforme à la PSA `restricted` (règles de sécurité des pods) [H] | Rendu hors cluster et `psa_check.py` avant l'étape 4 ; jamais d'exception |
| R6 | Comptes et secret par défaut publics dans les valeurs amont [L][tval] | Les remplacer à l'étape 4 ; aucune exposition |
| R7 | Écart MISSION et ADR-0007 | Limité à 48 h, retour arrière obligatoire |

Retour arrière (~15 min) : `tools/oke/uninstall.sh --step 6b --apply` [L](../PORTAL.md) ; depuis `main`,
`install.sh --step 6 --apply` (remet l'identité Authentik du CP) ; `helm uninstall` de ThunderID ; supprimer le
namespace `openchoreo-identity` et ses volumes ; vérifier qu'aucun volume OCI ne reste ; `--step 10` si Paul veut
`lab-pg` de nouveau ; `verify.sh --all`.

### 1.6 Repli si R1 ou R3 bloque

Test fonctionnel sur le Mac avec l'installation k3d de l'amont (portail et ThunderID inclus, 0 geste sur OKE) [L][k3d].
Il prouve les fonctions, pas le comportement sur OKE.

## 2. Accès de Paul (une commande)

Prérequis Mac : `oci` configuré, `kubectl` [L](../../tools/oke/open-oke-access.sh). Depuis la racine du dépôt :

```bash
tools/oke/open-oke-access.sh open 7200 && export KUBECONFIG="$HOME/.cache/oke-access/kubeconfig" && { kubectl -n openchoreo-control-plane port-forward svc/backstage 7007:7007 & kubectl -n openchoreo-identity port-forward svc/thunder-service 8090:8090 & kubectl -n openchoreo-control-plane port-forward svc/openchoreo-api 8080:8080 & wait; }
```

Puis ouvrir **http://localhost:7007** et se connecter avec le compte développeur (mot de passe remis hors dépôt par
l'opérateur). Le port 8090 sert à la page de connexion ; le port 8080 sert à `occ` et au MCP. Fin : `Ctrl-C`, puis
`tools/oke/open-oke-access.sh close` (ferme le bastion, efface le kubeconfig temporaire) [L](../../tools/oke/open-oke-access.sh).
Le bastion limite la session à 2 h (`7200`) ; la relancer si elle expire.

## 3. Fonctions d'OpenChoreo utilisables vs kube-ops aujourd'hui

| Fonction | OpenChoreo (test) | kube-ops aujourd'hui | Simplicité d'exploitation |
|---|---|---|---|
| Créer un projet ou un composant | Formulaire du portail pour le projet ; composant par `occ` ou YAML, ou par un formulaire à écrire une fois [L][tpl] | `app.yaml` (sans état seulement) ou 8 à 12 fichiers Kustomize, puis PR [L](KUBE-OPS-REQUIREMENTS.md) | OC : 1 formulaire ou 1 fichier ; kube-ops : beaucoup de fichiers par app |
| Déployer | Bouton Deploy ou `occ component deploy` [L][dp] | Fusion de PR, puis Argo CD applique [L](KUBE-OPS-REQUIREMENTS.md) | OC : immédiat, sans PR ; kube-ops : revue, mais plus lent |
| Promouvoir dev → prod | Bouton Promote, version figée d'un environnement à l'autre [L][dp] | Pas d'environnements dev/prod décrits [H] | OC : 1 clic ; kube-ops : à construire |
| Diagnostiquer | Portail : arbre des objets et événements ; logs seulement avec le plan d'observabilité, absent [L][logs] | `kubectl` et Grafana Cloud [L](KUBE-OPS-REQUIREMENTS.md) | OC : tout dans une page, sans logs ; kube-ops : logs complets, plus d'outils |
| MCP pour un agent | Serveur MCP natif ; droits = ceux de l'utilisateur dans l'API [L][mcp] | Aucun MCP de plateforme [H] ; l'agent utilise `kubectl` | OC : branché en 1 commande, droits contrôlés ; kube-ops : droits larges |
| Secrets | Par ESO (outil qui copie un secret externe dans le cluster) ; l'amont utilise OpenBao [L][inst] | Doppler + ESO, un ExternalSecret par app [L](KUBE-OPS-REQUIREMENTS.md) | Équivalent ; OC ajoute un coffre si on suit l'amont |
| Accès et droits | Rôles de l'API liés aux groupes de l'IdP (serveur de connexion) ; portail, `occ`, MCP partagent les mêmes règles [L][idp] | Groupes Authentik et proxy de connexion devant les apps [L](KUBE-OPS-REQUIREMENTS.md) | OC : une règle pour 3 canaux ; ThunderID est « pour le dev et le test » selon l'amont [L][idp] |

GitOps : l'amont recommande Flux (fichiers par namespace, PR obligatoires) [L][flux]. Si Flux suffit, il retire nos
règles Argo maison (`argo_guard`, 730 lignes) [L](OPENCHOREO-USAGE-NORMAL.md)[D]. À trancher avec l'identité après le test.

## 4. Checklist du test d'usage (30 à 45 min)

Pour chaque ligne : PASS, FAIL ou BLOCKED, l'heure, et une phrase « simple ou pénible ».

- [ ] 1 (5 min) Lancer la commande du §2 ; ouvrir http://localhost:7007 ; se connecter. → Catalogue visible.
- [ ] 2 (5 min) Créer le projet `lab-test-paul` par le formulaire Project. → Projet visible.
- [ ] 3 (7 min) Créer un composant (image de `apps/whoami/app.yaml`, épinglée par digest). → Composant créé.
- [ ] 4 (5 min) Onglet Deploy : déployer sur `development`. → État Ready.
- [ ] 5 (5 min) Cliquer Promote vers `production`. → Ready en production, même version.
- [ ] 6 (5 min) Brancher le MCP (`claude mcp add … http://localhost:8080/mcp` [L][mcp]) ; demander « liste les
      composants et leur état ». → Réponse juste.
- [ ] 7 (5 min) Casser : image inexistante ; diagnostiquer par le portail puis par le MCP. → Cause trouvée.
- [ ] 8 (3 min) Réparer : redéployer la version précédente. → Ready.
- [ ] 9 (3 min) Se connecter avec un compte sans droit d'écriture ; essayer de déployer. → Refusé.
- [ ] 10 (2 min) Supprimer le projet ; `Ctrl-C` ; `open-oke-access.sh close`. → Rien ne reste.
- [ ] Décision : identité (Authentik ou ThunderID) et GitOps (Flux ou Argo CD), au regard des fonctions et de la
      simplicité notées.

[tpvc]: https://github.com/thunder-id/thunderid/blob/v1.0.1/install/helm/templates/pvc.yaml
[tvals]: https://github.com/thunder-id/thunderid/blob/v1.0.1/install/helm/values.yaml
[tval]: https://github.com/openchoreo/openchoreo/blob/v1.3.3/install/k3d/common/values-thunder.yaml
[k3d]: https://github.com/openchoreo/openchoreo/blob/v1.3.3/install/k3d/README.md
[inst]: https://openchoreo.dev/docs/getting-started/try-it-out/on-your-environment/
[idp]: https://openchoreo.dev/docs/platform-engineer-guide/identity-configuration/
[tpl]: https://openchoreo.dev/docs/platform-engineer-guide/backstage-scaffolder-templates/
[dp]: https://openchoreo.dev/docs/developer-guide/deploying-applications/deploy-and-promote/
[logs]: https://openchoreo.dev/docs/developer-guide/deploying-applications/logs-and-troubleshooting/
[mcp]: https://openchoreo.dev/docs/ai/mcp-servers/
[flux]: https://openchoreo.dev/docs/platform-engineer-guide/gitops/using-flux-cd/
