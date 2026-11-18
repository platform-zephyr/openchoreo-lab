# Checklist A : service HTTP sans état

Script : `CLUSTER_LABEL=k3d KUBE_CONTEXT=k3d-openchoreo golden-paths/_checks/run-all.sh <app> production --evidence evidence/runtime`

## Avant la PR (local, sans cluster)

- [ ] `python3 tools/appgen/appgen.py validate` : OK.
- [ ] `python3 tools/appgen/appgen.py render` puis `check` : OK. Le diff contient `apps/<app>/app.yaml` et `generated/…` seulement.
- [ ] Image : index multi-arch avec `linux/arm64`, digest recopié de `docker buildx imagetools inspect`.
- [ ] L'image écoute sur un port ≥ 1024 et démarre en non-root avec un rootfs en lecture seule. Sinon : `args`/`env` pour changer de port ; si c'est impossible, archétype F.

## Après merge et synchronisation (lecture seule)

| ID | Preuve attendue |
|---|---|
| G1 | `appgen check` sans dérive |
| G2 | Argo `lab-crds`, `lab-platform`, `lab-o-<app>` : `Synced/Healthy`, révision = `origin/main` |
| G3 | Component présent, `autoDeploy=false` |
| G4 | `ReleaseBinding.spec.releaseName` du cluster = celui de Git ; ComponentRelease présente |
| G5 | ReleaseBinding `ReleaseSynced`, `ResourcesReady`, `Ready` = True ; ProjectReleaseBinding `Ready` |
| W1 | Cellule `dp-default-<app>-<env>-<hash>` en PSA `restricted` |
| W2 | `default-deny` + `allow-dns-and-cell` ; aucune NP d'egress non demandée |
| W3 | Quota : 0 LoadBalancer, 0 NodePort ; LimitRange présente ; Services en ClusterIP |
| W4 | Deployment prêt (`ready = desired`), moins de 3 redémarrages |
| W5 | `runAsNonRoot`, seccomp `RuntimeDefault`, pas de jeton SA, `allowPrivilegeEscalation=false`, rootfs RO, `drop ALL` |
| W6 | Image du pod = image de `app.yaml` (digest) |
| W8 | `GET <healthPath>` en 2xx via le proxy de l'API server (sinon NOT_TESTED : la NP peut bloquer) |

Verdict : `PASS` si aucun FAIL. Un `PARTIAL` est acceptable s'il ne contient que G2 BLOCKED (Argo pas encore installé, phase A3) ou W8 NOT_TESTED : le dire dans la PR.

## Rollback

`git revert <sha du merge>` dans une PR. La CI re-rend l'ancienne ComponentRelease (nom déterministe, encore présente car `Prune=false`). Après merge, rejouer la checklist.
