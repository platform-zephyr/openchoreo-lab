---
id: T-412
title: "Vérificateur `tools/dev/prior_art.py`, job CI `prior-art` requis dans `ci-ok`, hook Stop"
status: todo
phase: P0
adr: [0024]
depends_on: [T-411, T-413, T-331, T-332]
class: REVUE
velocity: true
lane: ci
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-412 — Vérificateur `tools/dev/prior_art.py`, job CI `prior-art` requis dans `ci-ok`, hook Stop

## Intention
Vérifier la section de PR sans jugement : permaliens à SHA complet, `gh api repos/<o>/<r>/commits/<sha>` et existence du chemin, licence égale à l'API et dans la liste admise, ≥ 2 requêtes si « Aucune trouvée », exemptions calculées par chemin. Même script dans le hook Stop (exit 2) et dans la CI.

## Périmètre de fichiers
tools/dev/prior_art.py, tests/prior-art/, .github/workflows/ci.yaml, .claude/hooks/

## Critères de fin
- [ ] tests : section absente, URL sur branche mobile, SHA inconnu, licence interdite ou inconnue, licence déclarée ≠ API, exemption par chemin, une seule requête
- [ ] le corps de PR est lu par variable d'environnement, jamais interpolé dans un `run:` (test actionlint)
- [ ] job `prior-art` dans `needs` de `ci-ok` ; essai daté sur 3 PR réelles du pilote
- [ ] appels `gh api` espacés (10 requêtes/min pour la recherche de code, 30 pour la générale) ; échec réseau = NOT_TESTED, pas PASS

## Notes
Proposition QA-2 (backlog/proposals/quality.yaml), intégrée (intégration 5, 2026-11-18). Le hook ne remplace pas la CI (ADR-0022 §3). Lit `pr-body.md` du worktree, ignoré par git.

L'essai sur 3 PR réelles se fait sur les PR du pilote si elles existent, sinon sur 3 PR d'essai.
