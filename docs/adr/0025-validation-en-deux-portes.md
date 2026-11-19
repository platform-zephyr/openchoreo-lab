# ADR-0025 — Validation d'OpenChoreo en deux portes : valeur pour les agents sur OKE, puis exploitation hybride
Statut : ACCEPTÉ (décision de Paul du 2026-11-19, relayée par le coordinateur ; PR de T-508) · Proposé : 2026-11-18 ·
Décideur : Paul
Décisions liées : ADR-0003 (amendé), ADR-0011, ADR-0017, ADR-0020 (amendé), ADR-0021, ADR-0022 (amendé) ; `docs/research/POC-OPENCHOREO-STRATEGY.md`

## Contexte
- Paul veut valider d'abord qu'OpenChoreo simplifie le modèle opérationnel des agents, avec OKE comme environnement
  jetable, puis migrer vers un déploiement hybride, sans perturbation du homelab pendant la validation.
- Arbitrages de Paul du 2026-11-18 (`docs/review/CONSENSUS-2.md`, n°3) : Mac Apple Silicon M1 ; Colima permis ;
  OKE sans donnée importante ; discontinuité de service et perte de données acceptées sur OKE et en local ; voie
  d'intégration indifférente, la vitesse prime ; s'appuyer sur la livraison Argo CD de kube-ops si cela accélère ;
  les agents doivent publier le statut sans le compte de Paul.
- ADR-0020 (amendement Fable, point 7) interdit toute mesure sur OKE et exige 4 gestes MANDAT avant la première
  mesure de valeur. OpenChoreo tourne déjà sur OKE avec le bundle arm64 (pilote `whoami` PASS le 2026-11-17).
- Le vrai comparateur est le chemin kube-ops (`apps-generated`, chart `platform-app`, Kustomize pour le reste).

## Décision
1. **Porte 1 « valeur pour les agents »** : banc A/B **minimal** préenregistré sur **OKE recréé vierge** : 4 tâches
   (M1-M4), 3 pièges, 2 runs par tâche et par bras, seuils S1, S2, S3, S5, S6, S7 de la stratégie §2.4. Bras K = chemin
   kube-ops reproduit dans un bac à sable figé ; bras O = ce dépôt. Même cluster, même Argo, même canal d'observation.
   La répétition sur le MacBook est remplacée par une **passe 0 non comptée sur OKE**.
2. **Seuils figés avant la mesure** (commit de `tests/bench-ab/thresholds.yaml`). Verdict : « valeur prouvée » si S1,
   S6 et S7 passent et au moins 2 de S2, S3, S5 ; sinon **arrêt** (on garde kube-ops), sans zone grise.
   **Arrêt anticipé** dès qu'un seuil devient inatteignable ; un piège non contenu par le bras O arrête tout.
   « Médiane agrégée » (S2, S3) = médiane sur tous les runs d'un bras, toutes tâches confondues. S2 et S3 ne passent
   que si **tous** leurs critères passent (S2 : fichiers et lignes ; S3 : tours et $).
3. **Livraison** : un Argo CD par cluster en mode pull. Pendant la porte 1, c'est l'Argo du labo, seul sur OKE ; il
   livre la plateforme, `generated/` (un ApplicationSet par app, modèle kube-ops) et le bras K (copie de l'ApplicationSet
   `apps-generated`). L'instance Argo de kube-ops n'est pas utilisée et le dépôt kube-ops n'est pas modifié. Cible
   après la porte 2 : l'Argo du cluster est amorcé par kube-ops, qui porte une seule Application vers ce dépôt.
4. **Statut** : publié dans GitHub par Argo CD Notifications (service `github`, check run par app et par révision),
   signé par une GitHub App dédiée aux statuts (Checks et Commit statuses seulement). La clé de l'App de l'usine
   n'entre jamais dans un cluster.
5. **OKE** : recréé vierge par ARC dans homelab-infra, décision consignée dans le journal de homelab-infra dans la même
   PR ; aucune session de ce dépôt n'écrit hors `openchoreo-*` et `lab-*`. Coût : 0 € ; tout dépassement est un MANDAT.
6. **Surface cloud en lecture seule** : le MCP OpenChoreo (rôle reader de `platform/authz/`) est joignable depuis les
   sessions cloud par Cloudflare Tunnel + Access (`Service Auth`, un service token par identité d'agent, injecté par
   le proxy de l'environnement cloud), sur OKE d'abord (T-006). L'apiserver n'est jamais exposé ; aucune écriture
   par cette surface ; le banc ne l'utilise pas. L'exécution cluster depuis le cloud reste NOT_TESTED (essai T-493) ;
   la session locale du Mac reste le chemin d'exécution.
7. **Porte 2 « exploitation hybride »** (T-211) : seulement si la porte 1 est positive (VM lab, amd64, jour 2, règle de
   routage). D11 reste la décision par défaut. Aucune migration d'app de kube-ops avant la porte 2.

8. **Adoption anticipée dès la passe 0 (Q26)** : OpenChoreo est adopté à l'issue de la passe 0 (verdict de la porte 1
   = « valeur prouvée »), sans campagne comptée, si les trois conditions sont réunies : (1) les 3 pièges sont contenus par le bras O ; (2) le bras O
   réussit M1, M2, M3 et M4 ; (3) le bras K échoue au moins une tâche pour une raison **structurelle**, documentée
   dans le rapport de la passe 0 (cas attendu : M3). Sinon, la campagne comptée (point 2) a lieu sans changement. La porte 2 reste exigée.
   Une raison structurelle tient au modèle du bras (capacité absente), pas à une erreur ponctuelle de l'agent ni à
   un défaut du harnais.
9. **M3 sans non-prod côté K (E6)** : si le chemin kube-ops reproduit n'a pas d'environnement hors production, cette
   absence est une **mesure défavorable au bras K**, consignée telle quelle. On n'invente pas de non-prod pour le
   bras K et on ne développe rien sur kube-ops pour le combler.
10. **Fidélité à l'implémentation native** : OpenChoreo est utilisé au plus près de son implémentation native ; aucune
   complexité maison qui n'est pas justifiée. Jusqu'à la décision « façade `app.yaml` ou objets natifs », prise
   juste après la porte 1, aucune ligne nouvelle n'entre dans `tools/appgen/` ni dans `tools/oke/argo_guard*`
   (suppression permise). Suivi : `docs/research/FIDELITE-JOURNAL.md`.

## Amendements (écrits dans les ADR concernés par T-508, 2026-11-19)
- **ADR-0020** : le point 7 de l'amendement Fable (« aucune mesure sur OKE ») est remplacé par le point 1 pour C1, C5
  et C6 ; C5 compare OpenChoreo au chemin kube-ops reproduit ; la décision se prend en deux temps.
- **ADR-0003** : « OKE devient optionnel » est complété par « OKE est l'environnement jetable du POC pendant la
  porte 1 ».
- **ADR-0022** : Colima est permis sur le Mac de Paul pour ce dépôt seulement (repli et k3d local) ; un résultat k3d
  reste NOT_TESTED pour OKE.

## Conséquences
- Q26 peut raccourcir la porte 1 : T-488 (campagne comptée) n'a lieu que si la règle d'adoption anticipée ne
  s'applique pas.
- Tickets : T-485 (protocole minimal), T-486 (passe 0 sur OKE), T-487 (installation sur OKE vierge), T-488 (campagne
  comptée et décision), T-489 (App de statut), T-490 (arbitrages au journal de homelab-infra et OKE recréé), T-491
  (ApplicationSet du bras O), T-492 (branchement cible sur l'Argo de kube-ops), T-493 (essai d'exécution depuis le
  cloud) ; T-006 recadré (check runs + MCP derrière Tunnel + Access). T-212 = bras K ; T-005 = Notifications.
- Un PASS de la porte 1 ne prouve ni l'amd64, ni le multi-cluster, ni les données réelles, ni le jour 2.

## Alternatives écartées
- **VM lab d'abord** : mesure la topologie avant la valeur ; 4 gestes MANDAT engagés à l'aveugle.
- **Répétition sur le MacBook** : un jour de plus pour une preuve k3d, alors qu'OKE est jetable.
- **Brancher OpenChoreo sur l'instance Argo de kube-ops pendant le POC** : PR croisées, AppProject `oracle-a1`
  appliqué par l'opérateur et sans kinds cluster-scoped ; `apps-generated` sur `main` déploie sur le homelab.
- **Publier le statut avec l'App de l'usine** : sa clé donnerait au cluster l'écriture de code et de workflows.
- **apiserver derrière Access** : exige kubectl et un jeton d'API chez l'agent, expose le chemin d'administration ;
  une erreur de RBAC expose les Secrets.
- **Banc de 30 runs** : même décision attendue pour plus de temps ; la sûreté garde une tolérance nulle.

## Vérification
- `tests/bench-ab/thresholds.yaml` commité avant le premier run compté (horodatage Git).
- Rapport daté `docs/research/POC-AB-RESULTS.md` (S1-S7 par bras, preuves RUNTIME OKE) ; décision de Paul consignée ici
  par amendement.
- Adoption anticipée (point 8) : le rapport de la passe 0 cite, par condition, la preuve RUNTIME OKE datée, et pour
  la condition (3) la raison structurelle de l'échec du bras K.

## Acceptation (2026-11-19)
Source : décision de Paul du 2026-11-19, relayée par le coordinateur ; la formulation exacte de Paul est dans la PR de
T-508 et le message du coordinateur, non recopiée ici. Paul accepte en séance de questions (Q7, Q8, Q9) : les deux
portes, le banc A/B minimal, les seuils S1-S7 et la règle de verdict (points 1 et 2). Il ajoute Q26 (point 8), la
règle sur M3 (point 9) et le gel des couches maison (point 10). Il confirme le cap : utiliser OpenChoreo au plus près
de son implémentation native, sans complexité inutile pour l'implémentation finale.
