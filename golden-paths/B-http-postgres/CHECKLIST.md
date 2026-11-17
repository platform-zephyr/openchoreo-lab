# Checklist B : HTTP + PostgreSQL (`lab-pg`)

Script : `CLUSTER_LABEL=k3d KUBE_CONTEXT=k3d-openchoreo golden-paths/_checks/run-all.sh <app> production --evidence evidence/runtime`
(enchaîne `check-gitops.sh`, `check-workload.sh` et `check-postgres.sh`)

## Avant la PR 1

- [ ] Les contrôles locaux de la checklist A.
- [ ] Clé `<NOM>_PG_PASSWORD` présente dans le store ESO, ainsi que chaque `secrets[].key`. L'agent ne la crée pas : c'est un MANDAT de Paul, à demander une seule fois avec la liste exacte des clés. **Ne jamais demander la valeur.**
- [ ] L'app accepte une URL PostgreSQL complète dans une variable (`envVar`), avec `sslmode=require`.

## Après la PR 1 (Resource créée, binding non épinglé)

- [ ] P1 : Cluster CNPG `lab-pg` en `Cluster in healthy state`.
- [ ] P2 : `BLOCKED … non épinglée`. C'est attendu : lire la release proposée dans la sortie, puis ouvrir la PR 2.

```bash
kubectl --context "$KUBE_CONTEXT" get resources.openchoreo.dev <app>-db -n default -o jsonpath='{.status.latestRelease.name}'
python3 tools/appgen/appgen.py pin-resource <app> production <app>-db-<hash>
python3 tools/appgen/appgen.py render && python3 tools/appgen/appgen.py check
```

## Après la PR 2 (lecture seule)

| ID | Preuve attendue |
|---|---|
| G1 à W8 | Comme pour l'archétype A |
| W2 | NP `egress-lab-pg` présente |
| P2 | Pin = dernière ResourceRelease ; binding `Ready` ; `retainPolicy=Retain` |
| P3 | Job `<app>-db-pg-init` (lab-pg) : `succeeded=1` (rôle, base, `REVOKE CONNECT FROM PUBLIC`) |
| P4 | ExternalSecret `<app>-db-role` (lab-pg) et `<app>-db-pg` (cellule) `Ready`. Secret présent, valeur jamais lue |
| P5 | Cellule étiquetée `platform.smadja.dev/pg-client=true` |
| P6 | `DATABASE_URL` (ou `envVar`) injectée par `secretKeyRef`, jamais en valeur littérale |
| P7 | NOT_TESTED ici. Refus inter-bases et refus réseau : tests 9 et 10 d'APP-CONTRACT §8 (`tests/k3d`) |

## Rollback

- Code ou image : `git revert` de la PR, comme pour A. **Une migration de schéma déjà appliquée n'est pas annulée.** Dans le labo, on recrée la base (classe protégée « données » : PR + accord de Paul).
- Retirer la base (supprimer `database:`) : classe protégée. `Retain` garde la ResourceRelease ; la base reste dans `lab-pg`.
