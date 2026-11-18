# Images du banc A/B : support linux/arm64 (T-485)

Relevé du 2026-11-18T20:58Z, niveau STATIC (lecture du registre), lancé depuis une session cloud.
`docker manifest inspect` a répondu `toomanyrequests` (limite anonyme de Docker Hub) ; la même lecture a été faite par
l'API du registre (`GET /v2/<image>/manifests/<tag>`, en-tête `Accept` index OCI et liste Docker) avec un jeton anonyme.
Le digest rendu est celui de l'index (`docker-content-digest`).

| Image (tag épinglé par les apps du dépôt) | Plateformes de l'index | Digest de l'index | Concordance |
|---|---|---|---|
| `corentinth/it-tools:2024.10.22-7ca5933` | linux/amd64, linux/arm64 | `sha256:8b8128748339583ca951af03dfe02a9a4d7363f61a216226fc28030731a5a61f` | identique à `apps/it-tools/NOTES.md` |
| `vikunja/vikunja:2.7.0` | linux/amd64, linux/arm, linux/arm64 | `sha256:e2204a1c1c6a81e833c2b3a5442be182ca2335b54c2e7e37578cc3fe12a27cfc` | identique à `apps/vikunja/NOTES.md` |
| `binwiederhier/ntfy:v2.28.0` | linux/amd64, linux/arm, linux/arm64 | `sha256:6ef4b819f722fccdc036af611c4774cfdc2de821ab74fdd48bbf4c9d6f8973da` | identique à `apps/ntfy/app.yaml` |

Verdict : PASS (STATIC) pour la présence de linux/arm64 dans les trois index. NOT_TESTED : la sortie littérale de
`docker manifest inspect` (à rejouer depuis un poste connecté à Docker Hub, puis à coller dans la PR du ticket) et
l'exécution des images sur OKE.
