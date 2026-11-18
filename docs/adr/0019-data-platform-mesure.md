# ADR-0019 — Data platform légère et mesure de la plateforme
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0003, ADR-0006, ADR-0008, ADR-0011, ADR-0012

## Contexte
- Paul veut à terme une data platform sur le homelab, légère en calcul, fondée sur des fichiers en bucket, dont le
  premier usage est d'évaluer la plateforme agentique (DORA, sécurité, maturité cloud native).
- Les ADR fixent des cibles (délai issue → merge, part de PR sans humain, preuves datées) sans instrument pour les mesurer.
- OKE est serré en CPU (ADR-0003) ; le homelab porte les données. Grafana Cloud existe déjà (kube-ops).

## Décision
1. **Une pile fichiers** : Parquet partitionné dans un stockage objet S3 (Garage sur homelab) + DuckDB ; aucun format
   de table ni moteur serveur tant qu'un besoin d'écritures concurrentes ou de time travel n'est pas prouvé.
2. **Mesure d'abord, plateforme ensuite** : le catalogue de métriques (A, B, C) est le périmètre initial ; toute
   nouvelle source passe par un ticket avec formule, source et classe de donnée.
3. **Démarrage sans cluster** (GitHub Actions planifié), puis déplacement sur le homelab comme une app du golden
   path (archétype D) ; jamais sur OKE.
4. **Les métriques sont des faits calculés** à partir de sources déjà publiées (GitHub, Argo, app-status.v1) ;
   aucune saisie manuelle ; aucun chiffre sans effectif ni sans fenêtre.
5. **Restitution** : fichiers statiques versionnés (lus par les agents) ; Grafana Cloud reçoit des jauges bornées
   (budget de séries) pour l'alerte uniquement.
6. **Maturité** : grille de checks PASS/FAIL/NOT_TESTED datés, par application et par cluster ; jamais une note déclarative.
7. **Données** : classes et rétentions du tableau ci-dessus ; ni secret, ni prompt, ni donnée personnelle.
8. **Les agents ne s'évaluent pas eux-mêmes** : le calcul et ses formules sont hors du pouvoir d'écriture des agents
   qu'ils mesurent (`tools/metrics/` en REVUE ; seuils d'objectif dans `docs/adr/`).

## Conséquences
- Ticket(s) : ingestion, formules testées, Garage, restitution, grille CNCF (voir `backlog/proposals/data-platform.yaml`).
- Coût : ~0 en phase 0 ; en phase 1 un volume Longhorn et un CronJob ; dépendance à T-030, T-011, T-072, T-023.
- Risque : loi de Goodhart, car des agents optimisent ce qu'on mesure (merges triviaux, revert rapides). Compensé par
  D3/D5 couplés à D1 et par l'exigence de preuve runtime.

## Alternatives écartées
- **Iceberg/Delta + catalogue** : surdimensionné pour quelques Mo, ajoute un service ; à revoir si volumétrie × 1000.
- **ClickHouse/Postgres/Prometheus seul** : un serveur de plus ; Prometheus ne porte pas bien PR/lead time.
- **MinIO / SeaweedFS** : MinIO en maintenance [E], SeaweedFS plus lourd ; Garage suffit.
- **Tout dans Grafana Cloud** : plafond de séries, pas de relecture facile par les agents, dépendance externe.
- **Outil DORA clé en main (Four Keys, Backstage)** : modèle de données imposé, pas de notion d'agent ni de classe.

## Vérification
- Rejeu : les gold recalculés depuis bronze sont identiques (test déterministe) ; jeu de test synthétique avec valeurs
  attendues pour chaque formule.
- Preuve runtime datée : le CronJob publie un `metrics.json` de moins de 26 h ; alerte sinon.
- Les cibles d'ADR-0002 (délai médian issue → merge, part de PR sans humain) sortent du rapport hebdomadaire.

## Références
cncf/cartografos `reference/v4beta1` ; CNCF TAG App Delivery Platform Engineering Maturity Model ; DORA ; OpenSSF
Scorecard ; SLSA ; DuckDB ; Garage ; `docs/research/IDP-AGENTIC-BEST-PRACTICES.md` ; kube-ops `observability-for-agents.md`.

_Source et détails : `docs/research/DATA-PLATFORM-METRICS.md`. Texte proposé par la recherche du 2026-11-18, intégré tel quel ; à revoir par la revue adverse._
