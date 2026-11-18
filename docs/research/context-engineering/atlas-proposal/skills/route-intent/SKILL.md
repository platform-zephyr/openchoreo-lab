---
name: route-intent
description: Router une demande en langage naturel (« installe-moi Mealie avec login famille et sauvegarde », « X est lent », « passe Y en prod ») vers le bon dépôt, le bon skill et les seuls documents utiles, à partir de context/index.yaml. À utiliser en premier dans Atlas, ou dans tout dépôt quand la demande vise un autre dépôt ou une autre plateforme. Ne modifie rien.
owner: paul
updated: 2026-11-18
review_days: 30
---

# route-intent

Entrée : la phrase de l'utilisateur. Sortie : un **routage** de 5 lignes, puis passage la main au skill du dépôt cible. Aucune écriture ici.

## Étapes
1. **Lire `context/index.yaml` seul** (~130 lignes). Ne rien ouvrir d'autre dans Atlas. Si l'index est absent ou `updated` + `review_days` dépassés : le dire dans le routage (confiance réduite), continuer avec `repos/catalog.md`.
2. **Découper la demande** en intentions : une phrase peut en contenir plusieurs (« installe » + « login » + « sauvegarde » = `deploy-app` avec `oidc-login` et `backup-restore` comme *exigences* du même `app.yaml`, pas trois missions). Choisir l'intention principale = celle qui produit l'artefact (PR).
3. **Choisir le dépôt** : `repo` de l'intention. Si `needs_decision` est présent (D1, D2…), la décision de Paul n'est pas encore prise : annoncer le choix retenu et son `alt`, sans le présenter comme acquis.
4. **Poser au plus UNE question**, seulement si elle figure dans `ask_only_if` (exposition publique, donnée irremplaçable, coût, accès d'une personne à un groupe) ou si la plateforme cible est ambiguë (lab ou production). Sinon avancer avec des valeurs par défaut sûres.
5. **Atteindre le dépôt** : cloner ou ouvrir **seulement** ce dépôt (`repos.<id>.url`), lire `read` dans l'ordre, puis le `SKILL.md` indiqué. Si le dépôt est inaccessible (privé, pas d'accès) : BLOCKED avec le nom du dépôt ; ne pas deviner ses règles.
6. **Rendre le routage** (conclusion d'abord, STE80) :
   ```
   Cible : <dépôt> · skill <nom> · classe <AUTONOME|REVUE|MANDAT si connue>
   Lecture : <≤ 4 chemins>
   Livrable : <PR / verdict / diagnostic>
   Exigences déduites : <login, sauvegarde, exposition…>
   Question : <une seule, ou « aucune »>
   ```
7. **Transmettre** au skill cible avec les champs d'une mission (`Objective`, périmètre, critère de fin = preuve runtime datée). Un ticket ou une issue existant(e) est relu(e) avant ; ne jamais en créer un doublon.

## Interdits
- Ne pas charger `decisions.md` entier, `docs/` en bloc ou plusieurs dépôts « pour voir ».
- Ne pas copier de règle dans la réponse : citer le chemin. Ne pas déduire une règle d'un nom de dépôt.
- Aucun secret dans le routage ni dans le ticket : noms de clés seulement.

## Exemple : « installe-moi Mealie avec login famille et sauvegarde »
- Intentions : `deploy-app` (principale), `oidc-login`, `backup-restore`. Lieu non précisé : cible lab (`needs_decision: D1`), `alt` kube-ops si production immédiate ; annoncer le choix.
- Cible : `openchoreo-lab` · skill `add-app`. Lecture : `AGENTS.md`, `STATE.md`, `SKILL.md` de `add-app`, `recipes/mealie.yaml` si elle existe, ADR-0007 et ADR-0008 (sections utiles).
- Exigences : OIDC Authentik (clients créés par Paul : MANDAT, noms de clés seulement), groupe « famille », classe de donnée à déclarer ; le volume OCI de 50 Go reste INTERDIT sans mandat, donc le skill qualifie un stockage compatible ou rend BLOCKED motivé.
- Question : « famille » = quel groupe Authentik existant ? (accès d'une personne à un groupe, pas de défaut sûr) ; sinon aucune.
- Livrable : PR `apps/mealie/app.yaml` + plan lisible ; l'image, le port et le digest arm64 viennent d'une recette vérifiée ou d'un `imagetools inspect`, jamais de la mémoire du modèle.
