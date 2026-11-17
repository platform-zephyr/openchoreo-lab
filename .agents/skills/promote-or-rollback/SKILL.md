---
name: promote-or-rollback
description: Mettre à jour (bump d'image par digest), promouvoir development → production, ou revenir en arrière (git revert) une application du labo OpenChoreo, uniquement par PR. Explique ce qui est réversible ou non (migrations, données), comment vérifier après, et quand le rollback est autonome ou protégé.
license: Apache-2.0 (modèle de promotion et de rollback adapté de openchoreo/skills@cefd81b, voir l'en-tête)
---

<!--
Adapted from openchoreo/skills@cefd81bc16b79bd2de0f6284e6fa06d6c15825b7:
skills/openchoreo-developer-gitops/references/recipes/promote.md (Apache-2.0).
Modifications : occ releasebinding generate remplacé par tools/appgen (release au nom déterministe),
rollback = git revert du merge, Argo CD au lieu de Flux, classes d'autonomie, limites du labo
(promotion par environnement non disponible : SCHEMA-GAPS G3) ; traduction en français.
-->

# promote-or-rollback

Charger `platform-guardrails`. Modèle : une ComponentRelease est **immuable** et nommée `<app>-<hash10>` d'après son contenu. Une ReleaseBinding pointe sur elle (`releaseName`). Argo ne purge jamais les ComponentRelease (`Prune=false,Delete=false`). Revenir en arrière consiste donc à re-rendre l'ancien contenu : on retrouve exactement l'ancien nom, et l'objet existe encore.

## Mise à jour (bump)

```bash
docker buildx imagetools inspect <img>:<nouveau-tag>       # digest de l'index + linux/arm64
git switch -c bump/<app>-<tag> origin/main
# éditer spec.source.image dans apps/<app>/app.yaml (tag + @sha256)
python3 tools/appgen/appgen.py validate && python3 tools/appgen/appgen.py render && python3 tools/appgen/appgen.py check
git add apps/<app> generated && git commit -m "<app>: <ancien> -> <nouveau>"
git push -u origin HEAD && gh pr create --fill && gh pr checks --watch --fail-fast
```

Classe : digest ou même majeure ⇒ AUTONOME. Majeure sur B ou C (migration probable) ⇒ REVUE. Lire les notes de version et citer toute migration irréversible dans la PR.

## Promotion development → production

Limite actuelle (SCHEMA-GAPS G3) : `appgen` écrit **la même release** dans tous les environnements listés. Il n'existe pas de pin par environnement. D'ici G3 :

- tester en `development` = une app en `environments: [development]` ; promouvoir = PR qui passe à `[development, production]` ;
- une app déjà dans les deux environnements reçoit chaque bump **partout à la fois**. Le dire dans la PR ; c'est le rollback par revert qui protège.

Après G3 : `appgen promote <app> development production` écrira une seule ligne de pin, en PR (même classe que le bump).

## Rollback

```bash
M=<sha du merge à annuler>          # gh pr view <PR> --json mergeCommit --jq .mergeCommit.oid
git switch -c revert/<app>-${M:0:7} origin/main
git revert --no-edit "$M"           # squash merge : un seul parent
python3 tools/appgen/appgen.py check   # le revert doit être sans dérive ; sinon render + commit
git push -u origin HEAD && gh pr create --title "revert: <app> ${M:0:7}" --body "Rollback de #<PR>, cause : <preuve>" && gh pr checks --watch --fail-fast
```

- AUTONOME si le merge annulé ne fait que bump, `size`, `env` ou ajout d'une app A ou C. REVUE s'il ajoute ou retire `database`, `storage`, `exposure: public`, un egress, ou un secret.
- **Non réversible par revert** : migration de schéma déjà jouée (B), fichiers déjà réécrits sur le PVC (C), effets externes. Le revert remet le code, pas les données. Dans le labo, l'issue est de recréer la base ou de vider le volume : classe MANDAT (données).
- Ne jamais repointer `releaseName` à la main dans `generated/` : la CI le refuse (dérive), et c'est un contournement.

## Vérification (bump, promotion, rollback)

```bash
kubectl --context $KUBE_CONTEXT get releasebindings.openchoreo.dev <app>-<env> -n default -o jsonpath='{.spec.releaseName}'   # = Git
CLUSTER_LABEL=k3d KUBE_CONTEXT=k3d-openchoreo golden-paths/_checks/run-all.sh <app> <env> --evidence evidence/runtime
```

Sortie : G4 (releaseName du cluster = celui de Git) en PASS, W6 (digest du pod = `app.yaml`) en PASS, verdict PASS. Evidence postée en commentaire de la PR.
