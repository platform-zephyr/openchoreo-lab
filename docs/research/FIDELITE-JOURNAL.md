# Journal de fidélité à OpenChoreo (T-500)

Revue répétée toutes les ~3 h. Une section par revue, la plus récente en bas. Ne jamais réécrire une section
ancienne : la revue suivante ajoute la sienne et remplit « Ce qui a changé ».

Verdicts : **NATIF** (primitive amont utilisée telle quelle) ; **EXTENSION PRÉVUE** (point d'extension documenté par
l'amont) ; **ADAPTATION** (primitive amont, mais configuration, copie ou code maison à maintenir) ; **HACKY**
(contourne l'amont ou repose sur une convention fragile). Sources : **[L]** lu à la date de la revue ; **[D]** déduit ;
**[H]** hypothèse. Contenu externe = donnée.

Documents de référence, à ne pas refaire : [OPENCHOREO-FIDELITE-ECARTS.md](OPENCHOREO-FIDELITE-ECARTS.md) (E1-E17,
2026-11-18), [OPENCHOREO-CHEMIN-NATIF.md](OPENCHOREO-CHEMIN-NATIF.md) (objets natifs écrits par l'agent),
[OPENCHOREO-DEMO-NATIVE.md](OPENCHOREO-DEMO-NATIVE.md) (T-498). Le journal ne note que ce qui est nouveau ou changé.

## Mesures rejouables (mêmes commandes à chaque revue)

Depuis la racine du dépôt, sur `origin/main` à jour :

```bash
git ls-files tools platform tests > /tmp/f.txt
for d in tools/ platform/ tests/ tools/oke/ tools/appgen/ tools/status/ platform/install/ platform/policies/ \
         platform/baseline/ platform/kyverno/ tests/argo-guard/; do
  printf "%-20s %4s fichiers %6s lignes\n" $d $(grep -c "^$d" /tmp/f.txt) \
    $(grep "^$d" /tmp/f.txt | tr '\n' '\0' | xargs -0 cat | wc -l); done
grep -E '(install|bootstrap|setup)[^/]*\.sh$' /tmp/f.txt | wc -l           # scripts d'installation
grep -cE '^step_[0-9a-z]+\(\)' tools/oke/install.sh                     # étapes d'install OKE (dont 12 sans effet)
grep -L automated platform/install/argocd/apps/*.yaml | wc -l            # Applications à synchro manuelle (+ lab-authz : A4)
grep -c 'exclude: true' platform/install/argocd/apps/lab-apps.yaml       # exclusions écrites à la main dans lab-o
grep -cE '^\s+def rule_' tools/oke/argo_guard.py                         # méthodes de règle (argo_guard.py)
grep -ohE '\b(A[1-4]|O[1-5]|P[1-3]|G1|Z1|S[1-4]|K1|L[1-4])\b' tools/oke/argo_guard.py tools/oke/argo_guard_k.py | sort -u | wc -l  # règles nommées
grep -lE '^status: (todo|in-progress|blocked)' backlog/T-*.md | wc -l    # tickets ouverts (en-tête, pas le statut dérivé)
```

---

## Revue n°1 — 2026-11-19T01:34Z (base de départ)

- **Plage** : `origin/main` de `79a63e0` (#134, T-217) à `7125bf6` (#167, T-499, fusionnée pendant la revue).
  Branche lue hors `main` : `origin/claude/t-060-kgateway-rbac` (`053090c`). Niveau : `STATIC` ; aucun accès cluster.
- **Relecteur** : agent Claude (T-500). Durée : ~40 min.

### Conclusion d'abord

1. **Rien de nouveau n'est HACKY au sens fort** : chaque ajout de #134 à #167 utilise une primitive amont (VAP
   Kubernetes, AppProject, ApplicationSet, Argo CD Notifications, fournisseur ESO `kubernetes`, option `rbac.create`
   de kgateway). Le cœur OpenChoreo n'est pas forké.
2. **Le coût est dans les couches maison autour des primitives**, pas dans les primitives : `argo_guard*` (730 l. +
   1 856 l. de tests, 23 règles nommées) ; `tools/oke/install.sh` (14 étapes, `tools/oke/` = 3 014 l.) ; 3 Applications
   à synchro manuelle ; une liste d'exclusions écrite à la main dans l'ApplicationSet `lab-o`.
3. **Deux écarts simples à l'amont, peu coûteux à fermer** : le store ESO s'appelle `lab-store` alors que la doc
   OpenChoreo demande un `ClusterSecretStore` nommé `default` ; le lecteur `tools/status/app_status.py` (357 l.)
   refait ce qu'un `gh api …/check-runs` donne en une ligne.
4. **Un vrai point HACKY** : l'ApplicationSet `lab-o` sélectionne les apps OKE par 6 exclusions écrites à la main,
   tenues correctes par une règle de lint (O5). Le choix de cluster devrait vivre dans le chemin généré.

### Tableau des composants

| Composant | Ce que nous faisons | Équivalent amont | Verdict | Coût d'exploitation | Simplification |
|---|---|---|---|---|---|
| VAP cellule (`platform/policies/`, #134 T-217) : `vap-cell-default-deny`, `-pod-hardening`, `-cluster-agent-scope` | 3 VAP CEL refusent un Pod dans une cellule `dp-*` sans NetworkPolicy default-deny, durcissent le pod, bornent le cluster-agent | `ValidatingAdmissionPolicy` Kubernetes GA [D] ; OpenChoreo ne livre aucune couche d'admission (ECARTS E6) [L] | **EXTENSION PRÉVUE** (Kubernetes) | 3 fichiers, 351 l. ; doublon partiel avec le `postRender` du CCT et Kyverno sur k3d (E6, non mesuré) | Mesurer le doublon (ECARTS reco 6) ; sur OKE (sans Kyverno) les VAP sont la seule garde : garder |
| Socle étape 0 (#145 T-494) : Cilium en chaînage `cni.chainingTarget=oci` + `platform/baseline/` (3 VAP + CCNP deny-IMDS) | `install.sh --step 0` ; valeurs et VAP **copiées sans modification** de kube-ops, contrôlées par `baseline-source.sh` | Chart Cilium officiel [L, `versions.env`] ; page Cilium « chaînage OKE » citée par kube-ops, **non relue** (404 sur le chemin supposé) [H] | **ADAPTATION** | 223 l. de VAP copiées + script de dérive ; 1 étape d'install hors Argo (Argo l'adopte à l'étape 11) | Garder ; la copie verbatim + contrôle de dérive est la bonne forme sans toucher kube-ops |
| `tools/oke/install.sh` (étapes 0-11, 6b, 12 sans effet) | Rejoue la procédure Helm amont avec gardes, quotas, pins sha256 | Procédure Helm + `kubectl apply` de la doc v1.3.x (ECARTS E7) [L] | **ADAPTATION** (inchangé, +1 étape) | `tools/oke/` 13 fichiers, 3 014 l. ; 14 `step_*`, chacune suivie de `verify.sh --step N` | Retirer `step_12` (sans effet) ; voir proposition 2 |
| `argo_guard.py` + `argo_guard_k.py` + `tests/argo-guard/` | Lint CI de 23 règles (A, O, P, G, Z, S, K, L) « là où l'AppProject ne peut pas agir » | AppProject (`sourceRepos`, `destinations`, whitelists, `syncWindows`) [D] | **ADAPTATION** (code maison au-dessus d'une primitive) | 730 l. + 1 856 l. de tests ; chaque nouvel AppProject ou Application ajoute des règles (L1-L4 pour `lab-k`) | Ne plus ajouter de règle qui duplique un champ d'AppProject ; voir proposition 2 |
| AppProject `lab-k` / `lab-k-root` (#160 T-495) | Frontière du bras K du banc ; racine à synchro manuelle | AppProject Argo CD [D] | **NATIF** | 1 Application de plus à synchroniser à la main ; règles L1-L4 | Aucune tant que le banc vit ; à retirer avec le banc |
| ApplicationSet `lab-o` (#129, #158) | Générateur git `directories` sur `generated/namespaces/default/projects/*` | ApplicationSet + générateur Git [D] ; OpenChoreo laisse l'outil GitOps libre (ECARTS E10) [L] | **NATIF** pour l'objet ; **HACKY** pour la sélection | 6 `exclude: true` écrits à la main (10 projets générés, 4 retenus), tenus par la règle O5 | `appgen` écrit les apps OKE sous un chemin propre au cluster ; le générateur vise ce chemin ; O5 et la liste disparaissent |
| Argo CD Notifications → check run GitHub (#159 T-489) | Gabarits `checkRun` par app et révision, jeton via ESO | Service `github` de notifications-engine, champ `checkRun` [L] | **NATIF** | 3 fichiers, 181 l. ; une App GitHub (MANDAT déjà fait) | Aucune |
| `tools/status/app_status.py` (#165 T-497) | Client anonyme : cache, limite de débit, schéma JSON `app-checkrun.v1` | `gh api repos/<o>/<r>/commits/<sha>/check-runs?check_name=argocd/<app>` [D] | **ADAPTATION** (surdimensionné) | 357 l. de Python + tests + skill `read-app-status` | Réduire à un appel `gh api … --jq` dans le skill ; garder le schéma si un agent le consomme |
| `platform/cloudflared/` (#162 T-006) | Connecteur sortant, routage distant (`/mcp` seul), egress borné ; copie MIT de kube-ops | Tunnel Cloudflare géré à distance, Deployment `cloudflared` documenté par Cloudflare [D] | **NATIF** | 3 fichiers, 139 l. ; config distante hors dépôt (homelab-infra) | Aucune |
| Store ESO `lab-store`, fournisseur `kubernetes` + capacité `secretStoreProvider` (#167 T-499) | `remoteRef.key` = Secret du coffre (`SEARXNG_SECRET` → `searxng-secret`), `property` = clé du contrat | Fournisseur ESO `kubernetes` : `key` = Secret, `property` = clé [L] ; doc OpenChoreo : un `ClusterSecretStore` **nommé `default`**, « changer de backend = remplacer une ressource » [L] | **ADAPTATION** | Nom non standard (`lab-store`) propagé dans `ClusterDataPlane.spec.secretStoreRef`, capacités, CCT ; convention de nom maison (`vault_secret_name`) ; +42 l. dans `appgen` | Renommer le store en `default` ; la capacité `secretStoreProvider` devient la seule chose qui varie |
| kgateway `rbac.create=false` + `05-kgateway-rbac.yaml` (branche T-060, non fusionnée) | Monte kgateway v2.3.11 → v2.4.8 ; ClusterRole copié du chart, seul écart : pas d'écriture des Secrets cluster-wide | Valeur `rbac.create` présente en v2.4.8 [L], **absente** en v2.3.11 [L] ; doc OpenChoreo v1.3.x cite v2.3.11 (ECARTS E1-E2) [L] | **ADAPTATION** | 119 l. de RBAC à regénérer à chaque montée de kgateway + `kgateway_rbac_check.py` 100 l. + étapes verify ; sortie de la version citée par OpenChoreo | Fusionner seulement si Paul exige le retrait de l'écriture cluster-wide ; sinon garder le RBAC du chart (résidu accepté, comme Cilium dans kube-ops) |
| `tools/appgen/` (releases, pins, `autoDeploy: false`) | Inchangé sur le fond (ECARTS E3, E9) ; +42 l. pour T-499 | `occ componentrelease generate` / `occ releasebinding generate` en mode file-system (CHEMIN-NATIF §1.2) [L] | **ADAPTATION** (inchangé) | `tools/appgen/` 23 fichiers, 2 287 l. | Décision de Paul attendue (ECARTS reco 4, DEMO-NATIVE §5) ; non répétée ici |
| `clusters/*/capabilities.yaml` | Fichier de politique par cluster, lu par `appgen` seulement (`kind: ClusterCapabilities`, jamais appliqué) | Pas d'équivalent unique : `ClusterDataPlane` (store, passerelle) et `Environment` portent une partie [D] | **ADAPTATION** | 3 fichiers + schéma ; `oke` déclare `identityProviders: [thunderid]` alors que ThunderID est retirable (DEMO-NATIVE §3) [L] | Garder (évite d'écrire au cluster) ; ne pas y dupliquer ce que `ClusterDataPlane` porte déjà (nom du store) |

### Mesures (base de départ, `7125bf6`)

| Mesure | Valeur |
|---|---|
| `tools/` | 87 fichiers, 15 577 l. |
| `platform/` | 73 fichiers, 6 809 l. |
| `tests/` | 720 fichiers, 42 475 l. |
| dont `tools/oke/` · `tools/appgen/` · `tools/status/` | 3 014 · 2 287 · 357 l. |
| dont `platform/install/` · `policies/` · `baseline/` · `kyverno/` | 2 831 · 351 · 223 · 1 122 l. |
| dont `tests/argo-guard/` | 1 856 l. |
| Scripts d'installation (`install`, `bootstrap` ou `setup` dans le nom, `.sh`) | 8 (dont 4 de tests) |
| Étapes d'install OKE (`step_*`) | 14 (0-11, 6b, 12 sans effet), chacune suivie d'un `verify.sh --step N` |
| Applications à synchro manuelle | 3 (`lab-platform`, `lab-authz`, `lab-k-root`) |
| Exclusions manuelles dans `lab-o` | 6 |
| Règles `argo_guard` | 23 nommées ; 22 méthodes `rule_*` dans `argo_guard.py` |
| Tickets ouverts (en-tête `todo`/`in-progress`/`blocked`) | 163 (128 / 30 / 5) |

### Propositions (≤ 3, par gain d'opérabilité)

1. **Sélection des apps OKE par chemin généré, pas par exclusions** (S). `appgen` écrit déjà le cluster de chaque app :
   il range les apps OKE sous un chemin propre (ex. `generated/clusters/oke/…`) et le générateur `directories` vise ce
   chemin. Gain : 6 lignes manuelles et la règle O5 disparaissent ; ajouter une app ne touche plus l'ApplicationSet.
   *Coût de ne pas le faire* : chaque app non OKE ajoutée exige une ligne `exclude` dans un fichier de la frontière
   Argo, et un oubli n'est rattrapé que par le lint.
2. **Geler `argo_guard` et `install.sh` à leur taille actuelle** (S, règle d'équipe). Toute nouvelle garde passe
   d'abord par un champ d'AppProject (`destinations`, whitelists, `syncWindows`) ou une VAP ; une règle Python
   seulement si aucun champ amont n'existe, avec la raison dans la PR. Supprimer `step_12`. *Coût de ne pas le
   faire* : `argo_guard` a gagné 4 règles (L1-L4) pour un seul AppProject ; la courbe suit le nombre de projets.
3. **Renommer le store ESO en `default`** (S, fenêtre de réinstall OKE). Alignement exact sur la doc OpenChoreo ;
   `ClusterDataPlane.spec.secretStoreRef` et les capacités n'ont plus de nom maison. *Coût de ne pas le faire* : faible
   mais permanent ; chaque guide amont (OpenBao, migration de backend) doit être traduit.

### Questions à Paul (recommandation en tête, « oui » suffit)

1. **Recommandé : oui.** Remplacer les 6 `exclude` de l'ApplicationSet `lab-o` par un chemin généré par cluster
   (proposition 1) ? Fichier : `platform/install/argocd/apps/lab-apps.yaml` l. 28-34.
2. **Recommandé : oui.** Le droit de **lecture** cluster-wide des Secrets par kgateway est-il un résidu accepté
   (comme Cilium dans kube-ops), ce qui rend inutile la branche `claude/t-060-kgateway-rbac` (119 l. de RBAC à
   regénérer à chaque montée, sortie de kgateway v2.3.11 cité par OpenChoreo) ? Si « non », la branche est la bonne
   forme (option amont `rbac.create`), à fusionner après preuve k3d du listener HTTPS.
3. **Recommandé : oui.** Renommer `lab-store` en `default` à la prochaine réinstallation OKE (proposition 3) ? Source :
   [secret-management.mdx l. 110-112](https://github.com/openchoreo/openchoreo.github.io/blob/147f5730ed8727a9918abb30a5f9d1107be14a2c/versioned_docs/version-v1.3.x/platform-engineer-guide/secret-management.mdx).
4. **Recommandé : oui.** Réduire `tools/status/app_status.py` à un appel `gh api` documenté dans le skill
   `read-app-status` ?

Questions ouvertes non répétées : DEMO-NATIVE §5 (5 questions) et ECARTS reco 1, 2, 4, 8.

### Sources primaires lues

- OpenChoreo v1.3.3 : tag `v1.3.3` = objet `4b6b5351f9c67500a0b00cd4b981f1fe04653ae5` (ls-remote) [L] ; doc v1.3.x
  [secret-management.mdx@147f573](https://github.com/openchoreo/openchoreo.github.io/blob/147f5730ed8727a9918abb30a5f9d1107be14a2c/versioned_docs/version-v1.3.x/platform-engineer-guide/secret-management.mdx) [L].
- ESO, fournisseur kubernetes : [kubernetes.md@f156b25](https://github.com/external-secrets/external-secrets/blob/f156b25a9585dfbf8daedd4888354c997d420f6f/docs/provider/kubernetes.md) [L].
- kgateway : [values.yaml v2.4.8 l. 13-15](https://github.com/kgateway-dev/kgateway/blob/c7c897cb28310b336574a1171f8e750f30daa265/install/helm/kgateway/values.yaml#L13-L15) (`rbac.create`) [L] ;
  [values.yaml v2.3.11](https://github.com/kgateway-dev/kgateway/blob/c2af2887b3c54cb00cb999711c2200cbb892fc60/install/helm/kgateway/values.yaml) (aucune clé `rbac`) [L].
- Argo CD Notifications : [github.go@adb8572](https://github.com/argoproj/notifications-engine/blob/adb8572f32ba5a8f411afb87bfeb6c5fb4d1258b/pkg/services/github.go) (`CheckRun`, l. 44-65) [L].
- Non lus (marqués [D] ou [H]) : doc Argo CD ApplicationSet/AppProject, doc Cilium du chaînage OKE, doc Cloudflare
  du tunnel, doc Kubernetes VAP. API GitHub du dépôt amont refusée par la session ; lecture par `raw.githubusercontent.com`.

### Ce qui a changé depuis la revue précédente

Sans objet (revue n°1, base de départ). Faits notables depuis ECARTS (2026-11-18) : E2 a une nouvelle forme
(branche `t-060-kgateway-rbac`, option amont au lieu d'un post-traitement) ; E13 a gagné la capacité
`secretStoreProvider` ; E10 a gagné Notifications, `lab-k` et 4 règles de garde. La branche `claude/t-060-kgateway-sa`
(réfutée par ECARTS reco 1) existe encore sur `origin`.

---

## Revue n°2 — 2026-11-19T10:43Z

- **Plage** : `git log 0fc7412..origin/main` = 12 commits, de `61f359f` (#172, T-501) à `8caf810` (#183, T-516). Hors
  `generated/` et `backlog/` : 50 fichiers, +1 415 / −952 lignes. Niveau : `STATIC` ; aucun accès cluster. kube-ops lu
  en local, en lecture seule (`main`) ; `bench-ab-arm-k` est absent en local et n'a pas été relu (ses lignes sont citées
  d'après `tests/bench-ab/arm-k/`).
- **Relecteur** : agent Claude, à la demande de Paul (« l'implémentation correspond-elle à une implémentation prévue
  par OpenChoreo, ou est-elle hacky ? la complexité doit être justifiée »).
- **Échelle demandée** : **natif** (= NATIF), **justifié** (= EXTENSION PRÉVUE, ou ADAPTATION dont le coût est
  justifié), **hacky** (= HACKY). Le verdict de la grille d'origine est donné entre parenthèses.

### Conclusion d'abord

1. **Aucun ajout de la plage n'est hacky.** Le seul HACKY de la revue n°1 est fermé : `lab-o` lit une liste par le
   générateur Git `files` natif d'Argo CD (6 `exclude` → 0). `tools/status/app_status.py` (357 l.) est supprimé au
   profit d'un appel `gh api`. Le code net a baissé : `tools/` −283 l. ; `argo_guard*` reste à 730 l.
2. **Le principal ajout de complexité est documentaire, pas technique.** L'orchestration (T-509, T-516) pèse désormais
   603 l. sur 6 fichiers, dont 3 décrivent le même rôle : `docs/ORCHESTRATION.md` (197 l.), le skill
   `orchestrate-backlog` (83 l.) et `docs/state/HANDOFF-COORDINATEUR.md` (90 l.). Une contradiction est déjà apparue
   (voir le tableau). Rien de cela ne touche OpenChoreo : la complexité est justifiée par le mode de travail, à
   condition d'élaguer.
3. **Un constat de T-504 est inexact.** L'écart E1 (« echo-bench sort du namespace de son AppProject ; Argo refuse la
   synchro ») cite l'AppProject du bac à sable, qui n'est **jamais appliqué**. L'AppProject qui gouverne (`lab-k`,
   `platform/install/argocd/project-lab.yaml` l. 202-236) admet déjà `svc-*`, donc E1 ne bloque pas. En revanche,
   `svc-*` sort du périmètre cluster d'`AGENTS.md` (`openchoreo-*`, `lab-*`) et cette exception n'est tracée ni dans
   `missions/` ni dans `docs/adr/` : Paul doit la confirmer.
4. **Résidu de T-502** : la liste `clusters/oke/lab-o-apps.yaml` répète le `cluster: oke` déjà écrit dans
   `apps/<app>/app.yaml` (ses 4 entrées sont exactement les 4 apps `cluster: oke`). La forme est native ; la double
   saisie est le coût qui reste.

### Tableau par élément

| Élément (commit) | Ce qui est fait | Équivalent amont | Verdict | Preuve | Complexité justifiée ? |
|---|---|---|---|---|---|
| T-502 (#174) : `lab-o` par liste | `git.files: [{path: clusters/oke/lab-o-apps.yaml}]` ; un tableau `- app: <nom>` rend un jeu de paramètres par élément ; plus aucun `exclude` | Générateur Git `files` d'Argo CD : un fichier qui n'est pas un objet est relu comme tableau, un jeu de paramètres par élément [L, `applicationset/generators/repo_path_utils.go` l. 173-191 @ `1942154`] | **natif** (NATIF) | `grep -c 'exclude: true' platform/install/argocd/apps/lab-apps.yaml` → 0 ; `wc -l tools/oke/argo_guard.py tools/oke/argo_guard_k.py` → 730 (inchangé) | Oui. O5 est réécrite pour valider la liste au lieu des exclusions, sans croissance du code ; +105 l. de tests (`tests/argo-guard/` 1 856 → 1 961). Résidu : la double saisie (point 4). La piste « `appgen` écrit la liste » est notée dans le ticket, mais pas réalisée |
| T-507 (#176) : lecteur de statut | `tools/status/app_status.py`, ses 7 fixtures et son test sont supprimés (−803 l.) ; le skill `read-app-status` se réduit à une garde `grep` et un `gh api … --jq` | API REST GitHub `check-runs` [D] | **natif** (NATIF) | `git show --stat 500db94` ; `tools/status/` → 0 fichier | Oui (simplification). Texte à corriger : le skill annonce « aucun identifiant » et « 60 requêtes/heure sans jeton », alors que `gh api` exige une session `gh` authentifiée [D]. Écrire « jeton `gh` en lecture » ou donner l'équivalent `curl` anonyme |
| T-505 (#173) : CRD Cilium de la suite k3d `argo-escalation` | 2 CRD écrites à la main, avec un schéma `x-kubernetes-preserve-unknown-fields` ; garde `cilium_crds_check` et auto-test négatif dans `run.sh` (+27 l.) | Les CRD Cilium existent en amont dans `pkg/k8s/apis/cilium.io/client/crds/v2/` au tag `v1.20.4` [L] ; le chart ne les livre pas : l'opérateur les crée (`operator.skipCRDCreation`, `values.yaml` l. 3457) [L] | **justifié** (ADAPTATION, fixture de test) | `tests/argo-escalation/cilium-crds.yaml` ; `run.sh` l. 55-80 et 99-101 | Oui : installer l'opérateur Cilium dans k3d coûterait plus cher. Le commentaire « même principe que les CRD CNPG » est inexact : `run.sh` prend les CRD CNPG et OpenChoreo de l'amont épinglé (`helm template`, sparse-checkout au commit), alors que les CRD Cilium sont réécrites. Forme amont possible au même coût : récupérer les 2 fichiers du tag `v1.20.4` (version déjà épinglée dans `versions.env`) avec leur sha256. La garde de 27 l. resterait utile |
| T-504 (#171) : revue de fidélité du bras K | `tests/bench-ab/arm-k/FIDELITY-REVIEW.md` : 10 écarts, dont 3 bloquants | — (document) | **justifié** (document), **mais E1 est faux** | kube-ops : `svc-{{ .Values.metadata.name }}` est codé en dur dans `k8s/charts/platform-app/templates/namespace.yaml` l. 7 [L] (ce constat est exact). Ce dépôt : `lab-k-root` n'inclut que `{apps-generated-applicationset.yaml,applications-applicationset.yaml}`, et `lab-k` admet `svc-*` (`project-lab.yaml` l. 202-236) [L] | E2, E3 et E4 sont vérifiés en partie dans kube-ops : `apps-generated-boundary.yaml` présent, cible `check:` du `.justfile` présente, projet `applications` à `*/*` (l. 103-108) [L]. E1 est à reclasser « neutre ». E5 reste exact (`lab-k` n'admet ni `ExternalSecret` ni `Password`) |
| T-010 (#136) : sondes depuis `healthPath` | `appgen` ajoute le ClusterTrait `health-probes` (`httpGet` sur le port de l'endpoint) quand le CCT l'autorise ; +25 l. dans `render_component.py` | ClusterTrait OpenChoreo (`traits`, `allowedTraits`) ; trait dit « upstream » dans `platform/README.md` l. 11 [D, origine non relue] | **natif** (NATIF pour la primitive ; `appgen` reste l'ADAPTATION notée à la revue n°1) | `platform/install/manifests/40-openchoreo-env.yaml` l. 109-123 ; `generated/…/whoami/components/whoami/component.yaml` | Oui : un champ du contrat devient un trait amont, pas un patch |
| T-501 (#172, #175) : harnais de la passe 0 | `observe.py` (142 l.) produit les 2 observations lues par les graders ; `admin-password.sh` (81 l.) pose un Secret aléatoire hors GitOps ; le README du banc classe M3 côté K comme mesure défavorable à K | ESO fournit un générateur `Password` [D] (le bras K l'emploie, voir E5) | **justifié** (ADAPTATION, harnais) | `tests/bench-ab/pass-0/` | Oui pour `observe.py` (rien ne produisait ces clés). `admin-password.sh` est acceptable pour un harnais jetable ; si le banc dure, un `ExternalSecret` avec un générateur `Password` ESO remplacerait le script |
| `tools/oke/open-oke-access.sh` (#182) | Session de bastion OCI (port forwarding, TTL ≤ 3 h), tunnel SSH et kubeconfig 0600 jetable ; TLS vérifié (`--tls-server-name`, jamais désactivé) | Procédure OCI « bastion + `oci ce cluster create-kubeconfig` » [D] | **natif** (côté OCI ; hors OpenChoreo) | Lecture du script : aucune valeur sensible versionnée ; `close` supprime la session, la clé et le kubeconfig | Oui (48 l.). `export PATH=/opt/homebrew/bin` lie le script au Mac, ce qui est cohérent avec la topologie « orchestrateur sur le Mac » |
| T-509 et T-516 (#179, #183) : `docs/ORCHESTRATION.md` | 197 l. : principes, topologie, rôle de l'orchestrateur (règle STOP), écritures OKE par zone, cycle d'un ticket, découpage, capacités mesurées, recettes, anti-patterns ; s'y ajoutent le journal des frictions (37 l.) et +30 l. dans le skill | — (procédure d'équipe, sans lien avec OpenChoreo) | **justifié**, avec 3 défauts | `wc -l` des 6 fichiers → 603 l. Contradiction : `orchestrate-backlog/SKILL.md` l. 55 dit « l'orchestrateur l'exécute après la fusion », alors que `docs/ORCHESTRATION.md` § Rôle dit « Il ne fait jamais : écrire sur OKE … lancer une vérification ». Deux étapes portent le n° 5 (l. 55-56) | En partie. (a) Le rôle est décrit 3 fois (§ 2, § Rôle, skill) et la cadence 2 fois (§ Cadence, `FRICTIONS-ORCHESTRATION.md`). (b) Le tableau § 5 « Capacités et limites » décrit l'outillage Claude du jour et vieillira vite. (c) La règle « un écrivain par zone » repose sur la seule mémoire de l'orchestrateur : aucun outil, aucune trace hors des PR. Point positif : le journal des frictions applique « supprimer avant d'ajouter » (1 seule friction à récurrence ≥ 2, aucun outil ajouté) |
| T-510 (#180) : reprise des tickets | `NEXT.md` +40 l., 5 tickets ouverts (T-511 à T-515), notes « Reprise » | — | **justifié** | `backlog/T-511-lab-store-default.md` (proposition 3 de la revue n°1, tracée) | Oui |

### Mesures (`8caf810`, mêmes commandes qu'en tête)

| Mesure | Revue n°1 (`7125bf6`) | Revue n°2 (`8caf810`) | Écart |
|---|---|---|---|
| `tools/` | 87 fichiers, 15 577 l. | 87 fichiers, 15 294 l. | −283 l. |
| `platform/` | 73 fichiers, 6 809 l. | 73 fichiers, 6 805 l. | −4 l. |
| `tests/` | 720 fichiers, 42 475 l. | 728 fichiers, 42 977 l. | +502 l. (harnais T-501, T-010, T-505 ; −274 l. par T-507) |
| `tools/oke/` · `tools/appgen/` · `tools/status/` | 3 014 · 2 287 · 357 | 3 062 · 2 313 · 0 | +48 (accès bastion) · +26 (T-010) · −357 |
| `platform/install/` · `policies/` · `baseline/` · `kyverno/` | 2 831 · 351 · 223 · 1 122 | 2 827 · 351 · 223 · 1 122 | −4 · 0 · 0 · 0 |
| `tests/argo-guard/` | 1 856 l. | 1 961 l. | +105 |
| Scripts d'installation | 8 | 8 | 0 |
| Étapes d'install OKE (`step_*`) | 14 | 14 (`step_12` toujours sans effet, `install.sh` l. 277) | 0 |
| Applications à synchro manuelle | 3 | 3 (`grep -L` en rend 2, `lab-platform` et `lab-k-root`, + `lab-authz` par A4) | 0 |
| Exclusions manuelles dans `lab-o` | 6 | **0** | −6 |
| Règles `argo_guard` | 23 nommées ; 22 `rule_*` | 23 ; 22 | 0 |
| Tickets ouverts (en-tête) | 163 (128 / 30 / 5) | 176 (135 / 36 / 5) | +13. Des en-têtes n'ont pas suivi la fusion : T-507 et T-516 sont encore `todo`, T-502 et T-505 `in-progress` |
| Docs d'orchestration (`ORCHESTRATION`, skill, `HANDOFF-COORDINATEUR`, `FRICTIONS`, `AGENT-RUNNERS`, `CLOUD-AGENTS`) | non mesuré | 603 l. | nouvelle mesure |

Note : les commandes de la section « Mesures rejouables » ont été rejouées telles quelles (`/tmp/f.txt` compris), en
appels séparés.

### Propositions (≤ 3, par gain d'opérabilité)

1. **Une seule source pour le rôle de l'orchestrateur** (S, texte). `docs/ORCHESTRATION.md` fait foi. Le skill ne
   garde que la procédure (les commandes) et renvoie au document ; `HANDOFF-COORDINATEUR.md` ne garde que les
   décisions de Paul. Corriger au passage la contradiction de `SKILL.md` l. 55 (c'est l'opérateur OKE qui exécute la
   preuve, pas l'orchestrateur) et la double étape 5. *Coût de ne pas le faire* : trois textes à tenir d'accord à
   chaque correction de Paul ; le premier écart est déjà là.
2. **`appgen` écrit `clusters/oke/lab-o-apps.yaml`** (S, après la passe 0). La liste devient une sortie du champ
   `cluster: oke`, et O5 vérifie l'égalité au lieu de l'inclusion. Le report actuel est voulu : il garde echo-bench et
   miniflux hors d'OKE avant la passe 0. Un champ explicite dans `app.yaml` obtiendrait le même effet sans liste
   manuelle. *Coût de ne pas le faire* : chaque app OKE se déclare deux fois, et un oubli dans la liste n'est pas
   détecté (O5 ne contrôle que l'inclusion).
3. **Corriger le constat E1 de T-504 et faire trancher `svc-*`** (XS). E1 passe de « bloquant » à « neutre ». Paul
   confirme que `svc-*` (où Argo écrit pour le bras K) est une exception admise au périmètre d'`AGENTS.md`, ou bien le
   périmètre l'écrit. *Coût de ne pas le faire* : la passe 0 attend un arbitrage inutile, et une exception de
   périmètre n'est écrite que dans un commentaire YAML.

### Questions à Paul (recommandation en tête, « oui » suffit)

1. **Recommandé : oui.** Regrouper le rôle de l'orchestrateur dans une seule source (`docs/ORCHESTRATION.md`) et
   réduire le skill à la procédure (proposition 1) ?
2. **Recommandé : oui.** Le namespace `svc-*` du bras K est-il une exception admise au périmètre cluster d'`AGENTS.md`
   (décision du 2026-11-18 citée dans `project-lab.yaml` l. 202-210) ? Si oui, E1 de T-504 se reclasse « neutre ».
3. **Recommandé : oui, après la passe 0.** Faire écrire la liste `lab-o` par `appgen` (proposition 2) ?

État des questions de la revue n°1 : la n°2 (kgateway) est tranchée « résidu accepté jusqu'à FINAL0 »
(`backlog/T-060-residu-kgateway.md`, Reprise) ; la n°3 (`lab-store` → `default`) est tracée par T-511, encore `todo` ;
la n°1 et la n°4 sont faites (T-502, T-507).

### Sources primaires lues

- Argo CD, générateur Git `files` : [repo_path_utils.go@1942154](https://github.com/argoproj/argo-cd/blob/19421540760d7d2e20561d572bd22c50ac661fba/applicationset/generators/repo_path_utils.go#L173-L191) [L]
  (la page `Generators-Git.md` ne traite pas le cas du tableau [L]).
- Cilium `v1.20.4` : `pkg/k8s/apis/cilium.io/client/crds/v2/` (contient `ciliumnetworkpolicies.yaml` et
  `ciliumclusterwidenetworkpolicies.yaml`) et `install/kubernetes/cilium/values.yaml` l. 3457 (`skipCRDCreation`) [L].
- kube-ops en local (`main`, lecture seule) : `k8s/charts/platform-app/templates/namespace.yaml`, `workload.yaml`,
  `k8s/bootstrap/argocd-root/applications-project.yaml`, `k8s/infrastructure/security/policies/`, `.justfile` [L].
- Non lus : `bench-ab-arm-k` (absent en local) ; l'origine amont du ClusterTrait `health-probes` ; la doc OCI du
  bastion ; le comportement de `gh api` sans authentification [D].

### Ce qui a changé depuis la revue précédente

- **HACKY fermé** : la sélection de `lab-o` (6 exclusions) est remplacée par une liste lue par un générateur natif. La
  ligne « ApplicationSet `lab-o` » passe à NATIF pour l'objet comme pour la sélection ; le résidu est la double saisie.
- **ADAPTATION retirée** : `tools/status/app_status.py` est supprimé (NATIF).
- **Inchangés** : `install.sh` (14 étapes ; `step_12` toujours là, proposition 2 de la revue n°1 non faite) ;
  `argo_guard*` (730 l., 23 règles : le gel proposé tient sur cette plage) ; le store `lab-store` (T-511 ouvert) ; les
  branches `claude/t-060-kgateway-rbac` et `claude/t-060-kgateway-sa`, toujours sur `origin`.
- **Nouveau** : le corpus d'orchestration (603 l.), le harnais de la passe 0, les CRD Cilium de test et le script
  d'accès au bastion.
