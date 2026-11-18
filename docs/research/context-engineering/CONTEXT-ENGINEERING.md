---
owner: paul
updated: 2026-11-18
review_days: 30
---
# Context engineering de l'écosystème d'agents

Date : 2026-11-18. Statut : proposition (rien n'est appliqué ; aucun fichier réel modifié). Mesures prises sur les clones lus ce jour ; tokens ≈ octets / 3,5 (français dense, ordre de grandeur).

## 0. Conclusion
1. Le coût en tokens n'est pas le problème principal : un agent paie ~7 000 tokens au démarrage dans openchoreo-lab, ~8 000 dans homelab-infra. Le problème est le **rapport signal/bruit** : une large part de `STATE.md` (lab) est de l'historique ou périmé, et **dix contradictions** entre dépôts attendent un agent qui ne sait pas laquelle croire (§1.4).
2. Le vrai risque « des milliers de lignes » est en second rang : `docs/APP-CONTRACT.md` (649 lignes, ~15 000 tokens) et `decisions.md` (1 033 lignes, ~37 000 tokens) sont lus en bloc dès qu'aucun index ne dit quelle section ouvrir.
3. Cible : **toujours chargé ≤ 150 lignes par dépôt**, le reste à la demande via des skills et un index machine-lisible ; Atlas devient routeur (`context/index.yaml` + skill `route-intent`), pas un second lieu de règles.
4. Gain mesuré sur le lab avec les brouillons de ce dossier : démarrage 135 → 90 lignes, 21,5 → 7 Ko (≈ 6,1 k → 2,0 k tokens), parcours « installe Mealie » ≈ 20 k → ≈ 10-12 k tokens (§4).
5. Trois décisions de Paul débloquent le reste (§8) ; sans elles, le check CI signale mais ne peut pas trancher.

## 1. Diagnostic

### 1.1 Ce qu'un agent charge aujourd'hui
| Dépôt | Toujours chargé (fichiers, lignes, ≈ tokens) | « À lire d'abord » imposé | Total au démarrage |
|---|---|---|---|
| Atlas | `AGENTS.md` 33 l + `CLAUDE.md` 3 l ≈ 1,0 k | `decisions-active.md` (homelab-infra, 73 l, 2,5 k), `catalog.md` 0,7 k, puis selon le rôle : `mission-contract` 0,9 k, `issue-to-pr` 0,5 k, `change-risk` 0,7 k, `communication-style` (192 l, 3,2 k) | 1 k seul ; **6 à 9 k** en pratique |
| openchoreo-lab | `AGENTS.md` 20 l (+ `CLAUDE.md` = `@AGENTS.md`) 0,5 k ; 9 descriptions de skills 1,1 k | `STATE.md` 74 l / 13,2 Ko = **3,8 k** ; `MISSION.md` 41 l = 1,9 k | **135 l, ≈ 7,3 k** ; puis `add-app` 1,2 k + `platform-guardrails` 1,6 k + `golden-paths/README.md` 2,8 k |
| kube-ops | `AGENTS.md` 78 l / 9 Ko = 2,6 k (+ 5 l) ; `k8s/CLAUDE.md` 1,1 k dès qu'on touche `k8s/` | `decisions-active.md` 2,5 k + un skill | **≥ 6 k** |
| homelab-infra | `AGENTS.md` 70 l = 1,9 k | `decisions-active.md` 2,5 k, `invariants.md` 78 l = 2,5 k, `state/CURRENT.md` 47 l = 1,0 k, ADR, skill | **≈ 8-10 k** |
Observations : (a) Claude Code ne charge pas `AGENTS.md` s'il existe un `CLAUDE.md` ; les dépôts font donc bien `@AGENTS.md` dans `CLAUDE.md` [L], mais un `@import` **ne réduit pas** le coût (le fichier importé est chargé avec l'importeur) [L]. (b) Les lignes de `STATE.md` font ~180 caractères : « 74 lignes » cache 13 Ko. (c) Les skills du lab sont bien dimensionnés (51-73 lignes) ; leurs descriptions (3,8 Ko cumulés) sont chargées en permanence, donc à surveiller.

### 1.2 Redondances
- **STE80 / statuts / niveaux de preuve** répétés dans Atlas `AGENTS.md`, kube-ops `AGENTS.md`, homelab-infra `AGENTS.md` (3 paragraphes quasi identiques) ; le texte complet existe en plus dans `communication-style.md`.
- **« Autonomie maximale »** (D-2026-11-15-03) résumée dans Atlas `change-risk.md`, kube-ops `Safety`, homelab-infra `Safety`, `decisions-active.md` : 4 formulations, 4 occasions de dériver.
- **Routage d'un dépôt** écrit 3 fois dans Atlas : README « Démarrage », `AGENTS.md` « Rôle », `catalog.md` « Routage ».
- **Lab** : liste des skills dans `AGENTS.md`, dans `.agents/README.md` et dans les descriptions de skills ; périmètre cluster écrit deux fois dans `AGENTS.md` (« Périmètre cluster », « Périmètre de lecture ») et une troisième dans `MISSION.md` ; décisions de Paul du 2026-11-18 présentes dans `MISSION.md`, `STATE.md` §1b, `CLOUD-AGENTS.md` et ADR-0012.
- `decisions-active.md` est lu au démarrage par Atlas, kube-ops **et** homelab-infra : 2,5 k tokens chargés trois fois pour un même fait.

### 1.3 Périmé ou invérifiable
- Lab `STATE.md` : en-tête « mise à jour 2026-11-17 ~20:45Z » alors que le corps cite des preuves 2026-11-18 ; §1b « rien n'est encore exécuté sur OKE » face au pilote `whoami` PASS sur OKE ; §2 session bastion « expire ~23:06Z » (échue) ; §6 « prochaines actions EXACTES » = étapes 6-9, déjà PASS en §1 ; §4 PR #8 « OUVERTE à fusionner » à re-vérifier ; §5 flux « EN COURS » sans date. Un agent ne peut pas savoir quelle partie est vivante.
- `golden-paths/README.md` : « `cluster: oke` reste refusé tant que le gate OKE n'est pas franchi » alors que `STATE.md` annonce OKE PASS.
- `docs/adr/README.md` annonce 0001-0012 ; `0013` et `0014` existent sans ligne dans le tableau (README en retard sur les fichiers). `backlog/` (ADR-0012) vient d'apparaître : la phrase « Linear / issues GitHub » de `STATE.md` n'est plus la seule vérité.
- Atlas : `catalog.md` « vérifié le 12 novembre » (6 jours, avant les décisions du 18) ; aucune entrée pour openchoreo-lab alors que ADR-0012 §4 et ADR-0013 §1 supposent qu'Atlas la route ; README mentionne encore Mastra Factory comme cible alors que le catalogue la dit gelée.
- Aucun fichier du lab ne porte de propriétaire ni de date de revue (hors l'en-tête libre de `STATE.md`).

### 1.4 Contradictions entre dépôts
| # | Sujet | Source A | Source B | Effet |
|---|---|---|---|---|
| 1 | Backlog | Atlas (`README`, `coordination`, `issue-to-pr`, `mission-contract.linear_issue` obligatoire) : Linear « boule » | Lab (`MISSION`, `CLOUD-AGENTS`, ADR-0012) : issues GitHub ou `backlog/` ; trois variantes dans le lab même | Un agent Atlas exige un ticket Linear que le lab n'utilise pas |
| 2 | Registre de décisions | Atlas/kube-ops/homelab : « uniquement `decisions.md`, ne rien recopier » | Lab : ADR locaux (`PROPOSÉ → ACTÉ`), décisions de Paul recopiées dans `MISSION.md` | Deux registres, pas de règle de préséance |
| 3 | IdP | `MISSION.md` + ADR-0007 : Authentik unique, « pas de ThunderID » | `APP-CONTRACT` §2.2, `BASE-CHOICE`, `AGENT-ACCESS` : OIDC via ThunderID ; `app.schema.json` : `provider` défaut **`thunderid`** | Un `app.yaml` généré par défaut viole la mission |
| 4 | Autonomie | homelab-infra/kube-ops : autonomie maximale, Paul seulement pour limites permanentes ; Doppler et OpenTofu via ARC autorisés aux agents | Lab : classes AUTONOME/REVUE/MANDAT/INTERDIT ; `tofu apply` et Doppler **interdits** | Même agent, règles opposées selon le dépôt ; aucune règle « la plus stricte gagne » |
| 5 | Statuts et preuves | Atlas : 5 statuts (+ `NOT_PROVEN`) et niveaux `STATIC<CI<RECONCILED<RUNTIME<USER` | Lab : 4 statuts, pas de niveaux, « k3d ≠ OKE » | Comptes rendus non comparables |
| 6 | Branches et tickets | Atlas : `claude/plt-<n>-<slug>`, un ticket = une PR | Lab : `feat/…`, issues `#n` | Verrous `wip:*` inapplicables |
| 7 | Accès aux sources | Atlas renvoie à des **URL https** de dépôts privés (`decisions.md`) | Sessions cloud : un dépôt cloné, pas de lecture https privée | Lien « mort » pour l'agent cloud |
| 8 | Routage attendu | ADR-0012/0013 : « Atlas route vers openchoreo-lab » | Atlas : aucune entrée, aucun skill de routage | L'intention en langage naturel n'a pas de point d'entrée |
| 9 | État OKE | `STATE.md` : OKE PASS (whoami) | `golden-paths/README` : `oke` refusé ; `STATE` §1b : « rien exécuté » | Verdict d'archétype faux |
| 10 | Production | Atlas/kube-ops : cluster actuel = production | Lab : plateforme « cible » mais jetable (`CLEANUP.md`) | « Installe Mealie » : où ? (D1) |

### 1.5 Coût réel
Au volume actuel (7 à 10 k tokens), le coût direct est modeste (< 5 % d'une fenêtre de 200 k). Les coûts qui comptent : (1) l'attention diluée par du périmé (« context rot » [L]) ; (2) les erreurs dues aux contradictions ci-dessus ; (3) la lecture en bloc d'un document de 15 à 37 k tokens faute d'index ; (4) la maintenance : chaque fait écrit à 3 endroits est faux à 2 endroits dans la semaine.

## 2. Principes retenus
Sources : [L] = lu le 2026-11-18 ; [E] = connu, non relu (accès refusé).
- Anthropic, « Effective context engineering for AI agents » [L, anthropic.com/engineering/effective-context-engineering-for-ai-agents] : viser « le plus petit ensemble de tokens à fort signal » ; le rappel baisse quand le contexte grossit (« context rot ») ; stratégie **juste-à-temps** : garder des identifiants légers (chemins, requêtes) et charger à l'usage ; **divulgation progressive** ; compaction, **notes structurées** hors contexte, sous-agents pour les longues tâches.
- Claude Code, mémoire/`CLAUDE.md` [L, code.claude.com/docs/en/memory] : `CLAUDE.md` est du contexte, **pas une application de règle** (pour bloquer : hook `PreToolUse`, permissions) ; cible < 200 lignes ; instructions vérifiables et sans contradiction ; règles par chemin pour ce qui ne concerne qu'une partie ; commentaires HTML de bloc **retirés** du contexte (notes de maintenance gratuites) ; `/doctor prompt-audit` repère instructions périmées, références mortes et fichiers qui se contredisent ; `AGENTS.md` lu seulement en l'absence de `CLAUDE.md`.
- Claude Code, skills [L, code.claude.com/docs/en/skills] : seule la `description` sert au déclenchement ; le corps n'est chargé qu'à l'appel = procédure à la demande.
- agents.md [L pour le README GitHub `agentsmd/agents.md` ; site agents.md inaccessible, 403] : « un README pour agents », Markdown simple, lieu prévisible ; fichiers imbriqués, le plus proche l'emporte [E].
- llms.txt [E, llmstxt.org inaccessible] : un index court de liens commentés pour qu'un LLM trouve le bon document sans tout lire ; modèle de `context/index.yaml`.
- Recherche du dépôt `IDP-AGENTIC-BEST-PRACTICES.md` (S10, S11, [E]) : distinguer **chemins** (préférés) et **contrôles** (hooks, tests) ; outils et retours économes en tokens ; mesurer avant de généraliser.

Principes (P) appliqués ici :
1. **Signal d'abord** : chaque ligne toujours chargée doit changer un comportement de n'importe quelle tâche ; sinon elle descend d'une couche.
2. **Règles ≠ état** : les règles changent par PR rare, l'état à chaque jalon ; ils vivent dans des fichiers séparés avec des péremptions différentes.
3. **Un fait, un lieu** ; ailleurs, un lien. Atlas ne recopie ni décision ni statut.
4. **Identifiants légers** : un index (`context/index.yaml`, `docs/README.md`) dit où ; le contenu se charge par section.
5. **Skill = unité de procédure** (≤ 80 lignes, description ≤ 450 caractères, « quand l'utiliser / ne pas l'utiliser »).
6. **Enforcement par le code** : ce qui ne doit jamais arriver (`kubectl apply`, secret en sortie) relève d'un hook, d'une VAP ou de la CI ; le prompt n'est qu'un rappel.
7. **Chaque document a un propriétaire, une date, une durée de revue** ; périmé = signalé par la CI, pas par un agent qui tombe dessus.
8. **Autosuffisance du dépôt** : un agent cloud dans un seul dépôt doit pouvoir agir sans Atlas ; Atlas accélère et unifie, il n'est pas un point de défaillance.
9. **Mesurer** : taille au démarrage, tokens par parcours, questions posées, contradictions détectées (§7).

## 3. Architecture cible

### 3.1 Rôles
| | Atlas (routeur + transverse stable) | Dépôt (local) |
|---|---|---|
| Contient | `context/index.yaml`, skill `route-intent`, catalogue, politiques (risque, STE80, coordination), contrat de mission, schémas | `AGENTS.md` (règles), `STATE.md` (état), skills, contrat, ADR, preuves |
| Ne contient pas | décisions d'un domaine, statuts, tickets, procédures propres à un dépôt | politiques inter-dépôts recopiées |
| Rythme | revue 30 j | `STATE` 7 j, `AGENTS` 30 j, skills 90 j |
| Panne d'Atlas | le dépôt fonctionne (table de routage locale dans `AGENTS.md`) | — |
Préséance (déclarée dans l'index) : registre de décisions du domaine > règles impératives du dépôt (la plus stricte gagne) > politiques Atlas > skills et docs > état court.

### 3.2 Couches de contexte
| Couche | Quand | Budget | Contenu |
|---|---|---|---|
| L0 toujours | chaque session | `AGENTS.md` ≤ 60 l, `STATE.md` ≤ 60 l, `CLAUDE.md` ≤ 3 l, total ≤ 130 l / 11 Ko ; descriptions de skills ≤ 450 c chacune | règles impératives, état court, table d'entrée |
| L1 à la demande | l'intention le demande | skill ≤ 80 l ; section de doc ≤ 150 l | procédure, archétype, ADR concerné |
| L2 référence | recherche ciblée (ancre, grep) | jamais en bloc | `APP-CONTRACT`, référence OpenChoreo, `decisions.md`, preuves, schémas |
| L3 mémoire | reprise de session | `STATE` + journal | état, journal en ajout, preuves datées |
Chaque dossier L2 reçoit un `README.md` de 10-20 lignes « fichier → quand l'ouvrir » (modèle llms.txt) ; un doc de plus de 300 lignes reçoit une table des matières avec ancres.

### 3.3 Skills, index machine-lisible, mémoire
- **Skills** : une procédure = un skill (existant : `add-app`, `fix-app`, `diagnose-app`, `promote-or-rollback`, …). Atlas ajoute **un seul** skill transverse, `route-intent` ; il n'héberge pas les skills des dépôts. Lien `.claude/skills → ../.agents/skills` conservé (déjà en place dans le lab).
- **Index** (`atlas-proposal/context/index.yaml`) : `repos` (rôle, maturité, tracker, registre de décisions, surface d'écriture), `intents` (déclencheurs → dépôt → skill → documents à lire), `precedence`, `fallback`. 130 lignes ≈ 2 k tokens ; validé par script (chemins, skills, dépôts déclarés).
- **Mémoire d'état** : `STATE.md` réécrit à chaque jalon (≤ 60 l, gabarit §6) + `docs/state/journal/AAAA-MM-JJ.md` en ajout seul (une ligne par événement) + preuves datées dans `docs/proofs/`. Un seul rédacteur (le coordinateur) ; les sous-agents rendent un résultat, ils n'écrivent pas l'état. Même protocole que `homelab-infra/docs/state/` (déjà éprouvé, < 60 l).
- **Mémoire de session** (compaction, notes) : jamais source de vérité ; avant compaction, mettre `STATE.md` à jour.

### 3.4 Fraîcheur et anti-dérive
- En-tête `---` : `owner`, `updated` (ISO), `review_days` ; obligatoire sur `AGENTS.md`, `STATE.md`, `MISSION.md`, index, politiques ; facultatif ailleurs (validé s'il est présent). ADR exemptés (immuables, statut explicite).
- Check CI `tools/context-check/check_context.py` (brouillon livré, 17 tests) : taille max des fichiers L0 et de leur somme ; liens Markdown et `@import` relatifs valides ; fraîcheur ; description de skill trop longue (avertissement) ; motifs interdits par domaine (`deny`) pour matérialiser une décision (ex. `ThunderID` hors tests k3d après D2).
- Sur le lab réel aujourd'hui : 5 erreurs (STATE 74 l / 13 Ko, total 15 Ko, deux en-têtes de fraîcheur manquants), 0 lien mort, 2 avertissements de description ; les 3 fichiers cibles passent sans erreur.
- À ajouter ensuite (non livré) : cohérence `docs/adr/README.md` ↔ fichiers (0013, 0014 absents) ; validation de l'index Atlas ; workflow hebdomadaire qui ouvre une issue « contexte périmé » ; `/doctor prompt-audit` mensuel [L] pour les contradictions sémantiques que le code ne voit pas.

## 4. Parcours : intention → PR (« installe-moi Mealie avec login famille et sauvegarde »)
| # | Étape | Contexte minimal chargé | ≈ tokens |
|---|---|---|---|
| 1 | Réception (session Atlas, ou tout dépôt avec la table de routage) | `AGENTS.md` Atlas + description de `route-intent` | 1,0 k |
| 2 | **Routage** : intentions `deploy-app` + exigences `oidc-login`, `backup-restore` ; lieu non dit → annoncer le choix (D1) ; ≤ 1 question | `context/index.yaml` | 2,0 k |
| 3 | Ouvrir le dépôt cible (cloner celui-là seul) | `AGENTS.md` (1,1 k) + `STATE.md` cible (0,9 k) | 2,0 k |
| 4 | **Skill** `add-app` + garde-fous (classe AUTONOME/REVUE/MANDAT) | `SKILL.md` 1,2 k + `platform-guardrails` 1,6 k | 2,8 k |
| 5 | **Qualifier** : recette `recipes/mealie.yaml` (image arm64 par digest, port, santé, OIDC, base) sinon `imagetools inspect` ; archétype (`golden-paths/README.md` ligne utile) ; ADR-0007 et ADR-0008 par section | recette 0,5 k + extraits 1,0 k | 1,5 k |
| 6 | Écrire `apps/mealie/app.yaml` depuis `golden-paths/<X>/app.yaml` | gabarit | 0,8 k |
| 7 | `appgen render/check`, sortie bornée ; corrections | sortie d'outil ≤ 30 lignes | 0,5 k |
| 8 | PR (corps : plan lisible, preuves, rollback) ; CI `ci-ok` ; classe REVUE/MANDAT pour OIDC et stockage → Paul ; noms de clés seulement | gabarit de PR | 0,5 k |
| 9 | Après merge : Argo, OpenChoreo, preuve runtime datée, compte rendu | `golden-paths/<X>/CHECKLIST.md` | 0,8 k |
Total ≈ **11,9 k** avec tous les gabarits (≈ 10 k si les garde-fous sont déjà en contexte ou résumés dans le skill) contre ≈ 20 k aujourd'hui (Atlas 7 k + lab 7,3 k + skills 2,8 k + `golden-paths/README` 2,8 k, sans compter une lecture partielle d'`APP-CONTRACT`). Points de contrôle déterministes : schéma `app.schema.json` via `appgen check`, CI, VAP, preuve runtime : l'agent juge, les machines décident si on avance.
Garde-fous du parcours : ne jamais déduire image/port/digest de la mémoire du modèle (ADR-0013) ; une seule question parmi `ask_only_if` ; blocage MANDAT annoncé avec les **noms** de secrets à créer, en parallèle de la PR.

## 5. Plan de migration
| Étape | Contenu | Critère de fin | Risque |
|---|---|---|---|
| M0 | Fusionner ce dossier (docs/research) ; lancer le check en mode informatif | script et 17 tests dans la CI du lab, non bloquant | nul |
| M1 lab | Remplacer `AGENTS.md` ; migrer l'ancien `STATE.md` vers `docs/state/journal/2026-11-18.md` et repartir du gabarit ; ajouter l'en-tête à `MISSION.md` ; corriger périmés §1.3 (README golden-paths, README ADR 0013-0014) ; check bloquant | démarrage ≤ 130 l ; check vert | moyen : relire que chaque règle de l'ancien `AGENTS.md` subsiste (diff ligne à ligne) |
| M2 Atlas | `AGENTS.md` court, `context/index.yaml`, `skills/route-intent`, entrée de catalogue ; README ramené à ~10 lignes ; `scripts/check-context.py` (même script + validation d'index) ; `.claude/skills` | « installe X » routé sans question inutile sur 5 intentions types | faible |
| M3 | Appliquer D1-D3 : trancher tracker/registre/préséance ; ADR-0007 ACTÉ puis purge ThunderID (`APP-CONTRACT`, `BASE-CHOICE`, schéma : défaut `provider`) ; niveaux de preuve Atlas adoptés par le lab ; règle « la plus stricte gagne » écrite | 0 contradiction listée en §1.4 ; règle `deny` active | moyen (touche le contrat) |
| M4 | kube-ops et homelab-infra : `AGENTS.md` ≤ 60 l (kube-ops 78 l : sortir la surface de commandes dans un skill), `decisions-active` seule lecture obligatoire (déjà ≤ 1 200 mots), `invariants` à la demande, en-têtes de fraîcheur ; table de routage locale vers Atlas | check vert dans les 2 dépôts | faible |
| M5 | Recettes (`recipes/`) + banc d'essai ADR-0013 (10 intentions) ; hook `PreToolUse` refusant `kubectl apply` et sorties de secrets dans le lab (modèle : kube-ops `secret-output-guard.py`) ; workflow hebdomadaire de péremption | métriques §7 mesurées avant/après | moyen |
Ordre imposé : M1 avant M2 (le lab doit être autosuffisant avant que le routage s'y appuie) ; M3 en parallèle dès que Paul a décidé.

## 6. Livrables de ce dossier (`docs/research/context-engineering/`)
- `atlas-proposal/AGENTS.md` (réécriture, 33 l), `repos/catalog.entry-openchoreo-lab.md`, `context/index.yaml` (12 intentions, 5 dépôts), `skills/route-intent/SKILL.md` (39 l, exemple Mealie).
- `openchoreo-lab-proposal/AGENTS.md` (44 l : les 8 règles + périmètre + INTERDIT condensés + table d'entrée + préséance), `CLAUDE.md`, `STATE.md` (gabarit 45 l rempli d'exemples), `tools/context-check/` (script, config, tests, extrait CI).
- Règles conservées dans le nouveau `AGENTS.md` du lab : lecture de `STATE`, PR pour tout changement durable, `generated/` intouchable, aucun secret, pas de contournement admission/PSA/NetworkPolicy, périmètre `openchoreo-*`/`lab-*` (+ lecture `dp-*`, `argocd`, `cnpg-system`, `external-secrets`, `default`), PASS = preuve datée, k3d ≠ OKE, français conclusion d'abord. Déplacés : liste des skills (déjà dans leurs descriptions et `.agents/README.md`), détail des interdits (reste dans `MISSION.md`), historique et accès (journal, handoff privé).
- Ajout assumé : « En cas de conflit » (préséance) et « Discipline de contexte » ; l'INTERDIT condensé duplique volontairement 6 lignes de `MISSION.md` car c'est une règle impérative qui doit être toujours chargée.

## 7. Mesures de succès (à relever avant M1 puis après M5)
Lignes et tokens L0 par dépôt (cible ≤ 150 l, ≤ 3 k tokens) ; tokens du parcours §4 (cible ≤ 10 k) ; nombre de contradictions détectées par `deny` + audit (cible 0) ; fichiers L0 périmés (0) ; sur le banc de 10 intentions : questions posées (≤ 1), interventions humaines hors MANDAT (0), délai intention → PASS runtime.

## 8. Décisions que Paul doit prendre
- **D1 : cible par défaut et autorité par domaine.** « Installe X » va-t-il vers openchoreo-lab (jetable) ou kube-ops (production actuelle) ? Et pour le lab : issues GitHub/`backlog/` ou Linear ; ADR locaux ou `decisions.md` ; en cas de conflit d'autonomie, « la règle la plus stricte gagne » ? Recommandation : lab par défaut pour les apps éligibles sans donnée irremplaçable, kube-ops sinon, choix annoncé ; un tracker et un registre **par domaine** déclarés dans l'index ; plus stricte gagne.
- **D2 : IdP du lab.** Acter ADR-0007 (Authentik seul, ThunderID limité aux tests k3d) et corriger `app.schema.json` (défaut `thunderid`), `APP-CONTRACT`, `BASE-CHOICE`, `AGENT-ACCESS` ? Recommandation : oui, avec la règle `deny` de la CI pour éviter le retour.
- **D3 : comment Atlas (privé) atteint les agents cloud.** Atlas monté en lecture seule dans chaque session, ou index public généré (`context/index.yaml` sans secret) miroir dans chaque dépôt ? Recommandation : montage lecture seule, avec la table de routage locale comme repli (déjà dans le nouvel `AGENTS.md` du lab) ; un propriétaire nommé (Paul) de la fraîcheur d'Atlas.
