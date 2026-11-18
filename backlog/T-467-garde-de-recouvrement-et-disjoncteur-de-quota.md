---
id: T-467
title: "Garde de recouvrement des périmètres et disjoncteur de quota Max pour le planificateur de l'usine"
status: in-progress
phase: P0
adr: [0017, 0021, 0023]
depends_on: [T-311]
class: REVUE
velocity: true
lane: factory
stage: S0
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-467 — Garde de recouvrement des périmètres et disjoncteur de quota Max pour le planificateur de l'usine

## Intention
Lever deux blocages du passage N = 3 → 6 → 10 (audit du premier run multi-issues, 2026-11-18, Q4 et Q5 n° 2 et 4) :

1. **Recouvrement.** Deux agents d'un même lot ne doivent jamais écrire au même endroit. La file de fusion refuse une PR
   en conflit et l'agent, déjà terminé, ne rebase pas. Le planificateur refuse donc un lot dont deux tickets ont des
   périmètres qui se recoupent, fichiers chauds compris (`ci.yaml`, `CODEOWNERS`, `tools/dev/check`, `ci-map.tsv`,
   `AGENTS.md`).
2. **Quota.** Un seul `CLAUDE_CODE_OAUTH_TOKEN` (abonnement Max) sert tous les jobs : la fenêtre de 5 h est commune.
   Une session qui se termine sur une limite d'usage ouvre le disjoncteur `factory/LIMIT.json` ; tant qu'il est ouvert,
   le planificateur n'émet plus de matrice. La reprise reste manuelle (T-326).

## Périmètre de fichiers
tools/factory/, tests/factory/, docs/AGENT-RUNNERS.md, .github/workflows/claude-agent.yml

## Critères de fin
- [x] `tools/factory/overlap.py` refuse (code 4) deux tickets dont les périmètres se recoupent, fichiers chauds compris ;
  code 3 pour une référence sans ticket ou sans périmètre exploitable dans un lot de plus d'un ticket — STATIC PASS
  2026-11-18 : `tests/factory/overlap-test.sh` (15 tests, dont 10 cas négatifs)
- [x] `tools/factory/ledger.py detect` ouvre le disjoncteur sur les formes officielles du message de limite
  (session, weekly, Opus, Sonnet), ignore les throttles (429, 529, « Server is temporarily limiting requests ») et le
  texte d'agent qui cite le message ; `ledger.py gate` écrit `limited=true|false` pour le planificateur — STATIC PASS
  2026-11-18 : `tests/factory/ledger-test.sh` (14 tests)
- [x] `docs/AGENT-RUNNERS.md` décrit la garde, le disjoncteur, le câblage et la reprise manuelle
- [x] câblage dans `.github/workflows/claude-agent.yml` selon la section « Câblage à faire » (jobs `plan`, `dev`,
  `report`, `breaker`) ; une issue d'un lot refusé reçoit un commentaire, aucun job `dev` — STATIC PASS 2026-11-18 :
  `tests/factory/workflow-guard-test.sh` (12 tests : structure, rejeu des scripts `run:` avec un `gh` factice, 7
  mutations du workflow toutes détectées), `tests/factory/run-ticket-test.sh` (66 PASS), actionlint propre
- [ ] preuve RUNTIME datée : un dispatch de deux issues en recouvrement s'arrête au job `plan` sans job `dev` ; un
  `factory/LIMIT.json` sur `main` empêche la matrice ; un job frère s'arrête après la limite d'un autre job du même run

## Câblage à faire
À insérer dans `.github/workflows/claude-agent.yml` (une PR, périmètre de T-313 ou suite de ce ticket). Les SHA des
actions sont ceux déjà épinglés dans le fichier. `python3` est celui de l'image `ubuntu-24.04-arm` (3.12, `zoneinfo`
disponible) : aucune dépendance à installer.

### Job `plan`
1. Ajouter aux `outputs` : `limited: ${{ steps.limit.outputs.limited }}`.
2. Après l'étape `Kill-switch factory/PAUSE`, insérer :
   ```yaml
      - name: Disjoncteur de quota factory/LIMIT.json (T-467)
        id: limit
        env:
          MODEL: ${{ inputs.model }}
        run: python3 -I tools/factory/ledger.py gate --state factory/LIMIT.json --model "$MODEL" || [ "$?" -eq 11 ]
      - name: Garde de recouvrement des périmètres (T-467)
        if: steps.pause.outputs.paused == 'false' && steps.limit.outputs.limited == 'false'
        env:
          TICKETS: ${{ inputs.tickets }}
        run: python3 -I tools/factory/overlap.py >/dev/null
   ```
   Un refus (code 3 ou 4) fait échouer `plan` ; `dev` ne démarre pas. Les motifs sont sur stderr, donc dans le journal.
3. Étape `Matrice des issues` : `if: steps.pause.outputs.paused == 'false' && steps.limit.outputs.limited == 'false'`.

### Jobs `dev`
1. Condition du job : `if: needs.plan.outputs.paused == 'false' && needs.plan.outputs.limited == 'false'`.
2. Permissions du job : ajouter `actions: read` (lecture des artefacts des jobs frères).
3. Après l'étape `Kill-switch factory/PAUSE (re-controle sur origin/main)`, insérer le re-contrôle (main et jobs frères
   du même run, qui attendent derrière `max-parallel`) :
   ```yaml
      - name: Disjoncteur de quota (re-controle origin/main et jobs freres, T-467)
        id: limit
        if: steps.pause.outputs.paused == 'false'
        env:
          GH_TOKEN: ${{ github.token }}
          GH_REPO: ${{ github.repository }}
          MODEL: ${{ inputs.model }}
        run: |
          limited=false
          git show origin/main:factory/LIMIT.json >limit-main.json 2>/dev/null || rm -f limit-main.json
          gh run download "$GITHUB_RUN_ID" -p 'factory-limit-*' -D limit-run 2>/dev/null || true
          for f in limit-main.json limit-run/*/LIMIT.json; do
            [ -f "$f" ] || continue
            python3 -I tools/factory/ledger.py check --state "$f" --model "$MODEL" || limited=true
          done
          echo "limited=${limited}" >>"$GITHUB_OUTPUT"
   ```
4. Ajouter `&& steps.limit.outputs.limited == 'false'` au `if:` des étapes `setup-python`, `Outils de test statique`,
   `Identite git`, `Jeton de l'App`, `Ticket et périmètre` et `claude`.
5. Après l'étape `claude` (avant `Branche de l'agent`), insérer la détection et la publication pour les jobs frères :
   ```yaml
      - name: Detection de la limite d'usage Max (T-467)
        id: quota
        if: always() && steps.claude.outputs.execution_file != ''
        env:
          EXEC_FILE: ${{ steps.claude.outputs.execution_file }}
          ISSUE: ${{ matrix.issue }}
          MODEL: ${{ inputs.model }}
        run: |
          rc=0
          python3 -I tools/factory/ledger.py detect --execution-file "$EXEC_FILE" --state limit-out/LIMIT.json \
            --issue "$ISSUE" --model "$MODEL" || rc=$?
          if [ "$rc" -eq 11 ]; then echo "tripped=true" >>"$GITHUB_OUTPUT"; echo "::error::limite d'usage Max : disjoncteur ouvert"
          elif [ "$rc" -eq 0 ]; then echo "tripped=false" >>"$GITHUB_OUTPUT"; else exit "$rc"; fi
      - name: Disjoncteur pour les jobs freres (artefact)
        if: always() && steps.quota.outputs.tripped == 'true'
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: factory-limit-${{ matrix.issue }}
          path: limit-out/LIMIT.json
   ```
   Un nom d'artefact par issue : deux jobs qui touchent la limite en même temps n'entrent pas en conflit.

### Persistance entre deux runs (job final `breaker`)
Nouveau job `breaker` (`needs: dev`, `if: always() && needs.plan.outputs.paused == 'false'`, `permissions: contents:
read, actions: read`) : `gh run download "$GITHUB_RUN_ID" -p 'factory-limit-*'` ; s'il y a au moins un fichier, il
ouvre avec le jeton de l'App une PR `claude/factory-limit-<run_id>` qui ajoute `factory/LIMIT.json` (le plus récent),
commit `noreply@anthropic.com` avec les trailers `Ticket: T-467`, `Model`, `Effort`, `Claude-Session: <URL du run>`,
puis arme l'auto-merge (mode dev). Tant que cette PR n'est pas fusionnée, un nouveau dispatch n'est pas bloqué : le
dire dans le résumé du run. Reprise : Paul fusionne une PR qui supprime `factory/LIMIT.json`
(`ledger.py reset --state factory/LIMIT.json`), au reset annoncé (`resume_at`).

## Notes
Câblage livré (2026-11-18, niveau STATIC). Écarts avec « Câblage à faire », choisis ici :
- `plan` : l'étape de garde publie `overlap=true|false` (au lieu de `>/dev/null`) ; une étape suivante commente chaque
  issue numérique du lot refusé (jeton du workflow, `issues: write` sur `plan`), puis sort en code 4 : `plan` rouge,
  aucun job `dev`, ni `report` ni `breaker`. Code 2 (usage) : `plan` rouge sans commentaire.
- `dev` : les artefacts des jobs frères sont lus par `actions/download-artifact` (épinglé, déjà utilisé par `report`)
  au lieu de `gh run download` ; fichiers dans `$RUNNER_TEMP`, hors de l'espace de travail (l'agent ne peut pas les
  committer). Les deux dispositions de l'action sont lues (`path/LIMIT.json` pour un seul artefact, v5+, et
  `path/<nom>/LIMIT.json`). Disjoncteur ouvert : étape « Arret par le disjoncteur » rouge et toutes les étapes `always()`
  suivantes (branche, trailers, mission-result, commentaire de PR, archive, Verdict) sautées ; `report` affiche FAIL
  sans mission-result pour cette issue (motif dédié `usage_limit` : suite, schéma hors périmètre).
- `report` et `breaker` exigent `limited == 'false'` et `overlap == 'false'` au plan.
- `breaker` : branche `claude/factory-limit-<run_id>-<run_attempt>` (une relance du run ne réutilise pas la branche) ;
  le disjoncteur le plus récent par `tripped_at` ; sans jeton d'App ni `FACTORY_GH_TOKEN`, job rouge avec consigne.
  Deux runs qui touchent la limite en même temps ouvrent deux PR : la seconde entre en conflit après la fusion de la
  première (sans effet : le disjoncteur est déjà ouvert).
NOT_PROVEN : `actions/download-artifact` voit les artefacts d'un job frère pendant que le run est en cours (attendu
avec les artefacts v4+, non observé ici).

Implémentations publiques consultées (câblage) :
- https://github.com/actions/download-artifact/blob/3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c/README.md | MIT | adopté |
  téléchargement par motif depuis le run courant ; un seul artefact trouvé est extrait dans `path/` (v5+).
- https://github.com/actions/upload-artifact/blob/cf430e030ddbb5b0abf93d22962f4752f3646cd9/README.md | MIT | adopté |
  v4+ : un artefact n'accepte pas d'envois de plusieurs jobs, d'où un nom par issue.

Formes du message de limite : doc officielle https://code.claude.com/docs/en/errors, section « Usage limits », lue le
2026-11-18 (`You've hit your session limit · resets 3:45pm`, `You've hit your weekly limit · resets Mon 12:00am`,
`You've hit your Opus limit`, `You've hit your Sonnet limit`). La doc dit qu'un throttle serveur n'est pas une limite
d'abonnement. En mode `-p`, le message final peut garder `subtype: success` avec `is_error: true`
(anthropics/claude-code#79500, issue amont, pas la doc) : la détection exige `is_error` et lit le champ `result`.
L'heure de reset est interprétée dans le fuseau entre parenthèses s'il y en a un, sinon en UTC (fuseau des runners).
NOT_PROVEN : la forme exacte du message dans un `execution_file` réel de `claude-code-action` (aucune limite atteinte
pendant le pilote).

Le schéma `docs/schema/mission-result.v1.json` (hors périmètre) n'a ni `status: LIMIT` ni `failure: usage_limit` :
`detect` écrit donc l'état du disjoncteur à part, sans toucher `mission-result`. Ajouter ces valeurs est une suite.

Constat sur le run réel `44313706955` : `overlap.py --tickets 66,67` refuse le lot (T-460 et T-462 partagent
`tests/dev-factory/`). Les tests `tests/factory/*` ne sont lancés par aucun job CI (`ci.yaml` est un fichier chaud, hors
périmètre) : suite T-475 (étape `factory` de `tools/dev/check`, job `dev-factory`, STATIC PASS 2026-11-18).
