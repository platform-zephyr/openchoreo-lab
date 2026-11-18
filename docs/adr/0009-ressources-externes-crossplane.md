# ADR-0009 — Ressources externes par app : Crossplane ; socle : OpenTofu
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : D-2026-11-14-04 (OpenTofu via ARC), D-2026-11-14-05 (secrets écrits par Tofu), ADR-0007, ADR-0008, ADR-0010

## Contexte
- Une app réelle a besoin de ressources hors cluster : application Cloudflare Access, stockage objet de sauvegarde,
  client OIDC, secrets. Aujourd'hui, elles vivent dans 20 roots OpenTofu appliquées par ARC, avec des listes
  centrales (`enable_*`, `generated-app-secrets.tf`) : chaque nouvelle app touche un autre dépôt (HOMELAB-INFRA §2-3).
- Paul est ouvert à Crossplane pour simplifier le modèle opérationnel.
- Le wildcard DNS `*.smadja.dev` existe déjà : pas besoin d'un enregistrement DNS par app.
- Providers Crossplane : Cloudflare et Authentik n'ont que des ports upjet communautaires (maturité non vérifiée) ;
  rien pour Doppler. Chaque provider coûte un pod et une IP ; OKE n'a qu'environ 260m de marge.

## Décision
1. **Socle en OpenTofu via ARC** (inchangé) : cluster, réseau, tunnel, comptes, IAM, émission des jetons (dont le
   « token factory » R2, qu'aucun contrôleur ne doit détenir).
2. **Par app, déclaratif et dans le même PR que l'app** : la ressource externe est produite par `appgen` à partir de
   `app.yaml` et réconciliée dans le cluster. Cible : **Crossplane**, installé **sur le homelab** (pas sur OKE), avec
   le minimum de providers.
3. **Choisir le mécanisme le plus simple par type**, Crossplane seulement s'il apporte quelque chose :
   - secrets applicatifs → **générés dans le cluster** (ESO generator), sans Doppler ni Crossplane ;
   - client OIDC → **blueprint Authentik généré** par `appgen` (Authentik lit ses blueprints), ou provider
     Crossplane Authentik si le spike le qualifie ;
   - application + politique Cloudflare Access → **provider Crossplane Cloudflare** (candidat n°1) ;
   - stockage de sauvegarde → **préfixe par app dans un bucket par domaine de risque** (pas de bucket par app,
     donc pas de jeton par app) ; un bucket dédié par Crossplane seulement pour une donnée `irreplaceable`.
4. **Spike obligatoire avant adoption** : providers maintenus, couverture des ressources voulues, coût mesuré,
   suppression qui ne détruit pas les données (`deletionPolicy: Orphan` par défaut). Si le spike échoue : repli
   sur des **entrées générées par `appgen` et appliquées par une root Tofu via ARC** (même déclaration dans
   `app.yaml`, autre réconciliateur).
5. **Un objet = un seul état** : une ressource migrée de Tofu vers Crossplane est importée puis retirée du state
   Tofu, jamais gérée par les deux.

## Conséquences
- L'agent ne touche plus `homelab-infra` pour une nouvelle app : tout est dans `app.yaml`.
- Le droit de Crossplane sur Cloudflare (jeton limité à Access) est une identité créée par Paul (MANDAT), une fois.
- Risque : provider communautaire abandonné ; atténué par le repli Tofu et `deletionPolicy: Orphan`.

## Alternatives écartées
- **Tout en Tofu** : chaque app = PR dans un second dépôt + plan ARC ; pas de « une PR, une app ».
- **Tout en Crossplane, socle compris** : circularité (le cluster gérerait ce dont il dépend), poids sur OKE.
- **Un bucket et un jeton R2 par app** : exige qu'un contrôleur puisse émettre des jetons (élévation).

## Vérification
- Spike : un `app.yaml` `public` crée l'application Access, un `git revert` la retire, sans geste humain ; mesure
  CPU/mémoire de Crossplane + provider sur le homelab.
- CI : toute ressource externe d'une app est déclarée dans `app.yaml` (aucune liste centrale à éditer).

## Références
`docs/research/HOMELAB-INFRA-REQUIREMENTS.md` §2-3, §6 ; homelab-infra `docs/architecture/invariants.md` (INV-STATE-02, INV-EDGE-01).
