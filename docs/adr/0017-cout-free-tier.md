# ADR-0017 — Coût : rester dans le free tier, garde-fous exécutables
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0003, ADR-0004, ADR-0009, ADR-0014, D-2026-11-11-17, D-2026-11-16-07 (homelab-infra)

## Contexte
- Paul veut le coût global le plus faible possible et reste dans les free tiers. OKE : A1 2/12 fixé, 200 Go de bloc
  dont 150 pris, LB = 0 par quota. homelab-infra a déjà un budget OCI à 0,01 USD, des alertes Grafana d'usage et un
  budget de 20 €/mois ; ce dépôt n'a aucun garde-fou de coût propre (T-009 seulement estimatif).
- Le web n'était pas lisible (2026-11-18) : les limites du fournisseur sont à reconfirmer.

## Décision
1. **Coût d'infrastructure additionnel de la plateforme : 0 €.** Aucun fournisseur payant n'est ajouté sans MANDAT (ADR-0002 §3).
2. **Registre unique des limites** `docs/state/free-tier.yaml` (valeur, date, source URL, prochaine revue) ; une limite
   non revérifiée depuis 90 jours échoue le lint.
3. **Refus à la source** : `appgen` et la CI refusent tout ce qui sort du free tier d'après `capabilities.yaml`
   (volume sur OKE, LB, `type: LoadBalancer`, IP publique, hors région).
4. **Alarme avant, jamais seulement après** : chaque ressource limitée a un seuil de 70-80 % qui crée une issue et une
   alerte ntfy ; le budget OCI 0,01 USD reste la dernière ligne.
5. **LLM** : abonnement forfaitaire pour les agents ; plafond de concurrence et de tours ; aucune clé API au token sans
   MANDAT, plafond de dépense côté fournisseur ; consommation consignée par PR.
6. **Pas d'OpenCost ni de FinOps Agent** tant que l'observability plane n'est pas déployé pour d'autres raisons.
7. **Un agent ne relève jamais un plafond** (quota, budget, seuil) : c'est un MANDAT.

## Conséquences
- Un registre et ~3 contrôles périodiques en lecture seule ; une clé OCI de lecture à créer (MANDAT, une fois).
- Aucune dépense ; refus plus tôt des apps lourdes sur OKE (cohérent avec ADR-0003/0004).
- Coût agents mesuré en durée/tours, pas en euros.

## Alternatives écartées
- **OpenCost + FinOps Agent** : lourd sur OKE, pour un coût en euros nul.
- **Budgets en euros seulement** : alerte après coup ; OCI facture avant coupure.
- **Plafond dur par API** : OCI/GCP n'en offrent pas ; les quotas OCI sont le seul plafond dur disponible.

## Vérification
- Test CI : une `app.yaml` avec volume sur OKE ou `expose: lb` est refusée (un test par refus).
- Preuve runtime datée : sortie `cost-evidence.v1` (volumes, quotas, R2 Go/objets, séries, minutes CI) PASS/FAIL.
- Test de lint : le registre `free-tier.yaml` n'a aucune ligne périmée.

## Références
`docs/research/COST-FREE-TIER.md`, homelab-infra `docs/state/billing.md`, `terraform/oracle-a1/main.tf` (quotas).

_Source et détails : `docs/research/COST-FREE-TIER.md`. Texte proposé par la recherche du 2026-11-18, intégré tel quel ; à revoir par la revue adverse._
