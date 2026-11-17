# idp-e2e : notes de portage

Source kube-ops : `k8s/apps-generated/idp-e2e/app.yaml` @ origin/main ef50472 [C] (format v1, replicas 2, size medium, port 80, /health).

- Image : `traefik/whoami:v1.10.3`, digest index `sha256:43a68d10...` identique a kube-ops, linux/arm64 present [C] (`docker buildx imagetools inspect`).
- Port : 8080 avec `args: ["--port", "8080"]` (le schema impose port >= 1024). Equivalent fonctionnel, meme sonde `/health`.
- Dimensionnement : `size: small` avec `replicas: 2` au lieu de `medium` (budget CPU lab, ecart assume).
- Egress : `none`. Ingress : `private` (internal). Equivalent a kube-ops (ingress seul).
- Statut runtime : NOT_TESTED (aucun deploiement k3d ici).
