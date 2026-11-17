# it-tools : NON PORTE (pas de app.yaml)

Source kube-ops : `k8s/applications/tools/it-tools/` @ origin/main ef50472 [C].

Raison precise : le schema v2alpha1 ne peut pas exprimer cette app, donc pas de descripteur.

1. **Port 80** : l'image `corentinth/it-tools:2024.10.22-7ca5933` expose et ecoute `80/tcp` (nginx, `CMD nginx -g 'daemon off;'`) [C]. Le schema impose `runtime.port >= 1024` et ne permet pas de choisir la configuration nginx. Bloquant.
2. **Ecritures nginx** : kube-ops monte 3 emptyDir (`/var/log/nginx`, `/var/cache/nginx`, `/run`) avec rootfs RO. Le contrat cell-restricted ne fournit que `/tmp`. Bloquant sans multi-volumes (E8) ou image d'un autre type.
3. Digest : index `sha256:8b812874...` contient linux/arm64 (`72dad891...`) [C], utilisable si le port est resolu.

Pistes (hors perimetre de cette mission) : une image nginx non-root ecoutant sur >= 1024 (autre image, donc autre digest), ou une extension du schema autorisant un port < 1024 sans NET_BIND_SERVICE (contraire a drop ALL, donc deconseille).
