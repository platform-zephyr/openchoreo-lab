# Parcours de bout en bout : déployer, corriger

Deux boucles, une seule voie d'écriture : **Git**. Le cluster est lu, jamais écrit à la main : pas de `kubectl apply/edit/patch/delete/scale/rollout`, pas de MCP en écriture, pas de console OpenChoreo. Chaque étape a un point de contrôle (CP), une commande exacte et un critère de sortie. Les règles d'autonomie sont dans [`../.agents/skills/platform-guardrails/SKILL.md`](../.agents/skills/platform-guardrails/SKILL.md).

Variables utilisées partout :

```bash
export KUBECONFIG=<kubeconfig dédié au labo>   # jamais celui de Paul
export CLUSTER_LABEL=k3d KUBE_CONTEXT=k3d-openchoreo
APPGEN="python3 tools/appgen/appgen.py"
```

## 1. Déployer : intention → contrat → génération → PR → CI → merge → réconciliation → preuve

| CP | Étape | Commande | Critère de sortie | Trace |
|---|---|---|---|---|
| 0 | Intention → archétype + classe d'autonomie | lire `golden-paths/README.md` (règle de choix) et `platform-guardrails` | Archétype A, B, C (sinon D BLOCKED, E désactivé, F refus) ; classe `AUTONOME`, `REVUE` ou `INTERDIT` | corps de PR |
| 1 | Contrat | `cp golden-paths/<X>/app.yaml apps/<nom>/app.yaml`, puis éditer | Aucune valeur « À REMPLIR » ; digest réel (`docker buildx imagetools inspect <img>:<tag>`) ; `linux/arm64` présent | — |
| 2 | Validation | `$APPGEN validate` | `appgen validate : OK` | sortie dans la PR |
| 3 | Génération | `$APPGEN render && $APPGEN check` | `aucune derive` ; `git status` ne touche que `apps/<nom>/`, `generated/` et `pins/` | diff de PR |
| 4 | PR | `git switch -c app/<nom>-<verbe>` ; `git add apps/<nom> generated pins` ; `git commit -m "<nom>: <intention>"` ; `git push -u origin HEAD` ; `gh pr create --fill --body-file <corps>` | PR ouverte ; corps conforme au §4.3 | URL de PR |
| 5 | CI | `gh pr checks <PR> --watch --fail-fast` | tous les checks requis verts. Rouge : lire `gh run view <id> --log-failed`, corriger **dans la PR**, ne jamais contourner | — |
| 6 | Merge | classe `AUTONOME` **et** protection de branche active (`gh api repos/{owner}/{repo}/branches/main/protection --jq .required_status_checks.contexts`) : `gh pr merge <PR> --squash --delete-branch`. Sinon : `gh pr edit <PR> --add-label needs-paul`, puis arrêt | PR mergée, SHA `M` noté (`gh pr view <PR> --json mergeCommit --jq .mergeCommit.oid`) | SHA |
| 7 | Réconciliation | attendre (aucun déclenchement en écriture) : `kubectl --context $KUBE_CONTEXT get applications.argoproj.io -n argocd lab-o-<app> -o jsonpath='{.status.sync.revision} {.status.sync.status} {.status.health.status}'` toutes les 60 s, 10 min au plus | révision = `M`, `Synced Healthy` | — |
| 7b | **B seulement** : pin de la base (PR 2) | `kubectl … get resources.openchoreo.dev <nom>-db -n default -o jsonpath='{.status.latestRelease.name}'` ; `$APPGEN pin-resource <nom> <env> <release>` ; `$APPGEN render && $APPGEN check` ; puis CP 4 à 7 | RRB épinglée et `Ready` | 2ᵉ URL de PR |
| 8 | Preuve runtime | `golden-paths/_checks/run-all.sh <nom> <env> --evidence evidence/runtime` | `verdict: PASS`, ou `PARTIAL` dont chaque ligne BLOCKED ou NOT_TESTED est expliquée | fichier evidence + `gh pr comment <PR> --body-file <evidence>` |
| 9 | Échec → rollback | `git switch -c revert/<nom>-<M7> origin/main && git revert --no-edit <M>` ; PR ; CP 5 à 8 | après revert, la preuve retrouve l'état d'avant (comparer avec la dernière evidence PASS) | evidence du revert |

Règles de passage :

- **Pas de CP sauté.** CP 8 est obligatoire : une CI verte n'est pas une preuve, et `Ready=True` ne veut pas dire « fonctionne ».
- **Délais.** Sync Argo au-delà de 10 min, ou binding non `Ready` 10 min après la sync : passer à la boucle « corriger » (§2), sans attendre plus longtemps.
- **Revert d'abord.** Une régression sur une app qui marchait se règle par un revert autonome (CP 9), puis par un correctif en avant. Exception : si le revert touche une classe protégée (données), PR `needs-paul`.
- **Evidence archivée.** Commentaire de PR immédiat, et fichier sous `evidence/runtime/<cluster>/<app>/` versionné par la PR suivante (ou par une PR `evidence/<app>-<date>`, classe AUTONOME).

## 2. Corriger : incident → diagnostic → PR de correctif → vérification

| CP | Étape | Commande | Critère de sortie |
|---|---|---|---|
| I0 | Signal | FAIL d'un `_checks`, Argo `Degraded/OutOfSync`, signalement humain (alerte → agent : non câblé, capacité D1) | incident ouvert : app, env, cluster, heure UTC |
| I1 | Photo en lecture seule | `golden-paths/_checks/run-all.sh <app> <env> --evidence evidence/incidents` | evidence « avant » écrite |
| I2 | Diagnostic | skill `diagnose-app` : échelle Git → Argo → OpenChoreo → cellule → pod | **une** cause, avec la ligne de preuve qui la montre (message de condition, event, extrait de log sans secret) |
| I3 | Régression ? | `git log --oneline -5 -- apps/<app> generated/namespaces/default/projects/<app>` ; la dernière evidence PASS est-elle antérieure au dernier merge ? | si oui : CP 9 du §1 (revert) d'abord |
| I4 | Correctif dans Git | éditer `apps/<app>/app.yaml` (ou ouvrir une PR plateforme protégée) ; CP 2 à 6 du §1 | PR mergée (ou `needs-paul`) |
| I5 | Vérification | CP 7 et 8 du §1 | `verdict: PASS` ; les ID en échec à I1 passent en PASS |
| I6 | Clôture | fiche d'incident (§4.2) en commentaire de PR et sous `evidence/incidents/` | fiche complète |

Table de causes (symptôme lu → cause probable → correctif **dans Git**) :

| Symptôme (où le lire) | Cause probable | Correctif | Classe |
|---|---|---|---|
| CI rouge `appgen validate` | contrat invalide | corriger `app.yaml` | AUTONOME |
| Argo `ComparisonError` / `SyncFailed` | manifest rendu refusé (CRD, admission) | corriger `app.yaml`, ou revert | AUTONOME |
| ReleaseBinding `ResourceSyncFailed`, message « image épinglée par digest » / « exposition publique sans authentification » | preRender de la CCT | digest complet ; `auth ≠ none` | AUTONOME (public : REVUE) |
| Event `FailedCreate … violates PodSecurity` | l'image exige root ou une capability | `runtime.runAsUser`, `args` pour un port ≥ 1024 ; sinon F | AUTONOME |
| Event `FailedCreate … exceeded quota` | quota de cellule (G4) | PR plateforme (`tools/appgen` ou CPT) | REVUE |
| Pod `ImagePullBackOff` | digest faux, pas d'arm64, registre privé | corriger le digest ; registre privé = F | AUTONOME |
| `CrashLoopBackOff`, log « read-only file system » | écriture hors `/tmp` | variable d'env vers `/tmp`, ou archétype C | AUTONOME (C : voir classe) |
| `OOMKilled` | taille | `size: medium` | AUTONOME |
| ExternalSecret `SecretSyncedError` | clé absente du store | demander la création de la clé (nom seulement) | MANDAT |
| RRB sans `resourceRelease`, binding en attente | PR 2 non faite | `pin-resource` (CP 7b) | AUTONOME |
| Job `<app>-db-pg-init` en échec | lab-pg indisponible, mot de passe absent | lire P1 et P4 ; clé manquante = MANDAT | REVUE |
| Timeouts sortants dans les logs | `network.egress: none` | `egress: public-internet` ou `allowIdp: true` | REVUE |
| `Ready=True` mais 5xx ou mauvaise réponse | configuration applicative (env, BASE_URL) | corriger `runtime.env` | AUTONOME |

## 3. Ce que l'agent ne fait jamais pour aller plus vite

`kubectl apply/edit/patch/delete/scale/rollout restart/annotate/label`, `kubectl exec`, écriture MCP OpenChoreo, `argocd app sync` avec un jeton personnel, `gh pr merge --admin`, `git push --force` sur `main`, édition de `generated/` à la main, `autoDeploy: true`, désactivation d'une NP, de la PSA ou d'une VAP, lecture ou affichage d'une valeur de Secret. Liste complète : `platform-guardrails`.

## 4. Formats de preuve

### 4.1 Evidence runtime (`evidence golden-path v1`, produit par `_checks`)

```text
# evidence golden-path v1
date_utc: 2026-11-17T18:02:11Z
cluster: k3d                     # k3d | oke : jamais confondus
kube_context: k3d-openchoreo
git_head: 1a2b3c4                # HEAD local au moment du run
app: whoami
environment: production
archetype: A-stateless-http
---
## check-gitops.sh
PASS       G3     Component 'whoami' présent, autoDeploy=false
FAIL       W4     Deployment … disponible (ready/desired) (obtenu '0/1', attendu '1/1')
NOT_TESTED W8     GET /health via proxy API server impossible (…)
BLOCKED    G2     CRD applications.argoproj.io absente : Argo CD non installé (phase A3)
INFO       W11    événements Warning : 3 BackOff
---
summary: PASS=14 FAIL=1 NOT_TESTED=1 BLOCKED=1
verdict: FAIL                    # PASS | PARTIAL | FAIL
```

Chemin : `evidence/runtime/<cluster>/<app>/<YYYYMMDDTHHMMSSZ>-<env>.txt` (déploiement) ou `evidence/incidents/<cluster>/<app>/…` (incident). Aucune valeur secrète : les scripts ne lisent les Secrets qu'en `-o name`.

### 4.2 Fiche d'incident

```markdown
## Incident <app>/<env> <cluster> <date UTC>
- Signal : <check FAIL / Argo / humain> à <heure>
- Evidence avant : evidence/incidents/<…>.txt (verdict FAIL : W4, W9)
- Cause : <une phrase> ; preuve : <condition, event ou extrait de log sans secret>
- Régression : oui/non (dernier merge <sha>, dernière evidence PASS <fichier>)
- Action : revert PR #<n> | correctif PR #<n> | MANDAT demandé (<quoi>)
- Classe : AUTONOME | REVUE | MANDAT
- Evidence après : evidence/runtime/<…>.txt (verdict PASS)
- Durée signal → PASS : <min>
```

### 4.3 Corps de PR (déploiement ou correctif)

```markdown
## <app> : <intention en une ligne>
- Archétype : A | B | C | E ; classe : AUTONOME | REVUE (raison)
- Fichiers : apps/<app>/app.yaml, generated/…, pins/… (aucun autre)
- appgen validate / check : OK
- Prérequis hors Git : aucun | clés à créer : <NOMS seulement>
- Preuve attendue : golden-paths/<X>/CHECKLIST.md ; evidence en commentaire après merge
- Rollback : git revert <ce merge> (+ conséquence données si B/C)
```
