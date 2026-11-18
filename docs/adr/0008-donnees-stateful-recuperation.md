# ADR-0008 — Données stateful : classe déclarée, sauvegarde et restauration prouvée
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : D-2026-11-11-05 (sauvegarder selon l'irremplaçabilité), D-2026-11-16-09 (Postgres partagé),
ADR-0005, ADR-0009

## Contexte
- OpenChoreo n'a ni sauvegarde ni restauration ; ses ResourceTypes de base sont « non production » (CONSOLIDATION §b).
- kube-ops classe les données en IRREPLACEABLE / USEFUL / REBUILDABLE / RETIRED / DRILL dans un **fichier TSV
  central**, hors manifeste, et utilise 4 mécanismes (Velero/Kopia, CNPG barman vers R2, restic chiffré, CronJob)
  avec un Schedule par app. Règle : « restauration n'est pas rollback » ; une donnée n'est sûre qu'après une
  restauration prouvée (KUBE-OPS-REQUIREMENTS §4).
- Le contrat actuel a `backup.class: none | regenerable | irreplaceable` et refuse `irreplaceable`.

## Décision
1. **La classe de donnée est déclarée dans `app.yaml`**, pas dans un fichier central :
   `data.class: ephemeral | rebuildable | useful | irreplaceable` (alignée sur kube-ops). Elle est propagée en label
   `platform.smadja.dev/data-class` sur namespace, PVC, base et Resource (G8).
2. **La plateforme choisit le mécanisme**, l'app ne le choisit pas :
   - base Postgres → CNPG, WAL + base backup vers stockage objet hors Oracle (R2) ;
   - volume → sauvegarde de volume vers stockage objet hors Oracle (mécanisme unique à trancher par ticket :
     VolSync/restic ou Velero/Kopia) ;
   - `irreplaceable` → en plus, copie chiffrée côté client (clé hors cluster) et vérification d'intégrité.
   Fréquence, rétention, RPO/RTO découlent de la classe (valeurs par défaut), surchargeables dans `app.yaml`.
3. **Le stockage de sauvegarde est déclaré avec l'app** (bucket ou préfixe par app, ADR-0009), pas créé à la main.
4. **Restauration prouvée automatiquement** : pour `useful` et `irreplaceable`, un drill planifié restaure dans un
   namespace jetable, vérifie (`verify`, ADR-0011) et publie une preuve datée (`restore-evidence`, péremption
   bornée). Sans preuve fraîche, l'app est signalée non conforme.
5. **Pas de suppression implicite** : PVC, bases et Resources en `Retain`, `Prune=false`/`Delete=false` ; retirer
   une app avec données = PR qui déclare `retire` + export ; la suppression effective de données `useful`/
   `irreplaceable` reste un MANDAT.
6. `irreplaceable` est **autorisé** dès que la chaîne sauvegarde + restauration hors Oracle est prouvée pour cet
   archétype (fin du refus inconditionnel).

## Conséquences
- Remplace le TSV central de kube-ops par le contrat ; les 4 mécanismes se réduisent à 2 (+ chiffrement client).
- Coût : stockage objet hors Oracle (R2 déjà utilisé), un opérateur de sauvegarde de volume (à mesurer sur OKE).
- Sur OKE, tout volume reste soumis au budget (volume OCI 50 Go min.) : les apps stateful iront de préférence sur le
  homelab tant que D1 n'est pas tranché (ADR-0003).

## Alternatives écartées
- **Classe hors manifeste (TSV)** : invisible pour l'agent qui écrit l'app.
- **Laisser l'app choisir son outil** : 4 mécanismes, comme aujourd'hui.

## Vérification
- CI : une app avec base ou volume sans `data.class` est refusée ; `irreplaceable` refusé sans preuve de drill
  pour l'archétype.
- Drill automatique PASS daté par app `useful`/`irreplaceable` ; tableau de couverture généré.

## Références
`docs/research/KUBE-OPS-REQUIREMENTS.md` §4, `docs/storage/`, `golden-paths/SCHEMA-GAPS.md` G8.
