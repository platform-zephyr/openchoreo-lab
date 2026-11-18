# Arbitrage de la revue Fable (2026-11-18, nuit)

Entrée : `docs/review/FABLE-REVIEW.md` (10 BLOQUANT, 6 MAJEUR). Arbitrage du coordinateur, dans le cadre des arbitrages de
Paul (mode dev à sécurité allégée, sécurité finale exigée, vitesse). Proposition à Paul via la PR.

| Constat | Décision |
|---|---|
| P1 jeton sans permission `workflows` | **Accepté.** Nouveau ticket S0 « essai réel de l'exécutant avant l'heure 0 » (push d'un workflow, `check.py` sur runner). En mode dev, l'exécutant utilise une identité qui a la permission `workflows` (App ou jeton fin de Paul, accepté par l'arbitrage 7) ; à FINAL, elle est remplacée. |
| P2 chemins absolus dans `tools/backlog/` | **Accepté, corrigé tout de suite** (chemins relatifs à la racine du dépôt). |
| P3 ADR non actés pour 15 tickets du pilote | **Accepté autrement** : la fusion de la PR #48 acte d'un coup les ADR 0001-0023 avec leurs amendements ; T-061 et T-061b sont `done` à cette fusion. |
| P4 11 tickets REVUE, pas de merge par l'exécutant | **Déjà levé par l'arbitrage 7** (revue des code owners désactivée en dev) : en dev, REVUE = merge après `ci-ok`. L'exécutant active l'auto-merge GitHub. Le test à 6, 10, 15 sessions est retiré de T-322 (paliers décidés par Paul, ADR-0021). |
| P5 concurrence 3 inexistante | **Accepté** : concurrence par matrice `max-parallel: 3` ou par groupe par couloir, pas un groupe unique. |
| P6 quota partagé | **Accepté** : pendant le pilote, le moteur horaire d'Atlas/homelab-infra est mis en pause et l'usage de Paul noté ; le ledger minimal (T-326) entre dans les prérequis ; plafonds portés à 90 min / 150 tours pour Opus. |
| P7 chevauchement | **Accepté** : contrôle de chevauchement minimal dans T-210 ; T-041 et T-070 sortent de la liste du pilote ; `STATE.md` et `ROADMAP.md` ne sont écrits que par le coordinateur. |
| F1 FINAL trop tard | **Accepté** : étape **FINAL-0** avant la première donnée réelle ou exposition publique (identité d'usine, retrait du contournement, rotation des secrets créés en dev, revue des code owners réactivée sur `platform/authz`, `platform/policies`, `security/`). |
| F2 réécriture d'historique | **Fait par Paul** (historique réécrit le 2026-11-18). `noreply` et trailers imposés par T-313 dès S0. |
| F3 inventaire des identités | **Accepté** : registre `docs/state/identities.yaml` (noms, rôles, date, jamais de valeur) tenu dès maintenant ; ticket FINAL de rotation complète. |
| F4 cluster administré en mode admin | **Accepté** : critère FINAL « VM lab recréée depuis Git, secrets neufs, diff RBAC/CRD/webhooks vide » ; VAP et Kyverno en `enforce` sur le lab avant la première app ; isolation réseau du lab (T-362) jamais allégée. |
| F5 traçabilité du noyau | **Accepté** : tag `core-baseline` avant le pilote, diff relu à FINAL ; PR du noyau ouvertes par l'exécutant (auteur bot). |
| G1-G2 C2/C4/C5 sans seuil, biais | **Accepté** : C2 = surcoût d'OpenChoreo vs plain (défaut proposé : ≤ 4 Gio et ≤ 25 pods) ; C4 = « jour 2 » (montée de patch avec bundle amd64, CP reconstruit depuis Git) ; C5 chiffré (plain pas plus de 30 % moins coûteux en lignes/tickets propres au moteur) ; C6 = capacités OpenChoreo réellement utilisées ; T-006 limité au statut publié dans GitHub et à la lecture API. Seuils proposés par défaut, ajustables par Paul. |
| G3 horloge et ordre | **Accepté** : horloge par voie, ordre de mesure croisé, banc T-044 pour les deux moteurs, C7 = couverture du catalogue kube-ops (T-050). |
| G4 repli sur OKE | **Accepté** : le repli du 2026-11-25 devient un **report** de la porte, pas une mesure sur OKE ; T-140 retiré des dépendances de T-211. |
