# ADR-0014 — Secrets : OpenBao pour les secrets internes, Doppler pour les primitives externes
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : D-2026-11-14-05, D-2026-11-15-10 (homelab-infra, secrets écrits par Tofu dans Doppler), ADR-0006,
ADR-0007, ADR-0008, ADR-0009 ; `docs/architecture/DECISIONS-OPEN.md` D2, `docs/storage/OPENBAO-DOPPLER-ESO.md`

## Contexte
- Dans l'implémentation actuelle, un secret applicatif doit **exister dans Doppler avant le déploiement** : soit posé
  à la main, soit généré par la root Tofu `doppler` (liste centrale, plan ARC). Une nouvelle app attend donc un humain
  ou un second dépôt. Paul juge ce point bloquant (2026-11-18).
- Un générateur ESO seul (`Password`) supprime l'étape manuelle, mais la valeur ne vit que dans un Secret Kubernetes :
  si le namespace est recréé, un mot de passe de base change alors que la base restaurée attend l'ancien.
- Il reste des secrets **fournis par un humain** (clé d'API d'un service tiers) : il leur faut un chemin d'entrée sans
  Doppler et sans PR.
- homelab-infra avait déconseillé OpenBao (coût d'exploitation : stockage, déscellement). Paul rouvre ce choix.

## Décision
1. **OpenBao est le coffre des secrets applicatifs et de plateforme.** ESO le lit (`ClusterSecretStore` par cluster)
   et livre des Secrets Kubernetes aux cellules ; aucune app ne parle à OpenBao directement en v1.
2. **Secrets générés par déclaration** : `secrets[].generate` dans `app.yaml` → la plateforme crée la valeur **dans
   OpenBao** (chemin `apps/<app>/<env>/<nom>`) si elle n'existe pas, puis ESO la livre. La valeur survit à la
   reconstruction du namespace et suit la sauvegarde d'OpenBao. Mots de passe de bases et secrets clients OIDC
   (ADR-0007) passent par là.
3. **Secrets fournis par un humain** : l'app déclare le **nom** (`secrets[].provided: true`, avec description) ; tant que
   la valeur manque, `app-status.v1` passe à BLOCKED avec la cause typée `secret-missing` et le chemin exact. L'humain
   la dépose une fois dans OpenBao (UI/CLI authentifiée par Authentik OIDC, politique limitée à `apps/*`). Ni Doppler,
   ni PR, ni valeur dans une conversation.
4. **Frontière nette entre deux coffres** (précision de Paul, 2026-11-18) :

   | Coffre | Contient | Qui écrit | Exemples |
   |---|---|---|---|
   | **Doppler** — secrets **externes, primitives de la plateforme** | tout secret dont la plateforme a besoin pour exister ou pour parler à un fournisseur, et qui ne peut pas être généré par elle | Paul (MANDAT) ou une root Tofu via ARC | clé d'auto-unseal / de récupération d'OpenBao, jeton Cloudflare (Access, tunnel), jetons R2, jeton admin Authentik de la plateforme, GitHub App, jeton ESO→OpenBao si besoin |
   | **OpenBao** — secrets **internes** | tout secret né dans la plateforme ou propre à une app | la plateforme (générés) ; un humain pour une valeur d'app fournie | mots de passe de bases, secrets clients OIDC, jetons entre services, clés de chiffrement d'app, clé d'API tierce propre à une app (`provided`) |

   Règle de décision : **si la plateforme peut le générer ou s'il ne sert qu'à une app, il va dans OpenBao ; s'il
   conditionne le démarrage de la plateforme ou son accès à un fournisseur, il va dans Doppler.** Aucun secret
   n'est dans les deux. ESO lit Doppler **seulement** pour les namespaces de plateforme, jamais pour une cellule d'app.
5. **Accès par politique** : chaque cellule ne lit que `apps/<app>/<env>/*` ; les agents n'ont **aucune** lecture de
   valeur (seulement la présence d'une clé, pour le diagnostic) ; audit OpenBao activé.
6. **Placement et exploitation, à qualifier par un spike** : OpenBao sur **OKE** (toujours allumé, à côté du control
   plane) avec un stockage qui ne crée pas de nouveau volume OCI si possible (backend PostgreSQL du CNPG plateforme,
   sinon Raft sur un petit volume : tout nouveau volume OCI reste un MANDAT de Paul), **auto-unseal** par une clé hors cluster (OCI Vault ou transit), sauvegarde
   chiffrée hors Oracle avec restauration prouvée (ADR-0008, classe `irreplaceable`).

## Conséquences
- Lève le principal geste humain par app ; rend la promesse d'ADR-0013 (« installe X » sans préparation) tenable.
- Coût : 1 pod (~100-250 Mi [E]), une sauvegarde de plus, un déscellement à prouver ; OpenBao devient une
  dépendance critique des **nouveaux** déploiements (les pods en cours gardent leurs Secrets).
- La root Tofu `doppler/generated-app-secrets` n'a plus de nouvelles entrées ; migration des secrets existants app par
  app, au fil des migrations kube-ops.
- CI : refus d'un `ClusterSecretStore` Doppler référencé depuis une cellule d'app ; inventaire des clés Doppler restreint
  aux primitives (liste fermée, revue à chaque ajout).

## Alternatives écartées
- **Doppler pour tout** (actuel) : secret posé avant chaque déploiement.
- **Générateur ESO seul** : pas de persistance hors namespace ni de chemin d'entrée humain.
- **Sealed Secrets / SOPS** : chiffré dans Git, mais un humain chiffre chaque valeur et la rotation est manuelle.
- **API de secrets d'OpenChoreo** : désactivée par décision de sécurité ; ne couvre pas le multi-cluster proprement.

## Vérification
- k3d CI : une app avec `secrets[].generate` démarre sans geste ; namespace supprimé puis recréé → même valeur.
- Une app avec `provided: true` est BLOCKED `secret-missing`, puis Ready après dépôt de la valeur.
- Drill : perte du pod OpenBao et de son stockage → restauration depuis la sauvegarde hors Oracle, descellement auto.

## Références
`docs/storage/OPENBAO-DOPPLER-ESO.md`, `docs/architecture/DECISIONS-OPEN.md` D2, homelab-infra `docs/architecture/secret-store-decision.md`.
