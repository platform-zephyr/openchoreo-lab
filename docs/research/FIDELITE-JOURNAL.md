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
