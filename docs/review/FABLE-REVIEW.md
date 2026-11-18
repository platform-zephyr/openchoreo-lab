# Revue indépendante n°3 (Fable) — pilote, étape FINAL, porte (2026-11-18)

Conclusion : **le pilote ne peut pas démarrer tel qu'écrit** (4 BLOQUANT) ; **FINAL ne suffit pas** (il vérifie un état final et
arrive après les données réelles) ; **la porte mono-cluster ne discrimine plus** (C2 et C4 passent par construction, C5 sans seuil).
Preuve : STATIC (lecture ; aucun cluster, aucun run). Lu en plus : `.github/`, `tools/backlog/`, `tools/apply-branch-protection.sh`.

## 1. Le pilote 24 h (T-322) peut-il démarrer ? Non, pas avec les prérequis listés.

**P1 — BLOQUANT — L'exécutant ne peut pas pousser de fichier de workflow.** `claude-agent.yml` pousse avec le jeton de l'App Claude,
sans permission `workflows` : GitHub refuse tout push qui touche `.github/workflows/`. 5 des 20 tickets y écrivent (T-002, T-070,
T-216, T-321, T-314) et T-002 est la racine de 5 autres. NOT_PROVEN ici ; limite documentée de l'action. *Correction* : essai daté
avant le pilote ; s'il échoue, ces 5 tickets sortent de la liste (sessions de Paul) et sont remplacés.

**P2 — BLOQUANT — Les outils du backlog ne tournent que sur une machine.** `tools/backlog/check.py:3`, `roadmap.py:3,66,114` et
`seed.py:2,297,948` codent en dur `/home/user/openchoreo-lab`. Sur un runner, `check.py` lit zéro ticket (vert à vide) et `next.py`
(T-210), bâti dessus, ne voit rien. *Correction* : critère ajouté à T-008 : racine déduite de `__file__` ; « 0 ticket lu » = échec.

**P3 — BLOQUANT — La règle « ADR ACTÉ avant tout ticket » vide la liste.** `docs/adr/README.md` l'impose ; T-061 n'acte que 0002 et
0021 ; au moins 15 des 20 tickets citent 0001, 0003, 0005, 0006, 0012, 0013 ou 0022, actés par T-061b, déclaré « ne bloque pas le
pilote ». T-330 (S0) cite 0022. *Correction* : Paul acte T-061 et T-061b dans la même séance, ou ADR-0021 écrit l'exception.

**P4 — BLOQUANT — Le pilote mesurera la latence de Paul, pas le quota.** 11 REVUE sur 20, dont les racines des chaînes (T-002 → 5
tickets ; T-332 → T-337 REVUE → T-340/T-341). L'exécutant n'a pas `gh pr merge` et T-315 est hors liste : Paul fusionne 20 PR à la
main. Dès sa première nuit les 3 slots sont vides. T-322 demande aussi « 6, 10, 15 sessions », interdit par ADR-0021 §2.
*Correction* : ≥ 14 AUTONOME sans racine REVUE ; T-002 et T-332 fusionnés avant l'heure 0 ; merge squash autorisé à l'exécutant
pour la classe AUTONOME recalculée ; test de concurrence après les 24 h.

**P5 — MAJEUR — « Concurrence 3 par le groupe de concurrence » (T-311) n'existe pas.** Un groupe GitHub Actions admet 1 run actif
et 1 en attente ; le suivant annule celui qui attend : des tickets sont perdus sans erreur. *Correction* : trois groupes
`factory-slot-{0,1,2}` ou une matrice `max-parallel: 3` ; test : 5 dispatchs, 5 runs terminés.

**P6 — MAJEUR — Quota : mesure polluée, aucun disjoncteur.** Le jeton d'abonnement est partagé avec les sessions de Paul et le moteur
horaire d'Atlas/homelab-infra ; 13 tickets sur 20 sont en Opus `high` ; le ledger (T-326) et la reprise (T-317) sont dans la liste,
donc absents pendant la mesure. Plafonds actuels : 45 min, 60 tours, trop courts pour T-002 ou T-214. *Correction* : autres moteurs
arrêtés 24 h ; un résultat « limit » arrête le lot sans relance ; quota relevé toutes les 5 h ; plafonds par classe dans T-313.

**P7 — MAJEUR — Conflits de fichiers sans contrôle de chevauchement.** L'admission est dans T-314, lui-même dans la liste. T-041
(`AGENTS.md, STATE.md, docs/, tools/, tests/`) et T-070 (`tools/, tests/, .github/workflows/`) recoupent presque tout. `AGENTS.md`
impose `STATE.md` à chaque jalon : 20 PR sur un fichier ; `ROADMAP.md` est généré. *Correction* : T-041 et T-070 hors pilote ;
`STATE.md` et `ROADMAP.md` interdits aux exécutants (régénérés sur `main`) ; test de recoupement des globs des 20 tickets avant l'heure 0.

## 2. FINAL suffit-il ? Non. Cinq choses ne se rattrapent pas après coup.

**F1 — BLOQUANT — FINAL arrive après les données réelles.** Il suit I8 ; avant lui passent sauvegardes (I1), secrets (I2), Authentik
(I6), services IA (I7), exposition publique (ADR-0010) et migration kube-ops. ADR-0002 amendé ne lie FINAL qu'à la phrase
« plateforme finie ». *Correction* : scinder. **FINAL-0** (identité de T-215, T-400, rotation F3) devient dépendance du premier ticket
qui apporte une donnée réelle, une identité réelle ou une exposition publique, au plus tard avant I1. FINAL garde T-007, T-401, T-402.

**F2 — BLOQUANT — L'historique git public se réécrit de plus en plus mal.** T-301 est sans date ; T-401 ne l'exige que « si Paul l'a
fait ». Chaque jour d'usine ajoute PR, branches, SHA cités dans les preuves (`backlog/evidence/`, trailers, `release-history`) et
commits sous l'e-mail de Paul ; les copies (forks, archives) ne se purgent pas. *Correction* : T-301 avant l'heure 0 (aucune PR
d'agent ouverte) ; `noreply` et trailers dans T-313 dès S0 ; critère T-401 sans condition ; ce qui a fuité est changé, pas effacé.

**F3 — BLOQUANT — Ni inventaire ni rotation des secrets créés en mode relâché.** T-066 est `dropped` ; T-401 dit « secrets » sans
méthode. Tout credential lisible par un agent aux droits étendus est à tenir pour compromis (jeton d'abonnement, jeton ESO et
kubeconfig du lab, service token Access de T-006, jeton de statut de T-005, secrets machine Talos). *Correction* : registre
`docs/state/identities.yaml` (nom, portée, date ; noyau) tenu dès la première création ; ticket FINAL « rotation de tout le registre ».

**F4 — BLOQUANT — Un cluster administré par des agents ne se durcit pas : il se reconstruit.** T-364 installe un CP « définitif », par
un installateur hors Argo (T-366), en accès admin. Rien ne prouvera l'absence d'un ClusterRoleBinding, d'un webhook, d'un jeton de
ServiceAccount ou d'une CRD posés à la main ; aucun ticket FINAL ne touche le cluster. *Correction* : critère FINAL « VM lab recréée
depuis Git, secrets machine et CA neufs, données restaurées (T-026), `_checks` PASS, diff RBAC/CRD/webhooks vide contre le rendu
Git ». Dès maintenant : Kyverno et VAP en `enforce` avant la première app (T-363 les laisse en audit) ; T-362 jamais allégé.

**F5 — MAJEUR — Le noyau n'a plus de référence de confiance.** Sous l'identité de Paul, l'auteur ne peut pas approuver sa PR : toute
PR du noyau passe par `bypass_actors`, sans trace de revue. ADR-0002 amendé §3 devient invérifiable. T-401 relit un état, par une
session de la même famille que les auteurs. *Correction* : tag signé `core-baseline` avant le pilote ; T-401 relit le diff depuis ce
tag sur les chemins CODEOWNERS et la liste des merges par contournement ; les PR du noyau passent par l'exécutant (auteur bot).

## 3. La porte (ADR-0020) en mono-cluster peut-elle rendre une décision juste ? Pas avec C1-C5 actuels.

**G1 — BLOQUANT — C2 et C4 révisés passent par construction.** C2 (plafond OKE : 70 %, 33 pods) devient « dans le budget du homelab »,
budget fixé par T-360 après la levée des contraintes : aucun seuil. C4 (reconnexion entre clusters) devient le redémarrage d'un agent
co-localisé. Deux critères sur cinq ne peuvent plus dire « abandonner ». *Correction* (T-061b, avant toute mesure) : **C2** = surcoût
d'OpenChoreo par rapport au backend plain sur la même VM, seuil chiffré (par ex. ≤ 4 Gio de requests et ≤ 25 pods). **C4** = jour 2 :
montée d'un patch avec reconstruction du bundle amd64, et CP reconstruit depuis Git sur VM vide, apps Ready, durée ≤ seuil.

**G2 — BLOQUANT — C5 n'a pas de seuil ; le biais joue dans les deux sens.** En mono-cluster la valeur propre d'OpenChoreo (multi data
plane) est hors mesure alors que tous ses coûts y sont : le plain gagne par construction. À l'inverse, T-364 dit « définitif », T-006
(gelé par ADR-0020 §5) est dégelé avec trois MANDAT, et une trentaine de tickets S1 pèsent pour « adopter ». *Correction* : C5
chiffré (« abandonner » si le plain passe la même suite `_checks` avec ≥ 30 % de lignes et de tickets propres en moins) ; **C6** :
≥ 2 capacités d'OpenChoreo utilisées par les 5 intentions et absentes du plain (release épinglée par environnement, cellule isolée
par défaut, statut lu par API) ; T-006 limité à l'option (b) avant la porte ; « définitif » retiré de T-364.

**G3 — MAJEUR — Protocole de mesure injuste.** (a) L'horloge part de T-363 pour les deux voies, mais OpenChoreo attend T-366 et T-364
(MANDAT) et un MANDAT de plus de 48 h vaut échec : un retard de Paul peut faire « abandonner ». (b) Mesure séquentielle : le second
moteur hérite des corrections du premier. (c) T-044 ne mesure que l'archétype A et ne cite qu'OpenChoreo ; le catalogue réel (T-050)
n'entre pas dans la porte. *Correction* : horloge par voie, en heures d'agent, depuis ses propres prérequis ; ordre croisé (3
intentions OpenChoreo d'abord, 2 plain d'abord) ; T-044 pour les deux moteurs ; **C7** : part du catalogue kube-ops couverte (T-050).

**G4 — MAJEUR — Le repli du 2026-11-25 décide sur une autre plateforme.** Mesurer C1 et C5 sur OKE (arm64, CP sur OKE) contredit D11 et
« k3d ≠ OKE » ; C2 et C4 restent non mesurés. Le chemin compte 9 vagues et au moins 6 MANDAT pour une décision à J+16 ; T-140 (free
tier OKE) bloque T-211 sans rapport. *Correction* : repli = report (2026-12-11), jamais changement de plateforme ; T-140 retiré de T-211.

## Les 5 corrections à faire en premier
1. **Essai réel de l'exécutant avant l'heure 0** (push d'un workflow, `check.py` sur runner) et chemins absolus corrigés (P1, P2).
2. **Refaire la liste figée** : ≥ 14 AUTONOME sans racine REVUE, T-041 et T-070 dehors, 3 slots réels, T-061 et T-061b ensemble (P3-P7).
3. **Faire maintenant ce qui ne se rattrape pas** : T-301 avant le pilote, `noreply`, tag `core-baseline`, `identities.yaml` (F2, F3, F5).
4. **Scinder FINAL** : FINAL-0 avant la première donnée réelle ; rotation complète et cluster reconstruit depuis Git (F1, F3, F4).
5. **Amender ADR-0020 avant toute mesure** : C2 différentiel, C4 jour 2, C5 chiffré, C6, C7, horloge par voie, repli = report (G1-G4).
