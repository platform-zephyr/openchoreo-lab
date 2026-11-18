# Identité GitHub des agents

Statut : proposition (docs seulement). Aucun secret dans ce fichier.
Dépôt : `platform-zephyr/openchoreo-lab`. Compte humain propriétaire : `<owner-humain>`.

## Décision recommandée

- Identité : une **GitHub App** dédiée `openchoreo-agents`, installée sur ce seul dépôt.
- Permissions : Contents RW, Pull requests RW, Metadata R. Aucune autre (pas Workflows, Administration, Environments).
- Pas de rôle Write ni Admin pour l'App ; pas de bypass dans les rulesets.
- Protection de `main` : PR obligatoire, 1 approbation humaine, Code owners requis, « Do not allow bypassing ».
- Repli si la rotation du token est trop coûteuse : un seul compte machine + fine-grained PAT (limites ci-dessous).

## Limites vérifiées (docs.github.com)

1. Fine-grained PAT : approbation requise par défaut pour les ressources non publiques de l'org ; expiration max par défaut 366 jours (réglable). La doc ne traite pas explicitement les outside collaborators ni les comptes machine : à tester.
2. Rôle Write : peut merger des PR, ne peut pas gérer rulesets ni branch protection, ne peut pas pousser sur branches protégées.
3. Rulesets / branch protection : s'appliquent aux Write sans bypass. Bypass = liste explicite (rôle Admin par défaut, teams, Apps). « Do not allow bypassing » étend aux admins. Restrictions de branche disponibles sur dépôts publics d'org Free ; la page rulesets cite Team/Enterprise : vérifier dans l'UI.
4. Auteur d'une PR : il ne peut pas approuver sa propre PR. Un agent auteur ne peut donc pas valider seul. Un humain code owner reste requis pour `.github/`.
5. GitHub App : token d'installation valable 1 h ; quota 5 000 req/h, +50 par dépôt au-delà de 20 et +50 par utilisateur au-delà de 20, plafond 12 500 req/h ; les 16 agents partagent ce quota. Coût en siège et identité `app[bot]` des commits : non confirmés par les pages lues.
6. CGU, section B.3 : un compte machine doit avoir un humain propriétaire qui accepte les CGU, un usage automatisé exclusif, et un seul compte machine gratuit par personne en plus du compte perso. Un seul compte machine est donc conforme ; deux ne le sont pas. Une App n'a pas ce problème.

## Étapes pour Paul (une action par ligne)

1. Ouvrir `https://github.com/organizations/platform-zephyr/settings/apps/new`.
2. Name : `openchoreo-agents`. Homepage URL : `https://github.com/platform-zephyr/openchoreo-lab`.
3. Décocher « Active » sous Webhook.
4. Repository permissions : Contents = `Read and write`, Pull requests = `Read and write`, Metadata = `Read-only`. Tout le reste reste `No access`.
5. Where can this GitHub App be installed : `Only on this account`.
6. Cliquer « Create GitHub App » et noter l'App ID affiché (ce n'est pas un secret).
7. Cliquer « Generate a private key ». Déplacer le `.pem` dans le coffre de secrets, jamais dans le dépôt ni dans le chat.
8. Cliquer « Install App », puis choisir uniquement `platform-zephyr/openchoreo-lab`.
9. Noter l'Installation ID (URL de la page d'installation) et le stocker au coffre avec l'App ID.
10. Dans Settings > Rules > Rulesets du dépôt, créer un ruleset ciblant `main`.
11. Activer « Require a pull request before merging » : 1 approbation, « Require review from Code Owners », « Require approval of the most recent reviewable push ».
12. Activer « Require status checks » sur les checks CI existants (merge queue si active).
13. Laisser la liste des bypass vide ; ne jamais y ajouter `openchoreo-agents`.
14. Cocher « Do not allow bypassing the above settings ».
15. Ajouter `CODEOWNERS` avec une ligne `/.github/ <owner-humain>` si ce n'est pas déjà fait.

## Vérifications de bon fonctionnement

À faire avec un token de l'App, sur une PR de test, sans toucher au cluster :

1. Push direct sur `main` : doit être refusé.
2. PR de test qui modifie `.github/workflows/*` : merge bloqué sans approbation du code owner.
3. Tentative d'approuver sa propre PR : refusée par GitHub.
4. Appel `PUT /repos/platform-zephyr/openchoreo-lab/rulesets` avec le token : doit être refusé (403 ou 404).
5. Tentative de modifier une branch protection ou un ruleset depuis l'App : refusée.
6. Création d'une PR qui touche `.github/` : l'App ne peut pas modifier `.github/workflows` (Workflows absent).
7. Vérifier `expires_at` d'un token d'installation : environ 1 h après émission.
8. Une PR approuvée par un humain non-auteur, hors `.github/`, se merge : confirmer que le flux nominal fonctionne.
