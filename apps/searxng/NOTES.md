# searxng : notes de portage

Source kube-ops : `k8s/applications/catalog/searxng/` @ origin/main ef50472 [C] (Deployment, ConfigMap settings.yml, ExternalSecret, HTTPRoute internal, CNP).

## Image
- `docker.io/searxng/searxng:2026.9.30-a9d990033@sha256:a07a5cd2...` ; index verifie le 2026-11-18 : HTTP 200 sur le registre, `docker-content-digest` identique ; manifests linux/amd64 et linux/arm64 [C].

## Cible OKE (cluster: oke, stateless)
- `cluster: oke`, `profile: stateless` : aucun `storage`, aucun `database`, aucun PVC. Le schema et `clusters/oke/capabilities.yaml` n'admettent aucun volume ni base sur OKE : rien a deroger.
- Secret : `SEARXNG_SECRET` seulement comme reference ESO (`secrets[]`, store `lab-store`). Aucune valeur dans Git ni dans le cluster par ce depot.
- Sécurité : PSA restricted generee (runAsNonRoot, uid 65532 par defaut, seccomp, automount off, drop ALL, readOnlyRootFilesystem) + `emptyDir` `/tmp` 64Mi. Pas d'exposition publique (`exposure: private`, `auth: none`).
- Egress `public-internet` conserve : les moteurs de recherche sont nombreux et changeants (allowlist FQDN non praticable). Il ouvre TCP 80/443 vers Internet hors RFC1918/CGNAT/link-local ; IMDS (169.254.0.0/16) exclu d'office. Plus strict que kube-ops (qui n'a aucune section egress) mais non minimal : a reduire si Paul fixe une liste de moteurs.
- Demarrage (T-517) : l'entrypoint de l'image ecrit `/etc/searxng/settings.yml` ; mesure OKE 2026-11-19 : CrashLoopBackOff (`cp: can't create ... Read-only file system`). Correctif : `runtime.command` lance `granian` directement et `SEARXNG_SETTINGS_PATH` lit le modele de l'image (lecture seule). Rootfs RO conserve, aucun volume. A chaque bump d'image, reverifier dans l'entrypoint amont (`container/entrypoint.sh`) les deux chemins `/usr/local/searxng/.venv/bin/granian` et `/usr/local/searxng/settings.template.yml`. Le modele active `image_proxy: true`.
- Preuve runtime sur OKE du correctif : NOT_TESTED. Points restants : uid 65532 accepte par l'image, endpoint `/healthz`.

## Ecarts fonctionnels (schema v2alpha1 actuel)
1. **Pas de settings.yml** : le schema ne peut pas monter de ConfigMap. Consequences : `search.formats: [html, json]` de kube-ops ne peut pas etre reproduit (format JSON desactive) ; `server.image_proxy: true` vient du modele de l'image (T-517) ; `ui.static_use_hash` non applique.
2. **base_url non declare** : `https://search.smadja.dev/` est le nom de production kube-ops, non reutilise ici. A fixer quand un hote d'exposition est choisi.
3. **Secret** : clé store nommee `SEARXNG_SECRET` (prefixe `SEARXNG_` impose par la CI). Dans kube-ops, la clé est `APP_SEARXNG_SECRET` ; la correspondance se fait au provisioning ESO du labo, pas dans Git.
4. **Dimensionnement** : `size: medium` (limite 512Mi) au lieu de 768Mi kube-ops ; `small` (256Mi) jugé trop juste.

## Securite et egress
- Kube-ops n'a **aucune section egress** dans sa CiliumNetworkPolicy (ingress seul) : egress non restreint. Ici `public-internet` (TCP 80/443, hors RFC1918/CGNAT/link-local) est donc plus strict que kube-ops.
- Une allowlist FQDN (E3) n'est pas praticable : les moteurs de recherche sont nombreux et changeants. `public-internet` reste la valeur de compatibilite retenue.
- Ingress : kube-ops autorise gpt-researcher et mastra-factory (namespace + label). Le schema n'exprime pas d'ingress inter-apps (E4) ; le cell-restricted bloque ces flux. Ecart fonctionnel attendu.

## Runtime : NOT_TESTED, risques identifies [S]
- Resolu par T-517 (non prouve) : l'entrypoint ecrivait sa configuration, il n'est plus execute.
- `runAsUser` minimum 1000 dans le schema : l'uid de l'utilisateur `searxng` de l'image n'est pas verifie (non autorise si 977).
- Endpoint de sante `/healthz` non verifie.
- A tester en k3d avant toute conclusion.
