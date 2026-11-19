# T-487 / E4 : empreinte de la plateforme seule et verify.sh --all (OKE recréé)

Niveau : RUNTIME OKE. Aucune application déployée : le contrôleur ApplicationSet est à 0/0, aucune Application `lab-o-*`, aucun
Component dans `default` (lecture, 2026-11-18T23:05Z).

## Durée d'installation (étapes 0 à 11)
| Étape | Début UTC | Fin UTC | Durée |
|---|---|---|---|
| 0 | 22:35:23 | 22:36:08 | 45 s |
| 1-2 | 22:40:46 | 22:41:53 | 1 min 07 |
| 3-5 | 22:42:06 | 22:46:26 | 4 min 20 |
| 6 | 22:46:54 | 22:50:36 | 3 min 42 |
| 7-9 | 22:52:41 | 22:59:26 | 6 min 45 |
| 10 | 22:59:43 | 23:02:45 | 3 min 02 |
| 11 | 23:03:12 | 23:05:00 | 1 min 48 |
Cumul des étapes : environ 21 min ; durée murale 22:35 à 23:05 (30 min, avec les vérifications).

## Empreinte (tools/oke/measure.sh, 2026-11-18T23:09:43Z)
| Mesure | Valeur | Seuil | Verdict |
|---|---|---|---|
| requests CPU (tous pods) | 570m / 1830m allouable = 32 % | 70 % | PASS |
| requests mémoire | 1918 Mi / 8650 Mi = 23 % | 70 % | PASS |
| pods | 26 | 33 | PASS |
| usage pile (MAX de 3 échantillons) | 26m CPU, 774 Mi | budget 300m / 1536 Mi | PASS |
| lab-pg | Cluster healthy, PVC lab-pg-1 50 Gi oci-bv Bound | volume <= 50 Go | PASS |

## verify.sh --all (2026-11-18T23:09:52Z à 23:20:38Z) : 99 PASS, 8 FAIL, 1 BLOCKED
| Contrôle | Verdict | Cause |
|---|---|---|
| B1-vap-digest | FAIL connu | binding baseline-image-digest de kube-ops en Warn/Audit (consigne : ne pas modifier) |
| B6-sa-effective | FAIL accepté | SA kgateway : lecture des Secrets cluster-wide (risque accepté par Paul, credentials factices seulement) |
| B6b-* (7 FAIL, 1 BLOCKED) | NOT_TESTED en pratique | l'étape 6b (portail Backstage, `--with-portal`) n'est PAS installée : hors périmètre E4 ; `--all` l'inclut |
Étapes 0 à 5, 7 à 11 : FAIL=0 hors B1-vap-digest. Le milieu `JALON NON VALIDABLE` vient de B6b-p3p5 (BLOCKED).
