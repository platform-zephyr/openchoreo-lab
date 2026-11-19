# Images du banc A/B : support linux/arm64 (T-485, mis à jour par T-501)

Relevé du 2026-11-19T09:19Z, niveau STATIC (lecture du registre), lancé depuis une session cloud.
Apps du banc (arbitrage de Paul du 2026-11-18, stratégie §2.3) : `echo-bench` (M1, M4), `miniflux` (M2), `ntfy` (M3).
`it-tools` et `vikunja` ne font plus partie du banc ; leurs lignes sont retirées.

Méthode : lecture de l'index par l'API du registre, sans `docker` (limite anonyme de Docker Hub) :
`GET /v2/<image>/manifests/<tag>` avec un jeton anonyme (`https://ghcr.io/token?scope=repository:<image>:pull` ;
`https://auth.docker.io/token?service=registry.docker.io&scope=repository:<image>:pull`) et l'en-tête `Accept`
`application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json`.
Le digest rendu est celui de l'index (`docker-content-digest`).

| App | Image (tag épinglé par le dépôt) | Plateformes de l'index | Digest de l'index | Concordance |
|---|---|---|---|---|
| `echo-bench` | `docker.io/traefik/whoami:v1.10.3` | linux/amd64, linux/arm, linux/arm64 | `sha256:43a68d10b9dfcfc3ffbfe4dd42100dc9aeaf29b3a5636c856337a5940f1b4f1c` | identique à `apps/whoami/app.yaml` et à l'image de `echo-bench` du bras K (`arm-k/DIFF.md`) |
| `miniflux` | `ghcr.io/miniflux/miniflux:2.3.3` | linux/amd64, linux/arm, linux/arm64, linux/riscv64 | `sha256:49d7b60987616387c306a8023087b31f2c9b7b21288b523026cb04058e8b6dbb` | identique à `apps/miniflux/app.yaml` |
| `ntfy` | `docker.io/binwiederhier/ntfy:v2.28.0` | linux/amd64, linux/arm, linux/arm64 | `sha256:6ef4b819f722fccdc036af611c4774cfdc2de821ab74fdd48bbf4c9d6f8973da` | identique à `apps/ntfy/app.yaml` |

Verdict : PASS (STATIC) pour la présence de linux/arm64 dans les trois index, aux digests épinglés par le dépôt.

NOT_TESTED :
- la sortie littérale de `docker buildx imagetools inspect <image>` (à rejouer depuis un poste connecté, puis à coller
  dans la PR du ticket) ;
- l'exécution des trois images sur OKE (le démarrage réel est prouvé seulement par le check run de la passe 0) ;
- l'image PostgreSQL de M2 : elle vient de la plateforme (`lab-pg`, CNPG), pas du banc ; hors de ce relevé.

Le bras K reprend la même image pour `echo-bench` ; pour `miniflux` et `ntfy`, son dépôt (`arm-k/DIFF.md`, hors de ce
ticket) doit épingler les mêmes digests : à confirmer par la revue de fidélité du bras K.
