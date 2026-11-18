# Résultats VAP sur un vrai API server — **k3d** `k3d-lab-sec-vap` (pas OKE)

- **Date** : 2026-11-17, 19:50-19:53 UTC. API server **Kubernetes v1.35.5+k3s1** (k3d v5.9.0, cluster jetable
  `lab-sec-vap`, 1 serveur, journal d'audit activé par `tests/vap/audit-policy.yaml`). Cluster supprimé à la fin.
- **Méthode** : `tests/vap/run.sh`. Les expressions CEL sont **évaluées par l'API server** (pas de rendu statique).
  Politiques appliquées telles quelles : `platform/policies/*.yaml` et la baseline exportée d'OKE
  (`tests/vap/fixtures/baseline-oke-export.json` : `baseline-pod-hardening`, `baseline-automount-token`,
  `baseline-image-digest`). Identités **réelles** (ServiceAccounts `openchoreo-data-plane/cluster-agent-dataplane`,
  `dp-vap-app/app`, `lab-vap-test/other`) **liées à cluster-admin** : RBAC ne masque rien, tout refus observé vient
  de l'admission. Requêtes par impersonation `--as`/`--as-group`. Écritures hors banc en `--dry-run=server`.
  CONNECT (`exec`, `attach`, `portforward`, `proxy`) : GET sans upgrade ; un refus de VAP est un 403 nommant la
  politique, une admission acceptée échoue ensuite pour une raison étrangère (pod sans nœud, upgrade requis).
- **Limite d'environnement** : le nœud k3s n'a jamais démarré (limite `fs.inotify.max_user_instances=128` de la VM
  colima partagée par 4 clusters). L'API server, l'admission et l'audit fonctionnaient ; les pods restent `Pending`.
  Sans effet sur l'admission (évaluée avant tout ordonnancement), mais aucun `exec` n'a atteint un kubelet.
- **Preuves** : `tests/vap/evidence/{avant-correctif,apres-correctif}/<id>.txt` (commande, sortie, rc, verdict),
  `results.tsv`, `00-policies.tsv`, `00-bindings.tsv`, `audit-extract.jsonl`.

## Bilan

| Jeu de politiques | PASS | FAIL | Remarque |
|---|---|---|---|
| `avant-correctif` (HEAD, `git show`) | 82 | **10** | 1 contournement PSA réel, 2 trous R6, 1 trou R2, identités d'app non bornées, pas d'audit |
| `apres-correctif` (arbre de travail) | **91** | 1 | le FAIL restant est un écart de la baseline **kube-ops** (hors périmètre) |

## Constats corrigés (FAIL avant → PASS après)

| Id | Requête réelle | Avant | Après | Correctif (`vap-cluster-agent-scope.yaml`) |
|---|---|---|---|---|
| V1-N13 | agent `PUT namespaces/dp-vap-ok/status` avec `enforce=privileged`, `cell=x` | **ADMIS, labels écrits** (`V1-N13-labels-apres.txt`) | refus R3 | R3 couvre aussi les sous-ressources du Namespace (`!isSubresource` retiré) |
| V1-N14 | idem via `namespaces/finalize` | **ADMIS** | refus R3 | idem |
| V1-W07 | agent crée `passwords.evil.lab-vap.test` dans `lab-pg` | admis (R2 ne comparait que le nom de ressource) | refus R2 | R2 : couples `groupe/ressource` exacts pour lab-pg et Events |
| V1-P03 | agent `ExternalSecret app-pg-role` avec `dataFrom.extract` depuis `lab-store` | admis | refus R6 | R6 : un seul `dataFrom`, `generatorRef` Password `<x>-pg`, ni `extract`/`find`/`storeRef`/`data` |
| V1-P03b | agent `ExternalSecret` avec `target.template.templateFrom` lisant `lab-pg-superuser` | **admis** (exfiltration du superuser vers le coffre via PushSecret) | refus R6 | R6 : `!has(spec.target.template)` |
| V1-A02, V1-A03 | SA d'app `dp-vap-app:app` : ConfigMap et `pods/exec` dans `kube-system` | admis (RBAC seul) | refus R2b | nouvelle règle R2b : une identité `dp-X` n'écrit que dans `dp-X` |
| AUD-* | journal d'audit de l'API server | 0 annotation | 40 (VAP-1), 9 (VAP-2) | bindings `validationActions: [Deny, Audit]` (VAP-1 et VAP-2) |

`["*/*"]` est conservé (`["*", "*/*"]` est refusé par l'API, cf. commentaire du fichier).

## VAP-1 `lab-cluster-agent-scope` — après correctif (tous PASS)

| Bloc | Tests | Attendu → obtenu |
|---|---|---|
| CONNECT/sous-ressources | C01 exec kube-system, C02 attach, C03 portforward, C04 pods/proxy, C05 services/proxy, C06 nodes/proxy, C07-C08 serviceaccounts/token, C10 pods/eviction, C11 deployments/scale, C12 pods/ephemeralcontainers | refus |
| Témoins | C09 exec agent dans `dp-*`, C13 exec admin dans kube-system, C14 SA d'un autre namespace (hors matchConditions) | admis |
| Namespaces | N02 dp-* sans labels, N03 non dp-*, N04 restricted→baseline (UPDATE, `oldObject`), N05 →privileged, N06 retrait `cell`, N09 DELETE non dp-*, N11 PSA de kube-system, N12 ns par une app, N13-N14 status/finalize | refus |
| Namespaces témoins | N01 CREATE dp-* conforme (`oldObject` nul), N07 annotation, N08 CREATE dp-* `baseline` direct (m1, connu), N10 DELETE dp-* | admis |
| Namespacés | W01 kube-system, W04 delete `lab-pg-superuser`, W05 ConfigMap lab-pg, W06 Deployment dans `openchoreo-data-plane`, W07 groupe étranger | refus ; W02 dp-*, W03 Event : admis |
| RBAC/politiques | R02 RoleBinding→admin, R03 2e sujet (R4), R04 Role, R05 ClusterRole, R06 CRB, R07 CCNP, R09 VWC | refus ; R01 amorce conforme, R10 TokenReview : admis |
| lab-pg (R6) | P02 cible superuser, P03/P03b, P05 clé hors `lab-pg-roles-`, P05b-e (T-456, NOT_TESTED en runtime à ce jour) ancienne clé `lab-pg-roles/app`, clé d'une autre app, préfixe seul, clé suffixée, P06 sélection superuser, P07 sans `data`, P09 jeton SA, P10 image busybox, P11 autre secretKeyRef, P12 hostPath, P13 nom | refus ; P01, P04, P08, P14 (gabarit CRT) : admis |
| Identités d'app | A01 ClusterRole, A02-A03 hors cellule | refus ; A04 dans sa cellule : admis |

## VAP-2 `lab-cell-pod-hardening` et baseline OKE

| Id | Requête | Résultat |
|---|---|---|
| V2-01..05, 07, 07b, 08, 10 | dp-*/lab-pg : sans digest, privileged, hostNetwork, hostPath, init sans digest, éphémère sans digest ou privileged, digest invalide | refus (PASS) |
| V2-06, V2-09 | pod conforme ; tag seul hors dp-*/lab-pg | admis (PASS) |
| B-01..05, B-08 | privileged, hostNetwork, hostPID, hostIPC, hostPath, Deployment privileged | refus `baseline-pod-hardening` (PASS) |
| B-06, B-07 | conforme ; privileged dans `kube-system` (exclu du binding) | admis (PASS) |
| B-10 / B-11 / B-12 | `auth` : sans automount=false refusé ; automount=false et annotation d'exception admis | PASS |
| B-13 / B-14 | `auth` : tag seul **admis avec avertissement** (binding `Warn,Audit`, pas Deny) ; `vap-plain` : aucun avertissement | PASS |
| **B-09** | **conteneur éphémère privileged hors dp-* (`pods/ephemeralcontainers`)** | **FAIL : admis.** La baseline kube-ops ne couvre pas cette sous-ressource. Dans dp-*/lab-pg, VAP-2 le refuse (V2-07b). À signaler à kube-ops. Classé `KNOWN_FAIL` au niveau du cas depuis T-457 (`known-fail.sh`) : exécuté, verdict visible, non bloquant ; correction réelle : baseline de la VM lab (T-363). |

Isolement : quand deux VAP refusent, l'API ne nomme qu'une politique. Pour R6 et VAP-2, le binding
`baseline-pod-hardening` est retiré pendant ces deux blocs puis réappliqué (k3d jetable seulement).

## Configuration vérifiée sur l'objet vivant (`00-policies.tsv`, `00-bindings.tsv`)

- `failurePolicy: Fail` sur les 5 VAP ; aucun `paramKind`/`paramRef`. `status.typeChecking` vide.
- Actions : VAP-1 et VAP-2 `Deny,Audit` (après) ; baseline `Deny`, sauf `baseline-image-digest` en `Warn,Audit`.
  Côté OKE, l'image sans digest n'est donc **pas** refusée hors dp-*/lab-pg (seulement signalée dans 3 namespaces).
- `matchConstraints` VAP-1 : `*/*/*`, `CREATE, UPDATE, DELETE, CONNECT`, `scope: *` (vérifié par C01-C12).
- Messages : chaque refus nomme la politique, le binding, l'identité, la ressource ou la sous-ressource et le
  namespace. Les échantillons sont dans `evidence/apres-correctif/*.txt`, et l'annotation
  `validation.policy.admission.k8s.io/validation_failure` apparaît dans `audit-extract.jsonl`.

## Limites restantes (NOT_TESTED ou hors VAP)

- **R08** : un DELETE du binding `lab-cluster-agent-scope` par l'agent est **admis** par l'admission. Les objets VAP et
  VAPB échappent aux VAP, et seul le RBAC protège cette suppression (prouvé par `tests/rbac` D05-D06).
- **m1** : un dp-* créé directement en `baseline` reste admis (N08).
- R1-R6 n'ont pas été vérifiés contre un cycle réel du cluster-agent OpenChoreo (A3) : NOT_TESTED. Aucun exec n'a
  atteint un kubelet, faute de nœud : NOT_TESTED.
- `PushSecret.spec.secretStoreRefs` n'est pas borné à `lab-store`. Le risque est faible : avec R6, il ne publie
  qu'un mot de passe généré.
