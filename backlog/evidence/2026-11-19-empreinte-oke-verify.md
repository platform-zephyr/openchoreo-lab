# Empreinte OKE, verify --all et check runs argocd/<app> (T-515, T-487, T-489) : RUNTIME

Niveau de preuve : RUNTIME (lecture seule sur le cluster OKE, aucune écriture). Date : 2026-11-19, relevés vers 10:40 UTC.

## verify.sh --all (journal du run de 10:24 à 10:32 UTC, non rejoué)

| Contrôle | Statut |
|---|---|
| B6-sa-effective | FAIL (résidu kgateway accepté) |
| B1-vap-digest | FAIL (image sans digest admise, la VAP baseline-image-digest ne refuse pas) |
| B6b-portal | NOT_TESTED (portail non demandé) |
| B7 à B11, B11-lab-k-*, S-dns, S-imds, S-egress, S-intra, S-cleanup (fin de journal) | PASS |

Total : FAIL=2. Le total de bloc OCI et le comptage d'un seul Argo CD ne sont pas relevés ici : NOT_TESTED.

## Empreinte du nœud (un seul nœud)

| Mesure | Valeur | Statut |
|---|---|---|
| maxPods du kubelet (configz) = capacité pods | 35 | PASS (relevé) |
| Pods présents (tous namespaces) | 33, dont 2 searxng en échec | PASS (relevé) |
| Marge de pods | 2 | PASS (relevé) |
| Requests CPU | 1140m sur 1830m allouables (62 %) | PASS (relevé) |
| Requests RAM | 2878Mi (33 %) | PASS (relevé) |
| Limits CPU / RAM | 10610m (579 %) / 9434Mi (109 %) | PASS (relevé, limits surengagées) |
| Consommation réelle (metrics-server absent) | non mesurée | NOT_TESTED |

Répartition des pods : kube-system 10, lab-argocd 6, openchoreo-control-plane 4, cert-manager 3, data-plane 2, external-secrets 1, lab-pg 1, lab-cnpg 1, namespaces dp-* 5 (searxng 2, whoami, ntfy, echo-demo).

Marge pour le bras K : 2 pods (T-487 en comptait 1 à 32 pods). Marge CPU jusqu'au seuil de 70 % (1281m) : environ 141m. Le plafond de pods est le facteur limitant : le bras K tient s'il ajoute au plus 2 pods, hors Jobs transitoires. La décision sur le plafond de 33 pods (T-515) revient à Paul ; non tranchée ici.

## Anomalie constatée

searxng : 2 pods en Error/CrashLoopBackOff (7 redémarrages). Le critère « pod Ready » de T-499 case 4 n'est pas satisfait : FAIL.

## Check runs argocd/<app> publiés par openchoreo-status (T-515, une seule lecture gh api sur main)

| Check run | Conclusion | Terminé (UTC) |
|---|---|---|
| argocd/lab-o-ntfy | success | 10:40:32 |
| argocd/lab-o-whoami | success | 10:40:30 |
| argocd/lab-o-echo-demo | success | 10:40:25 |
| argocd/lab-o-searxng | success | 10:38:59 |

PASS : 4 check runs publiés par l'App `openchoreo-status`. Limite : `success` prouve la synchro GitOps, pas la santé applicative (searxng est `success` avec ses pods en échec). Le test d'écriture négatif de l'App (T-489 case 4) reste NOT_TESTED (geste de Paul).
