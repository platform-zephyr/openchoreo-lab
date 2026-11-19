# T-487 / T-495 : ApplicationSet actif, bras O sur OKE (preuves RUNTIME)

Niveau : RUNTIME OKE. Commit du dépôt : 6ce861c (applicationSet.replicas 1). `tools/oke/install.sh --step 11 --apply` :
2026-11-19T00:25:46Z à 00:27:06Z. Aucun contournement de garde.

## Contrôleur et projets
| Preuve | Verdict | UTC |
|---|---|---|
| Contrôleur ApplicationSet 1/1 Ready | PASS | 00:27 |
| `verify.sh --step 11` : 11 contrôles PASS (dont B11-lab-k-projects, B11-lab-k-dest, B11-lab-k-root-manual) | PASS | 00:27:59 |
| `lab-o` génère EXACTEMENT 4 Applications : lab-o-whoami, lab-o-ntfy, lab-o-echo-demo, lab-o-searxng ; aucune app exclue déployée (aucun composant aiostreams, idp-e2e, mealie, miniflux, open-connector, rustical-pilot) | PASS | 00:30 |
| `lab-k-root` en synchro manuelle (Application `Unknown/Healthy`, non synchronisée), projet `lab-k-root` | PASS | 00:27 |

## Les 4 apps du bras O
| App | Application Argo | ReleaseBinding | Pod | HTTP (port-forward local) | Durée sync |
|---|---|---|---|---|---|
| whoami | Synced/Healthy (rev 6ce861c) | Ready | 1/1 Running | 200 (00:31:47Z) | 1 s |
| ntfy | Synced/Healthy | Ready | 1/1 Running | 200, `healthy:true` (00:31:51Z) | 1 s |
| echo-demo | Synced/Healthy | Ready | 1/1 Running | 200 (00:31:55Z) | 0 s |
| searxng | Synced/Healthy | **Ready=False** | **CreateContainerConfigError** | non joignable | 1 s |
Les 4 ProjectReleaseBinding sont Ready.

**searxng FAIL, cause prouvée en lecture seule** : le pod attend le Secret `searxng-production-env-secrets-…` ; l'ExternalSecret
de la cellule est en `SecretSyncedError` (« could not get secret data from provider », clé `SEARXNG_SECRET` absente de
`lab-store`). Le secret n'existe pas dans le magasin. Non réparé (consigne : rapporter). Première tentative de searxng sur OKE.

## Gardes (information, aucun contournement)
- NetworkPolicy actives dans la cellule whoami : `default-deny`, `allow-dns-and-cell`, `openchoreo-whoami`.
- Requête interdite : un Pod `privileged` en dry-run serveur dans la cellule est REFUSÉ par PodSecurity `restricted:latest` (00:32Z).
- Test de refus Argo : une Application `project: lab-k` vers `kube-system` est refusée (`InvalidSpecError` : destination hors des
  destinations autorisées du projet lab-k, 00:32:06Z) ; supprimée aussitôt (NotFound confirmé).

## Empreinte avec le bras actif (measure.sh, 2026-11-19T00:30:51Z)
| Mesure | Plateforme seule | Bras O actif | Seuil | Verdict |
|---|---|---|---|---|
| requests CPU | 32 % | 52 % (940m / 1830m) | 70 % | PASS |
| requests RAM | 23 % | 31 % (2622 Mi / 8650 Mi) | 70 % | PASS |
| pods | 26 | 32 | 33 | PASS (1 pod de marge) |
| usage pile (MAX de 3) | 26m / 774 Mi | 35m / 1037 Mi | 300m / 1536 Mi | PASS en régime établi |
Écart : pendant l'étape 11 le garde de budget a relevé un pic transitoire de 490m CPU (sync des 4 apps et démarrage du
contrôleur) > 300m et a annoncé « BUDGET DÉPASSÉ » ; 3 minutes plus tard la mesure stable est de 35m. Le garde compare
le MAX d'un pic de démarrage : à relativiser (ticket).

## bras K (T-495)
- Le dépôt bench-ab-arm-k est lisible sans identifiant (`git ls-remote` OK) : le bras K n'est pas BLOCKED.
- `lab-k-root` NON synchronisé : ses deux ApplicationSets ont `syncPolicy.automated` (prune, selfHeal) et le contrôleur est
  actif ; les synchroniser déploierait immédiatement `echo-bench` (lab-k-echo-bench). Consigne : ne pas synchroniser les apps
  (« la passe 0 viendra après »). NOT_TESTED.
