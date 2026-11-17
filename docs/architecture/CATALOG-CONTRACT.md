# Contrat du catalogue unique (Backstage) et fédération OpenChoreo + Helm/Argo

Statut : **PROPOSÉ** (2026-11-17). Ne modifie ni le schéma, ni `appgen`, ni `platform/**`. Les évolutions sont listées au §6.
Code lu : `openchoreo/backstage-plugins` tag **v1.3.3** (commit `6d09816`), chart `openchoreo-control-plane` 1.3.3.

## 1. Conclusion

- **La fédération est faisable en 1.3.3 sans code** et sans Components OpenChoreo artificiels :
  - **natif** : `OpenChoreoEntityProvider` reste la **seule** source de l'entité ;
  - **Helm/Argo** : un `catalog-info.yaml` généré par `appgen` est la **seule** source de l'entité, lu par **une** `Location` de type `url` déclarée dans `backstage.appConfig`.
- **Quatre pièges vérifiés dans le code**, à traiter avant d'activer la fédération :
  1. `appgen` génère aujourd'hui un `catalog-info.yaml` **aussi pour les apps natives**, avec le même nom que l'entité du provider. Activer la Location dans cet état créerait des **conflits** (§3.2).
  2. Fournir `catalog.locations` dans `appConfig` **remplace** la liste de l'image (les tableaux de config Backstage ne sont pas fusionnés) : on perdrait le Group `openchoreo-users` et les 14 Templates.
  3. L'image n'a ni `integrations.github` ni `catalog.rules` : il faut un jeton GitHub en lecture (sinon limite anonyme de 60 req/h), un egress vers GitHub et des règles explicites.
  4. Sans Thunder, aucun `User`/`Group` n'est synchronisé : les owners doivent être déclarés dans Git.
- Annotations : le plugin utilise le préfixe **`openchoreo.io/`** et non `openchoreo.dev/` (`openchoreo-common/src/constants.ts` l.2-28).
- `docs/PORTAL.md` l.45 (« ne pas déclarer de Location ») reste vrai **tant que** les changements du §6 ne sont pas faits. **Ne rien changer avant `whoami`.**

## 2. Contrat commun d'un service

| Champ | Natif OpenChoreo (source → entité) | Helm/Argo (source → entité) | Représentation Backstage commune |
|---|---|---|---|
| Identité | Component OpenChoreo `<ns>/<nom>` → `component:<ns>/<nom>` (`entityTranslation.ts` l.238-245) | `apps/<nom>/app.yaml` → `catalog-info.yaml`, `metadata.namespace: default` | `component:default/<nom>`, **unique tous modes confondus** (§3) |
| Propriétaire | annotation `backstage.io/owner` du Component, sinon du Project, sinon `group:default/openchoreo-users` (`utils/helpers.ts` l.39-57) | `spec.owner` | `group:default/<groupe>` qui existe dans le catalogue |
| Système | Project → `spec.system` | `spec.system` (un System OpenChoreo existant est admis) | `system:default/<projet>` |
| Environnement, Data Plane | Environments et Data Planes synchronisés (kinds dédiés), onglet Environments | annotation `platform.smadja.dev/environments`, `platform.smadja.dev/data-plane` (**proposées**) | même vocabulaire : `production`, `talos-production` ; `oke` / `talos` |
| Type de livraison | label `openchoreo.io/managed=true` (l.284-286) | annotation **proposée** `platform.smadja.dev/delivery: helm` | filtre du catalogue |
| Dépendances | `spec.dependsOn` vers `resource:<ns>/<nom>` (l.293) ; API `providesApis`/`consumesApis` | `spec.dependsOn` généré depuis `app.yaml` | relations `dependsOn` |
| Secrets | références de secret OpenChoreo (pas de valeur) | noms des ExternalSecret (pas de valeur) | annotation `platform.smadja.dev/secret-stores` : magasins seulement |
| Stockage | profil de l'app (`ephemeral`, `fast-rwo`, `bulk-rwo`, `database`) | idem | annotation `platform.smadja.dev/storage` |
| Exposition | endpoints `openchoreo.io/endpoint-*` | `platform.smadja.dev/exposure: private\|public+access` | idem |
| Politiques | CCT/CPT appliqués (rendu) | PSA + VAP + Kyverno de la cellule `lab-*` | annotation `platform.smadja.dev/policies` (référence à `KYVERNO-POLICY-CONTRACT.md`) |
| Santé | `openchoreo.io/status`, lifecycle dérivé du statut | `argocd/app-name` (déjà émis, `appgen.py` l.1123-1126) | santé lue sur la source ; aucun statut recopié à la main |
| Métriques | `observability.metrics` de l'app | idem | lien du tableau de bord (`metadata.links`) |
| Sauvegarde / restauration | `platform.smadja.dev/backup` (déjà émis, `appgen.py` l.1018-1019) | idem | + lien vers la procédure de restauration |
| PR, déploiement, incidents, rollback | `backstage.io/source-location` si le Component a un dépôt (l.274-281) ; sinon **limite** (§4) | `metadata.links` : `apps/<nom>`, Application Argo, `incidents/<nom>`, `golden-paths/` rollback ; `github.com/project-slug` | mêmes liens attendus pour les deux modes |

## 3. Règles d'unicité et de propriété

1. **Une source par entité.**
   - Natif : seul le provider la produit, et `appgen` **n'émet plus** de `catalog-info.yaml` pour ces apps.
   - Helm : seule la Location la produit, et l'app n'a **aucun** Component OpenChoreo.
2. **Une identité par service.** Le nom de l'app est unique dans `apps/` (un répertoire par app), et le namespace Backstage vaut `default` dans les deux modes. Une migration Helm → natif **garde donc la même référence** `component:default/<nom>`.
   - Pour un service kube-ops ajouté au catalogue, `appgen` (ou la CI) doit refuser un nom déjà pris.
   - Si OpenChoreo utilise un jour un namespace autre que `default`, la règle devient « le namespace Backstage d'une app Helm = le namespace OpenChoreo de rattachement ».
3. **Conflit pendant une migration.** Backstage garde l'entité déjà présente et rejette l'autre (« conflicting entity ») tant que la première n'a pas disparu.
   - Procédure : la **même PR** retire le `catalog-info.yaml` et ajoute le Component natif.
   - Il faut `catalog.orphanStrategy: delete` : par défaut, Backstage **garde** les orphelins.
   - Fenêtre attendue : ≤ une synchro (120 s, `catalogSync.frequency`). À prouver sur k3d.
4. **Propriété.** `app.yaml metadata.owner` est l'unique source du propriétaire. `appgen` la porte en `backstage.io/owner` sur le Project **et** le Component natifs (aujourd'hui absent : seul `catalog-info.yaml` porte l'owner, `appgen.py` l.1032), et en `spec.owner` côté Helm. L'owner doit être un **Group** (`group:default/…`), car aucun `User` n'est synchronisé avec Authentik (`catalog-backend-module-openchoreo-users/src/module.ts` l.20-24 : provider Thunder seulement).
5. **Pas de Component OpenChoreo artificiel pour un chart.** OpenChoreo le rendrait et le réconcilierait en concurrence avec Argo (deux propriétaires, cycle de vie incohérent). C'est déjà la règle de `docs/APP-CONTRACT.md` l.16 et l.198.

## 4. Ce que 1.3.3 permet réellement (vérifié dans le code)

| Question | Réponse | Preuve |
|---|---|---|
| Entités produites pour un Component natif | `kind: Component`, `metadata.namespace` = namespace OpenChoreo, `metadata.name` = nom du Component, annotations `openchoreo.io/component`, `/project`, `/namespace`, `/status`, `/component-type`, `backstage.io/managed-by-location: provider:OpenChoreoEntityProvider` | `catalog-backend-module-openchoreo/src/utils/entityTranslation.ts` l.223-297 |
| Mode de synchro | mutation **`full`** de toutes les entités du provider à chaque passage (ce que l'API ne renvoie plus disparaît) | `provider/OpenChoreoEntityProvider.ts` l.1902-1906 |
| Owner configurable | oui, par annotation `backstage.io/owner` (Component > Project > défaut) ; défaut `openchoreo.defaultOwner` | `utils/helpers.ts` l.39-57 ; `OpenChoreoEntityProvider.ts` l.152-157 |
| Enrichir une entité du provider par un `catalog-info.yaml` | **non** (sinon conflit) ; les seuls ajouts possibles passent par le Component OpenChoreo (annotations recopiées : owner, description, dépôt) ou par un processeur personnalisé (code, image maison) | l.238-290 : liste fermée d'annotations |
| Onglets OpenChoreo sur une entité Helm | non : « OpenChoreo metadata not found » (attendu et sans gravité) | docs v1.3.x `backstage-plugins/entity-views.mdx` l.59 |
| Lire des `catalog-info.yaml` | oui : `@backstage/plugin-catalog-backend` est dans l'image ; Location `url` ; pas de découverte GitHub (module absent) | `packages/portal-backend/src/features.ts` l.50 |
| Ajouter de la config | `backstage.appConfig` → ConfigMap `app-config.extra.yaml`, chargée en dernier | chart `templates/backstage/extra-config-configmap.yaml` ; `deployment.yaml` l.68-70 |
| Config de base de l'image | `app-config.production.yaml` copiée en `app-config.yaml` ; `catalog.locations` = Group `openchoreo-users` + 14 Templates (15 entrées) ; **pas** de `catalog.rules` ni d'`integrations` | `packages/backend/Dockerfile` l.111 ; `app-config.production.yaml` l.166-232 |
| Jeton GitHub | injectable par `backstage.extraEnv` (Secret hors dépôt) | `deployment.yaml` l.80-82 |

### Brouillon de `backstage.appConfig` (changement proposé, **non appliqué**)

```yaml
backstage:
  extraEnv:
    - name: GITHUB_TOKEN               # fine-grained, lecture seule du dépôt public, depuis Doppler via ESO
      valueFrom: {secretKeyRef: {name: backstage-secrets, key: github-read-token}}
  appConfig:
    integrations:
      github: [{host: github.com, token: ${GITHUB_TOKEN}}]
    catalog:
      orphanStrategy: delete
      rules:
        - allow: [Component, System, API, Resource, Location, Group, User, Template]
      locations:
        # 1) recopier À L'IDENTIQUE les 15 entrées de l'image (org.yaml + 14 templates) — sinon perdues
        # 2) groupes du labo (owners), alignés sur les groupes Authentik
        - type: url
          target: https://github.com/platform-zephyr/openchoreo-lab/blob/main/catalog/groups.yaml
          rules: [{allow: [Group]}]
        # 3) une seule Location agrégée générée par appgen (Location -> targets des apps Helm)
        - type: url
          target: https://github.com/platform-zephyr/openchoreo-lab/blob/main/generated/catalog/all.yaml
          rules: [{allow: [Location, Component, Resource]}]
```

Réseau : une CNP d'egress `backstage → github.com:443` (`api.github.com`, `raw.githubusercontent.com`) s'ajoute à `manifests/03-idp-egress.yaml`. Elle n'est prouvable qu'après C1.

## 5. Prouvé et non prouvé

- **Prouvé (lecture de code, 2026-11-17)** : tout le §4 ; la collision de nom entre `appgen` et le provider (`generated/catalog/whoami/catalog-info.yaml` contient `name: whoami`, namespace implicite `default`, et le Component OpenChoreo `whoami` vit dans le namespace `default`).
- **Non prouvé (k3d d'abord)** :
  - coexistence provider + Location sans conflit ;
  - effet de `orphanStrategy: delete` sur une migration Helm → natif ;
  - règles de catalogue réellement appliquées aux entités du provider (l'image n'a pas de `catalog.rules`, mais les Domain/System s'affichent sur k3d) ;
  - consommation du quota GitHub avec jeton.

## 6. Changements proposés (PR séparées, après `whoami`)

1. `tools/appgen` :
   - n'émettre `catalog-info.yaml` que pour la livraison Helm (`appgen.py` l.1007) ;
   - générer `generated/catalog/all.yaml` (`kind: Location`, `targets` des apps Helm) ;
   - porter `backstage.io/owner` sur les Project/Component natifs ;
   - remplacer `openchoreo.dev/managed` par `platform.smadja.dev/delivery`.
2. `docs/schema/app.schema.json` : `metadata.owner` limité à `group:default/<nom>`.
3. `catalog/groups.yaml` : Groups alignés sur Authentik (`openchoreo-developers`, `openchoreo-viewers`, `authentik-admins`, plus les équipes propriétaires).
4. `platform/install/values/openchoreo-control-plane.yaml` : le bloc du §4, plus le Secret `github-read-token` (ESO/Doppler).
5. `docs/PORTAL.md` l.45 : remplacer l'interdiction par ce contrat une fois les points 1 à 4 faits.
