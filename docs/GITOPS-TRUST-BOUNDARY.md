# Frontière de confiance GitOps : applicatif vs plateforme (flux A2)

> Propriétaire : flux A2. Preuves Argo : `tests/argo-escalation/RESULTS.md` (k3d, Argo CD v3.5.1 réel). Détail des attaques : `docs/ARGO-ESCALATION.md`.

## Décision

**Un seul dépôt, deux périmètres GitOps séparés DANS LE CLUSTER, et une identité d'agent distincte côté GitHub. Pas de second dépôt pour l'instant.**

1. **Fait (ce flux), sans dépendre de GitHub.** Un AppProject par source :
   - `lab-o` (ApplicationSet `lab-o`, une Application `lab-o-<app>` par app) : `generated/**`, synchro automatique sans prune, bornée aux kinds OpenChoreo namespacés dans `default` ;
   - `lab-platform` et `lab-authz` : `platform/**`, avec une fenêtre `deny` permanente (`manualSync: true`).

   Conséquence : **aucun merge ne modifie seul la plateforme**. Il faut une synchro manuelle de l'opérateur.
2. **À activer par Paul (non fait, décision requise).**
   - Identité d'agent distincte : GitHub App ou PAT fine-grained, ni admin, ni code owner, sans bypass.
   - Ruleset `main-protection` avec `require_code_owner_review: true` et une approbation, CODEOWNERS = Paul sur `platform/**`, `tools/oke/**`, `.github/**`, `CODEOWNERS`.
3. **Deux dépôts seulement si** le point 2 n'est pas tenable (par exemple, un agent garde les droits admin). Le dépôt plateforme serait alors en lecture seule pour l'agent.

## Niveaux de confiance

| Niveau | Contenu | Qui merge | Qui applique |
|---|---|---|---|
| Plateforme (privilégié) | `platform/**` : RBAC, VAP, types OpenChoreo, authz, Argo (projets, Application), identité, données, `tools/oke/**`, `.github/**` | Paul (cible : revue code owner obligatoire) | l'opérateur, par synchro manuelle `lab-platform` / `lab-authz`, ou `install.sh` pour le bootstrap |
| Applicatif (autonome) | `apps/**` → `generated/**` (`tools/appgen`) : app.yaml, versions, ressources, paramètres | agent, si `ci-ok` | Argo `lab-o-<app>` (ApplicationSet `lab-o`), borné par l'AppProject `lab-o` |

**Une PR qui touche `platform/**` n'est jamais une PR applicative**, même si elle vient d'un agent applicatif.

## État réel aujourd'hui (lu le 2026-11-17)

- Ruleset `main-protection`, lu en lecture seule par `gh api repos/platform-zephyr/openchoreo-lab/rulesets/27477991` : actif, `bypass_actors: []`, PR obligatoire et check `ci-ok`. Il exige aussi **0 approbation** et `require_code_owner_review: false`.
- Les agents agissent avec l'identité GitHub de Paul (`gh api user` renvoie `SmadjaPaul`), sur le même compte macOS que le kubeconfig OKE (`~/.cache/oke-access`).
- `ci-ok` est calculé par le workflow **de la PR elle-même** (`pull_request`). Une PR peut donc affaiblir `argo_guard.py` ou `ci.yaml` dans le même diff.

**Conséquence : côté GitHub, il n'existe aujourd'hui AUCUNE frontière entre agent et plateforme.** CODEOWNERS sans revue obligatoire n'est pas un contrôle d'autorisation. La seule frontière technique est dans le cluster : les AppProject, appliqués par l'opérateur et non synchronisés par Argo.

## Ce que chaque option garantit

| Option | Garantit | Ne garantit PAS |
|---|---|---|
| A. AppProject par source + fenêtre `deny` sur `lab-platform`/`lab-authz` (**fait**) | Un commit dans `generated/**` ne peut créer que des kinds OpenChoreo applicatifs dans `default`. C'est prouvé sur un vrai Argo, même avec une CI contournée. Un merge sur `platform/**` reste OutOfSync tant que l'opérateur ne synchronise pas (prouvé : N4, N9, N7a). | Rien si l'opérateur synchronise sans relire (N7b : Argo accepte la baisse PSA de `lab-pg`). Rien si l'agent détient les identifiants opérateur (admin Argo, kubeconfig OKE). La dérive des objets plateforme n'est plus corrigée automatiquement (plus de selfHeal) : elle reste visible en OutOfSync. |
| B. A + identité d'agent distincte + revue code owner obligatoire (**à décider**) | Le merge d'un changement privilégié exige l'approbation de Paul. La CI ne peut plus être affaiblie sans lui (`.github/**` est sous CODEOWNERS). L'agent ne peut pas modifier le ruleset (il n'est pas admin). | Une approbation sans lecture. Les secrets que l'agent détiendrait hors GitHub (kubeconfig OKE sur le même poste). |
| C. Deux dépôts (plateforme / applicatif) | Comme B, mais l'agent n'a aucun droit d'écriture sur le dépôt plateforme, ce qui est plus simple à auditer que CODEOWNERS. | Comme B. Coût : migration, et dépendances croisées (`generated/` référence les CCT/CPT de la plateforme ; la CI applicative a besoin des types plateforme). |
| Push ruleset « restricted file paths » (variante de B) | Refuse au push tout fichier `platform/**` pour les acteurs sans bypass. | Disponibilité à vérifier pour ce dépôt. Exige aussi une identité d'agent distincte. |

**Sans identité d'agent distincte, ni B ni C n'apportent de séparation** : l'agent agit en tant que Paul, admin du dépôt. C'est le prérequis.

## Ce qui reste un canal indirect (hors Argo)

- `SecretReference` (kind admis dans `lab-o`) : la portée réelle dépend du `ClusterSecretStore` et de l'ESO. C'est le flux A1 (lecture des Secrets), à borner côté ESO.
- Un Component choisit son `ClusterComponentType` parmi ceux qui existent. La borne est celle des CCT durcis (plateforme).
- `tools/appgen` et `.github/**` : une PR applicative qui les modifie n'élargit pas ce qu'Argo `lab-o` applique. Elle peut en revanche faire passer `ci-ok` sur un `generated/` qui n'est plus la sortie d'appgen. Le contenu reste borné par `lab-o`.
