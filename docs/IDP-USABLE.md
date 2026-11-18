# IDP utilisable : chemin minimal agent -> application -> preuve -> rollback

**Statut : préparation, statique seulement.** Rien n'est exécuté sur OKE par ce document ni par la PR qui l'introduit.
Le pilote `whoami` (PR #23, rollback PR #24, drift fermé par #25) est déjà PASS sur OKE (`STATE.md` §1). Ce document
décrit ce qui reste pour qu'un agent demande une application sans manipulation de Kubernetes.

Règle de preuve : PASS = preuve runtime datée. k3d ≠ OKE. Statique ≠ runtime. NOT_TESTED / BLOCKED ne sont jamais des PASS.

## 1. Chemin minimal de bout en bout

| # | Étape | Ce qui existe déjà | Preuve attendue | Statut OKE |
|---|---|---|---|---|
| 1 | Intention (« déploie X ») | skill `add-app` : archétype A/B/C, image vérifiée par digest | digest `docker.io/…@sha256:` dans `apps/<nom>/app.yaml` | PASS (whoami) |
| 2 | Contrat | `tools/appgen` : `validate`, `render`, `check` (sans dérive) | sortie appgen, 0 dérive | statique PASS |
| 3 | Demande = PR | `gh pr create` (skill `add-app`) ; `tests/idp-demo/run.sh plan|pr` | URL de PR | PASS (whoami, #23) |
| 4 | CI | `ci.yaml` : yamllint, appgen, crd-schema, secrets, actionlint, platform (argo_guard, kubeconform), release-history, ci-ok | checks verts | PASS |
| 5 | Merge | `gh pr merge --squash` ; classe AUTONOME ou REVUE (`platform-guardrails` §1) | SHA de merge | REVUE pour `cluster: oke` : accord de Paul |
| 6 | GitOps | Argo CD `lab-o-<app>` (ApplicationSet `lab-o` ; révision = SHA du merge) | `status.sync.revision` | PASS (whoami) |
| 7 | Preuve runtime | `golden-paths/_checks/run-all.sh` (lecture seule, `CLUSTER_LABEL=oke`) | verdict PASS, digest W6, releaseName G4 | PASS (whoami) |
| 8 | Modification | PR sur `apps/<nom>/app.yaml` (ex. `size`, AUTONOME) | même chaîne 4 à 7 | PASS (whoami, WHOAMI_NAME) |
| 9 | Rollback | `git revert` du merge (PR), `release-history` gardée | revert merge + Argo + run-all PASS | PASS (whoami, #24) |
| 10 | Vue humaine | portail Backstage (étape 6b) | catalogue, login | **NON FAIT** (6b) |

Le chemin est écrit dans Git de bout en bout. Aucun agent n'écrit dans le cluster (`AGENTS.md`).

## 2. Les 3 trous réels

| Trou | Constat (vérifié) | Action concrète | Qui |
|---|---|---|---|
| **T1. Pas de canal de demande pour un agent** | Le portail ne crée rien (lecture du catalogue, pas de template) et l'API MCP n'a pas d'écriture pour les agents (voulu). Un agent ne peut donc demander une app qu'en ouvrant une PR, et aucun jeton GitHub dédié à cet usage n'est prévu aujourd'hui. | Créer un jeton GitHub fine-grained « PR-only » : `contents: write` et `pull_requests: write` sur `idp-demo/*`, `revert/*`, `app/*` ; pas de merge, pas d'admin, pas de `main`. L'agent lance alors `tests/idp-demo/run.sh plan` puis `pr`. | Paul (accès GitHub) |
| **T2. Une preuve runtime qu'un agent peut lire lui-même n'existe pas** | Aucun client de lecture OpenChoreo n'existe sur OKE : `openchoreo-agent-reader` n'est pas créé dans Authentik (kube-ops #1630 non fusionnée), et le MCP OKE répond 401 sans jeton. Les preuves ne sont produites que par le coordinateur. Authentik est le **homelab** (`auth.smadja.dev`, éteint la nuit) : tout jeton OKE dépend de ce créneau. | Paul crée `openchoreo-agent-reader` (blueprint kube-ops #1630 après fusion) et dépose le secret dans Doppler, nom seulement dans le chat. Jusque-là, le coordinateur exécute `observe` et colle la preuve dans la PR. | Paul (IdP), coordinateur |
| **T3. Le portail n'est pas en service et le rollback n'est prouvé que pour `whoami`** | 6b n'est pas faite (checklist §5). Sans portail, pas de vue humaine du catalogue ni du déploiement. Le golden path n'a été joué qu'une fois, sur `whoami`, et le résidu `B6-sa-effective` (SA kgateway, Secrets cluster-wide) reste ouvert. | Exécuter la checklist §5 (6b). Jouer `tests/idp-demo/run.sh` une fois sur OKE avec une app neuve (`idp-demo-echo`), puis le rollback, et joindre les preuves à la PR. Ne pas construire de template Backstage avant ce PASS. | Coordinateur, après §5 |

## 3. Démonstration « initiée via la plateforme » : `tests/idp-demo/run.sh`

Script préparé ici. Garde-fous : `DRY_RUN=1` par défaut (aucun push, PR ni merge) ; cluster en lecture seule
(`get` et `run-all.sh` seulement, contexte explicite `context-oracle-a1-*` ou `k3d-openchoreo`, pas de `port-forward`
ni de lecture de Secret) ; merge refusé sans `CONFIRM_MERGE_PR=<n>` (accord de Paul) ; preuves hors dépôt
(`$XDG_STATE_HOME/openchoreo-lab/idp-demo/…`). Testé en local : `plan`, `resize`, `pr` (dry-run), refus de contexte,
refus de merge sans confirmation, refus d'image sans digest. Non testé : tout ce qui pousse ou lit OKE.

Preuves attendues (`summary.txt`, une ligne par étape) :

| ID | Preuve | PASS si |
|---|---|---|
| PLAN-INTENT, APPGEN-plan | gabarit `whoami` rempli, digest conservé, appgen validate/render/check | 0 dérive |
| PR, CI | URL de PR, `gh pr checks` | tous les checks requis verts |
| MERGE | SHA de merge, CONFIRM_MERGE_PR | accord de Paul tracé |
| ARGO-SYNC | `lab-o-<app>` révision = SHA | révision égale en moins de 10 min |
| RUNTIME | verdict `run-all.sh` (G4, W6, Ready, HTTP) | `PASS` (PARTIAL = à expliquer) |
| RESIZE, APPGEN-resize, PR/CI/MERGE/ARGO-SYNC/RUNTIME | modification `size: medium` | `PASS` |
| REVERT, ARGO-SYNC, RUNTIME | `git revert` du merge de `resize`, retour à `small` | `PASS` avec `size` d'origine |

Commandes du coordinateur, dans l'ordre (chaque ligne est une étape séparée ; `<n>` et `<sha>` viennent de la sortie précédente) :

```bash
export KUBE_CONTEXT=<contexte oke, kubectl config get-contexts> CLUSTER_LABEL=oke
IMG=docker.io/traefik/whoami:v1.10.3@sha256:43a68d10b9dfcfc3ffbfe4dd42100dc9aeaf29b3a5636c856337a5940f1b4f1c
tests/idp-demo/run.sh plan idp-demo-echo "$IMG"              # local, DRY_RUN=1 par défaut
DRY_RUN=0 tests/idp-demo/run.sh pr idp-demo-echo "creation (demo IDP)"
DRY_RUN=0 CONFIRM_MERGE_PR=<n> tests/idp-demo/run.sh merge <n>   # seulement après accord de Paul
tests/idp-demo/run.sh observe idp-demo-echo <sha>            # lecture seule
DRY_RUN=0 tests/idp-demo/run.sh resize idp-demo-echo medium && DRY_RUN=0 tests/idp-demo/run.sh pr idp-demo-echo "size medium"
DRY_RUN=0 CONFIRM_MERGE_PR=<n2> tests/idp-demo/run.sh merge <n2>
tests/idp-demo/run.sh observe idp-demo-echo <sha2>
DRY_RUN=0 tests/idp-demo/run.sh revert idp-demo-echo <sha2>  # PR de rollback
DRY_RUN=0 CONFIRM_MERGE_PR=<n3> tests/idp-demo/run.sh merge <n3>
tests/idp-demo/run.sh observe idp-demo-echo <sha3>
```

Le `plan` et le `resize` ne créent pas de branche sur `main`. L'app `idp-demo-echo` est une app neuve : la retirer
ensuite relève de REVUE (suppression) et n'est pas faite par ce script.

## 4. Rôles des agents (mappés sur `platform/authz/`)

Principe : aucune écriture directe dans le cluster pour un agent. Un changement durable est une PR.

| Rôle | Identité | Droits OpenChoreo (`platform/authz/`) | Écrit où | Statut |
|---|---|---|---|---|
| **Lecture** (agent : Claude, Codex) | client `openchoreo-agent-reader` (claim `client_id`) | `lab-agent-reader` (lecture, sans secret ni authz) + deny `lab-agent-forbidden` | rien | manifeste testé k3d (50 PASS) ; client Authentik **non créé** (#1630 non fusionnée) ; aucun jeton |
| **PR-only** (agent : add-app, fix-app, promote-or-rollback) | jeton GitHub fine-grained (T1) | aucun droit OpenChoreo | `apps/<nom>/`, `generated/`, `pins/`, `evidence/` par PR | à créer (Paul) |
| **Opérateur runtime** (mandat seulement, jamais par défaut) | client `openchoreo-agent-operator` | `lab-agent-reader` + `lab-agent-operator` (`releasebinding:create/update`, `componentrelease:create`) bornés CEL à development/staging + deny | écriture MCP **hors Git**, éphémère (`AGENT-ACCESS.md` §2) | manifeste présent ; client **non créé** ; décision Paul : ne pas créer tant qu'il n'y a pas de mandat |
| **Humain viewer** | groupe `openchoreo-viewers` | `lab-viewer` (lecture ; `logs:view` inclus, la doc IDENTITY disait « sans journaux » : à trancher) | rien | manifeste ; test H1-H7 k3d |
| **Humain développeur** | groupe `openchoreo-developers` | `developer` (chart), **cluster-wide** ; inclut `resource:read-secrets` et `component:exec` | composants, workloads, bindings | **décision Paul** : limiter à `default` (portée à valider sur v1.3.3, non testée) |
| **Admin humain** | groupe `authentik-admins` | `lab-platform-admin` (`*`) | tout | manifeste ; humain uniquement |
| **Coordinateur** | accès bastion (Paul, TTL 3 h) | `install.sh`, `verify.sh`, `uninstall.sh` (hors agents) | OKE, par étapes | seul exécutant d'écritures |

Vérifications statiques de `platform/authz/` faites dans cette PR : cohérence des rôles et bindings (7 bindings, 5 rôles,
aucun chevauchement entre allow des agents et actions deny) ; `argo_guard` 0 écart ; kubeconform `-strict` 12 ressources
valides (CRD du chart CP 1.3.3). Corrections minimales faites : `kubeconform-platform.sh` valide désormais `platform/authz/`
(il ne le faisait pas) ; `docs/IDENTITY.md` §4 et `docs/PORTAL.md` §3 réalignés sur les noms réels (`lab-agent-reader`,
`lab-agent-operator`, `lab-platform-admin`, pas de `cluster-reader`).

## 5. Checklist étape 6b (portail privé, port-forward, sans exposition)

Prérequis déjà vérifiés statiquement : values (`platform/install/values/openchoreo-control-plane.yaml`, `backstage.enabled: true`,
requests 10m/320Mi), egress `03-idp-egress.yaml`, quota CP 640Mi/2304Mi (`01-quotas.yaml`), `security/bundle.lock` en 1.0.1
(charts 1.3.3 compatibles), `tests/security-bundle/run.sh` 23 PASS, `verify.sh --step 6b` (B6b-*). Rien d'autre n'est vérifiable hors cluster.

**Paul, une action par ligne :**

1. Décider la fusion de kube-ops #1630 (blueprints Authentik OpenChoreo), ou créer les providers à la main (`docs/IDENTITY.md` §5).
2. Authentik : provider `openchoreo-backstage-client`, `issuer_mode: global`, redirect `http://localhost:7007/api/auth/openchoreo-auth/handler/frame`, scopes `openid profile email offline_access openchoreo`.
3. Authentik : provider `openchoreo-backstage-service`, `client_credentials`, scope `openchoreo-client-id` avec `client_id` fixe `openchoreo-backstage-service`.
4. Authentik : lier l'application aux groupes `openchoreo-viewers`, `openchoreo-developers`, `authentik-admins`.
5. Ajouter votre compte de test au groupe `openchoreo-viewers` (pour P3, login).
6. Déposer les deux secrets dans Doppler sous les noms `AUTHENTIK_BACKSTAGE_CLIENT_SECRET` et `AUTHENTIK_BACKSTAGE_SERVICE_SECRET` (valeurs jamais dans le chat).
7. Donner au coordinateur l'accès `gh` au dépôt privé du bundle, ou le chemin local de `security-bundle-1.0.1.tar.gz` (`OPENCHOREO_SECURITY_BUNDLE`).
8. Ouvrir une session bastion (TTL 3 h) pour la durée de l'étape.
9. Accepter le coût : +320 Mi de request pour le portail (budget : pile ≤ 1,5 Gi, requests ≤ 70 %).
10. Décider le périmètre `openchoreo-developers` (§4) et la présence de `lab-agent-operator` (§4) avant tout client Authentik agent.
11. Faire le test navigateur P2, P3 et P5 (`docs/PORTAL.md` §6) : seul vous pouvez le jouer.
12. Accepter ou traiter le résidu `B6-sa-effective` (SA kgateway, Secrets cluster-wide) avant d'appliquer le CP une seconde fois.

**Coordinateur, dans l'ordre (chaque ligne est une étape, dry-run par défaut) :**

```bash
tools/oke/security-bundle.sh status                             # bundle 1.0.1 : empreinte et compatibilité (sans cluster)
tools/oke/install.sh --step 1 --apply && tools/oke/verify.sh --step 1   # quota CP 640Mi/2304Mi
# Secret backstage-secrets : commande de docs/PORTAL.md §4, valeurs lues depuis Doppler (jamais affichées)
tools/oke/install.sh --step 6b                                  # dry-run : quota, 4 clés, bundle
tools/oke/install.sh --step 6b --apply
tools/oke/verify.sh --step 6b                                   # B6b-deploy, -restarts, -psa, -noexpose, -login
# Rollback si un critère d'arrêt (docs/PORTAL.md §4) :
tools/oke/uninstall.sh --step 6b --apply
```

## 6. Limites

- Tout ce document est statique : aucune commande ci-dessus n'a été jouée par cette PR.
- Le login OIDC dépend d'Authentik sur le homelab (éteint la nuit) : 6b et la démonstration se jouent pendant ce créneau.
- L'audit d'une écriture MCP ne donne ni le sujet ni la décision sans observability plane (`AGENT-ACCESS.md` §6).
- Le portail est mono-réplica, SQLite éphémère, catalogue synchronisé toutes les 120 s (`docs/PORTAL.md` §7).
