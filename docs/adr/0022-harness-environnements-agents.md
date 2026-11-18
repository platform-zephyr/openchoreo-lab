# ADR-0022 — Harness et environnements de dev des agents
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0004, ADR-0011, ADR-0012, ADR-0021, ADR-0023 ; `docs/review/CONSENSUS-2.md` (arbitrages 4 et 6)

## Contexte
- Des agents Claude Code (sessions cloud, runners GitHub) développent la plateforme ; le dépôt est public.
- Le dépôt n'a ni réglage `.claude/`, ni hook, ni sous-agent : tout repose sur du texte (AGENTS.md).
- Le homelab est x86_64 ; OKE et les runners GitHub ARM sont arm64 ; la VM cloud Claude Code est x86_64.
- homelab-infra (privé) a déjà des runners ARC sur le cluster local.

## Décision
1. **Trois niveaux d'environnement** : N0 statique (sans cluster, partout), N1 k3d jetable en CI (runner hébergé), N2 cluster
   lab du homelab (atteint par GitOps, lu par sondes publiées ou par T-006). Un PASS cite son niveau ; k3d ≠ homelab ≠ OKE.
2. Une commande unique `tools/dev/check` est la definition of done technique : même code dans le hook Stop, la CI, le
   conteneur et l'environnement cloud (T-332).
3. **Trois couches de garde** : hooks locaux (retour rapide), CI (preuve), CODEOWNERS et ruleset (frontière). Une règle sans
   exception est un hook ou une règle `deny`, jamais une phrase d'AGENTS.md. `.claude/` et le workflow d'agent sont noyau.
4. Les agents n'ont aucun accès kubectl, Doppler ou OCI. Ils lisent la plateforme du homelab en lecture seule (T-006).
5. **Runners** : runners GitHub hébergés par défaut. Des runners ARC du homelab ne sont admis que pour des workflows
   déclenchés par `push` ou `workflow_dispatch` d'un mainteneur, **jamais sur une PR de fork** ; scale set dédié, JIT, non
   privilégié, sans secret (T-343, arbitrage 6).
6. Un ticket est `done` seulement avec une preuve générée par `done.py` à partir des critères (T-337).
7. Un périmètre de fichiers par ticket, vérifié avant le lancement (chevauchement refusé) et pendant l'exécution (hook).
8. Le **banc de tâches de développement** (T-346) est différé après la porte (règle d'usine, ADR-0021) ; d'ici là, le pilote
   fournit les mesures.
9. Sécurité de dev (ADR-0002 amendé) : les outils étroits du workflow d'agent et le mode de permission sont vérifiés en FINAL
   (T-401) ; la garde de fuite (T-303) est active dès S0.

## Conséquences
- Coûts : écrire hooks et tests de hooks, minutes CI, un cluster lab sur le homelab.
- Les hooks ne tournent pas dans tous les contextes cloud : la CI reste la preuve.

## Alternatives écartées
- Tout en texte (AGENTS.md) : suivi non garanti.
- Runners homelab sur toutes les PR : exécution de code de fork sur le LAN.
- k3d sur le homelab : Docker privilégié (PSA). Hooks de type `prompt` : non déterministes.

## Vérification
- `tests/hooks/` (entrées → sorties) ; `check` identique dans les 4 contextes ; aucun `kubectl` autorisé dans
  `.claude/settings.json` (T-330).
- Garde CI : aucun `runs-on` homelab sur `pull_request` ou `pull_request_target` ; essai daté avec une PR de fork (T-343).

## Références
`docs/research/AGENT-HARNESS.md` §3-§5, `backlog/proposals/harness.yaml`, `docs/review/CONSENSUS-2.md`.
