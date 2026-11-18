# T-487 / E4 : étape 11 (Argo CD, AppProjects lab-o/lab-k, aucune application) sur OKE recréé

Niveau : RUNTIME OKE. Installation `tools/oke/install.sh --step 11 --apply` : 23:03:12 à 23:05:00 UTC (2026-11-18).
Contrôle `tools/oke/verify.sh --step 11` (dernier passage, journal verify.log) :

| Horodatage UTC | Verdict | Contrôle |
|---|---|---|
| 2026-11-18T23:18:06Z | PASS | B11-argo : Argo CD Available |
| 2026-11-18T23:18:08Z | PASS | B11-projects : AppProjects lab-platform, lab-o, lab-authz et lab-root présents |
| 2026-11-18T23:18:09Z | PASS | B11-default-locked : AppProject default verrouillé (0 dépôt, 0 destination, 0 whitelist) |
| 2026-11-18T23:18:11Z | PASS | B11-root-project : Application lab-root dans le projet lab-root |
| 2026-11-18T23:18:12Z | PASS | B11-no-default-app : aucune Application du projet default |
| 2026-11-18T23:18:14Z | PASS | B11-authz-manual : Application lab-authz sans synchro automatique |
| 2026-11-18T23:18:17Z | PASS | B11-lab-root-sync : Application lab-root Synced et Healthy (ou Progressing avec le contrôleur ApplicationSet à 0 réplica) |
| 2026-11-18T23:18:19Z | PASS | B11-lab-platform-manual : Application lab-platform sans synchro automatique (adoption différée) |
