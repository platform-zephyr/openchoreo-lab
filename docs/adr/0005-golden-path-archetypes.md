# ADR-0005 — Golden path unique et archétypes
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0001, ADR-0006 à ADR-0010

## Contexte
- Un homelab classique, c'est : services web stateless, apps avec Postgres, apps avec fichiers (SQLite, médias),
  workers et tâches planifiées, et quelques logiciels livrés seulement en chart Helm (KUBE-OPS-REQUIREMENTS §2.3).
- Aujourd'hui : A (stateless) prouvé sur OKE ; B et C disponibles sur k3d ; D bloqué (G1) ; E désactivé (G7).
- Le chart `platform-app` de kube-ops a les bons défauts (PSA, SA sans token, default-deny, PDB, ServiceMonitor) mais
  refuse base, stockage, public et OIDC.

## Décision
1. **Un seul golden path, plusieurs archétypes** choisis par l'arbre de décision de `golden-paths/README.md` :
   - **A** service HTTP sans état ;
   - **B** service + PostgreSQL (CNPG, base dans un cluster partagé par défaut, dédié sur critère chiffré, comme
     D-2026-11-16-09) ;
   - **C** service + volume (un PVC RWO, une réplique) ;
   - **D** worker et tâche planifiée (`spec.kind: worker | cronjob`, correction G1) ;
   - **E** chart Helm tiers **encapsulé** : le chart est rendu par Argo, mais `appgen` impose autour la même cellule que
     A-D (namespace PSA restricted, default-deny, quota, LB = 0, classes de données, OIDC, exposition) et une
     validation du rendu (correction G7) ;
   - **F** non éligible, refus motivé (CRD, RBAC cluster, privileged, hostPath, DaemonSet…).
2. Les **capacités transverses** se déclarent par des blocs optionnels, identiques pour tous les archétypes :
   `identity` (ADR-0007), `data`/`backup` (ADR-0008), `externalResources` (ADR-0009), `exposure` (ADR-0010),
   `network.egress`, `observability`, `verify` (ADR-0011), `dependsOn` (G11), `overrides.<env>` (G12).
3. **Le golden path est stable** : un archétype n'est « disponible » qu'avec un template, une checklist, une suite de
   preuves k3d en CI et une preuve OKE datée. Une évolution casse-compatibilité = nouvelle version du contrat.
4. **Priorité de couverture** : celle du catalogue kube-ops (apps familiales et services réels), pas l'exhaustivité.

## Conséquences
- Chantiers : G1 (D), G2 (probes), G4 (quota dérivé), G7 (E durci), G9 (secrets générés), G10 (`verify`), G11, G12.
- Le chart `platform-app` de kube-ops devient une source d'inspiration pour les défauts, pas un second chemin.
- Migration : chaque app kube-ops passe par `migrate-to-openchoreo` (verdict A-F) avant d'être déclarée.

## Alternatives écartées
- **Helm natif libre (archétype E sans cellule)** : sort du modèle de sécurité.
- **Un ComponentType par app** : explosion de types, contraire à « une surface ».

## Vérification
- Par archétype : template + checklist + suite k3d CI verte + preuve OKE (ou homelab) datée.
- Tableau de couverture du catalogue kube-ops : verdict A-F par app.

## Références
`golden-paths/`, `golden-paths/SCHEMA-GAPS.md`, `docs/research/KUBE-OPS-REQUIREMENTS.md` §2 et §6, `docs/KUBE-OPS-APP-MAP.md`.
