import os, textwrap
B = "/home/user/openchoreo-lab/backlog"
T = []
def t(id, slug, title, phase, adr, deps, cls, scope, intent, done, notes="", issue=None):
    T.append(dict(id=id, slug=slug, title=title, phase=phase, adr=adr, deps=deps, cls=cls, scope=scope,
                  intent=intent, done=done, notes=notes, issue=issue))

# P0 — Fondations
t("T-001","integrer-pr8-security-bundle","Fusionner la PR #8 (installation fail-closed avec le security bundle)","P0",["0002"],[],"REVUE",
  "tools/oke/, security/, docs/SECURITY-BUNDLE.md, tests/security-bundle/",
  "Débloquer `main` : intégrer la remédiation et l'installation fail-closed (STATE.md §6.1), diff public neutre.",
  ["`ci-ok` vert sur la PR #8", "grep des mots sensibles vide sur le diff public", "PR fusionnée (squash), STATE.md à jour"],
  "Coordinateur. Prérequis de tout ce qui installe sur OKE.")
t("T-002","ci-k3d","CI k3d jetable sur runners GitHub (PR #36) avec les 4 corrections de revue","P0",["0002","0004"],["T-003"],"REVUE",
  ".github/workflows/k3d-integration.yml, tools/k3d/",
  "Rendre la CI k3d fiable : c'est le contrôle compensatoire de l'autonomie sur `platform/` (ADR-0002 §4).",
  ["`development` vient de `platform/` (T-003), plus de `yq` dans le bootstrap", "gitops-k3d gardé en échec connu, pas retiré", "tests AUD : audit activé ou NOT_TESTED, jamais PASS", "limite « chart sans bundle » écrite dans la PR", "suites vap, k3d, argo-escalation vertes"],
  "Revue de la PR #36 faite le 2026-11-18 (4 points).")
t("T-003","env-development-promotion","Environment `development`, promotion vers `production`, pins de release par environnement","P0",["0004"],[],"AUTONOME",
  "platform/install/manifests/40-openchoreo-env.yaml, tools/appgen/, tests/appgen/",
  "Deux Environments sur le même data plane ; `appgen promote <app>` épingle en production la release validée en dev (corrige G3).",
  ["tests appgen verts (pins par env, promote, rollback)", "CI k3d verte", "preuve OKE datée : une app A en development, release prod inchangée"],
  "", 49)
t("T-004","garde-frugalite-dev","Check CI de frugalité du dev","P0",["0004"],["T-003"],"AUTONOME",
  "tools/appgen/, tests/appgen/",
  "Refuser : plus de 2 apps en development, `replicas` > 1 ou `size` ≠ small en dev, stockage ou base en dev sur OKE.",
  ["un test par refus", "message d'erreur typé avec la correction attendue"], "", 50)
t("T-005","preuve-runtime-auto","Preuve runtime automatique après sync et statut `app-status.v1`","P0",["0011"],["T-003"],"AUTONOME",
  "platform/ (Job PostSync, SA lecture), golden-paths/_checks/, tools/, tests/",
  "Après chaque sync Argo, un Job lit l'état et exécute les checks de l'archétype, puis publie un `app-status.v1` daté (statut de commit + lisible par MCP).",
  ["schéma `app-status.v1` versionné (repris de kube-ops)", "`_checks` en sortie JSON stable", "k3d CI : PASS puis FAIL volontaire typé", "preuve OKE datée sans coordinateur", "Job ≤ 50m / 64Mi, se termine"],
  "Supprime le goulot « coordinateur + bastion » pour les apps.", 51)
t("T-006","mcp-cloudflare-access","MCP OpenChoreo lisible depuis les sessions cloud (Tunnel + Access + authz)","P0",["0010","0007"],["T-001"],"REVUE + MANDAT",
  "platform/ (NetworkPolicy tunnel → MCP), docs/CLOUD-AGENTS.md, tests/mcp/",
  "Lecture MCP depuis une session cloud avec double contrôle : service token Access et client `openchoreo-agent-reader`.",
  ["NetworkPolicy : seul le namespace du tunnel atteint le port MCP", "depuis une session cloud : lecture OK, sans token Access → refus, écriture → refus (preuve datée)", "MANDAT Paul : hôte, application Access, service token, client Authentik, network secrets de l'environnement cloud"],
  "Vérifier : service token en un seul en-tête ; JWT reader par client_credentials injecté par le proxy.", 52)
t("T-007","test-noyau-codeowners","Test CI : le noyau de `CODEOWNERS` correspond à ADR-0002","P0",["0002"],[],"REVUE",
  "tests/, .github/workflows/ci.yaml",
  "Empêcher une dérive silencieuse de la frontière agents/humain.",
  ["le test échoue si un chemin du noyau ADR-0002 manque dans CODEOWNERS", "job requis par `ci-ok`"])
t("T-008","lint-backlog","Check CI des tickets `backlog/`","P0",["0012"],[],"AUTONOME",
  "tools/, tests/, backlog/README.md",
  "Valider l'en-tête des tickets : id unique, statut connu, dépendances existantes et sans cycle, ADR existant.",
  ["script + tests", "job ajouté à la CI (PR REVUE pour `.github/`)"])
t("T-009","budget-oke-mesure","Mesurer le budget réel d'OKE avec OpenChoreo, dev et futurs composants","P0",["0003","0004"],["T-001"],"AUTONOME",
  "tools/oke/verify.sh (lecture), docs/",
  "Savoir ce qui tient sur le nœud A1 (seuil 70 %) avant d'ajouter OpenBao, Kyverno, Crossplane ou des apps.",
  ["mesure datée (requests, usage, pods, IP)", "tableau : composant → cluster recommandé", "mise à jour de D1 dans DECISIONS-OPEN si besoin"])

# P1 — Golden path complet
t("T-010","probes-quota","Probes depuis `healthPath` (G2) et quota de cellule dérivé (G4)","P1",["0005"],["T-002"],"AUTONOME",
  "tools/appgen/, platform/component-types/, platform/project-types/, tests/",
  "Ready signifie « app saine » ; le quota suit `size × replicas` et le stockage.",
  ["readiness/liveness rendues", "quota calculé, test medium×3 et archétype C", "CI k3d verte"])
t("T-011","archetype-d-worker-cron","Archétype D : `spec.kind: worker | cronjob` (G1)","P1",["0005"],["T-010"],"AUTONOME",
  "docs/schema/, tools/appgen/, platform/component-types/, golden-paths/D-*/",
  "Déclarer un worker ou une tâche planifiée sans endpoint HTTP.",
  ["CCT `worker-restricted` et `cronjob-restricted` durcies", "template + checklist + suite k3d", "preuve OKE ou homelab datée"])
t("T-012","verify-contrat","`spec.verify` : vérification fonctionnelle déclarée (G10)","P1",["0011","0013"],["T-005"],"AUTONOME",
  "docs/schema/, tools/appgen/, golden-paths/_checks/",
  "L'app dit ce qu'on doit observer (code HTTP, redirection IdP) ; la preuve automatique l'exécute.",
  ["champ dans le schéma", "lu par le Job de preuve", "exemples pour A, B, OIDC"])
t("T-013","overrides-dependances","Surcharges par environnement (G12) et dépendances entre apps (G11)","P1",["0005","0004"],["T-003"],"AUTONOME",
  "docs/schema/, tools/appgen/",
  "`overrides.<env>` (size, replicas, env) et `dependsOn` (egress ciblé + variable d'URL).",
  ["tests appgen", "NetworkPolicy d'egress ciblée rendue", "preuve k3d A → B"])
t("T-014","archetype-e-helm-durci","Archétype E : chart Helm tiers encapsulé dans une cellule durcie (G7)","P1",["0005","0006"],["T-010"],"AUTONOME",
  "tools/appgen/, golden-paths/E-*/, tests/",
  "Un logiciel livré seulement en chart passe par le même contrat : namespace PSA, default-deny, quota, LB=0, validation du rendu.",
  ["rendu refusé si objet cluster-scoped, RBAC, LB, privileged", "template + checklist + suite k3d", "une app réelle du catalogue kube-ops en preuve"])
t("T-015","golden-path-ntfy","Golden path n°2 (ntfy interne) : development puis production","P1",["0004","0011"],["T-003","T-005","T-006"],"AUTONOME",
  "apps/ntfy/, generated/**, lab-apps.yaml",
  "Premier cycle complet du modèle : dev, preuve auto, promotion, rollback.",
  ["dev : PASS daté automatique", "promotion par PR, PASS en production", "rollback par `git revert` prouvé"], "", 53)

# P2 — Primitives
t("T-020","kyverno-enforce","Kyverno en Enforce sur le golden path, exceptions générées","P2",["0006"],["T-002","T-009"],"AUTONOME",
  "platform/kyverno/, tests/kyverno/, tools/appgen/",
  "Porter les règles Deny du golden path kube-ops ; `securityExceptions` → PolicyException générée.",
  ["suites de refus en CI k3d", "homelab : Enforce ; OKE : selon T-009 (sinon VAP seules)", "namespaces plateforme exclus, restauration non bloquée"])
t("T-021","reseau-egress-imds","Egress déclaré (FQDN Cilium) et IMDS refusé dans toutes les cellules","P2",["0006","0003"],["T-002"],"AUTONOME",
  "tools/appgen/, platform/project-types/, tests/",
  "Même rendu réseau sur OKE et homelab ; `dp-*` couverts par le refus IMDS.",
  ["CNP rendues pour fqdn/app/idp", "preuve OKE : IMDS refusé depuis une cellule `dp-*`", "test de non-régression egress"])
t("T-022","spike-openbao","Spike OpenBao : placement, stockage, déscellement, sauvegarde","P2",["0014"],["T-009"],"AUTONOME + MANDAT",
  "docs/storage/, platform/ (brouillon), tests/",
  "Qualifier OpenBao sur OKE : backend (PostgreSQL plateforme ou Raft), auto-unseal hors cluster, sauvegarde chiffrée hors Oracle, coût.",
  ["mesure CPU/mémoire", "auto-unseal prouvé sur k3d", "drill perte + restauration", "MANDAT Paul : clé d'auto-unseal, stockage des clés de récupération"])
t("T-023","secrets-generate-provided","Secrets `generate` et `provided` via OpenBao + ESO, statut `secret-missing`","P2",["0014","0011"],["T-022","T-005"],"AUTONOME",
  "docs/schema/, tools/appgen/, platform/, tests/",
  "Aucun secret applicatif posé à la main avant déploiement ; un secret tiers manquant donne BLOCKED typé.",
  ["k3d : app `generate` démarre sans geste, valeur stable après recréation du namespace", "app `provided` BLOCKED puis Ready", "agents sans lecture de valeur (test de politique)"])
t("T-024","identite-oidc-declaree","Identité : ThunderID retiré, `identity.mode: oidc | proxy | none`","P2",["0007"],["T-023"],"AUTONOME",
  "docs/schema/, tools/appgen/, platform/identity/, clusters/*/capabilities.yaml",
  "Client OIDC Authentik généré (blueprint) avec secret dans OpenBao ; mode proxy par l'outpost ; accès par groupe.",
  ["ThunderID absent du contrat et du chart", "k3d : client créé sans geste, hors groupe → refus", "preuve sur une app réelle"])
t("T-025","classe-donnees","Classe de donnée dans le contrat et labels `data-class` (G8)","P2",["0008"],["T-010"],"AUTONOME",
  "docs/schema/, tools/appgen/, platform/",
  "`data.class: ephemeral | rebuildable | useful | irreplaceable`, propagée en label ; `Retain` et pas de prune sur les données.",
  ["schéma + migration des apps existantes", "CI : base/volume sans classe → refus", "labels présents sur namespace, PVC, base"])
t("T-026","sauvegardes","Sauvegardes : CNPG → R2 par préfixe, mécanisme unique pour les volumes","P2",["0008","0009"],["T-025"],"AUTONOME + MANDAT",
  "platform/resource-types/, tools/appgen/, docs/storage/",
  "La plateforme choisit le mécanisme selon la classe ; spike VolSync/restic vs Velero/Kopia pour les volumes.",
  ["base : WAL + base backup vers R2 hors Oracle", "volume : mécanisme choisi et mesuré", "MANDAT Paul : jeton R2 limité au bucket (Tofu)"])
t("T-027","drill-restauration-auto","Drill de restauration automatique et `restore-evidence`","P2",["0008","0011"],["T-026","T-005"],"AUTONOME",
  "platform/, golden-paths/_checks/, tests/",
  "Pour `useful`/`irreplaceable` : restauration planifiée dans un namespace jetable, `verify`, preuve datée avec péremption.",
  ["drill PASS daté sur une app B", "app non conforme signalée si preuve périmée", "`irreplaceable` autorisé par la CI après preuve"])
t("T-028","exposition-publique","Exposition `private | internal | public` : route par hôte (G6) et Access par app","P2",["0010","0009"],["T-029"],"AUTONOME",
  "docs/schema/, tools/appgen/, platform/",
  "Une app `public` avec auth est publiée sans geste ; sans auth, refus.",
  ["CI : public sans auth → refus", "sonde externe : sans session → 302/403", "`git revert` retire la publication"])
t("T-029","spike-crossplane","Spike Crossplane sur le homelab (provider Cloudflare pour Access)","P2",["0009"],["T-030"],"AUTONOME + MANDAT",
  "docs/, platform/ (brouillon homelab)",
  "Qualifier un provider Cloudflare maintenu, `deletionPolicy: Orphan`, coût ; sinon repli Tofu via ARC.",
  ["provider choisi ou rejeté avec preuves", "app `public` → application Access créée, `git revert` → retirée", "MANDAT Paul : jeton Cloudflare limité à Access"])

# P3 — Hybride
t("T-030","dataplane-homelab","Enregistrer le homelab comme `ClusterDataPlane` (chemin NetBird L4)","P3",["0003"],["T-001"],"REVUE + MANDAT",
  "platform/install/, clusters/homelab/, docs/architecture/MULTI-DATAPLANE.md",
  "Agent homelab sortant vers le cluster-gateway d'OKE, mTLS de bout en bout, capacités homelab déclarées.",
  ["agent connecté, preuve datée", "SAN du cluster-gateway correct", "MANDAT Paul : ACL NetBird, accès Talos"])
t("T-031","placement-coupure","Règle de placement et test de coupure du homelab","P3",["0003"],["T-030"],"AUTONOME",
  "tools/appgen/, .agents/skills/add-app/, tests/",
  "L'agent place l'app selon ADR-0003 §4 ; une coupure homelab de 10 min ne casse ni le CP ni les apps.",
  ["règle codée et testée", "preuve de coupure datée", "même app déplacée oke ↔ homelab par changement de `cluster`"])

# P4 — Intention en langage naturel et connaissance
t("T-040","recettes-apps","Catalogue de recettes d'apps homelab vérifiées","P4",["0013"],["T-010"],"AUTONOME",
  "recipes/, tools/, tests/",
  "Faits vérifiés pour les apps courantes (image multi-arch par digest, port, santé, OIDC, base, volume, classe suggérée).",
  ["format + 10 recettes", "CI : digest existant et arm64", "agent de rafraîchissement documenté"])
t("T-041","context-engineering","Context engineering : contexte en couches, AGENTS.md court, checks de fraîcheur","P4",["0012"],[],"REVUE",
  "AGENTS.md, STATE.md, docs/, tools/, tests/",
  "Appliquer la proposition `docs/research/context-engineering/` dans ce dépôt.",
  ["fichiers toujours chargés sous la taille cible", "check CI taille/liens/fraîcheur", "aucune règle impérative perdue (diff relu)"])
t("T-042","atlas-route-intent","Atlas : entrée de catalogue et skill de routage d'intention","P4",["0012","0013"],["T-041"],"REVUE",
  "dépôt Atlas (PR séparée)",
  "Une intention en langage naturel est routée vers le bon dépôt et le bon skill.",
  ["entrée openchoreo-lab dans `repos/catalog.md`", "skill `route-intent` + index machine-lisible", "PR Atlas ouverte (accès en écriture à donner)"])
t("T-043","plan-compte-rendu","Gabarits de plan et de compte rendu dans `add-app`","P4",["0013"],["T-005"],"AUTONOME",
  ".agents/skills/add-app/, .agents/skills/fix-app/",
  "Avant : plan lisible de quelques lignes ; après : PR, statut, URL, comment annuler. Questions seulement sans défaut sûr.",
  ["gabarits", "liste fermée des questions autorisées", "exemple joué"])
t("T-044","banc-intentions","Banc d'essai de 10 intentions en langage naturel","P4",["0013"],["T-040","T-043","T-015"],"AUTONOME",
  "tests/intents/",
  "Mesurer questions posées, PASS runtime et interventions humaines sur 10 intentions types.",
  ["10 scénarios écrits", "rapport daté", "chaque échec → ticket ou garde-fou"])

# P5 — Migration
t("T-050","verdicts-kube-ops","Verdict A-F pour chaque app de kube-ops","P5",["0005"],["T-011","T-014"],"AUTONOME",
  "docs/, apps/ (brouillons)",
  "Passer le catalogue kube-ops dans `migrate-to-openchoreo` pour mesurer la couverture du contrat.",
  ["tableau app → archétype → manques", "liste des évolutions de contrat nécessaires"])
t("T-051","premiere-app-familiale","Première app familiale complète (OIDC + base + sauvegarde) sur le homelab","P5",["0007","0008","0014","0003"],["T-024","T-027","T-031"],"AUTONOME",
  "apps/<app>/",
  "Preuve de bout en bout sur une app réelle (ex. Vikunja ou Mealie) déclarée depuis une intention en langage naturel.",
  ["PASS runtime daté", "drill de restauration PASS", "login famille OK, hors groupe refusé"])
t("T-052","retrait-kube-ops","Retrait progressif des chemins kube-ops, app par app","P5",["0001","0008"],["T-051"],"MANDAT",
  "kube-ops (PR séparées), apps/",
  "Basculer chaque app migrée, puis retirer l'ancien chemin sans perte de données.",
  ["export + restauration prouvés avant bascule", "suppression de données = MANDAT", "kube-ops à jour"])


# ===== Corrections issues de la revue Sonnet (2026-11-18) =====
X = {x['id']: x for x in T}
def upd(id, **kw):
    for k,v in kw.items(): X[id][k]=v
def add_done(id, *c): X[id]['done'] += list(c)
def add_dep(id, *d):
    for e in d:
        if e not in X[id]['deps']: X[id]['deps'].append(e)
def new(*a, **k):
    t(*a, **k); X[T[-1]['id']] = T[-1]

# Nouveaux tickets
new("T-060","residu-kgateway","Résidu kgateway : SA avec lecture des Secrets cluster-wide (B6-sa-effective FAIL)","P0",["0006"],["T-001"],"REVUE",
  "platform/install/values/, tools/oke/, tests/",
  "Fermer le résidu de moindre privilège accepté (STATE.md §1) avant tout credential réel.",
  ["`verify.sh` : B6-sa-effective PASS daté sur OKE", "test de non-régression en CI k3d"])
new("T-061","aligner-mission-adr","Acter les ADR et aligner MISSION, AGENTS, STATE sur ADR-0002/0007/0010/0012/0014","P0",["0002","0012"],[],"MANDAT",
  "missions/MISSION.md, AGENTS.md, STATE.md, docs/adr/",
  "Lever les contradictions : MISSION interdit encore exposition publique, création d'identité, Cloudflare ; services visés obsolètes ; ADR tous PROPOSÉ.",
  ["Paul approuve : ADR passés ACTÉ (ou amendés)", "MISSION : interdits réécrits en classes (public avec auth, clients OIDC générés, Crossplane borné, volume OCI = MANDAT)", "AGENTS.md renvoie à backlog/ et docs/adr/ ; STATE.md sans contradiction"])
new("T-062","lab-platform-auto","`lab-platform` en synchronisation automatique (hors lab-pg)","P0",["0002"],["T-001","T-002"],"REVUE",
  "platform/install/argocd/",
  "Un merge sur `platform/` hors noyau est appliqué sans geste humain (promesse d'ADR-0002 §1).",
  ["sync auto, `prune: false`, selfHeal", "lab-pg exclu tant que le volume n'est pas autorisé", "preuve : un changement de CCT appliqué après merge"])
new("T-063","dr-plateforme","Reprise après sinistre de la plateforme : runbook de reconstruction et drill","P2",["0008","0003"],["T-022","T-062"],"AUTONOME + MANDAT",
  "docs/runbooks/, tests/",
  "Reconstruire OKE de zéro : CA du cluster-gateway et mTLS des data planes, Argo, ESO, OpenBao, objets OpenChoreo, bundle privé ; RTO mesuré.",
  ["runbook ordonné avec RTO", "drill complet sur k3d en CI ou manuel daté", "liste des secrets racines nécessaires (Doppler) sans valeurs"])
new("T-064","mises-a-jour","Mises à jour : Renovate (digests), montée OpenChoreo, montée OKE/K8s","P1",["0006","0004","0012"],["T-005","T-003"],"REVUE",
  ".github/renovate.json, docs/runbooks/, tools/",
  "Les images épinglées par digest sont mises à jour par PR, testées en dev avant prod ; procédure de montée OpenChoreo (bundle de sécurité, CRD, référence doc) et OKE (nœud unique).",
  ["Renovate ouvre des PR de digest, dev avant prod", "runbook de montée OpenChoreo d'une mineure, avec mise à jour de docs/reference/openchoreo/", "runbook de montée OKE"])
new("T-065","sante-periodique-alertes","Santé périodique, revert automatique et alertes (+ G5 observabilité)","P1",["0011","0002"],["T-005","T-015"],"AUTONOME + MANDAT",
  "platform/, golden-paths/_checks/, tools/appgen/",
  "Une régression entre deux syncs (CrashLoop, preuve de restauration périmée) est vue : statut périodique, PR de revert automatique, notification ntfy ; `observability` rendu (G5).",
  ["CronJob de statut ≤ 30 min d'intervalle", "régression simulée → PR de revert ouverte et notification reçue", "G5 rendu ou déclassé dans SCHEMA-GAPS"])
new("T-066","rotation-secrets","Rotation et échéances des secrets et jetons racines","P2",["0014"],["T-023"],"MANDAT",
  "docs/runbooks/, tools/",
  "Inventaire des échéances (service token Access, jetons R2, jeton GitHub, clé d'auto-unseal, secrets clients OIDC) et procédure testée.",
  ["inventaire sans valeurs, avec échéances", "rotation d'un secret OIDC prouvée sans coupure", "alerte avant échéance"])
new("T-067","retrait-app","`appgen retire` : retrait d'une app avec export des données","P2",["0001","0008","0013"],["T-025","T-026"],"AUTONOME",
  "tools/appgen/, .agents/skills/",
  "« Supprime X » : retrait par PR, export et `Retain` des données ; la suppression effective de données `useful`/`irreplaceable` reste MANDAT.",
  ["commande + tests", "preuve k3d : app retirée, données exportées et conservées"])
new("T-068","securite-agents","Sécurité et attribution des agents","P1",["0002","0011"],["T-001"],"REVUE + MANDAT",
  "docs/AGENT-IDENTITY.md, .github/, platform/authz/",
  "Compte dédié rôle Write, jetons fins sans admin, trailers d'attribution, journal des clients OpenChoreo ; entrées non fiables (issues, README amont, recettes) traitées comme données.",
  ["identité agent créée par Paul (MANDAT)", "test : un agent ne peut pas fusionner une PR du noyau", "règle documentée contre l'injection de prompt"])
new("T-069","vap-data-class","VAP : refus de DELETE des données `irreplaceable` (G8)","P2",["0008","0006"],["T-025"],"REVUE",
  "platform/policies/, tests/vap/",
  "Un objet porteur de `data-class=irreplaceable` ne peut pas être supprimé sans exception explicite.",
  ["VAP + suite de refus en CI k3d", "preuve OKE ou homelab datée"])
new("T-070","garde-contrat","Garde du contrat : compatibilité du schéma et aucun objet Kubernetes hors `apps/`/`generated/`","P1",["0001","0005"],["T-002"],"REVUE",
  "tools/, tests/, .github/workflows/",
  "Mettre en œuvre la vérification d'ADR-0001 et le versionnage d'ADR-0005 §3.",
  ["CI : rupture de schéma sans changement de version → refus", "CI : manifeste applicatif hors apps/generated → refus", "indicateur : part des apps déclarées par app.yaml seul"])
new("T-071","doc-utilisateur","Guide utilisateur : demander, suivre, annuler, déposer un secret","P4",["0013","0014"],["T-043","T-023"],"AUTONOME",
  "docs/USER-GUIDE.md",
  "Ce qu'un humain doit savoir pour parler à la plateforme, en une page.",
  ["une page, exemples de phrases", "dépôt d'un secret `provided` expliqué", "lecture d'un `app-status` expliquée"])
new("T-072","app-status-schema","Schéma `app-status.v1` et `_checks` en sortie JSON stable","P0",["0011"],["T-001"],"AUTONOME",
  "docs/schema/, golden-paths/_checks/, tests/",
  "Préparer la preuve automatique : format de statut versionné (repris de kube-ops) et checks qui l'émettent.",
  ["schéma JSON versionné + exemples", "`_checks` émet ce format, tests"])
new("T-073","dependances-apps","Dépendances entre apps `dependsOn` (G11)","P2",["0005"],["T-021"],"AUTONOME",
  "docs/schema/, tools/appgen/",
  "Egress ciblé + variable d'URL vers une autre app.",
  ["tests appgen", "NetworkPolicy d'egress ciblée rendue", "preuve k3d A → B"])
new("T-074","retrait-thunderid","Retirer ThunderID du contrat et des capacités ; Authentik seul","P1",["0007"],["T-001"],"AUTONOME",
  "docs/schema/, docs/APP-CONTRACT.md, docs/BASE-CHOICE.md, docs/AGENT-ACCESS.md, clusters/*/capabilities.yaml",
  "Une seule vérité sur l'IdP ; un refus CI empêche le retour de `thunderid`.",
  ["schéma : `authentik` seul", "docs corrigées", "test CI de refus"])
new("T-075","sauvegarde-volumes","Sauvegarde des volumes : spike VolSync/restic vs Velero/Kopia","P2",["0008"],["T-025","T-030"],"AUTONOME",
  "docs/storage/, platform/",
  "Un seul mécanisme pour les volumes, mesuré sur le homelab.",
  ["comparaison mesurée (coût, restauration)", "mécanisme choisi installé en `lab-*`", "sauvegarde + restauration d'un PVC prouvées"])
new("T-076","access-par-app","Application Cloudflare Access générée par app (Crossplane)","P2",["0010","0009"],["T-029","T-028"],"AUTONOME",
  "tools/appgen/, platform/",
  "Une app `public` obtient son application Access ; `git revert` la retire.",
  ["preuve : création et retrait sans geste", "`deletionPolicy: Orphan` vérifié"])
new("T-077","banc-intentions-complet","Banc complet de 10 intentions (OIDC, base, publique, worker, supprime)","P5",["0013"],["T-051","T-042","T-067"],"AUTONOME",
  "tests/intents/",
  "Rejouer le banc sur l'ensemble des archétypes une fois la première app familiale livrée.",
  ["≥ 8/10 PASS runtime sans intervention humaine", "≤ 1 question en moyenne", "rapport daté"])

# Corrections de tickets existants
X["T-002"]["done"] = [d for d in X["T-002"]["done"] if "T-003" not in d]; upd("T-002", deps=[])
upd("T-003", deps=["T-001","T-002"]); add_done("T-003","le bootstrap CI k3d n'invente plus `development` (suppression du `yq`)")
add_done("T-004","contrôle des valeurs effectives après `overrides` (T-013)")
upd("T-005", title="Preuve runtime automatique après sync (Job PostSync + publication)", deps=["T-072","T-003"], cls="AUTONOME + REVUE + MANDAT",
    notes="Publication du statut de commit = jeton GitHub (MANDAT). RBAC de lecture à valider contre `argo_guard` (REVUE). Egress de la cellule vers l'API GitHub à déclarer. Supprime le goulot « coordinateur + bastion » pour les apps.")
X["T-005"]["done"] = [d for d in X["T-005"]["done"] if "schéma" not in d and "_checks" not in d]
upd("T-006", deps=["T-001","T-060"], notes="Inclure le déploiement/réglage de cloudflared et sa NetworkPolicy. Access exige normalement deux en-têtes de service token : l'injection en un seul en-tête est une hypothèse à prouver, sinon prévoir un relais.")
upd("T-008", cls="REVUE")
upd("T-009", title="Estimer le budget OKE et tenir le registre des quotas gratuits", intent="Estimation initiale de ce qui tient sur le nœud A1 (seuil 70 %) et registre des quotas Always Free (volumes, IP, LB) avec contrôle périodique. Les composants futurs sont re-mesurés dans leur propre ticket.",
    done=["mesure datée (requests, usage, pods, IP)", "tableau : composant → cluster recommandé", "registre des quotas gratuits (volumes orphelins, disque de boot) et contrôle périodique"])
upd("T-010", deps=["T-001","T-002"])
upd("T-013", title="Surcharges par environnement (G12)", deps=["T-003"], intent="`overrides.<env>` (size, replicas, env).",
    done=["tests appgen", "valeurs effectives vérifiées par la garde de frugalité"])
upd("T-015", deps=["T-003","T-005"])
upd("T-020", deps=["T-002","T-009","T-030"], done=["suites de refus en CI k3d", "installé en `lab-*` ; homelab : Enforce", "OKE seulement si Kyverno ≤ 400 Mi de requests et total < 70 % (re-mesure datée), sinon VAP seules", "namespaces plateforme exclus, restauration non bloquée"])
upd("T-021", deps=["T-002","T-030"], cls="AUTONOME + MANDAT", notes="La CCNP `deny-imds` et `allow-egress-unisolated` sont possédées par kube-ops (PR #1629 non fusionnée) : ne pas créer un second propriétaire.")
upd("T-022", done=["installé en `lab-*`, re-mesure CPU/mémoire datée", "auto-unseal prouvé sur k3d", "drill perte + restauration", "backend sans nouveau volume OCI, sinon MANDAT explicite pour le volume", "MANDAT Paul : clé d'auto-unseal, stockage des clés de récupération (Doppler + hors ligne)"])
upd("T-023", deps=["T-022","T-005","T-060"], cls="AUTONOME + REVUE + MANDAT")
add_done("T-023","CI : aucune cellule d'app ne référence le store Doppler")
upd("T-024", title="Identité déclarée : `identity.mode: oidc | proxy | none`", deps=["T-023","T-074","T-061"], cls="REVUE",
    notes="Préciser comment les blueprints atteignent l'Authentik de production (kube-ops #1630) et où tourne Authentik en k3d. `platform/identity/` est dans le noyau.")
X["T-024"]["done"] = [d for d in X["T-024"]["done"] if "ThunderID" not in d]
upd("T-025", deps=["T-002"])
upd("T-026", title="Sauvegarde des bases : CNPG → R2 par préfixe", deps=["T-025","T-023","T-030"],
    done=["WAL + base backup vers R2 hors Oracle", "jeton R2 hors cellule d'app ; bucket versionné ou object lock contre l'effacement", "`irreplaceable` : copie chiffrée côté client + vérification d'intégrité", "MANDAT Paul : jeton R2 limité au bucket (Tofu)"])
add_dep("T-027","T-012","T-075")
upd("T-028", title="Exposition `private | internal | public` : route par hôte (G6) et refus « public sans auth »", deps=["T-024","T-061"],
    done=["CI : public sans auth → refus", "route par hôte rendue", "sonde externe : sans session → 302/403"])
upd("T-029", deps=["T-030","T-009","T-061"], notes="Crossplane en `lab-*` sur le homelab. Les CR générées par appgen sont appliquées par l'Argo du homelab dans un projet borné à ces CR (ADR-0003 §6 amendé). Re-mesure CPU/mémoire datée.")
upd("T-030", phase="P0", done=["agent connecté, preuve datée", "SAN du cluster-gateway correct", "Environments development et production sur le homelab", "MANDAT Paul : ACL NetBird, accès Talos"],
    notes="À lancer tôt : la latence est humaine (MANDAT).")
upd("T-031", cls="AUTONOME + MANDAT")
upd("T-040", deps=["T-010"])
upd("T-041", phase="P1", done=["fichiers toujours chargés ≤ 130 lignes au total", "check CI taille/liens/fraîcheur", "aucune règle impérative perdue (diff relu)"])
upd("T-042", cls="REVUE + MANDAT", notes="Accès en écriture au dépôt Atlas à donner par Paul.")
upd("T-043", phase="P1")
upd("T-044", title="Banc d'essai initial de 10 intentions (A, répare, promeut)", deps=["T-015","T-041","T-043","T-040"],
    done=["10 scénarios écrits", "≥ 8/10 PASS runtime sans intervention humaine sur le périmètre disponible", "rapport daté ; chaque échec → ticket ou garde-fou"])
upd("T-050", phase="P1", deps=["T-008"])
upd("T-051", deps=["T-024","T-027","T-031","T-020","T-021","T-040","T-043"])
add_dep("T-052","T-050")
add_done("T-007","couvre aussi tools/k3d, tests/k3d, tests/gitops-k3d, tests/argo-escalation, platform-guardrails, platform/identity")

# ===== Intégration des propositions de recherche (2026-11-18) =====
import yaml
P = "/home/user/openchoreo-lab/backlog/proposals/"
BASE = {"observability":100,"upgrades":120,"cost":140,"ai-services":160,"identity-secrets":180,"data-platform":200}
NEWADR = {"NEW-OBS":"0015","NEW-UPGRADES":"0016","NEW-COST":"0017","NEW-AI":"0018","NEW-AI-SERVICES":"0018","NEW-IDS":"0014","NEW-DATA":"0019"}
keymap = {}; props = []
for dom, base in BASE.items():
    for j, p in enumerate(yaml.safe_load(open(P+dom+".yaml"))):
        keymap[p["key"]] = f"T-{base+j:03d}"; props.append((dom, p))
dropped = {}   # ancien id -> nouveau id
for dom, p in props:
    for a in (p.get("absorbs") or []):
        if a in ("T-065","T-074"): continue     # T-065 réduit, T-074 conservé
        dropped.setdefault(a, keymap[p["key"]])
# IDS-1 et DATA-1 (acter des ADR) sont fusionnés dans T-061
merged_into_061 = [k for k in ("IDS-1","DATA-1") if k in keymap]
for k in merged_into_061: dropped[keymap[k]] = "T-061"
def mapdep(d, self_id=None, self_abs=()):
    d = keymap.get(d, d)
    if d in self_abs: return None
    d = dropped.get(d, d)
    return None if d == self_id else d
for dom, p in props:
    nid = keymap[p["key"]]
    if nid in dropped: continue
    adr = []
    for a in (p.get("adr") or []):
        a = str(a); a = NEWADR.get(a, a)
        if a.startswith("NEW-"): a = NEWADR.get(a.split("-")[0]+"-"+a.split("-")[1], a)
        adr.append(a.replace("ADR-",""))
    deps = [x for x in (mapdep(d, nid, tuple(p.get("absorbs") or [])) for d in (p.get("depends_on") or [])) if x]
    notes = (p.get("notes") or "").strip()
    if p.get("absorbs"): notes = (notes + f"\n\nAbsorbe : {', '.join(p['absorbs'])}.").strip()
    notes = (notes + f"\n\nProposé par la recherche `{dom}` (clé {p['key']}).").strip()
    for k,v in keymap.items(): notes = notes.replace(k+" ", v+" ").replace(k+")", v+")").replace(k+",", v+",")
    t(nid, p["key"].lower(), p["title"].replace('"',"'"), p["phase"], sorted(set(adr)), deps, p["class"], p.get("scope",""),
      (p.get("intent") or "").strip(), list(p.get("done") or []), notes)
    T[-1]["velocity"] = bool(p.get("velocity")); T[-1]["lane"] = p.get("parallel_lane") or dom
    X[nid] = T[-1]
# Tickets existants absorbés
for old, newid in dropped.items():
    if old in X:
        X[old]["status"] = "dropped"; X[old]["notes"] = (X[old]["notes"] + f"\n\nAbsorbé par {newid} (intégration des recherches du 2026-11-18).").strip()
# Redirection des dépendances vers les tickets absorbants
for x in T:
    x["deps"] = sorted({dropped.get(d, d) for d in x["deps"] if dropped.get(d, d) != x["id"]})
# T-061 reprend IDS-1 et DATA-1
X["T-061"]["title"] = "Acter les ADR 0001-0019 (+ amendements identité/secrets) et aligner MISSION, AGENTS, STATE"
X["T-061"]["done"] += ["ADR-0015 à 0019 actés ou amendés après la revue adverse", "amendements d'ADR-0007/0014/0002 issus de docs/research/IDENTITY-SECRETS.md tranchés (seal statique, noyau users/ groups/ identities/ platform/secrets/)"]
# T-065 réduit
X["T-065"]["title"] = "CronJob de statut périodique (réduit : sondes → T-103, revert → T-106, ntfy → T-107)"
# Velocity sur les tickets existants qui accélèrent les autres
for v in ["T-001","T-002","T-003","T-005","T-007","T-008","T-041","T-043","T-062","T-072","T-070","T-010"]:
    X[v]["velocity"] = True
LANES = {"T-001":"socle-oke","T-060":"socle-oke","T-062":"socle-oke","T-009":"cout","T-002":"ci","T-007":"ci","T-008":"ci","T-070":"ci",
 "T-003":"contrat-appgen","T-004":"contrat-appgen","T-010":"contrat-appgen","T-011":"contrat-appgen","T-012":"contrat-appgen","T-013":"contrat-appgen",
 "T-014":"contrat-appgen","T-025":"contrat-appgen","T-073":"contrat-appgen","T-074":"contrat-appgen","T-067":"contrat-appgen",
 "T-005":"preuve","T-072":"preuve","T-065":"preuve","T-006":"acces-mcp","T-015":"apps","T-051":"apps","T-052":"migration","T-050":"migration",
 "T-020":"securite","T-021":"securite","T-069":"securite","T-068":"securite","T-022":"secrets","T-023":"secrets","T-063":"exploitation",
 "T-026":"donnees","T-027":"donnees","T-075":"donnees","T-028":"exposition","T-029":"exposition","T-076":"exposition",
 "T-030":"hybride","T-031":"hybride","T-040":"intention","T-041":"connaissance","T-042":"connaissance","T-043":"intention","T-044":"intention",
 "T-071":"intention","T-077":"intention","T-061":"gouvernance","T-024":"identite","T-066":"secrets","T-064":"exploitation"}
for k,v in LANES.items():
    if k in X: X[k].setdefault("lane", v)

# ===== Ajustements après validation du graphe =====
X["T-167"]["phase"]="P4"                      # banc d'injection après le banc d'intentions
X["T-164"]["deps"]=[d for d in X["T-164"]["deps"] if d!="T-189"]   # identité des agents ≠ OIDC des apps
X["T-188"]["status"]="dropped"; X["T-188"]["notes"]+="\n\nAbsorbé par T-164 (doublon : identité des agents IA)."
X["T-164"]["done"]+= [d for d in X["T-188"]["done"] if d not in X["T-164"]["done"]]
for x in T: x["deps"]=sorted({("T-164" if d=="T-188" else d) for d in x["deps"] if not (x["id"]=="T-164" and d=="T-188")})
X["T-121"]["phase"]="P1"                      # Renovate auto-hébergé attend l'identité GitHub App

# ===== Passe d'ordonnancement (vélocité) =====
for k in ("T-022","T-020"):
    X[k]["deps"]=[d for d in X[k]["deps"] if d not in ("T-141","T-009")]
new("T-210","dispatcher-agents","Dispatcher : tickets prêts → un agent par ticket, en parallèle par couloir","P0",["0002","0012","0013"],["T-008"],"REVUE",
  "tools/backlog/, .github/workflows/claude-agent.yml, backlog/README.md",
  "Calculer les tickets prêts (dépendances `done`, classe sans geste humain en attente), ouvrir l'issue `agent:dev` correspondante et lancer un agent par ticket, au plus N par couloir pour éviter les conflits de fichiers ; marquer `in-progress` dans la PR de l'agent.",
  ["`tools/backlog/next.py` liste les tickets prêts triés (vélocité, nombre de tickets débloqués)", "workflow : déclenchement par Paul ou planifié, plafond global et par couloir (COST-6)", "condition `SmadjaPaul` du workflow d'agent remplacée par une identité de dispatch bornée", "preuve : 3 tickets indépendants traités en parallèle, 3 PR vertes"],
  "Plus gros accélérateur : sans lui, chaque lancement d'agent attend un humain.")
X["T-210"]["velocity"]=True; X["T-210"]["lane"]="ci"

# ===== Consensus avec la revue adverse (2026-11-18, docs/review/CONSENSUS.md) =====
def mk(id, slug, title, phase, adr, deps, cls, scope, intent, done, notes="", velocity=False, lane="divers"):
    t(id, slug, title, phase, adr, deps, cls, scope, intent, done, notes); X[id]=T[-1]; T[-1]["velocity"]=velocity; T[-1]["lane"]=lane
mk("T-215","pack-identite","Pack identité : compte agent (rôle Write) et GitHub App plateforme","P0",["0002"],["T-007"],"MANDAT",
   "docs/AGENT-IDENTITY.md, .github/",
   "Une identité agent sans droit d'admin et une seule GitHub App (statut de commit, Renovate, dispatch, remédiation). Aucun agent n'agit avec le compte admin de Paul.",
   ["compte agent rôle Write créé par Paul", "GitHub App plateforme installée sur ce dépôt seulement, permissions minimales listées", "essai réel : une PR du noyau ouverte par l'agent n'est pas fusionnable"],
   "Absorbe les parties GitHub de T-005, T-106, T-121, T-164 et T-210.", True, "gouvernance")
mk("T-217","vap-default-deny","VAP : refus d'un namespace de cellule sans NetworkPolicy default-deny","P0",["0006","0002"],["T-002"],"REVUE",
   "platform/policies/, tests/vap/",
   "Rendre le default-deny réseau non contournable même si un agent modifie un ProjectType.",
   ["VAP + test de refus en CI k3d", "preuve sur k3d datée"], "", False, "securite")
mk("T-211","porte-openchoreo","Porte d'adoption OpenChoreo : mesurer C1-C5 et décision de Paul (2026-12-04)","P1",["0020"],["T-044","T-031","T-140","T-212","T-213"],"MANDAT",
   "docs/review/, docs/adr/0020-porte-adoption-openchoreo.md",
   "Rapport daté des critères C1-C5 et décision adopter/abandonner (ADR-0020), avec les règles en cas d'échec d'une voie.",
   ["C1 à C5 mesurés avec preuves", "décision de Paul consignée dans ADR-0020", "tickets `deferred` dégelés ou `dropped` selon la décision"], "", False, "gouvernance")
mk("T-212","backend-plain","Backend « plain » d'appgen (spike 3 jours) : chart commun + Argo par cluster","P1",["0001","0020"],["T-061","T-214"],"AUTONOME",
   "tools/appgen/ (backend séparé), platform/plain/",
   "Rendre le même `app.yaml` sans OpenChoreo (inspiré de `platform-app` et `apps-generated` de kube-ops) pour comparer à la porte (C5).",
   ["une app A sur le homelab via le backend plain, PASS runtime daté", "même suite `_checks`", "mesures : délai, lignes et tickets propres au moteur"], "Échec = pas d'app A Ready avec PASS après 3 jours d'agent (ADR-0020 §3).", False, "moteur-plain")
mk("T-213","argo-unique-oke","Un seul Argo CD sur OKE et nomenclature OKE figée (D4)","P1",["0003"],["T-001","T-061"],"REVUE + MANDAT",
   "platform/install/argocd/, docs/architecture/",
   "Fusionner les Argo sur OKE (AppProject borné), trancher l'emplacement d'Authentik, sortir Backstage d'OKE, mesurer la nomenclature (≤ 33 pods, ≤ 70 %).",
   ["un seul Argo sur OKE, preuve datée", "nomenclature mesurée et versionnée", "emplacement d'Authentik décidé par Paul"], "", False, "socle-oke")
mk("T-214","appgen-modulaire","Découper appgen en modules (avant le couloir contrat)","P1",["0001","0005"],["T-061"],"AUTONOME",
   "tools/appgen/, tests/appgen/",
   "Le fichier unique de ~1 500 lignes limite le couloir contrat à 1 agent ; des modules permettent plusieurs agents en parallèle.",
   ["modules par domaine (schéma, rendu OpenChoreo, Argo, réseau, données…)", "137 tests et plus toujours verts, `appgen check` sans dérive"], "", True, "contrat-appgen")
mk("T-216","ci-registre","CI extensible par registre de suites","P1",["0002"],["T-002","T-007"],"REVUE",
   ".github/workflows/, tests/registry.yaml",
   "Ajouter une suite de tests sans toucher `.github/` : un registre (noyau pour les suites de garde, libre pour les autres) lu par un job générique.",
   ["registre + job générique", "ajout d'une suite non-garde sans revue prouvé"], "", True, "ci")
mk("T-218","acter-adr-0014-0019","Acter les ADR 0014-0019 après le MVP","P2",["0014","0015","0016","0017","0018","0019"],["T-211"],"MANDAT",
   "docs/adr/", "Seconde moitié de l'ancien T-061 : décisions secrets, observabilité, montées, coût, IA, data platform, une fois le moteur choisi.",
   ["ADR actés ou amendés", "seal OpenBao tranché par Paul"], "", False, "gouvernance")
# T-061 = T-061a
X["T-061"]["title"]="Acter les ADR 0001-0006, 0010-0013 et 0020, réaligner MISSION sur le homelab"
X["T-061"]["done"]=["ADR 0001-0006, 0010-0013, 0020 actés (ou amendés)", "MISSION.md réaligné : homelab par défaut, OKE sur demande, interdits réécrits en classes, critère « plateforme finie »", "AGENTS.md et STATE.md sans contradiction"]
# Fusions et suppressions
def drop(old, into, why):
    if old in X:
        X[old]["status"]="dropped"; X[old]["notes"]=(X[old]["notes"]+f"\n\n{why} (consensus du 2026-11-18)." + (f" Fusionné dans {into}." if into else "")).strip()
        if into: X[into]["done"] += [f"(repris de {old}) {d}" for d in X[old]["done"]]
for o in ("T-141","T-142"): drop(o,"T-140","Fusion coût")
drop("T-143","T-026","Mesure R2 avec les sauvegardes")
drop("T-187","T-186","Golden path utilisateur unique (arrivée et départ)")
for o in ("T-182","T-191"): drop(o,"T-181","Migration Doppler en une séance MANDAT")
drop("T-202","T-201","Ingestion et DORA ensemble")
for o in ("T-102","T-103"): drop(o,"T-101","Collecte : Alloy de kube-ops réutilisé")
for o in ("T-104","T-108"): drop(o,"T-100","Contrat d'alerte, règles et runbooks ensemble")
drop("T-105","T-005","Statut publié par la preuve automatique")
drop("T-110","T-106","Journal d'incident avec la remédiation")
for o in ("T-112","T-144","T-146","T-169","T-170"): drop(o,None,"Supprimé par la revue adverse")
X["T-186"]["title"]="Golden path utilisateur : arrivée et départ (users/<id>.yaml)"
X["T-181"]["title"]="Séance de migration Doppler : inventaire, cible (1 projet, 7 jetons), injection dans OpenBao"
X["T-201"]["title"]="Ingestion GitHub vers Parquet et métriques DORA par agent"
X["T-101"]["title"]="Collecte : Alloy de kube-ops réutilisé, budget de séries, sondes depuis healthPath"
X["T-100"]["title"]="Contrat d'alerte, règles génériques et runbooks lisibles par agent"
# Revert : un seul propriétaire (T-106)
for k in ("T-065","T-124"):
    X[k]["done"]=[d for d in X[k]["done"] if "revert" not in d.lower()]
X["T-124"]["deps"]=[d for d in X["T-124"]["deps"] if d!="T-065"]
X["T-106"]["done"]+=["seul propriétaire du revert automatique", "jamais une seconde PR d'agent sur une même (app, env) sans humain"]
X["T-120"]["done"]+=["pas d'automerge des digests d'actions ni d'apps avant T-124", "fichier de refus de versions lu par Renovate (ajout seul)"]
# Dispatcher réduit
X["T-210"]["deps"]=["T-008","T-215","T-007"]
X["T-210"]["done"]=["`tools/backlog/next.py` liste les tickets prêts (vélocité, débloqués)", "workflow_dispatch déclenché par Paul avec une liste d'ID ; pas de planification en S0", "classe recalculée depuis les chemins touchés, pas lue dans l'en-tête", "plafond 4, contrat de mission d'Atlas (max_attempts 2, ressources exclusives)", "preuve : 3 PR parallèles sur couloirs distincts (hors contrat-appgen avant T-214) ; une PR du noyau lancée par le dispatcher reste non fusionnable"]
X["T-007"]["done"]+=["compare CODEOWNERS aux scripts appelés par ci.yaml et aux ADR 0002/0014/0016/0017/0019", "essai réel avec l'identité agent (T-215)"]
X["T-007"]["deps"]=["T-215"]; X["T-215"]["deps"]=[]
X["T-005"]["deps"]=sorted(set(X["T-005"]["deps"]+["T-215"])); X["T-106"]["deps"]=sorted(set(X["T-106"]["deps"]+["T-215"]))
X["T-121"]["deps"]=sorted(set([d for d in X["T-121"]["deps"] if d!="T-164"]+["T-215"]))
# OpenBao : pas de migration avant drill
X["T-022"]["done"]+=["pod OpenBao inscrit dans la nomenclature OKE avant installation", "exercice perte + restauration réussi et daté AVANT toute migration"]
X["T-181"]["deps"]=sorted(set(X["T-181"]["deps"]+["T-022","T-190"]) - {"T-181"})
X["T-026"]["done"]+=["mots de passe de bases par rôles gérés CNPG (sans Doppler ni OpenBao)"]
# MVP réduit
X["T-044"]["title"]="Banc d'essai de 5 intentions A (MVP)"; X["T-044"]["done"]=["5 intentions A écrites", "5/5 PASS runtime sur le homelab, délai médian ≤ 30 min (C1)", "rapport daté"]
X["T-040"]["done"]=["format + 5 recettes", "CI : digest existant et arm64"]
X["T-050"]["deps"]=["T-008"]
X["T-029"]["status"]="blocked"; X["T-029"]["notes"]+="\n\nBloqué par : déclencheur ADR-0009 §6 non atteint."
X["T-076"]["status"]="blocked"; X["T-076"]["notes"]+="\n\nBloqué par : déclencheur ADR-0009 §6 non atteint."
X["T-028"]["deps"]=[d for d in X["T-028"]["deps"] if d not in ("T-029",)]
X["T-028"]["done"]+=["v1 : application Access wildcard (Tofu, une fois) + routes déclarées"]
DEFER=["T-006","T-042","T-127","T-129","T-130","T-133","T-134","T-135","T-136","T-137","T-138","T-128","T-126","T-014","T-013","T-073","T-205","T-206","T-207","T-208","T-209","T-052","T-077","T-063"]
for k in DEFER:
    if k in X and X[k].get("status","todo")=="todo":
        X[k]["status"]="deferred"; X[k]["notes"]=(X[k]["notes"]+"\n\nDifféré après la porte OpenChoreo (ADR-0020, consensus du 2026-11-18).").strip()
# Étapes
STAGE={}
for k in ["T-007","T-215","T-217","T-002","T-001","T-061","T-008","T-210","T-041"]: STAGE[k]="S0"
for k in ["T-072","T-005","T-216"]: STAGE[k]="S1"
for k in ["T-030","T-212","T-214","T-062","T-145","T-213"]: STAGE[k]="S2"
for k in ["T-003","T-010","T-015","T-043","T-040","T-044","T-050","T-004","T-070","T-031","T-140"]: STAGE[k]="S3"
STAGE["T-211"]="PORTE"
for k in ["T-025","T-026","T-027","T-069","T-075","T-012","T-067"]: STAGE[k]="I1"
for k in ["T-011","T-014"]: STAGE[k]="I1bis"
for k in ["T-060","T-074","T-022","T-184","T-183","T-023","T-164","T-185","T-189","T-186","T-051","T-071","T-218","T-194","T-195"]: STAGE[k]="I2"
for k in ["T-028","T-020","T-021"]: STAGE[k]="I3"
for k in ["T-100","T-101","T-106","T-107","T-111","T-065","T-109","T-147"]: STAGE[k]="I4"
for k in ["T-120","T-121","T-122","T-123","T-124","T-125","T-131","T-132"]: STAGE[k]="I5"
for k in ["T-181","T-190","T-192","T-193"]: STAGE[k]="I6"
for k in ["T-160","T-161","T-162","T-163","T-165","T-166","T-167","T-168","T-171"]: STAGE[k]="I7"
for k in ["T-201","T-203","T-204"]: STAGE[k]="I8"
for x in T:
    x["stage"]=STAGE.get(x["id"], "après-porte" if x.get("status") in ("deferred","blocked") else ("—" if x.get("status")=="dropped" else "I9"))
# T-061 prérequis explicite
EXEMPT={"T-061","T-001","T-002","T-007","T-215","T-217","T-008","T-041"}
for x in T:
    if x.get("status","todo") in ("todo",) and x["id"] not in EXEMPT and "T-061" not in x["deps"]:
        x["deps"]=sorted(x["deps"]+["T-061"])


# ===== Ajustements d'étapes =====
X["T-145"]["deps"]=["T-061","T-215"]
X["T-003"]["stage"]="S1"
X["T-051"]["stage"]="I3"
X["T-026"]["deps"]=[d for d in X["T-026"]["deps"] if d!="T-023"]
X["T-194"]["stage"]="I6"; X["T-195"]["stage"]="I6"
# ===== Nettoyage post-consensus =====
MERGE={"T-141":"T-140","T-142":"T-140","T-143":"T-026","T-187":"T-186","T-182":"T-181","T-191":"T-181","T-202":"T-201",
       "T-102":"T-101","T-103":"T-101","T-104":"T-100","T-108":"T-100","T-105":"T-005","T-110":"T-106"}
DROP={k for k,x in X.items() if x.get("status")=="dropped"}
for x in T:
    nd=set()
    for d in x["deps"]:
        d=MERGE.get(d,d)
        if d in DROP: continue
        if d!=x["id"]: nd.add(d)
    x["deps"]=sorted(nd)
X["T-190"]["deps"]=[d for d in X["T-190"]["deps"] if d!="T-181"]
# ===== Intégration 2 (2026-11-18 soir) : sensitive, factory, harness, homelab, model-routing =====
# Détail et table de correspondance : backlog/INTEGRATION-2.md. Ids : SEC → T-300.., FAC → T-310.., HAR → T-330.., HOME → T-360.., MOD → T-380..
import fnmatch, unicodedata, re as _re
props2 = {}; dom2 = {}
for dom in ("sensitive", "factory", "harness", "homelab"):
    for p in yaml.safe_load(open(P + dom + ".yaml")):
        props2[p["key"]] = p; dom2[p["key"]] = dom
_MR = yaml.safe_load(open(P + "model-routing.yaml"))
for p in _MR["tickets"]:
    props2[p["key"]] = p; dom2[p["key"]] = "model-routing"
ROUTING = _MR["rules"]
def kid(k):
    pre, n = k.rsplit("-", 1)
    return "T-%03d" % ({"SEC": 299, "FAC": 309, "HAR": 330, "HOME": 360, "MOD": 379}[pre] + int(n))
# Propositions fusionnées dans un ticket (aucun fichier créé ; voir INTEGRATION-2.md)
MERGED2 = {"FAC-1": "T-215", "FAC-3": "T-210", "FAC-15": "T-008", "HAR-3": "T-313", "HAR-5": "T-210", "HAR-6": "T-303",
           "HAR-21": "T-323", "HOME-6": "T-031", "HOME-9": "T-160", "HOME-10": "T-022", "HOME-11": "T-140", "HOME-13": "T-061",
           "MOD-1": "T-061", "MOD-2": "T-008", "MOD-4": "T-313", "MOD-5": "T-313", "MOD-6": "T-323", "MOD-8": "T-322", "MOD-12": "T-350"}
NEWADR2 = {"NEW-FACTORY": "0021", "NEW-HARNESS": "0022", "NEW-MODELS": "0023"}
def ref2(s):
    s = _re.sub(r"\b(SEC|FAC|HAR|HOME|MOD)-\d+\b", lambda m: MERGED2.get(m.group(0), kid(m.group(0))), s)
    return s.replace("T-145", "T-311").replace("ADR-0021", "ADR-0021/0022/0023")
def slug2(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    s = _re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return "-".join(s.split("-")[:6])[:48].strip("-")
# Dépendances fixées à la main (jugement d'intégration), stage si différent de la proposition
DEPS2 = {
 "SEC-1": [], "SEC-2": ["T-300", "T-302", "T-303"], "SEC-3": ["T-303"], "SEC-4": [],
 "FAC-2": ["T-061", "T-215"], "FAC-4": ["T-215", "T-210", "T-311"], "FAC-5": ["T-311", "T-210", "T-313", "T-301"],
 "FAC-6": ["T-215", "T-210", "T-321", "T-007"], "FAC-7": ["T-314"], "FAC-8": ["T-314", "T-382"],
 "FAC-9": ["T-002", "T-313", "T-360"], "FAC-10": ["T-318"], "FAC-11": ["T-316"], "FAC-12": ["T-313", "T-002", "T-382"],
 "FAC-13": ["T-311", "T-313", "T-301"], "FAC-14": ["T-311", "T-313", "T-314", "T-346"], "FAC-16": ["T-008"],
 "HAR-0": ["T-061"], "HAR-1": ["T-330", "T-332", "T-303"], "HAR-2": [], "HAR-4": ["T-332"], "HAR-7": ["T-008", "T-332"],
 "HAR-8": ["T-002", "T-332"], "HAR-9": ["T-002", "T-216", "T-332"], "HAR-10": ["T-210", "T-337"], "HAR-11": ["T-330", "T-337"],
 "HAR-12": ["T-363"], "HAR-13": ["T-342"], "HAR-14": ["T-214", "T-062"], "HAR-15": ["T-330", "T-332"],
 "HAR-16": ["T-332", "T-337", "T-338", "T-339", "T-311"], "HAR-17": ["T-338", "T-341", "T-346"], "HAR-18": ["T-342", "T-343", "T-004", "T-005"],
 "HAR-19": ["T-346", "T-343", "T-120"], "HAR-20": ["T-346", "T-311", "T-164", "T-386", "T-388"], "HAR-22": ["T-340", "T-346"],
 "HOME-0": [], "HOME-1": ["T-360"], "HOME-2": ["T-361"], "HOME-3": ["T-361", "T-362", "T-001"], "HOME-4": ["T-363", "T-365", "T-360"],
 "HOME-5": ["T-214"], "HOME-7": ["T-363", "T-215", "T-311", "T-343"], "HOME-8": ["T-360", "T-363"], "HOME-12": ["T-140", "T-364"],
 "MOD-3": ["T-008"], "MOD-7": ["T-044", "T-346", "T-323"], "MOD-9": [], "MOD-10": ["T-161", "T-023", "T-388"], "MOD-11": ["T-389", "T-025"],
 "MOD-13": ["T-323", "T-388"],
}
STAGE2 = {"FAC-14": "S3", "HOME-4": "S1", "HOME-6": "S3", "HOME-7": "après-porte", "HOME-12": "après-porte", "MOD-13": "I9", "HAR-12": "S2"}
STATUS2 = {"HOME-7": "blocked", "HOME-12": "blocked"}
EXEMPT2 = {"T-300", "T-301", "T-302", "T-303", "T-332", "T-360", "T-325"}   # sans T-061 : purge, garde de fuite, outillage, mesure en lecture
for k, p in props2.items():
    if k in MERGED2: continue
    nid = kid(k)
    adr = sorted({NEWADR2.get(str(a), str(a).replace("ADR-", "")) for a in (p.get("adr") or [])})
    notes = ref2((p.get("notes") or "").strip())
    if p.get("absorbs"): notes += f"\n\nLa proposition visait : {', '.join(p['absorbs'])} (décision d'intégration : INTEGRATION-2.md)."
    notes = (notes + f"\n\nProposé par la recherche `{dom2[k]}` (clé {k}) ; intégration 2 du 2026-11-18.").strip()
    deps = list(DEPS2[k]) + ([] if nid in EXEMPT2 else ["T-061"])
    mk(nid, slug2(p["title"]), ref2(p["title"]).replace('"', "'"), p["phase"], adr, sorted(set(deps)), p["class"], ref2(p.get("scope", "")),
       ref2((p.get("intent") or "").strip()), [ref2(d) for d in (p.get("done") or [])], notes, bool(p.get("velocity")), p.get("parallel_lane") or dom2[k])
    X[nid]["stage"] = STAGE2.get(k, p.get("stage", "I9")); X[nid]["proposed_model"] = str(p.get("model") or "")
    if k in STATUS2: X[nid]["status"] = STATUS2[k]
def rep(id, *c, key=None):
    X[id]["done"] += [(f"(repris de {key}) " if key else "") + ref2(d) for d in c]
def note(id, s): X[id]["notes"] = (X[id]["notes"] + "\n\n" + s).strip()
def drop2(old, into, why):
    X[old]["status"] = "dropped"; note(old, f"{why} Fusionné dans {into} (intégration 2 du 2026-11-18).")

# --- Sécurité du dépôt public : la garde de fuite absorbe HAR-6
X["T-303"]["scope"] += ", tools/dev/leak-guard.sh, tests/leak-guard/"
rep("T-303", "cas négatifs : une IP privée, un OCID factice et un jeton factice font échouer la garde", "cas positif : les adresses documentaires (plages réservées) passent",
    "même script en local, en CI et dans le hook Stop (T-331) ; seuls fichier et ligne sont affichés, jamais la valeur", key="HAR-6")
note("T-301", "À faire AVANT le pilote 24 h (T-322) et le dispatcher planifié (T-314) : chaque branche ouverte serait à recréer après la réécriture.")
note("T-300", "Le retour en public rétablit la règle « aucun runner auto-hébergé » (T-343).")
# --- Identité : T-215 absorbe FAC-1 (mandat de lot, App étendue)
X["T-215"]["title"] = "Pack identité et mandat de lot : compte agent, GitHub App (dispatch, merge sous conditions), mandate.v1"
X["T-215"]["cls"] = "REVUE + MANDAT"
X["T-215"]["scope"] = "docs/AGENT-IDENTITY.md, docs/AGENT-PR-MODEL.md, missions/mandates/, .github/ (CODEOWNERS : ligne missions/mandates/)"
X["T-215"]["intent"] += " Ajoute le mandat de lot (étape, tickets, chemins, plafonds de diff et de dépense, expiration) signé par PR dans le noyau ; l'App reçoit les permissions de dispatch et de merge sous conditions (merge effectif : T-315)."
rep("T-215", *props2["FAC-1"]["done"], key="FAC-1")
rep("T-215", "GITHUB_TOKEN ne déclenche pas la CI sur les PR qu'il ouvre et plafonne à 1 000 req/h (vérification du 2026-11-18) : dispatch, Renovate et remédiation passent par l'App")
note("T-215", "MANDAT : création de l'App, option « Allow auto-merge ». Le mandat n'ouvre jamais secret, accès, dépense hors free tier, apply, INTERDIT (platform-guardrails). Fusion de FAC-1.")
# --- Dispatcher : T-210 = cerveau (next.py + admission) ; FAC-3 et HAR-5 absorbés ; l'exécution passe à T-313
X["T-210"]["title"] = "Dispatcher (cerveau) : next.py et admission — prêts, classe recalculée, couloirs, ressources exclusives, chevauchement de périmètres"
X["T-210"]["scope"] = "tools/backlog/next.py, tools/backlog/admission.py, tests/backlog/"
X["T-210"]["intent"] = ref2(props2["FAC-3"]["intent"]) + " Un ticket n'est proposé que si les globs de son périmètre ne recoupent ni un ticket `in-progress`, ni une PR ouverte, ni une `exclusive_resources` (HAR-5)."
X["T-210"]["done"] = [ref2(d) for d in props2["FAC-3"]["done"]] + [ref2(d) for d in props2["HAR-5"]["done"][:2]] + [
    "plafond global 4 au départ (relevé par T-322), 2 par couloir, 1 sur contrat-appgen avant T-214 ; contrat de mission d'Atlas (max_attempts 2)",
    "l'admission lit le gouverneur de quota (T-311) quand il existe : refus au-delà du seuil (test hors ligne)",
    "le modèle et l'effort de chaque ticket admis viennent de route.py (T-382) ou, à défaut, de l'en-tête"]
note("T-210", "Intégration 2 : absorbe FAC-3 et HAR-5. Le lancement (workflow_dispatch, preuve de 3 PR parallèles) passe à T-313.")
# --- Exécutant : T-313 absorbe HAR-3 (même fichier), MOD-4 (passage du modèle) et MOD-5 (trailers, mission-result.v1)
X["T-313"]["title"] = "Exécutant claude-agent.yml : workflow_dispatch(ticket, modèle, effort), outils étroits, journal JSON, mission-result.v1"
X["T-313"]["scope"] += ", .github/pull_request_template.md, docs/schema/mission-result.v1.json"
rep("T-313", *props2["HAR-3"]["done"], key="HAR-3")
rep("T-313", props2["MOD-4"]["done"][0], "entrées `model` et `effort` du workflow passées à claude_args (--model, --effort) ; Sonnet plafonné à `xhigh`", key="MOD-4")
rep("T-313", "trailers Model, Effort, Escalated-from sur chaque PR d'agent ; mission-result.v1 contient modèle, effort, escalade, tokens, tours, durée, échecs CI, sans aucun prompt", key="MOD-5")
note("T-313", "Fusion de HAR-3 (même fichier), de la partie « passage du modèle » de MOD-4 et du schéma de MOD-5 (un seul schéma : mission-result.v1, pas de model-run.v1 séparé). L'escalade de MOD-4 est dans T-317.")
rep("T-317", props2["MOD-4"]["done"][1], "l'escalade suit l'échelle de la règle de routage (T-382), étiquette `escalated-from`", key="MOD-4")
X["T-317"]["title"] = "Reprise automatique et escalade de modèle : max_attempts, tickets bloqués, rebase par l'App, disjoncteur de boucle"
note("T-317", "Vocabulaire des classes d'échec partagé avec le protocole T-340.")
# --- Lint des tickets : T-008 absorbe FAC-15, MOD-2 et la règle de périmètre de HAR-5
X["T-008"]["title"] = "Check CI des tickets `backlog/` : en-tête, graphe, étapes, champs `model` et `effort`"
X["T-008"]["scope"] = "tools/backlog/check.py, tests/backlog/, backlog/README.md, backlog/proposals/FORMAT.md, .github/workflows/ci.yaml (REVUE)"
X["T-008"]["intent"] += " Valide aussi `stage`, `model` (ID complet épinglé ou `human`) et `effort`, et leur cohérence avec la règle de routage (ADR-0023 proposé)."
rep("T-008", *props2["FAC-15"]["done"], key="FAC-15"); rep("T-008", *props2["MOD-2"]["done"], key="MOD-2")
rep("T-008", props2["HAR-5"]["done"][2], key="HAR-5")
note("T-008", "Intégration 2 : la présence de `model`/`effort` est déjà vérifiée par tools/backlog/check.py (2026-11-18) ; restent les tests, le job CI requis et le refus des valeurs inconnues en CI.")
# --- Gouverneur de quota : T-311 (FAC-2) absorbe T-145 ; T-322 (FAC-13) absorbe MOD-8 et la collecte de MOD-5
drop2("T-145", "T-311", "Le gouverneur de quota (FAC-2) couvre concurrence, tours, durée et règle de clé API.")
rep("T-311", "concurrence maximale documentée et testée (workflow lint)", "agrégat hebdomadaire par identité d'agent", key="T-145")
rep("T-322", *props2["MOD-8"]["done"], "seuil de repli fixé : quota hebdomadaire > 70 % ⇒ Opus → Sonnet high hors noyau", key="MOD-8")
note("T-322", "C'est le pilote 24 h à N=3 (section « Lancement 24/7 » de ROADMAP.md), puis N=6, puis 8-10. Ne démarre qu'après la réécriture de l'historique (T-301).")
# --- Observabilité de l'usine : T-323 (FAC-14) absorbe MOD-6, HAR-21 et T-209
X["T-323"]["title"] = "Observabilité de l'usine : indicateurs, rapport hebdomadaire par (type de tâche, modèle), écart banc/réel, drill de panne"
X["T-323"]["scope"] += ", tools/metrics/model-routing/report.py, docs/metrics/agents-scorecard.md"
rep("T-323", *props2["MOD-6"]["done"], key="MOD-6"); rep("T-323", *props2["HAR-21"]["done"], key="HAR-21")
drop2("T-209", "T-323", "Coût LLM par agent couvert par le ledger (T-311) et le rapport de l'usine.")
# --- Remontées de la vérification en ligne (docs/research/VERIFICATION-2026-11-18.md)
rep("T-140", *props2["HOME-11"]["done"], key="HOME-11")
rep("T-140", "A1 Always Free = 2 OCPU / 12 Go même en PAYG (vérification du 2026-11-18) ; MISSION.md et STATE.md corrigés (plus de « 4/24 »)")
X["T-140"]["cls"] = "AUTONOME + MANDAT"; note("T-140", "Intégration 2 : absorbe HOME-11 (confirmation de facturation A1).")
rep("T-132", "aucun nœud de surge (au-delà de 2/12 = payant) : montée par « Replace boot volume » ou coupure planifiée (vérification du 2026-11-18)")
note("T-372", "Vérification du 2026-11-18 : tout ce qui dépasse 2/12 est facturé, même en PAYG ; pas de nœud de surge.\n\nBloqué par : aucune app OKE demandée par Paul.")
rep("T-100", "Grafana Free : date de création du stack relevée ; si postérieure au 2026-04-20, webhook seul (ni e-mail ni Cloud Alertmanager) ; budget ≤ 500 règles (vérification du 2026-11-18)")
rep("T-107", "contact point webhook vers ntfy (pas d'e-mail Grafana sur un stack Free récent)")
note("T-170", "Vérification du 2026-11-18 : les agents SRE et Portal Assistant d'OpenChoreo sont routables par agentgateway (baseUrl), FinOps non. Option après la porte : SRE derrière une clé virtuelle à budget bas.")
rep("T-181", "journal d'activité Doppler Developer limité à 3 jours : décision de Paul consignée (export du journal vers un webhook ou plan Team) avant la séance")
rep("T-193", "chaque étape de nettoyage garde la copie OpenBao vérifiée (retour arrière Doppler limité à 3 jours)")
rep("T-201", "ingestion budgétée sous 1 000 req/h (limite du jeton Actions) ou par l'App")
rep("T-203", "SLSA affiché « Build L2 » (attestations GitHub) ; L3 seulement avec un workflow réutilisable vérifié")
rep("T-026", "test de restauration : les mots de passe des rôles gérés CNPG sont réalignés après restauration (non documenté en amont, à prouver avant de s'y fier)")
# --- Homelab : VM lab dédiée, CP + DP sur la VM pendant la porte ; T-030 recadré
X["T-364"]["done"] = [d for d in X["T-364"]["done"]] + ["(repris de T-030) Environments development et production sur le cluster lab, clientCA du cluster-gateway correct",
    "(repris de T-003) une app A en development, release de production inchangée, preuve datée"]
note("T-364", "Emplacement DÉFINITIF du control plane NON tranché : décision de Paul à la porte (D11, T-211). Le CP est sur la VM lab pendant la porte seulement (recommandation homelab, ADR-0003 amendé par T-061).\n\nRemplace le cœur de T-030 (recadré en DP distant, gelé).")
X["T-030"].update(status="deferred", title="Data plane distant entre le cluster lab et OKE (selon la décision D11)",
    intent="Seulement si Paul demande une app sur OKE ou déplace le CP (D11) : CP sur lab ⇒ DP OKE (exception de flux OKE → homelab, D13) ; CP sur OKE ⇒ DP lab par NetBird L4.",
    done=["agent du DP distant connecté au CP, mTLS et clientCA corrects, preuve datée", "flux réseau conforme à la décision D11/D13, ACL limitée au port de la cluster-gateway",
          "(repris de T-031) même app déplacée oke ↔ homelab par changement de `cluster`", "MANDAT Paul : ACL NetBird, enrôlement"])
note("T-030", "Recadré par l'intégration 2 : le cœur (DP homelab, Environments, app A) est passé à T-364 (S1).\n\nDifféré après la porte OpenChoreo (D11).")
X["T-031"].update(title="Test de reprise du cluster lab (critère C4 révisé)", intent=ref2(props2["HOME-6"]["intent"]),
    scope="tests/, docs/architecture/MULTI-DATAPLANE.md", done=[ref2(d) for d in props2["HOME-6"]["done"]] + ["résultat C4 transmis au rapport de porte (T-211)"])
note("T-031", "Intégration 2 : absorbe HOME-6. La règle de placement passe à T-365, le déplacement oke ↔ homelab à T-030.")
X["T-213"]["status"] = "deferred"
note("T-213", "Intégration 2 : plus bloquant du MVP (CP sur la VM lab pendant la porte ; lab-argocd devient l'Argo du lab, D4). Dégel si OKE héberge le CP ou des apps (D11). L'emplacement d'Authentik passe à T-211.")
rep("T-211", "C1, C2 et C4 mesurés sur le cluster lab selon ADR-0020 amendé (T-061)", "D11 : Paul décide l'emplacement définitif du CP (lab ou OKE) ; le backlog ne le tranche pas",
    "emplacement d'Authentik décidé par Paul (repris de T-213)")
X["T-022"].update(title="OpenBao sur le cluster lab : stockage, déscellement, sauvegarde hors site, drill")
X["T-022"]["done"] = [("pod OpenBao inscrit dans le budget du cluster lab (T-360) avant installation ; OKE, s'il sert, lit Doppler" if "nomenclature OKE" in d else d) for d in X["T-022"]["done"]]
rep("T-022", "Raft local sur un seul volume du cluster lab, snapshot chiffré hors site (hors Oracle)", key="HOME-10")
rep("T-022", "option backend PostgreSQL (production ready, HA depuis 2.7.0) comparée à Raft ; dépendance circulaire CNPG ↔ OpenBao tranchée et écrite (vérification du 2026-11-18)")
note("T-022", "Intégration 2 : absorbe HOME-10 (variante lab prioritaire). Seal statique : décision de Paul (CONSENSUS).")
X["T-160"].update(title="gVisor et vcluster jetables pour les agents sur le cluster lab", scope=X["T-160"]["scope"] + ", platform/ai-sandbox/")
rep("T-160", *props2["HOME-9"]["done"], key="HOME-9")
note("T-160", "Intégration 2 : absorbe HOME-9 ; le mécanisme vcluster est choisi par le spike T-342.")
X["T-342"]["intent"] = ("Le cluster lab (T-361) existe : comparer sur lui (a) vcluster par PR en nœuds partagés, (c) namespaces `lab-dev-*` seuls, et (b) une VM Talos de dev "
    "supplémentaire (défavorisée par le budget T-360). Mesurer démarrage, RAM au repos, nettoyage, isolation entre agents, compatibilité PSA restricted et default-deny ; seuils (≤ 2 previews, TTL 24 h).")
rep("T-343", "décision écrite : runner Actions sur le homelab seulement si le dépôt devient durablement privé (T-300 n'est que temporaire)", key="FAC-9")
X["T-318"]["done"] = [d for d in X["T-318"]["done"] if not d.startswith("décision écrite")] + ["taille de la VM dans le budget du homelab (T-360) ; concurrence plafonnée par la RAM et la température (Tctl)"]
note("T-318", "Conflit à trancher par Paul : la proposition visait 8 vCPU / 32 Go alors que le budget homelab (64 Gio) laisse 6-8 Gio de marge après la VM lab ; la taille vient de T-360.")
note("T-367", "Bloqué par : décision (b) de T-343 (runners ARC) ; par défaut (a) aucun runner homelab sur un dépôt public.")
X["T-062"]["deps"] += ["T-363"]; note("T-062", "Intégration 2 : cible = Argo du cluster qui porte le CP (lab-argocd pendant la porte, D4).")
X["T-212"]["deps"] += ["T-363"]; note("T-212", "Intégration 2 : cible = cluster lab (T-363).")
X["T-003"]["done"] = [d for d in X["T-003"]["done"] if not d.startswith("preuve OKE")] + ["preuve k3d CI : une app A en development, release de production inchangée (la preuve runtime est dans T-364)"]
X["T-005"]["done"] = [("preuve runtime datée sur le cluster lab, sans coordinateur" if d.startswith("preuve OKE") else d) for d in X["T-005"]["done"]]
X["T-005"]["deps"] += ["T-364"]
for _v in ("T-363", "T-364"): X[_v]["velocity"] = True   # chemin critique vers la preuve automatique
X["T-214"]["stage"] = "S1"   # vélocité : débloque T-365 et le couloir contrat
rep("T-007", "couvre aussi .claude/, factory/, missions/mandates/, backlog/routing.yaml (ADR-0021/0022/0023)")
# --- T-061 absorbe HOME-13 (amendements homelab) et MOD-1 (ADR-0023) ; actage des trois nouveaux ADR
X["T-061"]["title"] = "Acter les ADR 0001-0006, 0010-0013, 0020-0023 (+ amendements homelab), réaligner MISSION sur le homelab"
X["T-061"]["scope"] += ", docs/architecture/"
rep("T-061", "ADR-0021 (usine 24/7), ADR-0022 (harness), ADR-0023 (routage des modèles) rédigés au gabarit depuis docs/research/ et actés (ou amendés)",
    "amendements homelab (HOMELAB-CAPACITY-DATAPLANE §5) : ADR-0003 et ADR-0020 (C1, C2, C4) amendés et actés ; texte d'ADR-0017 amendé (acté avec T-218) ; TARGET-ARCHITECTURE, MULTI-DATAPLANE, DECISIONS-OPEN (D1 reformulée, D11-D14) à jour",
    "D11 (emplacement définitif du CP) laissé ouvert jusqu'à la porte", "Paul a tranché pour ADR-0023 : plancher Opus du noyau, Fable sur demande seulement, DeepSeek Flash sur données publiques (MANDAT de dépense)",
    "aucun ticket ne cite encore « Talos éteint la nuit » ou « CP sur OKE » comme prérequis", "MISSION.md et STATE.md : A1 = 2/12, plus de « 4/24 »")
note("T-061", "Intégration 2 : absorbe HOME-13 et MOD-1 pour garder un seul geste de Paul. Ticket lourd sur le chemin critique : Paul peut le scinder (question dans INTEGRATION-2.md).")
# --- Redirections de dépendances
for x in T:
    if x.get("status", "todo") == "dropped": continue
    nd = set()
    for d in x["deps"]:
        d = {"T-145": "T-311", "T-209": "T-323"}.get(d, d)
        if x.get("status", "todo") == "todo" and d == "T-030": d = "T-364"
        if d == "T-213" and x.get("status", "todo") == "todo": continue
        if d != x["id"]: nd.add(d)
    x["deps"] = sorted(nd)
for x in T:   # homelab : les tickets gelés qui visaient T-030 visent le cluster lab
    if x["id"] in ("T-029", "T-133", "T-205"): x["deps"] = sorted({("T-364" if d == "T-030" else d) for d in x["deps"]})
X["T-211"]["deps"] = sorted(set(X["T-211"]["deps"]) | {"T-364"})
for x in T:
    if x.get("status") in ("deferred", "blocked") and x.get("stage") not in (None, "après-porte", "I1bis"): x["stage"] = "après-porte"

# ===== Routage des modèles (backlog/proposals/model-routing.yaml `rules:`, première règle qui s'applique) =====
LADDER = ["claude-haiku-5-5", "claude-sonnet-5-5", "claude-opus-5-5"]
def parse_model(s):
    s = (s or "").lower()
    if not s: return None
    if s.startswith("aucun"): return "human"
    for m in ("opus", "sonnet", "haiku"):
        if m in s: return f"claude-{m}-5-5"
    return None
def infer_kind(x):
    t = x["title"].lower()
    if t.startswith(("acter", "porte")): return "plan"
    if "spike" in t: return "research"
    if t.startswith("banc"): return "bench"
    if t.startswith(("veille", "revue trimestrielle")): return "watch"
    if t.startswith(("guide", "runbook")): return "doc"
    return None
def _glob(g): return _re.escape(g).replace(r"\*\*", ".*").replace(r"\*", r"[^/,\s]*")
def rule_match(r, x, kind):
    m = r.get("match") or {}
    sel = not any(k in m for k in ("lane", "paths", "kind"))
    if "lane" in m and any(fnmatch.fnmatch(x.get("lane", ""), l) for l in m["lane"]): sel = True
    if "paths" in m and any(_re.search(r"(^|[\s,(`])" + _glob(g), x["scope"]) for g in m["paths"]): sel = True
    if "kind" in m and kind in m["kind"]: sel = True
    if not sel: return False
    if "class" in m and not any(c in x["cls"] for c in m["class"]): return False
    if "keywords" in m and not any(k.lower() in (x["title"] + " " + x["intent"]).lower() for k in m["keywords"]): return False
    return True
for x in T:
    if x.get("status", "todo") == "dropped": continue
    kind = infer_kind(x)
    r = next(r for r in ROUTING if "model" in r and rule_match(r, x, kind))
    model, eff = r["model"], r["effort"]; floor = r.get("floor", model)
    pm = parse_model(x.get("proposed_model"))
    if pm == "human": model, eff = "human", "none"
    elif pm and LADDER.index(pm) >= LADDER.index(floor) and LADDER.index(pm) > LADDER.index(model): model, eff = pm, "high"
    if model == "claude-sonnet-5-5" and eff == "max": eff = "xhigh"
    x["model"], x["effort"], x["routing"] = model, eff, r["id"]

SP={"S0":"P0","S1":"P0","S2":"P1","S3":"P1","PORTE":"P1","I1":"P2","I1bis":"P2","I2":"P2","I3":"P2","I4":"P3","I5":"P3","I6":"P3","I7":"P4","I8":"P4","I9":"P4","après-porte":"P5"}
for x in T:
    if x.get("stage") in SP: x["phase"]=SP[x["stage"]]
PH = {"P0":"Fondations : débloquer l'autonomie","P1":"Golden path complet","P2":"Primitives (sécurité, secrets, identité, données, exposition)","P3":"Hybride OKE + homelab","P4":"Intention en langage naturel et connaissance","P5":"Migration depuis kube-ops"}
for x in T:
    deps = "[" + ", ".join(x["deps"]) + "]"
    adr = "[" + ", ".join(x["adr"]) + "]"
    mline = f"model: {x['model']}\neffort: {x['effort']}\nrouting: {x['routing']}\n" if x.get('model') else ''
    body = f"""---
id: {x['id']}
title: "{x['title']}"
status: {x.get('status','todo')}
phase: {x['phase']}
adr: {adr}
depends_on: {deps}
class: {x['cls']}
velocity: {str(x.get('velocity', False)).lower()}
lane: {x.get('lane','divers')}
stage: {x.get('stage','I9')}
{mline}{('github_issue: ' + str(x['issue'])) if x['issue'] else 'github_issue: null'}
---
# {x['id']} — {x['title']}

## Intention
{x['intent']}

## Périmètre de fichiers
{x['scope']}

## Critères de fin
""" + "\n".join(f"- [ ] {d}" for d in x['done']) + "\n"
    if x["notes"]:
        body += f"\n## Notes\n{x['notes']}\n"
    open(os.path.join(B, f"{x['id']}-{x['slug']}.md"), "w").write(body)

rows = []
for p in PH:
    rows.append(f"\n### {p} — {PH[p]}\n\n| Ticket | Titre | Dépend de | Classe | Modèle | ADR |\n|---|---|---|---|---|---|")
    for x in T:
        if x["phase"] == p:
            rows.append(f"| [{x['id']}]({x['id']}-{x['slug']}.md) | {x['title']} | {', '.join(x['deps']) or '—'} | {x['cls']} | {x.get('model','—')} | {', '.join(x['adr'])} |")
open(os.path.join(B, "INDEX.md"), "w").write("# Index du backlog (généré)\n\nGénéré à partir des en-têtes ; ne pas éditer à la main.\n" + "\n".join(rows) + "\n")
print(len(T))
