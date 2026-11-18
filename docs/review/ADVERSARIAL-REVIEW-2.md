# Revue adverse n° 2 : intégration 2, usine 24/7, VM lab, routage des modèles

Date : 2026-11-18 (soir). Lecture seule, aucun cluster touché, rien de commité.
Entrées lues : `backlog/INTEGRATION-2.md`, `backlog/ROADMAP.md`, `docs/review/CONSENSUS.md`, `docs/adr/0020-*.md`, les tickets T-061, T-211, T-300 à T-303, T-311, T-322, T-361, T-362, T-364 et T-031, `docs/research/{HOMELAB-CAPACITY-DATAPLANE,MODEL-ROUTING}.md`, `docs/SECURITY-BUNDLE.md`, `.github/`, `MISSION.md`, `STATE.md`.
Étiquettes : **[B]** BLOQUANT · **[M]** MAJEUR · **[m]** MINEUR · [V] = à vérifier.

## Verdict (5 lignes)
1. Le plan a regrossi. Avant la porte, il y a 68 tickets (S0 24 + S1 19 + S2 9 + S3 16) contre 14 au consensus. Environ 30 d'entre eux construisent l'usine elle-même, pas le produit. La date de la porte, le 2026-12-04, n'est plus tenable avec ce périmètre.
2. Le pilote 24 h peut démarrer avec **12 tickets**. Il n'a besoin ni de la VM lab, ni du routage, ni du harness complet. Il a besoin d'une identité qui ne soit pas celle de Paul, d'un historique réécrit et d'un interrupteur d'arrêt.
3. La VM lab avec le control plane co-localisé rend la porte plus rapide à mettre en place. Mais elle vide C2 et C4 de leur sens et ne mesure plus la valeur multi-cluster d'OpenChoreo. Il faut le dire dans ADR-0020 et mesurer C2-OKE sur l'installation qui existe déjà.
4. Deux nouveaux risques bloquants ne sont dans aucun ticket. L'image corrigée du contrôleur est arm64 alors que la VM lab est x86_64. Et un dépôt privé perd peut-être les runners arm64 gratuits.
5. Le routage des modèles est utile, mais son plancher de sécurité est modifiable par un agent. DeepSeek doit rester hors du travail sur ce dépôt.

## 1. Taille, S0 et lancement de l'usine
- **[B] Le pilote utilise encore l'identité de Paul.** Les sessions cloud et les routines commitent avec l'identité GitHub de Paul. Le ruleset garde le rôle admin en `bypass_actors` (`apply-branch-protection.sh` l.29). Une usine 24/7 qui tourne sous l'identité de Paul rend inutiles CODEOWNERS et le noyau. Il faut que T-215 soit fait **et** que le contournement admin soit retiré du ruleset avant le premier lancement automatique. Paul le réactive à la main, ponctuellement, quand il en a besoin.
- **[M] S0 à 24 tickets n'est pas crédible pour un lancement rapide.** Le chemin vers T-322 traverse T-061, qui doit acter 15 ADR dont 3 encore à rédiger. Il traverse aussi la réécriture, T-311, T-313 et T-215. Une bonne partie de S0 n'est pas nécessaire au pilote :
  - T-382, T-325, T-332, T-334, T-041 ;
  - T-360, T-361, T-362 (VM lab), qui ne servent que la porte ;
  - T-001, T-002 et T-217, qui servent les changements de plateforme et non un pilote sur des tickets sans cluster.
- **[M] La boucle méta.** L'usine fabrique des tickets d'usine : T-346 (banc de 20 à 30 tâches), T-386 (étalonnage), T-323, T-352, T-342, T-343, T-318 et T-320 sont tous avant la porte. Le produit (une app avec preuve) recule derrière son outil. Règle proposée : avant la porte, un ticket d'usine n'entre que s'il supprime un geste de Paul mesuré pendant le pilote.
- **[M] Le pilote ne mesure que ce qu'on lui donne.** Il lui faut au moins 20 tickets AUTONOME sans cluster dont les critères de fin sont exécutables. Candidats : T-214, T-072, T-338, T-140, T-050, T-008, T-070, T-337 et la doc. Sans cette liste figée à l'avance, le tableau de T-322 reste vide ou biaisé.
- **[m] Le plafond de 4 agents est déjà dépassé dans le plan.** CONSENSUS n°11 fixe 4 ; T-322 prévoit d'aller à 6 puis 8-10. C'est acceptable, mais seulement par ADR-0021 et décision de Paul, avec des seuils écrits.

**S0 minimal pour lancer le pilote (12 tickets)**, dans cet ordre :

| Ordre | Tickets | Contenu |
|---|---|---|
| 1 | T-300 → T-303 → T-302 → T-301 | Dépôt privé, garde de fuite, corrections de l'arbre, réécriture. La fenêtre privée dure une journée. |
| 2 | T-215 + ruleset | Identité agent et retrait du contournement admin. |
| 3 | T-061a | ADR-0002 et ADR-0021 réduit (règles du pilote), plus 3 lignes dans MISSION. Les autres ADR passent en T-061b, en parallèle du pilote. |
| 4 | T-008, T-007 | Garde du format des tickets et test du noyau. |
| 5 | T-313 minimal | `workflow_dispatch` avec ID, modèle et effort ; sortie `mission-result.v1`. |
| 6 | T-210 minimal | `next.py` ; la liste reste fournie par Paul. |
| 7 | T-311 minimal | Fichier `factory/PAUSE` et groupe de concurrence de 3. Le registre de consommation se construit pendant le pilote. |
| 8 | T-330 | Liste `deny` et sandbox. |

Le reste de S0 passe en S1 ou en voie parallèle (VM lab).

## 2. VM lab et control plane co-localisé pendant la porte
- **[B] L'image corrigée n'est pas construite pour la VM lab.** Le security bundle impose une image corrigée du contrôleur, et elle est **arm64** (`docs/SECURITY-BUNDLE.md` l.45). Le homelab est en x86_64. De plus, `helm_secure` (Helm 4 avec plugin de post-rendu) est le seul chemin d'installation autorisé, et Argo ne sait pas l'exécuter. T-364 ne dépend ni de T-001, ni d'une reconstruction amd64 du bundle, ni d'un installateur pour le lab. Le coordinateur n'a pas de kubeconfig lab : il est distribué par Doppler. La limite d'échec de 3 jours d'ADR-0020 §3 sera consommée par ce problème. Il faut ajouter un ticket « bundle multi-arch + installateur lab » et le mettre en dépendance de T-364.
- **[M] C2 devient trivial.** C2 mesuré sur une VM de 16 Gio ne dit rien de la décision D11 (control plane sur OKE ?). Si Paul choisit OKE à la porte, ce choix n'aura pas été mesuré. Contre-proposition :
  - trancher D11 dès maintenant à « lab » : le homelab est allumé 24 h/24, Authentik y tourne et OKE n'est qu'une option ;
  - sinon, mesurer **tout de suite** C2-OKE sur le control plane déjà installé (étapes 6 à 11), en lecture seule par le coordinateur.
- **[M] C4 ne teste plus le lien hybride.** Il se réduit à un redémarrage d'un agent interne au cluster. Avec un control plane et un data plane co-localisés, la valeur distinctive d'OpenChoreo (plusieurs data planes) n'est plus mesurée. C5 compare alors deux moteurs mono-cluster, ce qui favorise le backend `plain`. C'est honnête si l'usage réel est mono-cluster, mais ADR-0020 doit l'écrire : « la porte juge OpenChoreo en mono-cluster ; si Paul veut des apps sur OKE, il faut une porte bis (T-030) ».
- **[M] La comparaison doit être équitable.** Les deux moteurs tournent sur la même VM de 16 Gio. Il faut les mêmes apps, des mesures séquentielles et non simultanées, et une horloge de 3 jours qui démarre quand T-363 est fait, pas à l'ouverture du ticket.
- **[M] Le chemin vers la porte dépend d'un autre dépôt.** T-361 s'applique par ARC dans homelab-infra, avec ses propres règles. T-362 touche la configuration UniFi. Avec 3 MANDAT homelab sur le chemin critique, le 2026-12-04 est irréaliste. Repli proposé : si la VM lab n'est pas Ready le 2026-11-25, mesurer C1 et C5 **sur OKE** pour les deux moteurs. Le control plane y est déjà installé et whoami y a un PASS. Les deux moteurs sont alors comparés sur le même cluster.
- **[m] Écart d'architecture.** La CI et k3d tournent sur arm64, le homelab sur x86_64. Une preuve k3d ne couvre pas une image amd64 seule. Il faut une garde « image multi-arch » dans T-365 pour toute app éligible aux deux clusters.

## 3. Sécurité contre vitesse : faut-il attendre T-301 ?
- **Position : le pilote attend le force-push de la réécriture, pas la purge par le support GitHub.** Les branches créées avant la réécriture sont à refaire, donc il faut réécrire d'abord. La confirmation du support peut prendre des jours ; on n'attend que l'envoi de la demande. La réécriture doit être préparée par un agent et exécutée en une séance de Paul le jour 0 (environ 2 h).
- **[B, à vérifier] Un dépôt privé risque de casser la CI.** Toute la CI tourne sur `ubuntu-24.04-arm` (12 occurrences). Les runners arm64 standard sont gratuits pour les dépôts publics. En privé, ils sont payants ou absents [V], et le quota tombe à 2 000 minutes par mois. Un pilote lancé pendant la fenêtre privée échoue ou coûte. Règle : fenêtre privée = réécriture plus T-302/T-303 verts, puis retour public **avant** le pilote.
- **[M] La réécriture n'efface pas ce qui a déjà été copié.** Les forks, clones, GH Archive et Software Heritage gardent la copie. La vraie mesure est de **prévenir l'amont** que le détail a été public pendant N jours. Ce geste manque : il faut un critère dans T-301 ou un MANDAT dédié.
- **[m] Les fuites futures.** Il faut un hook local de config git (e-mail noreply) dans T-330 ou T-334, en plus de T-303 en CI, sinon l'e-mail professionnel revient au prochain commit d'une session.

## 4. Routage des modèles
- **[M] Le plancher de sécurité est modifiable par un agent.** `backlog/proposals/model-routing.yaml` et le champ `model:` des en-têtes sont hors CODEOWNERS. Un agent peut faire baisser un ticket du noyau d'Opus à Haiku. Comme pour la classe (CONSENSUS n°11), le modèle doit être **recalculé au dispatch** depuis les chemins. Les règles doivent passer dans le noyau, avec `factory/` (T-311, absent de CODEOWNERS), `docs/state/model-prices.yaml` et `docs/state/homelab-capacity.yaml` (seuils, ADR-0017 §9).
- **[M] « Plancher Opus = sécurité » est une fausse assurance.** La sécurité vient des gardes déterministes et d'une revue par un autre modèle (T-321), pas du modèle qui écrit. 45 tickets en Opus `high` risquent d'épuiser le quota hebdomadaire. La recherche montre aussi qu'Opus peut coûter moins par ticket que Sonnet (MODEL-ROUTING §1.1). Avant le pilote : une seule règle (noyau → Opus, reste → Sonnet `high`) et rien d'autre. T-382, T-386, T-388, T-390 et T-392 viennent après les données du pilote.
- **[M] L'escalade automatique de modèle (T-317) gaspille du quota.** La plupart des échecs viennent de la CI ou de l'environnement, pas du modèle. Il ne faut escalader que sur une classe d'échec « capacité » prouvée (deux échecs sur des critères de fin, CI verte par ailleurs).
- **[M] DeepSeek présente plusieurs risques.**
  - Ses conditions autorisent l'entraînement sur les entrées.
  - Une session Claude Code redirigée par `ANTHROPIC_BASE_URL` envoie **tout** le contexte : sorties d'outils, fichiers, journaux CI.
  - « Données publiques seulement » est faux pendant la fenêtre privée.
  - Il y a un piège d'alias : `claude-opus*` part sur `deepseek-v4-pro`, à 6,7 % au banc.

  Conclusion : jamais comme agent de code sur ce dépôt en v1. Seulement derrière agentgateway, pour des services internes, en I7, avec MANDAT de dépense. C'est déjà presque le cas, mais il faut l'écrire comme une interdiction dans ADR-0023.
- **[m]** Les ID figés (`claude-opus-5-5`) dans 134 en-têtes vieilliront. Il vaut mieux des alias `opus|sonnet|haiku`, résolus par le registre au dispatch.

## 5. Incohérences restantes
- **[M] MISSION et STATE ne sont toujours pas alignés.** `MISSION.md` (titre et objectif) et `STATE.md` (l.4) disent encore « IDP sur OKE ». STATE parle de « 88 tickets actifs » alors qu'il y en a 134.
- **[M] ADR-0020 n'est pas amendé.** Il garde « C2 OKE ≤ 33 pods », « C4 coupures nocturnes », et sa règle §4 repose sur T-030, désormais `deferred`. Cette règle doit viser T-364. Tant que T-061 n'est pas fusionné, un agent applique l'ancienne porte.
- **[M] Le consensus est contredit sans être amendé.**
  - CONSENSUS n°16 : MVP d'environ 14 tickets ; le plan en compte 68.
  - CONSENSUS n°7 : Argo unique et nomenclature OKE ; T-213 est maintenant `deferred`.
  - CONSENSUS n°11 : plafond 4 ; le plan va à 8-10.

  Il faut un `CONSENSUS-2` explicite, pas une dérive silencieuse.
- **[m] Autres écarts.**
  - T-364 ne dépend pas de T-001 alors qu'il installe le même chart avec bundle.
  - T-031 demande « kube-ops inchangé », ce qui n'est pas mesurable sans une ligne de base d'alertes.
  - T-061 exige que Paul tranche ADR-0023, ce qui suppose un ADR encore à rédiger : cela allonge le chemin critique.
  - Les questions 4 et 6 d'INTEGRATION-2 (taille de la VM du travailleur, abonnement) bloquent T-318 et T-322 sans date.

## Plan recommandé
- **J0 (une séance de Paul)** : T-300, réécriture (T-301, préparée), retour public, T-215 + ruleset sans contournement admin, T-061a, et décision D11 = lab ou mesure C2-OKE immédiate.
- **J1-J2** : S0 minimal (12 tickets), puis pilote 24 h à N=3 sur 20 tickets AUTONOME sans cluster, listés à l'avance. Une seule règle de modèle.
- **En parallèle** : VM lab (T-360 à T-363), puis un nouveau ticket « bundle amd64 + installateur lab », puis T-364 et T-212. Repli sur OKE le 2026-11-25 si le lab n'est pas Ready.
- **Avant la porte** : T-005, T-003, T-010, T-015, T-043, T-040, T-044, T-031 réduit, T-140. Tout le reste de S1 à S3 qui sert l'usine est différé, sauf ce que le pilote a montré comme supprimant un geste de Paul.
- **Porte** : reportée au 2026-12-11 si C1 n'est pas mesuré le 2026-12-04, une seule fois (règle de CONSENSUS n°4 inchangée).

## Changements concrets
1. **Ruleset** : retirer `bypass_actors` admin. Le pilote ne démarre qu'avec T-215 fait et aucun commit d'usine sous l'identité de Paul (vérifié dans T-007).
2. **S0 réduit à 12 tickets** (tableau §1). Passent en S1 ou en voie parallèle : T-001, T-002, T-041, T-217, T-325, T-332, T-334, T-382, T-331, T-360 à T-362.
3. **Scinder T-061.** T-061a = ADR-0002, ADR-0021 réduit et MISSION (prérequis du pilote). T-061b = les autres ADR, amendements d'ADR-0003 et ADR-0020, ADR-0022 et ADR-0023.
4. **Nouveau ticket T-366 « bundle multi-arch + installateur lab »** (MANDAT : dépôt privé), dépendance de T-364. Ajouter aussi T-001 en dépendance de T-364.
5. **Amender ADR-0020.**
   - Écrire que la porte évalue OpenChoreo en mono-cluster.
   - Trancher D11 = lab maintenant, sinon mesurer C2-OKE tout de suite sur l'installation existante.
   - Remplacer T-030 par T-364 dans la règle §4.
   - Faire partir l'horloge de 3 jours à T-363 `done`.
   - Repli de mesure sur OKE le 2026-11-25.
6. **Fenêtre privée bornée.** Pas de pilote ni de CI lourde en privé. T-301 : critère « amont prévenu de l'exposition » et réécriture exécutée en une séance au J0, sans attendre la confirmation du support.
7. **CODEOWNERS** : ajouter `/factory/`, `/backlog/proposals/model-routing.yaml` (ou son emplacement final), `/docs/state/model-prices.yaml` et `/docs/state/homelab-capacity.yaml`. Le dispatcher recalcule le modèle depuis les chemins et ignore le `model:` de l'en-tête quand il est sous le plancher.
8. **ADR-0023.**
   - Une seule règle (noyau → Opus, reste → Sonnet `high`) jusqu'aux données du pilote.
   - Alias de modèles plutôt qu'ID figés.
   - DeepSeek interdit comme agent de code sur ce dépôt.
   - Escalade T-317 seulement sur échec de capacité.
   - Différer T-382, T-386, T-388, T-390 et T-392 après le pilote.
9. **Règle de l'usine dans ADR-0021.**
   - Avant la porte, un ticket d'usine n'entre que s'il supprime un geste de Paul mesuré.
   - Différer T-346, T-386, T-323, T-352, T-342, T-343, T-318 et T-320 après la porte.
   - Liste figée de 20 tickets pour le pilote.
   - Paliers N=3 → 6 → 10 décidés par Paul dans ADR-0021.
10. **Écrire `CONSENSUS-2.md`** : MVP révisé, plafond, T-213 et D11. Corriger `STATE.md` (OKE → homelab, 134 tickets) et `MISSION.md` dans T-061a.
11. **Garde « image multi-arch »** dans T-365 pour les apps éligibles aux deux clusters. Configuration git noreply imposée dans T-330 ou T-334.

## Incertitudes
- **Runners arm64 en privé** [V] : si les runners arm64 restent gratuits en privé, le point [B] §3 descend en [M] (il reste le quota de 2 000 minutes).
- **Construction de l'image corrigée** : elle est peut-être déjà multi-arch dans le dépôt privé, que je n'ai pas lu. Dans ce cas, le point [B] §2 se réduit à la question de l'installateur lab.
- **Durée de la réécriture** : je suppose qu'elle se fait en environ 2 h si elle est préparée. Les PR ouvertes, kube-ops et les worktrees peuvent l'allonger.
- **Taille réelle de S0** : des tickets que j'écarte (T-002, T-217) peuvent devenir nécessaires si les tickets du pilote touchent `platform/`. La liste figée doit l'éviter.
- **Routage** : mon conseil d'une seule règle sacrifie un gain de quota possible avant les données. Le pilote peut me contredire.
- **D11** : je suppose que l'usage réel de Paul est mono-cluster. S'il veut vraiment des apps sur OKE à court terme, mesurer le multi-cluster redevient central et C4 doit tester T-030.
