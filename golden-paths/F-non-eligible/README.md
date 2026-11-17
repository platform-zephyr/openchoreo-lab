# F : non éligible

Une app est **F** quand aucun archétype A à E ne la couvre sans affaiblir une primitive. L'agent ne la déploie pas. Il rend un verdict court et s'arrête.

## Signaux (un seul suffit)

| Signal | Pourquoi |
|---|---|
| `CustomResourceDefinition`, opérateur, `APIService` | Objet cluster-scoped, hors du périmètre d'une app |
| `ClusterRole`, `ClusterRoleBinding`, RBAC applicatif | « Rien de cluster-scoped créable par une app » |
| Webhook d'admission (`Mutating`/`ValidatingWebhookConfiguration`) | Contournement de l'admission |
| `DaemonSet`, `hostNetwork`, `hostPath`, `hostPID`, `privileged`, capabilities ajoutées | PSA `restricted` |
| Port < 1024 sans option de changement, uid 0 obligatoire, écriture hors volume et hors `/tmp` | PSA `restricted` et rootfs en lecture seule |
| Plusieurs conteneurs ou sidecar applicatif obligatoires, plusieurs PVC, PVC RWX, plusieurs réplicas avec PVC | CCT `service-restricted` (1 conteneur, 1 PVC RWO) |
| Base autre que PostgreSQL `lab-pg` (MySQL, Mongo, Redis persistant…), ou base exigeant un superuser | CRT `cnpg-lab-db` uniquement |
| Service `LoadBalancer`/`NodePort`, protocole non HTTP exposé (UDP, TCP brut) | Pas de LB OCI ; exposition HTTP seulement |
| Image sans `linux/arm64` | k3d sur Mac et OKE A1 sont en arm64 |
| Donnée `irreplaceable` | Refusée tant qu'aucune restauration hors Oracle n'est prouvée |
| Pas d'image ni de chart officiel (build depuis la source) | Pas de workflow plane dans le labo |
| Worker ou CronJob | Archétype D, non disponible aujourd'hui |

## Réponse type de l'agent

```text
Verdict : F (non éligible). Signal : <signal> dans <fichier/ressource>.
Primitive qui serait affaiblie : <PSA restricted | default-deny | rien de cluster-scoped | …>.
Options : (1) image ou chart alternatif sans ce besoin ; (2) évolution de plateforme (PR protégée, accord de Paul) ;
(3) hors labo. Aucune action effectuée.
```

Ne jamais rendre une app éligible en relâchant une garde : pas d'exception PSA, pas de NP élargie, pas de `kubectl apply` direct.
