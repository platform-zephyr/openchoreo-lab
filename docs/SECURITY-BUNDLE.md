# Security bundle (temporaire)

Les charts `openchoreo-control-plane` et `openchoreo-data-plane` 1.3.3 sont installés **uniquement** avec un
security bundle privé : durcissement des droits de lecture rendus par les charts et image du contrôleur imposée par
digest. Les détails sont hors dépôt (coordination en cours avec l'amont). Sans bundle valide, `tools/oke/install.sh`
s'arrête **avant toute écriture** (étapes 6, 6b, 7, 10, y compris `--step`, `--from/--to`, rejeu et dry-run).

## Obtenir et vérifier

- Prérequis : accès GitHub de Paul au dépôt privé nommé dans `security/bundle.lock` (`BUNDLE_REPO`), `gh`
  authentifié, `python3` avec PyYAML, Helm 4.
- Automatique : `install.sh` télécharge `gh release download $BUNDLE_TAG -R $BUNDLE_REPO -p $BUNDLE_ASSET` dans
  `$STATE_DIR/security-bundle`. Chemin local à la place : `OPENCHOREO_SECURITY_BUNDLE=/chemin/security-bundle-X.tar.gz`.
- Vérification seule (sans cluster) : `tools/oke/security-bundle.sh status`.
- Contrôles (tous bloquants) : sha256 de l'archive = `BUNDLE_SHA256` du lock ; `manifest.json` (version, empreinte de
  chaque fichier) ; versions et sha256 des charts de `platform/install/versions.env` compatibles avec le bundle ;
  image du contrôleur = `BUNDLE_CONTROLLER_IMAGE` (digest, jamais un tag seul) ; plugins Helm installés dans le
  Helm isolé de `STATE_DIR` (jamais la config Helm du poste).
- Épinglage : version + empreinte dans `security/bundle.lock`. Changer de bundle = PR qui modifie le lock.

## Ce que fait l'installation

- `helm_secure` (`tools/oke/security-bundle.sh`) est le seul chemin `helm upgrade --install` des deux charts : il
  refuse les arguments de contournement, impose post-renderer et values, vérifie le rendu local avant d'écrire, puis
  la révision stockée.
- Upgrade du control plane (release existante) : seul conflit d'écriture admis = ConfigMap `cluster-gateway-ca`
  (vide dans le chart, peuplé hors Helm). Contrôle objet par objet en dry-run serveur, `--force-conflicts` pour ce
  seul cas, puis recopie immédiate de la CA publique (CP et DP) et redémarrage de controller-manager et
  openchoreo-api (aussi après `rollback`). Tout autre conflit : refus sans écriture.
- Data plane : les droits du cluster-agent sont rendus **avec** le chart (étape 7) ; l'ancienne étape 12 est sans
  effet. Complément `lab-pg` appliqué à l'étape 10.
- Prérequis fonctionnel : le CPT `cell-restricted` doit porter le RoleBinding de cellule (modèle dans le bundle) ;
  sans lui, les écritures du cluster-agent dans `dp-*` sont refusées (échec fermé, aucun élargissement).
- Vérification après déploiement : `tools/oke/verify.sh --step 6|6b|7|8|12` (release durcie, image épinglée,
  permissions effectives des ServiceAccounts du control plane et du cluster-agent).

## Rollback

`helm rollback` rejoue le manifest stocké **sans** post-renderer : interdit en direct sur ces releases. Utiliser
`tools/oke/security-bundle.sh rollback <release> <révision> [--apply]`, qui refuse toute révision dont
`helm get manifest --revision N` ne passe pas les invariants du bundle.

## Reconstruction

Procédure privée : README du dépôt privé (image arm64 du contrôleur, archive reproductible, release).

## Tests

`tests/security-bundle/run.sh` (faux bundles, `kubectl`/`helm` factices, sans cluster) : sans bundle, mauvaise
empreinte, chart incompatible, tag mutable, plugin manquant, rendu non durci, `--step`/`--from`, rollback non durci,
cas positifs. Bloc proposé pour le job CI `platform` (non appliqué ici) :

```yaml
      - name: Security bundle (tests de refus)
        run: tests/security-bundle/run.sh
```

## Plan de retrait

Quand le correctif amont est publié : passer aux charts et à l'image officiels corrigés (`versions.env`), remplacer
`helm_secure cp|dp` par `helm upgrade --install` simple dans `install.sh`, supprimer `security/`,
`tools/oke/security-bundle.sh`, `tests/security-bundle/` et cette page, puis archiver le dépôt privé.
