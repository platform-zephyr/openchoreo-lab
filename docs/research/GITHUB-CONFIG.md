# Configuration GitHub propre : organisation FREE, dépôt public

Date : 2026-11-18 · Dépôt : `platform-zephyr/openchoreo-lab` · Niveau de preuve : STATIC (documentation GitHub relue ce jour ; aucun réglage lu ni modifié sur GitHub).
Tickets proposés : `backlog/proposals/github.yaml` (GH-1 à GH-14). Décideur : Paul. Sources : section 8.

## 1. Conclusion

- Tout ce dont la plateforme a besoin existe gratuitement sur un dépôt public d'une organisation Free : rulesets de dépôt (revue des code owners, check requis, bypass par rôle ou App), file de fusion native, auto-merge, environnements avec règles, secret scanning + push protection, CodeQL (Python et workflows Actions), Dependabot, signalement privé, attestations [S1 S2 S5 S6 S7 S11 S12].
- Ne pas viser : rulesets d'organisation, push rulesets, rôles personnalisés, SAML, journal d'audit en flux, secret scanning avancé (motifs personnalisés, bypass délégué, IA), Code Security payant [S3 S6]. Aucun besoin réel ne les impose ; gitleaks (T-303) remplace les motifs personnalisés.
- Principal risque d'un dépôt public : un secret (`CLAUDE_CODE_OAUTH_TOKEN`) lisible par tout workflow poussé sur une branche par une identité Write. À fermer avant FINAL : environnement limité à `main` (GH-8) et App sans permission `workflows` (GH-11).
- Dev et FINAL se distinguent par 5 réglages seulement : revue des code owners, `bypass_actors`, source du check `ci-ok`, `k3d-ok` requis, résultats CodeQL requis. Deux fichiers JSON versionnés suffisent (GH-1, GH-12).
- Automatisation recommandée : script `gh api` idempotent + JSON versionnés, exécuté par Paul (admin). Terraform `integrations/github` : écarté tant qu'il y a un seul dépôt (section 6).

## 2. Écarts constatés dans le dépôt (lecture de `.github/`, `tools/`, `docs/`)

1. `tools/apply-branch-protection.sh` met `require_code_owner_review: true` ; l'ADR-0002 (amendement n°2) suspend cette revue en dev. À aligner (GH-1). En FINAL, un ruleset sans bypass rend aussi non fusionnable une PR du noyau **écrite par Paul** (un auteur n'approuve pas sa propre PR [S4]) : l'auteur du noyau doit être l'App, Paul approuve.
2. `docs/AGENT-IDENTITY.md` demande 1 approbation + « Do not allow bypassing » ; le script a 0 approbation et un bypass Admin. Retenir : 0 approbation + code owners (seul le noyau attend un humain) ; bypass vide en FINAL0.
3. `k3d-integration.yml` n'a pas le déclencheur `merge_group` : un check `k3d-ok` requis ne serait jamais publié dans la file de fusion et la bloquerait [S5]. Ajouter le déclencheur avant de le requérir (GH-6 ; ADR-0002 §4, `docs/CI-K3D.md` §4).
4. `ci-ok` est requis sans source attendue : tout porteur du rôle Write peut publier un statut de ce nom [S4]. En FINAL, fixer `integration_id` = GitHub Actions (15368).
5. `claude-agent.yml` : déclencheur limité à `SmadjaPaul` (bien) ; le corps d'une issue publique reste modifiable par son auteur après le label. Ajouter un contrôle `author_association` et lire le corps au moment du label (GH-8).
6. Aucun `SECURITY.md`, aucun formulaire de signalement, aucun `dependabot.yml` (Renovate gère les versions), aucun workflow CodeQL/Scorecard/dependency review, `config.yml` des issues absent (issues vides permises).
7. T-215 prévoit « une seule App » pour dispatch, merge et Renovate. Renovate doit modifier `.github/workflows/` (pins d'actions) : il lui faut `workflows: write`, que les agents ne doivent jamais avoir (ADR-0002 §5). Recommandé : deux Apps (GH-11). Une App ne coûte ni siège ni licence.

## 3. Tableau fonction → gratuit ? → dev → FINAL → automatisation

Légende gratuit : OUI = dépôt public d'une org Free ; OUI* = source muette sur le plan, à confirmer dans l'interface ; NON = Team/Enterprise. « as-code » = `tools/github/apply.sh` (GH-1/2).

| Fonction | Gratuit ? | Recommandé dev | Recommandé FINAL | Automatisation |
|---|---|---|---|---|
| Ruleset de dépôt sur `main` [S2] | OUI | actif : non_fast_forward, deletion, PR (0 appro), merge queue, check `ci-ok` | idem + revue code owners, last-push approval, `ci-ok` lié à l'App Actions, `k3d-ok` | JSON `.github/rulesets/main-{dev,final}.json`, `gh api PUT` |
| Rulesets d'organisation [S3] | NON | sans objet | sans objet | — |
| Push rulesets (chemins, taille) [S2] | NON (privé/interne) | sans objet | sans objet | gitleaks + push protection |
| Bypass : rôle, team, App [S3] | OUI | Admin, mode `pull_request` (Paul) | vide ; réactivation ponctuelle par Paul, motif consigné | JSON |
| Revue des code owners [S4] | OUI | désactivée (ADR-0002) | active ; CODEOWNERS par étapes (FINAL0 : authz, policies, security ; FINAL : tout le noyau) | JSON + CODEOWNERS |
| Team comme code owner | OUI (teams Free [S1]) | `@SmadjaPaul` | `@platform-zephyr/core-owners` (permet un 2e approbateur) | `gh api` teams |
| Merge queue [S5] | OUI | active, SQUASH, 5 entrées max ; 10 à N=10 | idem | JSON (règle `merge_queue`) |
| Auto-merge [S1] | OUI | repo `allow_auto_merge` ; avec la file : « Merge when ready » | idem, armé par l'App | `gh api PATCH repos` |
| Checks requis [S4] | OUI | `ci-ok` | `ci-ok` (source Actions) + `k3d-ok` (après `merge_group`) | JSON |
| Signature des commits requise [S4] | OUI, mais bloquant | NON | NON tant que les sessions cloud ne signent pas : un commit non signé sur la branche de PR bloque même le squash | décision à rouvrir en I-stage |
| Historique linéaire | OUI | implicite (SQUASH) | idem | JSON |
| Protection des tags [S2] | OUI | `core-baseline*` : deletion + update interdits dès T-305 | + `v*` ; releases immuables [S7] | JSON `tags.json` |
| Résolution des conversations | OUI | non | non (les agents résolvent mal) ; à reconsidérer | JSON |
| Secret scanning + push protection [S6 S7] | OUI (défaut en public) | actifs | actifs | `PATCH repos security_and_analysis` |
| Motifs personnalisés, bypass délégué, secrets IA [S6] | NON | gitleaks (T-303) | gitleaks | — |
| CodeQL / code scanning [S6] | OUI | « default setup » : `python` + `actions` (le shell n'est pas géré [S9]) | idem + règle `code_scanning` requise | `PATCH .../code-scanning/default-setup` |
| Dependency review [S8] | contradictoire : page dédiée OUI, tableau GHAS NON | différé | `actions/dependency-review-action` si l'essai passe | GH-10 (essai) |
| Dependabot alerts + security updates [S7] | OUI | actifs (pas de version updates : Renovate) | actifs | `PUT .../vulnerability-alerts`, `automated-security-fixes` |
| Signalement privé (PVR) + `SECURITY.md` [S10] | OUI | actifs | actifs + formulaire `VULNERABILITY_REPORT.yml` | `PUT .../private-vulnerability-reporting` |
| Dependency graph, SBOM, advisories [S7] | OUI | actifs | actifs | — |
| Permissions du `GITHUB_TOKEN` [S11] | OUI | lecture seule ; PR par Actions interdites | idem (org + dépôt) | `PUT .../actions/permissions/workflow` |
| Allowlist d'actions + SHA obligatoire [S11] | OUI | `actions/*`, `github/codeql-action/*`, `anthropics/claude-code-action`, + SHA complet | idem + `renovatebot/github-action` si auto-hébergé | `PUT .../actions/permissions` + `selected-actions` |
| Approbation des workflows de forks [S11] | OUI | tous les contributeurs externes | idem | `PUT .../fork-pr-contributor-approval` |
| Politiques d'exécution (acteurs, événements) [S12] | OUI* | défaut : `pull_request_target` bloqué le 2026-12-02 (aucun usage ici) | acteurs : Paul + Apps seulement | UI puis export JSON si l'API existe |
| Environnements + règles de déploiement [S13] | OUI (public) | `agent-runner` : secret Claude, branche `main` seule | + relecteur requis pour tout environnement de preuve | `PUT .../environments/{n}` |
| OIDC [S14] | OUI | `id-token: write` uniquement dans le job qui en a besoin (déjà le cas) | idem ; fédération cloud : hors périmètre | — |
| Secrets/variables d'org ou de dépôt | OUI* | secrets de dépôt, un seul (token Claude) | secrets d'environnement, clés d'Apps | `gh secret set` (Paul, jamais en clair) |
| Artifact attestations [S15] | OUI (public) | sans objet (rien construit) | `attest-build-provenance` sur toute image ou archive produite | GH-14 |
| Scorecard (T-136) | OUI | différé | hebdomadaire, SARIF | workflow |
| Verrouillage des workflows (`actions.lock`, GA 2026-10-28 [S16]) | OUI | non (le dev bouge) | à évaluer avec Renovate | NOT_TESTED |
| GitHub App vs PAT fin [S17] | OUI | session de Paul (arbitrage 4) | Apps : jeton 1 h, sans siège, permissions minimales ; PAT fin proscrit | GH-11 |
| Politique PAT de l'org [S14] | OUI | approbation des PAT fins ; classiques interdits | idem, durée max 30 jours | UI |
| 2FA obligatoire [S18] | OUI | oui, tout de suite | oui | UI seulement |
| Permission de base des membres [S19] | OUI | « Aucune » | « Aucune » | `PATCH /orgs/platform-zephyr` |
| Création de dépôts par les membres [S20] | OUI | interdite | interdite | `PATCH /orgs/platform-zephyr` |
| Accès OAuth/Apps tiers (restrictions) | OUI* | restreint, Claude et Renovate approuvés | idem | UI |
| Issue forms, `config.yml`, labels | OUI | formulaire agent existant ; issues vides coupées ; labels synchronisés | idem | `.github/labels.yml` + `gh label create --force` |
| Projects v2 | OUI* | facultatif : vue lecture du backlog (Git reste source de vérité) | idem | GH-9 |
| Discussions, Wiki, Pages | OUI | désactivés (surface d'injection, aucun besoin) | désactivés | `PATCH repos` |
| Journal d'audit en flux, liste d'IP, SAML, rôles personnalisés, workflows requis | NON | sans objet | sans objet | — |

## 4. Mode dev et mode FINAL : différences exactes du ruleset `main`

| Paramètre | Dev (S0 → PORTE) | FINAL0 (T-400) | FINAL |
|---|---|---|---|
| `bypass_actors` | Admin, `pull_request` | vide | vide |
| `require_code_owner_review` | false | true, CODEOWNERS réduit à authz + policies + security | true, noyau complet |
| `require_last_push_approval` | false | true | true |
| `ci-ok` | sans source | source Actions (id 15368) | idem |
| `k3d-ok` requis | non | oui (après GH-6) | oui |
| Règle `code_scanning` (CodeQL) | non | non | oui, alertes `high` et plus |
| Identité des agents | session de Paul | App `openchoreo-agents` | idem, sans permission `workflows` |

La revue par code owners s'applique à **toutes** les lignes de CODEOWNERS : l'étape FINAL0 partielle passe par un CODEOWNERS réduit (lignes commentées, restaurées en FINAL), pas par un ruleset partiel. T-007 vérifie le fichier complet.

## 5. Actions, secrets et identités : réglages concrets

1. Org + dépôt : `GITHUB_TOKEN` en lecture seule, « Allow GitHub Actions to create and approve pull requests » coupé (valeur par défaut d'une org neuve [S11b]). Les workflows existants déclarent déjà `permissions: contents: read` au niveau racine.
2. Un jeton `GITHUB_TOKEN` ne déclenche pas la CI sur les PR qu'il ouvre (T-215) : dispatch, Renovate et remédiation passent par une App.
3. Les logs d'un dépôt public sont publics : pas de `show_full_output`, pas de `ACTIONS_STEP_DEBUG`.
4. Secret du token Claude : le déplacer dans l'environnement `agent-runner` (branche `main` seule). Un workflow poussé sur une autre branche ne le lit plus.
5. Clés privées des Apps : secrets d'environnement `factory` (branche `main` seule), jamais dans le dépôt ni dans Doppler lisible par les agents.
6. Allowlist : tout ajout d'action passe par le ruleset (noyau). Les 4 actions actuelles sont déjà épinglées par SHA (`ci.yaml`, `k3d-integration.yml`, `claude-agent.yml`).

## 6. Automatisation as-code

Choix : script `tools/github/apply.sh [--check|--apply] [dev|final]` + fichiers versionnés.
- `.github/rulesets/main-dev.json`, `main-final.json`, `tags.json` (charge utile exacte de `POST /repos/{r}/rulesets`) ; `.github/settings/repo.json`, `actions.json`, `security.json` ; `.github/labels.yml`.
- Idempotent : `PUT`/`PATCH` partout ; recherche du ruleset par nom ; secret jamais lu ni écrit. Défaut = affichage sans écriture (comme le script actuel). `--check` compare l'état lu (JSON normalisé, clés triées, sans identifiants ni dates) et sort en erreur s'il y a dérive.
- Exécution : Paul seul (jeton admin, jamais dans le dépôt). Contrôle de dérive en CI limité aux rulesets, lisibles sans authentification sur un dépôt public [S2] ; les réglages admin se vérifient par la commande locale de Paul, preuve datée dans `docs/proofs/`.
- `tools/apply-branch-protection.sh` reste comme enveloppe (T-400, ADR et docs le citent). `/tools/github/` et `/.github/` entrent dans CODEOWNERS (noyau).
- Terraform `integrations/github` couvre les mêmes objets mais ajoute un état à stocker et un jeton admin permanent ; l'authentification 2FA d'org n'est pas réglable par l'API. À réétudier au-delà de 3 dépôts. `NOT_TESTED` : champ `sha_pinning_required` et fork-approval de l'API REST (à valider par `--check` sur le dépôt avant GH-2).

## 7. Gestes de Paul (admin d'organisation)

Mode dev (une séance, environ 20 minutes ; GH-5, GH-2) :
1. Org > Authentication security : exiger la 2FA.
2. Org > Member privileges : permission de base « No permission » ; création de dépôts interdite ; forks privés sans objet.
3. Org > Personal access tokens : fine-grained avec approbation, classiques restreints, durée max 30 jours.
4. Org > Third-party access : restreindre ; approuver l'App Claude existante.
5. Org > Actions > General : « Allow select actions », SHA obligatoire, fork-approval « tous les externes », jeton en lecture.
6. Dépôt : `tools/github/apply.sh --apply dev` avec `gh auth login` (admin), puis `--check dev` : PASS attendu.
7. Dépôt > Settings > Advanced Security : confirmer secret scanning, push protection, CodeQL, PVR (le script lit l'état ; l'interface est la preuve).
8. Après T-305 : appliquer `tags.json` (GH-4).
FINAL0 : créer les Apps (T-215 + GH-11), retirer le bypass (T-400 avec `main-final.json`), créer la team `core-owners`.
Jamais : coller une clé d'App ou un jeton dans le chat ; ajouter une App aux `bypass_actors`.

## 8. Pièges et points NOT_PROVEN

- Interaction entre le bypass Admin en mode `pull_request`, l'auto-merge et la file de fusion : non documentée dans les pages lues ; l'essai T-304/T-315 reste à faire (NOT_PROVEN).
- 0 approbation + code owners : comportement attendu (approbation seulement sur les chemins du noyau). À prouver par T-007 avec l'identité agent.
- Dependency review : deux pages GitHub se contredisent ; test réel avant tout job requis.
- Dependabot : « alerts pause on inactive repositories » dès 2026-12-08 [S21] ; le dépôt est actif, aucun effet attendu.
- Plan Free : une migration vers Team ne s'impose pour aucune fonction citée ici ; la liste « NON » est la seule frontière.

## 9. Sources (docs.github.com et github.blog, lues le 2026-11-18)

- [S1] /en/get-started/learning-about-github/githubs-plans
- [S2] /en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets
- [S3] .../managing-rulesets/creating-rulesets-for-a-repository
- [S4] .../managing-rulesets/available-rules-for-rulesets
- [S5] /en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue
- [S6] /en/get-started/learning-about-github/about-github-advanced-security
- [S7] /en/code-security/getting-started/github-security-features
- [S8] /en/code-security/supply-chain-security/understanding-your-software-supply-chain/about-dependency-review
- [S9] /en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning-with-codeql
- [S10] /en/code-security/security-advisories/working-with-repository-security-advisories/configuring-private-vulnerability-reporting-for-a-repository
- [S11] /en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository
- [S11b] /en/organizations/managing-organization-settings/disabling-or-limiting-github-actions-for-your-organization
- [S12] /en/actions/concepts/about-actions-policies et github.blog/changelog/2026-11-02-pull_request_target-blocked-by-default-december-2
- [S13] /en/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment
- [S14] /en/organizations/managing-programmatic-access-to-your-organization/setting-a-personal-access-token-policy-for-your-organization ; OIDC : /en/actions/concepts/security/openid-connect
- [S15] /en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds
- [S16] github.blog/changelog/2026-10-28-github-actions-workflow-lockfiles-are-generally-available
- [S17] /en/apps/creating-github-apps/about-creating-github-apps/best-practices-for-creating-a-github-app
- [S18] /en/organizations/keeping-your-organization-secure/managing-two-factor-authentication-for-your-organization/requiring-two-factor-authentication-in-your-organization
- [S19] /en/organizations/managing-user-access-to-your-organizations-repositories/managing-repository-roles/setting-base-permissions-for-an-organization
- [S20] /en/organizations/managing-organization-settings/restricting-repository-creation-in-your-organization
- [S21] github.blog/changelog/2026-11-10-dependabot-alerts-will-pause-on-inactive-repositories
