---
name: add-app
description: Déployer une nouvelle application sur le labo OpenChoreo par GitOps, à partir d'une intention en langage naturel (« déploie X », « ajoute Y avec une base Postgres »). Choisit l'archétype (A/B/C ; D, E, F refusés ou bloqués), écrit apps/<nom>/app.yaml, génère avec tools/appgen, ouvre la PR, suit la CI, merge si la classe est AUTONOME, attend Argo CD et archive la preuve runtime. Ne touche jamais le cluster en écriture.
---

# add-app

Prérequis : charger `platform-guardrails`. Référence : `golden-paths/README.md` et `golden-paths/DEPLOY-AND-FIX-FLOW.md` §1.

## Étapes

0. **Art antérieur** : charger `prior-art` (niveau `complet` pour un nouvel `apps/<nom>`) ; la section « Implémentations publiques consultées » va dans le corps de la PR.
1. **Qualifier l'intention** (sans poser de question si la réponse est dans l'image ou la doc amont) :
   - image officielle et tag récent : `docker buildx imagetools inspect <img>:<tag>` → digest de l'index et présence de `linux/arm64` ;
   - port, uid, chemin d'écriture, besoin de base, de volume, d'egress, d'OIDC, d'exposition publique : lire le Dockerfile ou la doc de l'app.
2. **Archétype** (règle de `golden-paths/README.md`) : F, D ou E ⇒ répondre avec le verdict et s'arrêter (`golden-paths/F-non-eligible/README.md`). Pour une app existante livrée en chart, compose ou YAML, faire le verdict avec `migrate-to-openchoreo`.
3. **Classe** : AUTONOME si A ou C sur k3d, `private`, `egress: none`, sans nouvelle clé de secret ; sinon REVUE ou MANDAT (`platform-guardrails` §1). Clés de store manquantes (`secrets[].key`, `<NOM>_PG_PASSWORD`) : MANDAT, à demander **avec les noms seulement**, en parallèle de la PR.
4. **Contrat** :

   ```bash
   mkdir -p apps/<nom> && cp golden-paths/<X>/app.yaml apps/<nom>/app.yaml   # puis remplir chaque « À REMPLIR »
   python3 tools/appgen/appgen.py validate
   python3 tools/appgen/appgen.py render && python3 tools/appgen/appgen.py check
   git status --short    # seulement apps/<nom>/ et generated/
   ```

4b. **Local d'abord** : `tools/dev/check --static --changed` avant tout push ; FAIL = corriger, pas de push. Reporter verdict, niveau et reçu (SHA, date) dans le corps de la PR ; `NOT_TESTED` = `INCOMPLET`, pas « PASS ».
5. **PR** (corps : format §4.3 de DEPLOY-AND-FIX-FLOW) :

   ```bash
   git switch -c app/<nom>-add origin/main
   git add apps/<nom> generated && git commit -m "<nom>: ajout (archétype <X>)"
   git push -u origin HEAD && gh pr create --title "<nom>: ajout" --body-file /tmp/pr-<nom>.md
   gh pr checks --watch --fail-fast
   ```

   CI rouge : `gh run view <run-id> --log-failed`, corriger dans la même branche, re-pousser. Ne jamais contourner.
6. **Merge** : classe AUTONOME et contrôles du §4 de `platform-guardrails` OK ⇒ `gh pr merge --squash --delete-branch`. Sinon `gh pr edit --add-label needs-paul`, compte rendu, arrêt.
7. **Réconciliation** (lecture) : `kubectl --context $KUBE_CONTEXT get applications.argoproj.io -n argocd lab-apps -o jsonpath='{.status.sync.revisions[0]} {.status.sync.status} {.status.health.status}'`, jusqu'à révision = SHA du merge (10 min au plus).
8. **Archétype B** : PR 2 de pin (`golden-paths/B-http-postgres/CHECKLIST.md`), puis retour à l'étape 5.
9. **Preuve** :

   ```bash
   CLUSTER_LABEL=k3d KUBE_CONTEXT=k3d-openchoreo golden-paths/_checks/run-all.sh <nom> production --evidence evidence/runtime
   gh pr comment <PR> --body-file evidence/runtime/k3d/<nom>/<fichier>.txt
   ```

   FAIL ⇒ `fix-app` (ou revert immédiat si l'app cassée gêne une autre app).

## Critères de sortie

- `verdict: PASS`, ou `PARTIAL` avec chaque BLOCKED et NOT_TESTED expliqué (par exemple G2 tant qu'Argo n'est pas installé).
- Compte rendu de 5 lignes : archétype, classe, URL de PR, SHA de merge, chemin de l'evidence et verdict. Il dit aussi ce qui attend Paul (clés, label `needs-paul`).
- Rien d'autre modifié que `apps/<nom>/`, `generated/`, `pins/` et `evidence/`.

## Cluster OKE : déclarer l'app dans lab-apps (même PR)
Pour `cluster: oke`, ajouter dans `platform/install/argocd/apps/lab-apps.yaml` UNE entrée `sources[]` (copie de la précédente, `path: generated/namespaces/default/projects/<app>`). Ce fichier est libre de revue humaine : `tools/oke/argo_guard.py` (CI) refuse toute entrée hors app OKE stateless (sans storage ni database). Toute autre modification de `platform/`, `tools/`, `.github/` exige l'approbation de Paul (docs/AGENT-PR-MODEL.md).
