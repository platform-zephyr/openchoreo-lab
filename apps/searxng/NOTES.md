# searxng : notes de portage

Source kube-ops : `k8s/applications/catalog/searxng/` @ origin/main ef50472 [C] (Deployment, ConfigMap settings.yml, ExternalSecret, HTTPRoute internal, CNP).

## Image
- `searxng/searxng:2026.9.30-a9d990033`, digest index `sha256:a07a5cd2...` ; linux/arm64 present [C].

## Ecarts fonctionnels (schema v2alpha1 actuel)
1. **Pas de settings.yml** : le schema ne peut pas monter de ConfigMap. Consequences : `search.formats: [html, json]` de kube-ops ne peut pas etre reproduit (format JSON desactive) ; `server.image_proxy: true` de kube-ops ne peut pas etre active (reglage par defaut) ; `ui.static_use_hash` non applique.
2. **base_url non declare** : `https://search.smadja.dev/` est le nom de production kube-ops, non reutilise ici. A fixer quand un hote d'exposition est choisi.
3. **Secret** : clé store nommee `SEARXNG_SECRET` (prefixe `SEARXNG_` impose par la CI). Dans kube-ops, la clé est `APP_SEARXNG_SECRET` ; la correspondance se fait au provisioning ESO du labo, pas dans Git.
4. **Dimensionnement** : `size: medium` (limite 512Mi) au lieu de 768Mi kube-ops ; `small` (256Mi) jugé trop juste.

## Securite et egress
- Kube-ops n'a **aucune section egress** dans sa CiliumNetworkPolicy (ingress seul) : egress non restreint. Ici `public-internet` (TCP 80/443, hors RFC1918/CGNAT/link-local) est donc plus strict que kube-ops.
- Une allowlist FQDN (E3) n'est pas praticable : les moteurs de recherche sont nombreux et changeants. `public-internet` reste la valeur de compatibilite retenue.
- Ingress : kube-ops autorise gpt-researcher et mastra-factory (namespace + label). Le schema n'exprime pas d'ingress inter-apps (E4) ; le cell-restricted bloque ces flux. Ecart fonctionnel attendu.

## Runtime : NOT_TESTED, risques identifies [S]
- L'entrypoint `/usr/local/searxng/entrypoint.sh` s'execute sans `USER` dans la config d'image (`User` vide) ; il peut demarrer en root puis changer d'uid, ou ecrire sa configuration. Avec `runAsNonRoot` et `readOnlyRootFilesystem` du cell-restricted, le demarrage peut echouer.
- `runAsUser` minimum 1000 dans le schema : l'uid de l'utilisateur `searxng` de l'image n'est pas verifie (non autorise si 977).
- Endpoint de sante `/healthz` non verifie.
- A tester en k3d avant toute conclusion.
