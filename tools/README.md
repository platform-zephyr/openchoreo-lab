# tools/ : générateur d'applications (appgen)

Une app = `apps/<nom>/app.yaml`. Le générateur produit les manifests OpenChoreo v1.3.3 sous `generated/`, que la CI vérifie sans dérive. Contrat complet : `docs/APP-CONTRACT.md`. Schéma : `docs/schema/app.schema.json`.

## Ajouter une app (1 fichier)

1. Créer `apps/<nom>/app.yaml` à partir de `apps/whoami/app.yaml` (natif) ou de `apps/_examples/podinfo-helm/` (Helm, non activé).
2. Épingler l'image par **digest** (`image: repo:tag@sha256:...`) après `docker buildx imagetools inspect <image>` : l'index multi-arch doit contenir `linux/arm64`.
3. Pour une base : `database: {engine: postgres}` ; les secrets se déclarent dans `secrets[]` avec le préfixe `<NOM>_` (ex. `MINIFLUX_...`). Aucune valeur n'entre dans Git.
4. Lancer `python3 tools/appgen/appgen.py validate`, puis `render` (voir ci-dessous).

## Régénérer

```sh
python3 tools/appgen/appgen.py validate            # schéma + règles (choix natif/helm, secrets, exposition, sauvegarde)
python3 tools/appgen/appgen.py render              # écrit generated/ (suppression préalable, sortie déterministe)
python3 tools/appgen/appgen.py check               # échoue si generated/ diffère du rendu (dérive)
python3 tools/appgen/appgen.py pin-resource miniflux production <release>   # 2e PR d'une base (voir ci-dessous)
```

Dépendances : `pip install -r tools/appgen/requirements.txt` (PyYAML, jsonschema). Aucune autre.

Le nom d'une ComponentRelease est `<composant>-<hash10>` (hash du contenu). Ce n'est pas la convention `occ` (`<composant>-<YYYYMMDD>-<n>`) : `occ` n'est pas disponible ici (pas de Go) et sa convention dépend de la date. Écart documenté.

## Politique par cluster et extensions

`clusters/<cluster>/capabilities.yaml` (schéma `docs/schema/capabilities.schema.json`) définit ce que le cluster admet : Cilium, CIDR privés nommés, instances de base, IdP, profils de stockage, mécanismes de sauvegarde, store ESO. Ce qui n'y figure pas est refusé. Extensions (egress FQDN/CIDR/app, `pg-shared`, Authentik et groupes, `workloads[]`, `jobs[]`, multi-volumes, `backup.mechanism`, `securityExceptions[]`, parcours Helm) : `docs/APP-CONTRACT.md` §1.1, §2.4 et §7.4.

`--allow-unenforced-fqdn` (labo seulement) : sur un cluster sans Cilium, une règle FQDN produit un avertissement au lieu d'un refus, et l'aperçu CNP est marqué `enforced: "false"`. Les flux restent refusés.

## Tester localement

```sh
python3 -m unittest discover -s tests/appgen -v    # validation, cas négatifs, rendu déterministe, dérive
tests/appgen/kubeconform-negative.sh <dossier CRD>  # une valeur fausse doit être refusée
tools/appgen/fetch-ext-schemas.sh <dossier vide>    # schémas Cilium, Argo CD, ESO épinglés (sha256 vérifié)
tools/appgen/validate-crd.sh <dossier CRD> [generated] [schémas externes]   # kubeconform -strict
APPGEN_CRDS=<dossier CRD> APPGEN_EXT_SCHEMAS=<dossier> python3 -m unittest discover -s tests/appgen   # + test kubeconform des extensions
```

`<dossier CRD>` = `config/crd/bases` du tag `v1.3.3` d'openchoreo/openchoreo (commit épinglé dans `.github/workflows/ci.yaml`).

## Pin de ResourceReleaseBinding (le piège connu)

Une `ResourceReleaseBinding` doit pointer une `ResourceRelease` existante (`spec.resourceRelease`). Aucun générateur ne la crée : le nom vient de `Resource.status.latestRelease.name` (`<res>-<hash>`). Procédure à deux PR :

1. PR 1 : `app.yaml` avec la base. `render` produit `Resource` et `ResourceReleaseBinding` **sans** pin (binding en attente).
2. Après création de la `Resource` sur le cluster : `kubectl get resource <app>-db -n default -o jsonpath='{.status.latestRelease.name}'`, puis `pin-resource <app> <env> <nom>`, `render`, PR 2.

Le pin est la seule lecture du cluster, faite par un humain ou un opérateur, jamais par la CI.

## Règles de sécurité appliquées (cas négatifs dans tests/appgen)

- Refus : secret en clair (nom ou valeur ressemblant à un secret), URL avec identifiants, image sans digest, exposition publique sans auth ou sans hôte, champ inconnu, `LoadBalancer`/`NodePort`/`hostPath`, `backup.class: irreplaceable`, OKE sans gate, PVC avec plusieurs réplicas, hôte public en double.
- `autoDeploy: false` partout. `ComponentRelease` immuables (noms à hash). Pas de `Prune` côté Argo sur les releases (voir `docs/APP-CONTRACT.md` section 5).

## Fichiers

- `appgen.py` : générateur (validate, render, check, pin-resource).
- `crd2schema.py` : CRD v1.3.3 vers JSON Schema pour kubeconform.
- `validate-crd.sh` : validation kubeconform du rendu (CRD OpenChoreo ; aperçus et Helm avec les schémas externes).
- `fetch-ext-schemas.sh` : schémas JSON externes de datreeio/CRDs-catalog, commit et sha256 épinglés.
- `yamllint.yaml` : configuration yamllint (appelée explicitement).
- `apply-branch-protection.sh` : enveloppe de `github/apply.sh dev` (ruleset GitHub sur `main`, `ci-ok` requis, revue des code owners désactivée en dev). Affichage par défaut, `--check` (dérive, lecture seule), `--apply` (Paul, jeton admin). Charge utile : `.github/rulesets/main-dev.json`. Test hors ligne : `tests/github-config/run.sh`.
