# it-tools : NON PORTE (pas de app.yaml), nouvel essai 2026-11-17

Source kube-ops : `k8s/applications/tools/it-tools/` @ origin/main [C].

Image verifiee : index `sha256:8b8128748339583ca951af03dfe02a9a4d7363f61a216226fc28030731a5a61f` contient linux/arm64 (`72dad891...`) [C], via `docker buildx imagetools inspect corentinth/it-tools:2024.10.22-7ca5933`. kube-ops pinne le tag seul.

Re-essai avec le schema etendu : **toujours bloque**.

1. **Port 80** : l'image ecoute `80/tcp` (nginx). `runtime.port` et `extraRuntime.port` ont `minimum: 1024`. Pas d'option pour changer le port de nginx. Bloquant.
2. **Ecritures nginx** : kube-ops monte 3 emptyDir (`/var/log/nginx`, `/var/cache/nginx`, `/run`) sur un rootfs en lecture seule. Le schema ne permet que `/tmp` (emptyDir) ; `storage` ne produit que des PVC (`block-rwo` / `rwx-shared`), donc pas de scratch. Bloquant. Une extension `emptyDir` (scratch) serait requise.
3. **Scale to zero** : kube-ops utilise KEDA (`minReplicaCount: 0`, InterceptorRoute). Le schema impose `replicas >= 1`. Non bloquant seul, mais a noter pour le portage.

Extensions requises pour porter it-tools : (a) port d'ecoute >= 1024 ou image nginx non-root sur un port haut (autre image, autre digest) ; (b) volumes `emptyDir` avec `sizeLimit` ; (c) plus tard, replicas 0 si la mise en veille est voulue.
