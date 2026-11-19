---
id: T-517
title: "searxng : CrashLoopBackOff, l'entrypoint écrit /etc/searxng/settings.yml sur un rootfs en lecture seule"
status: todo
phase: P1
adr: [0025]
depends_on: []
class: AUTONOME
velocity: false
lane: apps
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-517 — searxng : CrashLoopBackOff, l'entrypoint écrit /etc/searxng/settings.yml sur un rootfs en lecture seule

## Intention
Mesure OKE (RUNTIME, 2026-11-19) : le pod `searxng` (`lab-o-searxng`) est en `CrashLoopBackOff`. Le Secret est résolu (ExternalSecret Ready). L'entrypoint de l'image fait `cp` de `settings.template.yml` vers `/etc/searxng/settings.yml`, or `readOnlyRootFilesystem: true` et seul `/tmp` est inscriptible : `cp: can't create '/etc/searxng/settings.yml': Read-only file system`. Argo montre Synced/Healthy : la santé Argo est trompeuse.

Correctif retenu : `apps/searxng/app.yaml` seulement. `runtime.command` lance `granian` directement (sans l'entrypoint), `runtime.env` pointe `SEARXNG_SETTINGS_PATH` vers le modèle de l'image (lecture seule). `SEARXNG_SECRET` (Secret) prime sur `secret_key`. Aucun volume, aucun changement de type, aucun code.

Options comparées (preuve : source de l'entrypoint à l'amont, commit `a9d990033`) :

| Option | Verdict | Raison |
|---|---|---|
| `command`/`args`/`env` dans `app.yaml` | **Retenue** | Contrat existant (`spec.runtime`) ; une seule app touchée ; retrait = `git revert`. |
| `emptyDir` 16Mi sur `/etc/searxng` dans `service-restricted.yaml` | Écartée | Le type est partagé : une release embarque une copie du type, donc toute modification réédite les 10 apps (essai local : 10 nouvelles ComponentRelease, 10 bindings changés). Hors périmètre, et un chemin propre à une image dans un type commun (« pas de règle pour un seul cas », `docs/ORCHESTRATION.md` §1). |
| `settings.yml` par ConfigMap (comme kube-ops) | Écartée | Le fichier existant évite le `cp` (c'est pourquoi kube-ops démarre), mais le contrat ne monte pas de ConfigMap (NOTES, écart 1) : il faudrait du code dans `tools/appgen/` (gel). |
| `SEARXNG_SETTINGS_PATH` seul | Insuffisante | L'entrypoint écrit en dur `$__SEARXNG_CONFIG_PATH/settings.yml` ; la variable ne change que la lecture. Utile seulement avec `command` (option retenue). |
| `readOnlyRootFilesystem: false` | Écartée | Affaiblit le type restreint (consigne de Paul). |

Compromis assumé : on contourne l'entrypoint, donc on dépend de deux chemins internes de l'image (`/usr/local/searxng/.venv/bin/granian`, `/usr/local/searxng/settings.template.yml`). Un bump d'image revérifie ces deux chemins (NOTES.md). Gain : `image_proxy: true` (comme kube-ops) vient du modèle.

## Périmètre de fichiers
apps/searxng/app.yaml, apps/searxng/NOTES.md, generated/namespaces/default/projects/searxng/**, backlog/T-517-searxng-rootfs.md

## Critères de fin
- [ ] `appgen validate` et `appgen check` PASS ; seul `generated/…/searxng/` change (STATIC)
- [ ] `tools/dev/check --static --changed` lancé, verdict reporté dans la PR
- [ ] k3d-integration lancé en `workflow_dispatch` sur la branche ; suites non lancées listées `NOT_TESTED`
- [ ] PREUVE OKE (orchestrateur) : pod `searxng` Ready, `healthPath` `/healthz` répond 200, `restartCount` stable 10 min (RUNTIME)

## Notes
`readOnlyRootFilesystem` reste `true`. Si le démarrage échoue encore, causes à tester d'abord : chemin du binaire ou du modèle absent de l'image ; `/healthz` absent (adapter `healthPath` dans `app.yaml`, pas ici).
