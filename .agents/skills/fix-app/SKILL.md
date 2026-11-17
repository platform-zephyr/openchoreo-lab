---
name: fix-app
description: Corriger une application cassée du labo OpenChoreo sans contourner Git — diagnostic en lecture seule, cause prouvée, revert immédiat si c'est une régression, correctif par PR dans apps/<nom>/app.yaml, vérification runtime et fiche d'incident. À utiliser quand une app est en erreur, qu'un check golden-path est FAIL, qu'Argo est Degraded, ou qu'on demande « répare X ».
---

# fix-app

Charger `platform-guardrails`. Parcours de référence : `golden-paths/DEPLOY-AND-FIX-FLOW.md` §2.

## Étapes

1. **Photo avant** (lecture seule) :

   ```bash
   CLUSTER_LABEL=k3d KUBE_CONTEXT=k3d-openchoreo golden-paths/_checks/run-all.sh <app> <env> --evidence evidence/incidents
   ```

2. **Cause** : appliquer `diagnose-app` jusqu'à obtenir **une** cause et sa preuve. Pas de correctif sans preuve.
3. **Régression ?**

   ```bash
   git log --format='%h %cI %s' -5 origin/main -- apps/<app> generated/namespaces/default/projects/<app>
   ls -t evidence/runtime/$CLUSTER_LABEL/<app>/ | head -3     # dernière evidence PASS antérieure au dernier merge ?
   ```

   Si oui, **revert d'abord** (skill `promote-or-rollback`, section Rollback), puis correctif en avant sur une branche propre. Le revert est AUTONOME, sauf s'il retire une base, un volume ou une exposition (REVUE).
4. **Correctif dans Git** : modifier le seul champ en cause dans `apps/<app>/app.yaml` (table de causes du flux §2), puis :

   ```bash
   git switch -c fix/<app>-<cause-courte> origin/main
   python3 tools/appgen/appgen.py validate && python3 tools/appgen/appgen.py render && python3 tools/appgen/appgen.py check
   git add apps/<app> generated pins && git commit -m "<app>: corrige <cause>"
   git push -u origin HEAD && gh pr create --title "<app>: corrige <cause>" --body-file /tmp/fix-<app>.md
   gh pr checks --watch --fail-fast
   ```

   Corps de PR : fiche d'incident (flux §4.2) + preuve « avant ».
   Cause hors app (quota du CPT, CCT, générateur, store ESO) : pas de rustine dans `app.yaml`. PR plateforme (REVUE) ou demande MANDAT (nom de clé seulement).
5. **Merge** selon la classe (`platform-guardrails` §1 et §4) : `gh pr merge --squash --delete-branch`, ou `--add-label needs-paul` et arrêt.
6. **Vérifier** : attendre la sync Argo (révision = SHA du merge), puis relancer `run-all.sh … --evidence evidence/runtime`. Chaque ID FAIL de la photo avant doit passer à PASS. Sinon, retour à l'étape 2 (au plus 2 itérations, puis REVUE avec la fiche complète).
7. **Clore** : `gh pr comment <PR> --body-file <fiche>` ; fiche copiée sous `evidence/incidents/<cluster>/<app>/`.

## Critères de sortie

- `verdict: PASS` après correctif, cause et preuve écrites, durée signal → PASS notée.
- Aucune écriture cluster, aucun secret affiché, aucun check contourné.
- Si bloqué (MANDAT, REVUE) : la fiche dit exactement ce qui est attendu de Paul.

## Anti-patterns

`kubectl rollout restart` « pour voir » ; supprimer un pod ; élargir `egress` pour faire taire un timeout sans preuve ; passer `size` à `medium` sans `OOMKilled` observé ; corriger `generated/` à la main ; enchaîner trois correctifs sans revert.
