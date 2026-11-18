# ADR-0013 — L'utilisateur exprime une intention en langage naturel à un LLM
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0001, ADR-0002, ADR-0011, ADR-0012

## Contexte
- Le but final : **un utilisateur décrit ce qu'il veut en langage naturel à un LLM** (« installe Mealie pour la famille,
  avec login et sauvegarde »), et la plateforme livre seule, avec preuve.
- ADR-0001 fixe ce que l'agent écrit (`app.yaml`). Il manque la couche au-dessus : comprendre l'intention, choisir les
  bonnes valeurs, ne poser que les questions utiles, rendre compte.
- Un LLM invente volontiers des images, ports et variables : il faut des faits vérifiés.

## Décision
1. **Entrées acceptées** : conversation avec Claude (app, session cloud), issue GitHub, ou plus tard un canal de chat.
   Toutes aboutissent au même flux : intention → routage (Atlas) → skill `add-app`/`fix-app`/`promote-or-rollback`.
2. **L'agent traduit l'intention en `app.yaml` avec des valeurs par défaut**, et ne pose une question **à l'utilisateur qui fait
   la demande** (pas à Paul) que pour une décision qui n'a pas de défaut sûr : exposition publique, donnée `irreplaceable`, coût, accès d'une personne à un
   groupe. Tout le reste (archétype, taille, placement, réseau, sauvegarde selon la classe) est déduit.
3. **Recettes vérifiées** : un catalogue `recipes/<app>.yaml` d'applications homelab courantes (image multi-arch par
   digest, port, chemin de santé, variables, besoins OIDC/base/volume, classe de donnée suggérée), produit et
   rafraîchi par un agent, vérifié par la CI (digest existant, arm64). L'agent part d'une recette quand elle existe.
4. **Avant d'agir, un plan lisible** de quelques lignes (ce qui sera créé, où, qui y accède, quelles données, comment
   revenir en arrière), affiché à l'utilisateur ; l'agent n'attend une réponse que s'il y a une question du point 2.
5. **Après, un compte rendu** : lien de PR, statut `app-status.v1` (ADR-0011), URL, et la marche à suivre pour annuler.
6. **Opérer aussi en langage naturel** : « Mealie est lent », « passe Vikunja en prod », « supprime X » suivent le même
   flux (diagnostic en lecture, puis PR).

## Conséquences
- Nouveaux artefacts : catalogue de recettes, skill de routage d'intention (Atlas), gabarit de plan et de compte rendu.
- Le contexte chargé par l'agent doit rester court et ciblé (context engineering, ADR-0012).
- Mesure du succès : intentions livrées sans question ni intervention humaine, et délai intention → PASS runtime.

## Alternatives écartées
- **Formulaire / template Backstage** : rassurant mais rigide, et ce n'est pas du langage naturel.
- **Laisser le LLM tout deviner sans recettes** : hallucinations d'images et de configuration.

## Vérification
- Banc d'essai : 10 intentions types (stateless, avec base, avec OIDC, publique, worker, « répare », « supprime ») jouées
  par un agent sans contexte ; on mesure questions posées, PASS runtime et interventions humaines.

## Références
`.agents/skills/add-app/`, `docs/research/IDP-AGENTIC-BEST-PRACTICES.md`, `docs/research/context-engineering/` (en cours).
