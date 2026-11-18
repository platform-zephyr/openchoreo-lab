# ADR-0007 — Identité : Authentik, OIDC déclaré par l'app
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0009, ADR-0010 ; `docs/IDENTITY.md`, `missions/MISSION.md` (Authentik, pas de ThunderID)

## Contexte
- Authentik est l'unique IdP (issuer global, un provider par client). La doc OpenChoreo est centrée sur ThunderID ;
  le schéma du contrat a encore `thunderid` comme défaut.
- Dans kube-ops, une app OIDC demande : un blueprint Authentik, un client confidentiel, un secret Doppler
  `APP_<APP>_OIDC_CLIENT_SECRET`, un ExternalSecret, un groupe lié. Une app sans OIDC passe par l'outpost forward-auth.
  Chaque nouvelle app OIDC est donc un geste humain (KUBE-OPS-REQUIREMENTS §2.3).

## Décision
1. **Authentik est le seul IdP** des humains et des agents, **configuré en GitOps** (blueprints générés depuis Git),
   comme dans l'implémentation actuelle qui a déjà donné les primitives voulues. Keycloak reste une alternative
   acceptable si une primitive manque, pas un objectif. `identityProviders: [authentik]` partout ; ThunderID retiré
   du contrat et désactivé dans le chart.
2. **L'app déclare son mode d'accès**, la plateforme fait le reste :
   - `identity.mode: oidc` → client OIDC Authentik créé **déclarativement** (provider Crossplane ou blueprint généré,
     ADR-0009), secret client **généré et livré au namespace** sans passer par un humain, groupes autorisés liés ;
   - `identity.mode: proxy` → protection par l'outpost forward-auth d'Authentik ;
   - `identity.mode: none` → seulement pour une app privée sans données personnelles.
3. **Accès par groupe, jamais par utilisateur** (`identity.groups: [family, admins…]`).
4. **Agents** : un client par usage (`agent-reader`, `agent-operator`, CI, portail) ; jetons courts ; droits OpenChoreo
   par rôle et condition ABAC par environnement ; le reader n'a aucune action d'écriture.
5. **Cycle de vie des utilisateurs = golden path** : ajouter une personne = PR sur `users/<id>.yaml` (identité, groupes,
   accès) → blueprint Authentik → groupes → accès aux apps ; la retirer = PR qui désactive le compte, révoque sessions et
   jetons, retire les groupes et traite ses données personnelles. Aucune action à la main dans la console.
6. Une app **publique** (ADR-0010) exige `identity.mode` ≠ `none` ou Cloudflare Access par groupe.

## Conséquences
- Lever le geste humain par app : c'est la condition de l'autonomie sur les apps familiales.
- L'agent ne crée **pas** d'identité au sens MANDAT : c'est la plateforme qui génère un client borné à l'app à partir
  d'une déclaration revue en CI. Le droit de la plateforme à créer des clients Authentik est lui-même dans le noyau.
- Configuration OpenChoreo à prouver : claims des comptes de service Authentik, audience, mappings bootstrap
  (CONSOLIDATION §d.1).

## Alternatives écartées
- **Blueprints Authentik écrits à la main par app** : c'est le geste humain qu'on veut supprimer.
- **Garder ThunderID pour OpenChoreo** : deux IdP, deux cycles de vie.

## Vérification
- k3d CI : une app `identity.mode: oidc` obtient un client et un secret sans intervention ; un utilisateur hors
  groupe est refusé ; un jeton reader ne peut pas écrire (test `evaluate_authz`).
- Preuve OKE datée sur une app réelle (ex. Mealie ou Vikunja).

## Références
`docs/IDENTITY.md`, `docs/AGENT-ACCESS.md`, `docs/reference/openchoreo/authz-identity.md`, kube-ops `deploy-a-service`.
