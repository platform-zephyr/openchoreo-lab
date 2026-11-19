# Banc A/B OpenChoreo (K = kube-ops reproduit, O = ce dépôt)

Protocole : `docs/research/POC-OPENCHOREO-STRATEGY.md` §2. Passe 0 : `pass-0/` et `docs/research/POC-AB-PASS-0.md`.
Consignes préenregistrées : `tasks/`, `traps/` (identiques pour K et O, seul `repo` diffère). Seuils : `thresholds.template.yaml`.

## M3 : pas d'équivalent non-prod côté bras K (décision de Paul, 2026-11-19, E6)
M3 demande de valider un changement hors production avant la production. Le bras K n'a pas d'environnement non-prod
pour une app Kustomize (`arm-k/DIFF.md` §4, point 3). Règle : un échec de K sur M3 est une **mesure défavorable à K**,
consignée telle quelle. On n'invente pas de non-prod pour K et on ne développe rien sur kube-ops. La consigne de M3
(`tasks/M3.*.yaml`) n'est pas modifiée.

## S2 : ce que compte « effort écrit »
`files_written` et `lines_written` : fichiers et lignes écrits hors `generated/`. Les sorties d'`occ` ne sont pas
mentionnées dans le gabarit ni dans `tools/bench-ab/` : leur exclusion est **non définie** (NOT_TESTED). Décision de Paul
requise avant le gel de `thresholds.yaml` ; elle n'est pas devinée ici.
