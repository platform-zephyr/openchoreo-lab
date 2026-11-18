# ADR-0020 — Porte d'adoption d'OpenChoreo
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0001 (contrat indépendant du moteur), ADR-0003, ADR-0004 ; `docs/review/CONSENSUS.md`

## Contexte
- L'adoption d'OpenChoreo n'est pas tranchée, alors qu'une vingtaine de tickets ne servent qu'à lui et qu'il coûte cher
  sur des nœuds uniques : control plane, agents de data plane, bundle de sécurité privé, chemin NetBird, budget OKE serré.
- Une alternative plus simple existe : le contrat `app.yaml` rendu par un backend « plain » (chart commun inspiré de
  `platform-app` de kube-ops + Argo par cluster).
- La revue adverse du 2026-11-18 recommande de mesurer avant d'investir le reste du backlog.

## Décision
1. **Décision de Paul le 2026-12-04** (T-211), sur mesures datées, entre « adopter OpenChoreo » et « abandonner ».
2. **Adopter seulement si les cinq critères sont réunis** :
   - **C1** : 5/5 intentions A livrées sur le homelab par OpenChoreo, PASS runtime, délai médian intention → PASS
     ≤ 30 min, zéro geste du coordinateur ;
   - **C2** : nomenclature OKE mesurée ≤ 70 % des requests et ≤ 33 pods (CP, un seul Argo, cloudflared/NetBird, place
     réservée à OpenBao) ;
   - **C3** : bundle de sécurité retiré (correctif amont publié) ou reconstruction scriptée ≤ 2 h par patch ;
   - **C4** : data plane homelab reconnecté sans action après 3 coupures nocturnes ;
   - **C5** : le backend « plain » (T-212) n'est pas nettement plus simple (même suite `_checks`, même délai, lignes et
     tickets propres au moteur).
3. **Échec d'une voie** = pas d'app A Ready avec PASS runtime sur le homelab après 3 jours d'agent, ou un blocage qui
   exige un MANDAT non obtenu sous 48 h.
4. **Règles si une voie échoue** :
   - T-030 (OpenChoreo) échoue et T-212 réussit → « abandonner » par défaut (C4 en échec, alternative prouvée) ;
   - T-030 réussit et T-212 échoue → évaluation C1-C4 sans C5 ;
   - les deux échouent → un seul report d'une semaine ; si le second essai échoue, **Paul choisit** entre MVP temporaire
     sur OKE, réparation du socle homelab ou abandon. Aucune décision automatique.
5. **Jusqu'à la porte**, les tickets propres à OpenChoreo sont `deferred` (MCP via Access, Atlas, montées OpenChoreo,
   bundle, observability plane, portail Backstage 6b, migration kube-ops…).

## Conséquences
- Si « abandonner » : `app.yaml` + `appgen plain`, un Argo par cluster, OKE réduit à l'identité, OpenBao et cloudflared ;
  les tickets propres à OpenChoreo passent `dropped`.
- Si « adopter » : dégel des tickets `deferred`, par incréments.

## Alternatives écartées
- **Tout construire sur OpenChoreo sans porte** : risque de 120 tickets sur un choix non validé.
- **Abandonner tout de suite** : la valeur d'OpenChoreo (modèle déclaratif, multi data plane, MCP) n'a pas été mesurée.

## Vérification
- Rapport daté de T-211 avec C1-C5 mesurés, sources et preuves ; décision de Paul consignée dans cet ADR (amendement).

## Amendement (consensus n°2 et arbitrages de Paul, 2026-11-18)
Source : `docs/review/CONSENSUS-2.md` (décision 5, arbitrage 2).
1. **La porte évalue OpenChoreo en mono-cluster.** Le CP et le DP sont sur la VM lab du homelab (D11 tranché, ADR-0003
   amendé). Elle ne mesure pas la valeur multi-cluster d'OpenChoreo ; si Paul veut des apps sur OKE, une porte bis (T-030)
   la mesurera.
2. Critères révisés : **C2** = requests du CP et du DP mesurées sur la VM lab, dans le budget du homelab (T-360, T-364) ;
   **C4** = reprise sans action du cluster lab après redémarrage (T-031). C1, C3 et C5 inchangés.
3. **§4 : T-364 remplace T-030** dans les règles en cas d'échec d'une voie.
4. **Horloge** : les 3 jours d'agent du §3 partent de T-363 `done` (socle de la VM lab prêt), pas de l'ouverture du ticket.
   Les deux moteurs sont mesurés sur la même VM, avec les mêmes apps, l'un après l'autre.
5. **Repli** : si la VM lab n'est pas Ready le **2026-11-25**, C1 et C5 sont mesurés sur OKE pour les deux moteurs (CP déjà
   installé). La date de décision reste le 2026-12-04, avec un seul report possible au 2026-12-11.
