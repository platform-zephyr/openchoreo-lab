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
PH = {"P0":"Fondations : débloquer l'autonomie","P1":"Golden path complet","P2":"Primitives (sécurité, secrets, identité, données, exposition)","P3":"Hybride OKE + homelab","P4":"Intention en langage naturel et connaissance","P5":"Migration depuis kube-ops"}
for x in T:
    deps = "[" + ", ".join(x["deps"]) + "]"
    adr = "[" + ", ".join(x["adr"]) + "]"
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
{('github_issue: ' + str(x['issue'])) if x['issue'] else 'github_issue: null'}
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
    rows.append(f"\n### {p} — {PH[p]}\n\n| Ticket | Titre | Dépend de | Classe | ADR |\n|---|---|---|---|---|")
    for x in T:
        if x["phase"] == p:
            rows.append(f"| [{x['id']}]({x['id']}-{x['slug']}.md) | {x['title']} | {', '.join(x['deps']) or '—'} | {x['cls']} | {', '.join(x['adr'])} |")
open(os.path.join(B, "INDEX.md"), "w").write("# Index du backlog (généré)\n\nGénéré à partir des en-têtes ; ne pas éditer à la main.\n" + "\n".join(rows) + "\n")
print(len(T))
