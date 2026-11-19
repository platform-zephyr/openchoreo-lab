---
id: T-497
title: "Lecteur anonyme du statut des apps par les check runs GitHub (outil, tests, skill) et pose conditionnelle d'Argo CD Notifications à l'étape 11"
status: in-progress
phase: P1
adr: [0010, 0007, 0011]
depends_on: [T-489]
class: AUTONOME
velocity: true
lane: acces-mcp
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-497 — Lecteur anonyme du statut des apps (première moitié de T-006)

## Intention
Un agent cloud ou de l'usine lit l'état d'une app déployée sur OKE sans accès cluster et sans identifiant de Paul :
le check run `argocd/<application>` publié par Argo CD Notifications sous l'App `openchoreo-status` (T-489), lu par
l'API GitHub publique en anonyme. L'installation OKE pose Notifications après Argo CD, seulement si le Secret source
existe. Première moitié de T-006 (critère 1) ; la surface MCP + Access reste à T-006.

## Périmètre de fichiers
tools/status/app_status.py, tests/status/, .agents/skills/read-app-status/SKILL.md, tools/oke/install.sh, tools/oke/lib.sh, tests/registry.yaml, backlog/T-497-lecteur-statut-check-runs.md

## Critères de fin
- [x] `tools/status/app_status.py <app> [--sha SHA|--ref REF]` : Python standard, requêtes anonymes (aucun jeton lu, aucun en-tête Authorization), 1 requête par minute au plus, 403/429 sans boucle, cache local avec ETag, sortie JSON stable `app-checkrun.v1` (app, revision, conclusion success|failure|pending|absent, details_url, completed_at, source, …) documentée dans la docstring (`tests/status/test_app_status.py` : 27 tests OK le 2026-11-19)
- [x] tests hors réseau : fixtures JSON de l'API Checks, cas rate-limit (403 et 429), limite locale, app inconnue ou exclue, check absent, check d'une autre App ignoré, cohérence du nom de check avec `platform/install/argocd/notifications/` (même preuve)
- [x] skill `.agents/skills/read-app-status/SKILL.md` (commande, interprétation, limites, renvoi à `diagnose-app`) ; AGENTS.md inchangé (les skills ne s'y listent pas)
- [x] `tools/oke/install.sh` étape 11 : `platform/install/argocd/notifications/` en server-side apply (field-manager openchoreo-lab) après Argo CD, seulement si `lab-secrets/openchoreo-status` existe (présence par `-o name`), sinon « notifications non appliquées : Secret absent » et poursuite ; dry-run par défaut (`tests/status/install-notifications.sh` : 7 PASS le 2026-11-19, kubectl factice)
- [x] lecture réelle anonyme : `python3 tools/status/app_status.py whoami --ref main` le 2026-11-19T01:00:44Z, `conclusion: success`, révision `fc16f9bc8360b7a0fe15ca3726c32993b19b721a`, `source: api` (poste local, sans jeton)
- [ ] même lecture depuis une session cloud (critère 1 de T-006, preuve datée)
- [ ] étape 11 rejouée sur OKE avec et sans le Secret (preuve datée, coordinateur)

## Notes
Art antérieur : API REST GitHub « List check runs for a Git reference » (`GET /repos/{owner}/{repo}/commits/{ref}/check-runs`, paramètres `check_name`, `filter`), limites de débit anonymes (60 requêtes/heure par IP, en-têtes `x-ratelimit-*`, `retry-after`) et requêtes conditionnelles (ETag, 304) de la documentation GitHub ; gabarit `checkRun` d'Argo CD Notifications (T-489).
Schéma nommé `app-checkrun.v1` pour ne pas se confondre avec `app-status.v1` (`docs/schema/app-status-v1.schema.json`, golden paths, T-072).
Suites ajoutées au registre libre `tests/registry.yaml` (`status-reader`, `status-install-notifications`) : aucun fichier `.github/` modifié.

Note du 2026-11-19 (T-507) : `tools/status/app_status.py` et `tests/status/test_app_status.py` sont supprimés, remplacés par un appel `gh api` documenté dans le skill `read-app-status` (décision de Paul, `docs/research/FIDELITE-JOURNAL.md`). Les cases cochées ci-dessus décrivent l'état livré par T-497 ; le statut reste dérivé. Reste en place : `tests/status/install-notifications.sh` (consommateur : `tools/oke/install.sh` étape 11).
