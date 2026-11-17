# Résultats authz + MCP — **k3d** (pas OKE)

- **Bilan** : **50 PASS, 0 FAIL, 2 NOT_TESTED**. Séparation lecture/écriture des identités agents prouvée sur k3d.
- **Date** : 2026-11-17, 18:49 UTC. Dernière exécution complète de `tests/mcp/run.sh` sur un état propre (installation, matrice, nettoyage). Trois exécutions vertes au total, les deux dernières sur les manifestes finaux.
- **Environnement** : cluster `k3d-openchoreo`, OpenChoreo **v1.3.3**, ThunderID 1.0.1 (IdP du k3d), MCP `http://api.openchoreo.localhost:8080/mcp`.
- **Preuve brute** : `evidence/k3d-20261117T184914Z.txt`. Elle ne contient ni jeton ni secret : les secrets des clients de test sont aléatoires et gardés hors dépôt (0600), et les clients sont supprimés à la fin.
- **Objets testés** : `platform/authz/` (rôles `lab-agent-reader`, `lab-agent-operator`, `lab-agent-forbidden`, `lab-viewer`, `lab-platform-admin` et 7 bindings), plus la cible jetable `fixtures/lab-mcp-target.yaml` (namespace OpenChoreo `lab-mcp`, environnements development et production, 2 ReleaseBindings en `Undeploy`, une SecretReference factice). Rien n'est rendu sur le data plane.

## Tableau

| ID | Test | Résultat | Preuve |
|---|---|---|---|
| I1-I2 | Les jetons client_credentials des 2 agents portent `client_id` et aucun `groups`, donc le sujet est de type `service_account` | PASS | liste des claims |
| I3-I4 | MCP sans jeton, ou avec une signature altérée | PASS | HTTP 401 |
| L1 | reader : `tools/list` filtré, 55 outils, **0 outil d'écriture** | PASS | |
| L2 | operator : 58 outils, dont 3 d'écriture seulement : `update_release_binding`, `create_release_binding`, `create_component_release` | PASS | |
| L3 | Aucun outil authz ni `secret_reference` listé pour les agents | PASS | |
| L4 | `?filterByAuthz=false` affiche les 130 outils : le filtre règle la **visibilité**, pas le droit d'appel | PASS | voir R5-R10 et O4-O10 |
| R1-R4 | reader : namespaces, composants, release bindings (lecture) | PASS | |
| R5-R5b | reader **non filtré** : `update_release_binding`, puis binding vérifié inchangé | PASS | « insufficient permissions » |
| R6-R7, R10 | reader non filtré : `create_component`, `delete_component`, `create_release_binding` | PASS | refusés |
| R8-R8b | reader : `list_secret_references` renvoie une liste vide alors qu'une référence existe ; `get_secret_reference` est refusé | PASS | |
| R9 | reader : `list_authz_role_bindings` | PASS | refusé |
| O1-O1b | operator : `update_release_binding` (replicas et ressources) en **development**, écriture **effective dans le cluster, hors Git** | PASS | `spec.replicas=2` |
| O2-O2b | operator : même appel en **production**, refusé par la condition CEL, binding inchangé | PASS | |
| O3 | operator : `create_component_release` autorisé par l'authz | PASS | échec métier « workload not found », attendu |
| O4-O6 | operator non filtré : `create_component`, `delete_component`, `create_workload` | PASS | refusés |
| O7-O8 | operator : aucune SecretReference visible ; `get_`/`create_secret_reference` refusés | PASS | |
| O9-O10 | operator : `create_authz_role_binding` (vers `admin`) et `list_authz_role_bindings` | PASS | refusés |
| O11 | Constat : `list_authz_actions` reste appelable par tous. Catalogue statique, sans donnée de binding | PASS (constat) | |
| T1 | operator : `create_trait` d'un ClusterTrait qui rend une **ClusterRoleBinding** vers `cluster-admin` | PASS | refusé |
| T2 | operator : `patch_component` pour attacher le trait CRB existant `t-add-crb` | PASS | refusé |
| T3-T5 | **Deny explicite** : un allow d'escalade est ajouté exprès (`clustertrait:create`, `trait:create`, `component:update`), mais T1 et T2 restent refusés et `evaluate_authz` répond `decision:false`. Le deny gagne | PASS | |
| T6 | Aucun ClusterTrait créé, aucun trait attaché | PASS | |
| H1-H7 | Humains par groupe (décision du PDP via `evaluate_authz`) : viewers en lecture seule sans secretreference ; developers qui créent des composants sans authz ; `authentik-admins` admin ; groupe inconnu refusé | PASS | |
| H8 | Connexion réelle par navigateur (console, Backstage) avec un utilisateur de chaque groupe | NOT_TESTED | login interactif non joué |
| G1 | Argo CD écrase-t-il une écriture MCP sur un binding géré par Git ? | NOT_TESTED | A3 (Argo sur k3d) n'est pas terminé |
| AU1 | Le journal `openchoreo-api` contient un `ACCESS-LOG` par requête MCP (méthode, chemin, IP, user-agent, statut) | PASS | |
| AU2 | Constat : au niveau INFO, le journal ne contient **ni le sujet ni la décision**. Un refus MCP est une réponse HTTP 200 (erreur JSON-RPC) | PASS (constat) | 0 ligne |
| AU3 | L'objet écrit garde une trace minimale : `managedFields` avec le gestionnaire `openchoreo-api` et l'horodatage, sans l'identité de l'agent | PASS (constat) | |

## Écarts découverts (vérifiés dans le code v1.3.3)

1. **Format de `resource.environment`**. Pour un Environment namespacé, l'attribut vaut `<namespace>/<env>`, par exemple `lab-mcp/development` (`services/releasebinding/service_authz.go`, `FormatDualScopedResourceName`). Or l'exemple de la CRD, `resource.environment in ["dev","staging"]`, **ne correspond jamais** à cette valeur. Première exécution : l'opérateur était refusé partout. Correctif : `endsWith("/development")`.
2. **Le MCP ne journalise pas les refus**. La décision du PDP n'est loguée qu'au niveau DEBUG, et l'audit (`audit.enabled`) a besoin d'un observability plane. Voir `docs/AGENT-ACCESS.md` §6.
3. **`list_authz_actions`** n'est pas protégé : l'outil n'est pas scopé et le service ne fait pas de contrôle. L'impact est faible (catalogue statique).
4. **Liste des SecretReference** : elle est filtrée élément par élément et renvoie une liste vide au lieu de refuser. Il n'y a pas de fuite.
5. **Liaison par défaut du chart `mcp-tryout-client-binding`** : elle donne le rôle `admin` au client `service_mcp_client`, dont le secret est une valeur publique du chart. **À retirer sur OKE** (déjà prévu dans `docs/IDENTITY.md` §4).

## Incident du banc (k3d) : JWKS injoignable

Au début du test, `openchoreo-api` refusait tout jeton (401 `INVALID_TOKEN`) et journalisait : `lookup thunder.openchoreo.localhost … no such host`. La cause : après un redémarrage, k3s réécrit la ConfigMap `kube-system/coredns`. L'entrée `host.k3d.internal` disparaît alors de `NodeHosts`, alors que c'est la cible du rewrite `coredns-custom`.

`kube-system` est hors de mon périmètre. Contournement temporaire : un `hostAliases` (`thunder.openchoreo.localhost → 172.18.0.1`, la passerelle du réseau k3d) sur `openchoreo-control-plane/openchoreo-api`, **retiré après les tests**. Le cluster est donc revenu à son état d'origine, et le MCP du k3d reste cassé tant que `NodeHosts` n'est pas réparé. `run.sh` le détecte et s'arrête en BLOCKED (code 3).

Correctif durable, à faire par le coordinateur : remettre `172.18.0.1 host.k3d.internal` dans `NodeHosts`, ou le faire dans le script d'installation k3d après chaque démarrage.

## Rejouer

```bash
export DOCKER_CONTEXT=colima-openchoreo KUBECONFIG=<kubeconfig du k3d>
tests/mcp/run.sh            # installe, teste, nettoie
tests/mcp/run.sh --keep     # sans nettoyage
tests/mcp/run.sh --cleanup
```
