# Revue adverse du plan de plateforme (ADR 0001-0019, backlog 124 tickets)

Date : 2026-11-18. Auteur : agent critique (lecture seule, aucun cluster touché). Sources : `missions/MISSION.md`, `STATE.md`,
`docs/adr/`, `backlog/`, `docs/research/`, `docs/architecture/{TARGET-ARCHITECTURE,DECISIONS-OPEN}.md`, `.github/`,
kube-ops @ `ef50472`, Atlas. Étiquettes : **[B]** BLOQUANT · **[M]** MAJEUR · **[m]** MINEUR. [V] = à vérifier.

## Verdict (5 lignes)
1. Le plan est un bon inventaire mais un mauvais plan : 124 tickets, 70 environ qui attendent Paul, et **aucune porte « adopter / abandonner OpenChoreo »** alors que l'adoption n'est pas tranchée.
2. Le chemin le plus court vers « intention → app en prod avec preuve » tient en **environ 14 tickets**. Le reste (IA, data platform, migration Doppler, Crossplane, upgrades plateforme) doit être gelé derrière ce MVP et derrière la porte OpenChoreo.
3. Le noyau ADR-0002 a **des trous exploitables aujourd'hui** : des scripts que le coordinateur exécute en admin sur OKE (`tools/oke/install.sh`, `lib.sh`, `verify.sh`) et le default-deny réseau (`platform/project-types/`) sont modifiables et fusionnables sans Paul.
4. La cible OKE **ne tient pas** dans le nœud A1 (35 pods au maximum, `TARGET-ARCHITECTURE.md` §6.3) et les ADR ignorent la décision ouverte D1. Il faut une nomenclature OKE figée avant d'ajouter OpenBao, Alloy, Kyverno ou gVisor.
5. Mon conseil : un MVP sur le homelab en 2 semaines, et en parallèle un backend `plain` d'`appgen` (sans OpenChoreo) pour comparer. Décision OpenChoreo datée (2026-12-04), puis on dégèle le reste par incréments.

## Axe 1 — OpenChoreo vaut-il son coût ?
- **[B] Pas de porte de décision.** `MISSION.md`, `ADR-0012` et `CLOUD-AGENTS.md` disent que l'adoption n'est pas tranchée, mais aucun ADR ni ticket ne la tranche. Du coup, environ 25 tickets n'ont de sens qu'avec OpenChoreo : T-001, T-003 (pins de release), T-006, T-030, T-060, T-062, T-112, T-127, T-129, T-130, T-170, le portail 6b, G3 et le pin des ResourceRelease. On les finance avant de savoir si on garde l'outil.
- **[M] Ce qu'OpenChoreo apporte réellement ici est mince.** Selon `CONSOLIDATION.md` §b, il ne couvre ni les sauvegardes, ni les bases de production, ni les charts tiers, ni l'admission, ni l'exposition sans LB, ni les secrets générés, ni le retour machine-lisible. Tout cela est justement le gros du backlog, et il faut le construire de toute façon (ADR-0005 à 0011, 0014). Ce qui reste propre à OpenChoreo : le modèle CRD rendu par un contrôleur, les releases immuables (qu'il a fallu corriger, G3, PR #25), l'agent de data plane, le MCP (≈110 outils, sans mode lecture seule) et Backstage. Ni le MCP ni Backstage ne sont sur le chemin des agents (ADR-0001 : on écrit par Git ; ADR-0013 écarte les formulaires Backstage).
- **[M] Le coût récurrent propre à OpenChoreo est élevé.**
  - Un **contrôleur corrigé, servi depuis un registre privé**, et un security bundle à reconstruire à chaque version (T-130 MANDAT, `STATE.md` §7). C'est la maintenance d'un fork.
  - Des exceptions de périmètre (`default` labellisé, `dp-*`) et un second Argo (D4).
  - Une doc injoignable depuis les sessions, une version 1.x jeune (ResourceRelease à épingler à la main = 2 PR par base).
  - Un control plane sur un nœud déjà plein.
- **[M] Il existe une alternative déjà à moitié construite, et elle ne fait l'objet d'aucun ticket.** kube-ops a le chart `platform-app` et l'ApplicationSet `apps-generated` (1 Application par `app.yaml`, sur les deux clusters, Argo en pull : `KUBE-OPS-REQUIREMENTS.md` §1). Un backend `plain` d'`appgen` (Deployment, Service, NetworkPolicy, ExternalSecret, CNPG Cluster) appliqué par l'Argo **de chaque cluster** aurait trois effets :
  - il supprime le besoin d'un chemin CP → DP (NetBird, SAN, T-030 MANDAT) ;
  - il supprime le bundle ;
  - il garde `app.yaml` comme surface unique.
  Le contrat `app.yaml` est déjà indépendant du moteur (ADR-0001 §1-2) : c'est la vraie protection de l'investissement.
- **Où placer la porte :** juste après le MVP A sur le homelab (vague 2 du plan alternatif), avant tout ticket propre à OpenChoreo au-delà du MVP. Critères et date en fin de document.

## Axe 2 — Taille et séquencement
- **[B] Les dépendances de la feuille de route contredisent la règle des ADR.** `docs/adr/README.md` dit : « les tickets ne démarrent qu'une fois leurs ADR ACTÉ (T-061) ». Or presque aucun `depends_on` ne cite T-061, et la vague 0 met en parallèle des tickets dont les ADR ne sont pas actés. `MISSION.md` est toujours « IDP sur OKE » (Miniflux, AIOStreams sur OKE) et interdit encore Cloudflare, l'exposition et la création d'identité, ce qu'ADR-0003/0007/0010 contredisent. Un agent qui lit `AGENTS.md` → `STATE.md` → `MISSION.md` exécute donc l'ancien plan. Il faut que T-061 soit réduit et devienne le seul prérequis de tout.
- **[B] Le MVP homelab dépend d'un MANDAT réseau non planifié en détail.** L'app va par défaut sur le homelab (ADR-0003 §4). Mais le seul data plane existant est OKE, et T-030 (ACL NetBird, accès Talos, installation du DP homelab avec le bundle privé, par qui ? via l'Argo homelab de kube-ops ?) n'a ni ticket d'installation ni ticket de PR kube-ops. Sans T-030 ou sans backend `plain`, « intention → homelab » est impossible.
- **[M] La latence humaine domine.** Sur 124 tickets, 54 sont AUTONOME seuls : environ 70 attendent une REVUE ou un MANDAT. La vague 2 compte 16 gestes de Paul, et il y a 9 vagues. Avec un lot par jour, le calendrier minimal est d'environ 9 jours de gestes, sans compter les reprises. De plus, tout ticket qui ajoute un job CI touche `.github/` et devient REVUE (T-008, T-007, T-070, T-144…).
- **[M] `tools/appgen/appgen.py` (1 481 lignes, un seul fichier) est un goulot de conflits.** 26 tickets le touchent, avec la règle « 1 agent pour `contrat-appgen` » (`ROADMAP.md` §3). Ce couloir sérialise à lui seul environ 20 % du backlog : le plafond de 4 agents ne sera jamais atteint sur l'essentiel.
- **[M] Le chemin critique de la première app familiale (T-051) est en vague 6.** Il traverse 6 MANDAT : T-022, T-023, T-026 (R2), T-030, T-185 (PR kube-ops), T-182. Ce n'est pas « le plus vite possible ».
- **[M] Il y a trop de largeur avant la première valeur.** On compte 12 tickets IA (T-160 à T-171), 8 data (T-201 à T-209), 19 upgrades (T-120 à T-138), 7 coût, 13 observabilité et 14 identité/secrets. Ils sont lancés tôt parce que « vélocité » est attribué à des tickets qui n'accélèrent rien sur le chemin MVP (ex. T-201, T-128, T-185 en vague 1).
- **[m] Les doublons et tickets morts restent indexés.** `INDEX.md` liste T-009, T-024, T-064, T-066, T-068 et T-188 (`status: dropped`). T-124 dépend de T-065 alors que T-065 dit « revert → T-106 » : le revert automatique a 3 propriétaires (T-065, T-106, T-124). Il faut aussi fusionner T-140/T-141/T-142, T-100/T-104/T-108, T-101/T-102/T-103 et T-186/T-187.

## Axe 3 — Autonomie contre sécurité
- **[B] Le noyau ne couvre pas ce que la CI requise et le coordinateur exécutent.** `ci.yaml` (job `platform`, requis par `ci-ok`) lance `tools/oke/render-check.sh`, `tools/oke/kubeconform-platform.sh`, `tools/oke/psa_check.py` et `tests/cell-cpt/run.sh`, qui sont tous **hors CODEOWNERS**. Un agent remplace l'un d'eux par `exit 0` et la garde « PSA, 0 PVC/LB, digest » tombe, avec une fusion autonome. Pire : `tools/oke/install.sh`, `lib.sh`, `verify.sh` et `uninstall.sh` ne sont pas protégés (seuls `security-bundle.sh` et `argo_guard.py` le sont). Or le coordinateur les exécute **avec des droits admin sur OKE**, et `verify.sh` produit les PASS. Règle à ajouter dans ADR-0002 : *tout script exécuté par un job requis ou par le coordinateur avec des droits cluster fait partie du noyau*. T-007 doit le tester.
- **[B, conditionnel] L'identité des agents.** Le ruleset a pour `bypass_actors` le rôle admin (`apply-branch-protection.sh` l.29). Si une session cloud ou un runner agit avec le compte de Paul (admin), CODEOWNERS ne protège rien : l'agent peut fusionner une PR du noyau par contournement. Le « compte dédié, rôle Write » (en-tête de `CODEOWNERS`) est dans T-164 (MANDAT, todo). C'est un prérequis de l'autonomie, pas un chantier de la vague 0 parmi d'autres. Il faut une preuve : une PR du noyau ouverte par l'identité agent ne peut pas être fusionnée. [V] Comportement de `required_approving_review_count: 0` avec `require_code_owner_review: true`.
- **[M] Le default-deny réseau est hors noyau.** Il vit dans `platform/project-types/cell-restricted.yaml` (non protégé), et aucune VAP ne vérifie la présence d'une NetworkPolicy. ADR-0002 « accepte » de dégrader Kyverno, mais la MISSION liste le default-deny comme primitive à prouver. Un agent peut l'affaiblir seul, et `lab-platform` en synchronisation automatique (T-062) l'appliquerait. Deux options : protéger `platform/project-types/`, ou ajouter une VAP « namespace de cellule sans NP default-deny = refus ».
- **[M] Le contexte des agents est réécrivable par les agents (persistance d'injection).** `STATE.md` (« prochaines actions EXACTES »), `.agents/skills/*` (hors `platform-guardrails`) et `golden-paths/` sont des instructions chargées à chaque démarrage, et non protégées. Une PR autonome peut y planter une consigne qui oriente tous les agents suivants. Proposition : protéger `.agents/skills/**` (ils changent rarement) et limiter `STATE.md` à un format d'état validé par un lint (pas de prose impérative).
- **[M] Le dispatcher T-210 crée une boucle d'auto-amplification.** `backlog/` est libre et les tickets sont écrits par des agents ; le champ `class:` est déclaratif. Si le dispatcher remplace la condition `sender == SmadjaPaul` de `claude-agent.yml` par une identité de dispatch, un agent qui fusionne un ticket « AUTONOME » fait lancer d'autres agents sur ce texte. Le dispatcher ne doit lancer que sur déclenchement de Paul (`workflow_dispatch` avec une liste d'ID), plafonné à 4 agents. La classe est recalculée depuis les chemins touchés (CODEOWNERS), jamais lue dans l'en-tête.
- **[M] Les boucles entre montées et remédiation.** Un revert automatique (T-065/T-106/T-124) d'une montée Renovate est re-proposé par Renovate au cycle suivant, ce qui donne une boucle quotidienne. Il faut une liste de refus par version. Or `renovate.json` est noyau, donc l'agent ne peut pas la poser : il faut un fichier de refus lu par Renovate, hors noyau mais en ajout seul, contrôlé par la CI. Il faut aussi une règle : pas de seconde PR « fix » agent sur la même (app, env) sans humain, car l'ADR-0015 §4 compte les essais mais pas les cascades fix → revert → fix.
- **[M] L'injection par la télémétrie.** Les annotations et labels d'alerte Grafana peuvent porter des valeurs émises par l'app (code tiers) : URL de sonde, labels de métriques. T-106 assainit les logs mais pas les champs d'alerte. Il faut une liste fermée de champs typés vers l'agent, et aucune chaîne libre.
- **[m] Renovate contredit ADR-0016.** `renovate.json` fusionne automatiquement les digests d'actions GitHub, alors qu'ADR-0016 §8 dit « jamais en AUTO », et `.github/` est noyau (fusion bloquée, donc du bruit). Les digests d'apps sont en automerge sans porte dev (T-124 non fait). Ils n'aboutissent aujourd'hui que parce que `postUpgradeTasks` ne tourne pas sur l'App Mend.
- **[m]** Le prompt de `claude-agent.yml` dit encore « platform/, tools/, tests/ exigent l'approbation de Paul », ce qui contredit ADR-0002.

## Axe 4 — Faisabilité technique
- **[B] Budget OKE.** `TARGET-ARCHITECTURE.md` §6.3, avec les planchers du dépôt, donne **35/35 pods avant toute app**, 29/31 IP VCN et 76,5 % de CPU pendant une restauration Authentik. D1 (« B = second nœud payant, recommandé ») n'est pas tranché. ADR-0017 promet 0 €. ADR-0003 ajoute OpenBao sur OKE, ADR-0015 un Alloy, ADR-0006 peut-être Kyverno, T-005 des Jobs PostSync, ADR-0018 gVisor. Il manque une **nomenclature OKE exhaustive** (pods, requests) dans ADR-0003, et deux décisions :
  - D4 : un seul Argo sur OKE (−4 pods, −480 Mi), qui n'a aucun ticket ;
  - le portail Backstage hors OKE (−1 pod, −320 Mi).
  Il manque aussi l'emplacement réel d'Authentik : « au homelab » selon TA §6.4, sur OKE selon D-2026-11-15-11.
- **[M] OpenBao.** Le seal statique (clé dans Doppler, puis ESO, puis un Secret) met la clé dans le même etcd que les données chiffrées : contre un admin du cluster, cela ne vaut guère mieux qu'un `Secret`. C'est acceptable sur un homelab mono-utilisateur, à condition de le dire. ADR-0014 §6 promet encore un auto-unseal OCI/transit que `IDENTITY-SECRETS.md` §1.5 juge impossible. [V] La présence du seal `static` dans la version d'OpenBao épinglée. La justification n°1 (un mot de passe de base qui change à la recréation du namespace) se règle sans coffre : les rôles gérés CNPG (`managed.roles` + `passwordSecret`) réalignent le mot de passe [V]. OpenBao reste utile pour les secrets clients OIDC partagés entre clusters et pour les `provided`, mais après le MVP.
- **[M] gVisor.** Sur Talos, l'extension `siderolabs/gvisor` existe. Mais le schematic change, il faut une montée Talos (MANDAT) et le support arm64/systrap est à vérifier [V]. Sur OKE : le runtime est **CRI-O** (`STATE.md` §1), pas containerd comme le suppose `AI-SERVICES.md`. Modifier le node pool remplace l'unique nœud, donc coupe le CP. Il faut décider « pas de service IA sur OKE » et supprimer T-169.
- **[M] Crossplane sur le homelab pour un seul usage (Access par app).** Les providers upjet Cloudflare sont communautaires et lourds (centaines de CRD, mémoire de l'API server), alors que le repli Tofu existe déjà. Une **application Access wildcard `*.smadja.dev`** (une fois, Tofu, MANDAT) protège tout hôte public par groupe. Avec « une route n'existe que si `exposure: public` » (ADR-0010 §2), T-029 et T-076 ne servent plus. Il reste un cas : une exception par app (client mobile), à traiter en MANDAT rare.
- **[M] Grafana Cloud.** kube-ops plafonne déjà à 8 000 + 8 000 séries pour une limite de 10 000 (`OBSERVABILITY-OPERATIONS.md` §0.4). T-102 ajoute un second Alloy sur OKE, à côté de celui de kube-ops : c'est un pod en double, et deux propriétaires du budget. Il vaut mieux étendre l'Alloy existant par une PR kube-ops.
- **[M] Le CP sur OKE avec un DP homelab par NetBird.** C'est faisable en principe (agent sortant, mTLS), mais rien n'est prouvé : SAN du cluster-gateway, routeur NetBird qui appartient à kube-ops, CRD Gateway API et cert-manager déjà installées sur le homelab par kube-ops (conflit de versions), bundle privé à servir au homelab, coupures nocturnes. C'est le spike le plus risqué, et c'est exactement ce que le backend `plain` évite.
- **[m] Kyverno sur OKE.** D3 recommande déjà « non, VAP + PSA » : il faut le décider maintenant au lieu de le « mesurer » (ADR-0006 Conséquences).

## Axe 5 — Cohérence et trous
- **[M]** Incohérences entre documents :
  - `CLOUD-AGENTS.md` §1 : promotion en production = REVUE. ADR-0004 : promotion autonome pour A et D.
  - ADR-0004 et ADR-0016 parlent d'une classe `important` qui n'existe pas (ADR-0008 : `ephemeral|rebuildable|useful|irreplaceable`).
  - ADR-0004 interdit B et C en dev « sur OKE » mais ne dit rien du homelab.
- **[M]** Le noyau déclaré par ADR-0016 §3 (`upgrade-gate`, `ops/maintenance-windows.yaml`), ADR-0019 §8 (`tools/metrics/`, seuils), ADR-0017 §7 (`docs/state/free-tier.yaml` : les seuils sont des plafonds) et l'amendement IDENTITY-SECRETS (`users/`, `groups/`, `platform/secrets/`) est **absent de CODEOWNERS**. Or T-007 ne teste que la liste d'ADR-0002.
- **[M]** Trous :
  - pas de ticket D4 (Argo unique) ;
  - pas de ticket « installer le DP homelab via kube-ops » ;
  - pas de nomenclature OKE ;
  - pas de « pack identité GitHub » unique : T-005, T-106, T-121, T-164 et T-210 créent chacun une identité GitHub séparément, soit 5 MANDAT pour ce qui pourrait être 1 ou 2 Apps ;
  - pas de critère de fin de projet (« fini » = quoi ?).
- **[m]** `STATE.md` décrit un flux d'agents et un handoff privé qu'un agent cloud ne peut pas lire. `AGENTS.md` y renvoie quand même en « à lire d'abord ».

## Axe 6 — Vélocité : ce qui accélérerait vraiment
1. **Une séance MANDAT unique, guidée**, préparée par les agents (script assistant, noms seulement). Elle regroupe GitHub App(s), compte agent rôle Write, ACL NetBird, Access wildcard, jeton R2, clients Authentik, jetons Doppler cibles et clé OCI de lecture. Les MANDAT disparaissent alors du chemin critique.
2. **Un découpage d'`appgen` en modules par capacité** (`render/identity.py`, `render/data.py`…) **avant** le couloir contrat. Cela fait passer de 1 à 3 ou 4 agents en parallèle.
3. **Une CI extensible sans REVUE** : `ci.yaml` (noyau) exécute un registre `tests/*/ci.manifest`. Ajouter une suite est libre ; modifier ou retirer une suite existante qui garde le noyau reste protégé.
4. **Un retour runtime pour les agents sans Paul** : un workflow k3d déclenchable sur branche (`workflow_dispatch`, résultats en artefact JSON `app-status.v1`), plus un namespace d'aperçu `lab-pr-<n>` sur le homelab.
5. **Un relecteur LLM indépendant** (autre modèle) qui remplace la REVUE humaine hors noyau. Paul ne revoit que le noyau et les MANDAT.
6. **Réutiliser l'existant** au lieu de réécrire : dispatcher et contrat de mission d'Atlas (`atlas/dispatcher/mission-contract.md`), chart `platform-app` et ApplicationSet `apps-generated`, Alloy de kube-ops.
7. **Geler le WIP** : au plus 2 incréments ouverts à la fois. Les ADR 0015-0019 restent PROPOSÉ jusqu'à la fin du MVP.

## Plan alternatif recommandé
**MVP (cible : 2026-12-02).** Une app A sur le homelab, en prod, livrée à partir d'une phrase, avec preuve datée sans coordinateur.
- **S0, socle de confiance (J0-J2)** : changements 1 à 4 ci-dessous ; T-002 (CI k3d) ; T-001 ; T-061a (actant seulement ADR 0001-0006 et 0010-0013 amendés, et MISSION réalignée sur le homelab).
- **S1, preuve automatique** : T-072 puis T-005 (statut de commit via la GitHub App du pack), avec T-105 fusionné.
- **S2, deux moteurs en parallèle** : T-030 (DP homelab OpenChoreo) **et** T-212 (backend `plain`, homelab, 3 jours maximum).
- **S3, golden path** : T-003, T-010, T-015 (ntfy dev → prod → rollback), T-043, T-040 (5 recettes), T-044 réduit à 5 intentions A.

**Porte OpenChoreo (ADR-0020, décision de Paul le 2026-12-04).** Adopter si les cinq conditions sont réunies, sinon abandonner :
- **C1** : 5/5 intentions A livrées sur le homelab par OpenChoreo avec PASS runtime, délai médian intention → PASS ≤ 30 min, zéro geste du coordinateur ;
- **C2** : nomenclature OKE mesurée ≤ 70 % des requests et ≤ 33 pods, avec le CP, un seul Argo, cloudflared/NetBird et la place réservée à OpenBao ;
- **C3** : bundle de sécurité retiré (correctif amont publié), ou reconstruction scriptée ≤ 2 h par patch ;
- **C4** : DP homelab reconnecté sans action après 3 coupures nocturnes ;
- **C5** : le backend `plain` n'est pas nettement plus simple, mesuré sur la même suite `_checks`, le même délai et le nombre de lignes et de tickets propres au moteur.

Si la décision est « abandonner » : `app.yaml` et `appgen plain`, un Argo par cluster, OKE réduit à l'identité, OpenBao et cloudflared ; les tickets propres à OpenChoreo passent en `dropped`.

**Ensuite, par incréments (un ou deux ouverts à la fois)** :
- **I1, données** : T-025, T-026 + T-143, T-027, T-069, puis Miniflux (B) sur le homelab.
- **I2, secrets et identité** : T-022 (seal statique acté), T-023, T-185, T-189, puis T-051.
- **I3, exposition** : T-028 avec Access wildcard.
- **I4, exploitation** : observabilité fusionnée (contrat + règles + runbooks ; Alloy kube-ops), T-106 (seul propriétaire du revert), T-107, T-111.
- **I5, montées** : T-120, T-122, T-124.
- **I6** : migration Doppler en une séance (T-181, T-182, T-190, T-191, puis T-192, T-193).
- **I7** : IA sur le homelab seulement (T-160, T-161, T-162, T-163, T-171).
- **I8** : DORA (T-201 + T-202 fusionnés ; Garage différé).

**À couper ou différer** :
- **Supprimer** : T-029, T-076, T-112, T-144, T-146, T-169, T-170.
- **Différer après la porte** : T-006, T-042, T-127, T-129, T-130, T-133, T-134, T-135, T-136, T-137, T-138, T-128, T-126, T-014, T-013, T-073, T-205 à T-209, T-052, le portail 6b.

## Liste de changements concrets
1. **CODEOWNERS (noyau)** : ajouter `/tools/oke/`, `/tests/cell-cpt/`, `/platform/project-types/`, `/.agents/skills/`, `/ops/`, `/tools/metrics/`, `/docs/state/free-tier.yaml`, `/users/`, `/groups/`, `/platform/secrets/`. Amender **ADR-0002 §2** avec la règle « tout script exécuté par un job requis ou par le coordinateur avec des droits cluster est noyau ».
2. **T-007 étendu** : il compare CODEOWNERS à la **liste des scripts appelés par `ci.yaml`** et à tous les ADR (0002, 0014, 0016, 0017, 0019), pas seulement à ADR-0002. Il ajoute un essai réel : une PR du noyau ouverte par l'identité agent ne peut pas être fusionnée.
3. **Nouveau T-215 « pack identité »** (MANDAT, vague 0) : compte agent rôle Write et une GitHub App plateforme (statut de commit, Renovate, dispatch, remédiation). Il absorbe les parties GitHub de T-005, T-106, T-121, T-164 et T-210. Aucun agent n'agit avec le compte admin de Paul.
4. **VAP (noyau)** : refuser un namespace de cellule sans NetworkPolicy `default-deny` (`platform/policies/`), avec un test dans `tests/vap/`.
5. **Nouvel ADR-0020 « Porte d'adoption OpenChoreo »**, critères C1 à C5, date 2026-12-04, et ticket T-211 (MANDAT : décision). Geler jusque-là les tickets propres à OpenChoreo listés plus haut.
6. **Amender ADR-0001** : le contrat est indépendant du moteur. Nouveau **T-212 « backend `plain` d'appgen »** (spike de 3 jours, réutilise `platform-app` et `apps-generated` de kube-ops).
7. **Scinder T-061** : T-061a (ADR 0001-0006 et 0010-0013 + MISSION réalignée sur le homelab), prérequis explicite (`depends_on`) de tout ticket. T-061b (ADR 0014-0019, après MVP).
8. **Amender ADR-0003** : une nomenclature OKE exhaustive et figée, plus la règle « ≤ 33 pods ». Nouveau **T-213 « Argo unique sur OKE » (D4)**, emplacement d'Authentik tranché, Backstage hors OKE.
9. **Amender ADR-0009** : Crossplane retiré de la cible v1, remplacé par une application Access wildcard (Tofu, une fois) et des routes déclarées. Supprimer T-029 et T-076.
10. **Amender ADR-0014** :
    - seal statique acté (« pas mieux qu'un Secret contre un admin cluster ») ;
    - mots de passe de bases par rôles gérés CNPG ;
    - OpenBao réservé aux secrets OIDC et aux `provided` ;
    - OpenBao placé après le MVP.
11. **Amender ADR-0018** : aucun service IA sur OKE (CRI-O, nœud unique). Supprimer T-169.
12. **Amender ADR-0015** : réutiliser l'Alloy de kube-ops (PR kube-ops). Fusionner T-101, T-102 et T-103 ; fusionner T-100, T-104 et T-108 ; T-105 passe dans T-005 et T-110 dans T-106. Liste fermée des champs d'alerte vers l'agent.
13. **Revert automatique** : un seul propriétaire, T-106. Retirer « revert » de T-065 et de T-124, et corriger `depends_on` de T-124. Règle anti-cascade : pas de seconde PR agent sur une même (app, env) sans humain. Fichier de refus de versions lu par Renovate, en ajout seul.
14. **renovate.json** : retirer l'automerge des digests d'actions (ADR-0016 §8) et des digests d'apps jusqu'à T-124.
15. **T-210 réduit** : uniquement sur déclenchement de Paul avec une liste d'ID, classe recalculée depuis les chemins, plafond de 4, contrat de mission d'Atlas réutilisé. Jamais de lancement à partir d'un texte de ticket écrit par un agent sans validation de Paul.
16. **Nouveau T-214 « appgen modulaire »** (vélocité, avant le couloir contrat), puis **T-216 « CI extensible par registre »** (REVUE une fois, ensuite ajout libre de suites).
17. **Fusions** :
    - T-140 + T-141 + T-142 ;
    - T-143 dans T-026 ;
    - T-186 + T-187 ;
    - T-181 + T-182 + T-190 + T-191 en une séance MANDAT ;
    - T-201 + T-202.
18. **Cohérence** :
    - `CLOUD-AGENTS.md` aligné sur ADR-0004 (promotion d'une app A ou D autonome) ;
    - classe `important` remplacée par `useful` dans ADR-0004 et ADR-0016 ;
    - prompt de `claude-agent.yml` aligné sur ADR-0002 ;
    - `INDEX.md` sans les tickets `dropped` ;
    - lint du format de `STATE.md` (pas de prose impérative) ;
    - critère « plateforme finie » ajouté à `MISSION.md`.

## Points sur lesquels je pourrais me tromper
- **La valeur d'OpenChoreo.** Elle serait plus grande si Paul veut à terme un portail multi-utilisateur, des builds depuis les sources, ou si le correctif amont arrive vite (le bundle disparaît). C'est pour cela que je demande une porte mesurée et non un abandon immédiat.
- **L'identité des sessions cloud.** Je n'ai pas pu vérifier sous quelle identité elles poussent et fusionnent (`gh` non authentifié ici). Si c'est déjà un compte Write dédié, le point [B] de l'axe 3 tombe. Même incertitude sur la sémantique exacte de `require_code_owner_review` avec 0 approbation requise.
- **Les points techniques non vérifiés.** Le seal `static` d'OpenBao, le réalignement des mots de passe par les rôles gérés CNPG, gVisor arm64/systrap sur Talos et le comportement de CRI-O sur OKE sont de mémoire, non vérifiés (web limité).
- **L'Access wildcard.** Il peut ne pas suffire si plusieurs apps publiques exigent des groupes différents, ou des clients non navigateurs (mobile, CalDAV). Crossplane ou le repli Tofu redeviendraient alors utiles.
- **Le budget OKE.** Les chiffres viennent de planchers et d'estimations (`TARGET-ARCHITECTURE.md`), pas de mesures après les étapes 6 à 11. Une mesure réelle pourrait desserrer la contrainte de pods si Authentik n'est pas sur OKE.
- **La latence de Paul.** Je l'estime à environ un lot par jour. S'il répond en quelques minutes, les REVUE coûtent moins et le gain du point 6.5 diminue.
- **L'estimation du MVP à 14 tickets.** Elle suppose que T-030 ou T-212 réussit en moins de 3 jours. Si les deux échouent, le MVP doit retomber sur OKE (contre ADR-0003 §4), ce qui demande une décision explicite de Paul.
