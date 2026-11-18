# ADR-0002 — Autonomie d'abord, noyau de confiance protégé
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : D-2026-11-15-03 et D-2026-11-16-07 (homelab-infra, autonomie maximale), ADR-0001, ADR-0006, ADR-0011

## Contexte
- Paul vise d'abord l'**autonomie totale des agents**, puis la sécurité.
- Jusqu'ici, `.github/CODEOWNERS` soumettait à sa revue `platform/`, `tools/`, `tests/`, `golden-paths/`, `.agents/`… :
  presque tout changement utile attendait un humain. Le goulot est humain, pas technique.
- Une approbation humaine n'est pas un contrôle fiable à vitesse machine ; un contrôle exécutable l'est.

## Décision
1. **Par défaut, un agent livre seul** : branche, PR, `ci-ok` verte, merge, déploiement, preuve runtime, `git revert`
   s'il échoue. Cela vaut pour les apps **et** pour la plateforme (`platform/` hors noyau, `tools/appgen`, tests,
   golden paths, skills).
2. **Seul le noyau de confiance reste soumis à Paul** : ce qui définit le pouvoir des agents eux-mêmes.
   - CI et protection du dépôt : `.github/`, `tools/apply-branch-protection.sh` ;
   - mandat, règles et décisions : `missions/`, `AGENTS.md`, `CLAUDE.md`, `.claude/`, `docs/adr/` ;
   - droits des agents et frontière GitOps : `platform/authz/`, `platform/cluster-agent/`, `platform/install/argocd/`,
     `argo_guard` et ses tests ;
   - admission qui borne les cellules (VAP) : `platform/policies/` et ses tests ;
   - contrôle compensatoire et classes d'autonomie : `tools/k3d/`, `tests/k3d/`, `tests/gitops-k3d/`,
     `tests/argo-escalation/`, `.agents/skills/platform-guardrails/` ;
   - identité générée par la plateforme : `platform/identity/` (ADR-0007) ;
   - sécurité amont : `security/`, bundle et ses tests.
3. **MANDAT (Paul seul)** reste réservé à ce qu'une PR ne peut pas faire : créer une identité, une clé ou un jeton ;
   un coût hors Always Free ; une suppression de données sans restauration prouvée ; un premier accès réseau
   externe (Cloudflare, DNS) tant qu'il n'est pas déclaré par Crossplane (ADR-0009).
4. **Contrôle compensatoire** : une PR qui touche `platform/` doit avoir la CI k3d verte (suites VAP, cellules,
   GitOps). Une régression détectée en runtime déclenche un `git revert` autonome.
5. **Un agent ne peut jamais élargir ses propres droits** : c'est l'invariant qui rend le reste acceptable.

## Conséquences
- `.github/CODEOWNERS`, `platform-guardrails` et `docs/AGENT-PR-MODEL.md` sont alignés sur ce noyau (même PR).
- La CI devient la vraie frontière : elle doit être solide (k3d en CI, PR #36) et rapide.
- Risque accepté : un agent peut dégrader une politique Kyverno ou un type de composant hors noyau. Compensé par
  les VAP (noyau), la CI k3d et le revert.

## Alternatives écartées
- **Garder la revue sur `platform/`** : sécurité forte, autonomie faible ; contraire à la priorité de Paul.
- **Aucun noyau** : un agent pourrait se donner des droits (authz, Argo, CI) ; perte du seul invariant indispensable.

## Vérification
- Test CI : la liste du noyau dans `CODEOWNERS` est égale à celle de cet ADR (test à écrire).
- Indicateur : délai médian issue → merge pour une PR hors noyau ; part des PR fusionnées sans humain.

## Références
`.github/CODEOWNERS`, `.agents/skills/platform-guardrails/SKILL.md`, `docs/AGENT-PR-MODEL.md`, `docs/GITOPS-TRUST-BOUNDARY.md`.
