#!/usr/bin/env bash
# Assistant des gestes humains (T-325, ADR-0013/0021) : une séance par étape, générée depuis les tickets du backlog
# qui sont en classe MANDAT ou en `model: human`. Le geste est fait par Paul ; ce script ne crée aucun accès,
# n'écrit rien dans le cluster ni sur GitHub, ne lit aucune valeur de secret (platform-guardrails §2).
# Sous-commandes :
#   list       [--stage S0]   -> une ligne par geste : ordre, ticket, durée estimée (min)
#   generate   [--stage S0] [--out FICHIER] [--budget 30] [--strict]
#                             -> séance en Markdown (stdout, ou FICHIER) ; déterministe, hors ligne.
#                                --strict : code 1 si la durée estimée dépasse le budget.
#   verify-doc [--stage S0] [--doc docs/GESTES-PAUL.md]
#                             -> code 1 si le document n'est pas à jour avec les tickets.
#   check      [--stage S0] [--log FICHIER]
#                             -> sondes en lecture seule, une ligne « horodatage | ticket | statut | détail » par geste.
#   seance     [--stage S0] [--log FICHIER]
#                             -> interactif : montre le geste, attend la réponse de Paul, puis relit l'effet.
# Statuts : PASS (effet relu), FAIL (effet absent ou geste refusé), NOT_TESTED (aucune sonde, sonde impossible,
# ou geste déclaré sans preuve). Une déclaration de Paul seule n'est jamais PASS.
# Garde : une sortie qui contiendrait un motif de secret est refusée (code 3), sans afficher la valeur.
# Variables : GESTES_REPO (owner/repo, sinon déduit de remote.origin.url), GESTES_ORG (sinon owner du dépôt),
#   GESTES_NOW (horodatage fixe, tests), GESTES_FIXTURES (dossier de fixtures : aucune commande réseau, tests).
# Durée : « Durée : N min » ou « environ N minutes » dans le ticket ; sinon 3 min par ticket (convention).
# Art antérieur : mattpocock/skills « wizard » (plugin mattpocock-skills:wizard) : idée seule (étapes numérotées,
#   confirmation à chaque étape, URL avant la valeur), aucun code copié, licence non vérifiée ; pas d'implémentation
#   publique équivalente trouvée pour « séance générée depuis des tickets MANDAT » (voir PR).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
DEFAULT_MIN=3

die() { echo "gestes: $*" >&2; exit 2; }

now() { echo "${GESTES_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"; }

# --------------------------------------------------------------------------- lecture des tickets

fm_get() { # fichier clé -> valeur de l'en-tête (sans commentaire ni guillemets)
  awk -v k="$2" '
    NR == 1 && $0 == "---" { inh = 1; next }
    inh && $0 == "---" { exit }
    inh { i = index($0, ":"); if (i && substr($0, 1, i - 1) == k) {
      v = substr($0, i + 1); sub(/[ \t]+#.*$/, "", v); gsub(/^[ \t"]+|[ \t"]+$/, "", v); print v; exit } }
  ' "$1"
}

section() { # fichier titre -> corps de « ## titre »
  awk -v t="## $2" '
    $0 == t { on = 1; next }
    /^## / { on = 0 }
    on { print }
  ' "$1"
}

minutes_of() { # fichier -> durée estimée
  local n
  n="$({ grep -oiE 'Durée : [0-9]+ min|environ [0-9]+ min' "$1" || true; } | head -1 | grep -oE '[0-9]+' || true)"
  echo "${n:-$DEFAULT_MIN}"
}

BACKLOG="$ROOT/backlog"
STAGE=S0
declare -A FILE TITLE CLASS DEPS MIN
ORDER=() LATER=()

load() { # remplit FILE/TITLE/… pour les gestes de l'étape ; ORDER (séance) et LATER (hors séance)
  local f id st cl md sel=()
  FILE=() TITLE=() CLASS=() DEPS=() MIN=()
  ORDER=() LATER=()
  [ -d "$BACKLOG" ] || die "dossier backlog absent : $BACKLOG"
  for f in "$BACKLOG"/T-*.md; do
    [ -f "$f" ] || continue
    [ "$(fm_get "$f" stage)" = "$STAGE" ] || continue
    st="$(fm_get "$f" status)"
    case "$st" in todo | in-progress | blocked) ;; *) continue ;; esac
    cl="$(fm_get "$f" class)"
    md="$(fm_get "$f" model)"
    case "$cl" in *MANDAT*) ;; *) [ "$md" = human ] || continue ;; esac
    id="$(fm_get "$f" id)"
    [ -n "$id" ] || die "id absent : $f"
    FILE[$id]="$f"
    TITLE[$id]="$(fm_get "$f" title)"
    CLASS[$id]="$cl"
    DEPS[$id]="$(fm_get "$f" depends_on | tr -d '[]' | tr ',' ' ')"
    MIN[$id]="$(minutes_of "$f")"
    if grep -qi 'hors chemin critique' "$f"; then LATER+=("$id"); else sel+=("$id"); fi
  done
  # tri topologique parmi la séance (dépendances hors séance ignorées), égalité par identifiant
  local pending=("${sel[@]}") pick d ok rest
  while [ "${#pending[@]}" -gt 0 ]; do
    pick=""
    for id in $(printf '%s\n' "${pending[@]}" | sort); do
      ok=1
      for d in ${DEPS[$id]}; do
        if [[ " ${pending[*]} " == *" $d "* ]]; then ok=0; fi
      done
      if [ "$ok" = 1 ]; then pick="$id"; break; fi
    done
    [ -n "$pick" ] || die "cycle de dépendances entre gestes : ${pending[*]}"
    ORDER+=("$pick")
    rest=()
    for id in "${pending[@]}"; do [ "$id" = "$pick" ] || rest+=("$id"); done
    pending=("${rest[@]+"${rest[@]}"}")
  done
}

total_min() { local t=0 id; for id in "${ORDER[@]+"${ORDER[@]}"}"; do t=$((t + MIN[$id])); done; echo "$t"; }

# --------------------------------------------------------------------------- sondes en lecture seule

REPO="${GESTES_REPO:-}"
repo_slug() {
  if [ -z "$REPO" ]; then
    REPO="$(git -C "$ROOT" config --get remote.origin.url 2>/dev/null | sed -E 's#^(https://[^/]+/|git@[^:]+:)##; s#\.git$##' || true)"
  fi
  echo "$REPO"
}

fx() { [ -n "${GESTES_FIXTURES:-}" ]; }

probe_desc() {
  case "$1" in
    T-305) echo "git ls-remote --tags origin core-baseline (objet de tag annoté présent)" ;;
    T-431) echo "tools/github/apply.sh --check dev (lecture API, sans jeton affiché)" ;;
    T-433) echo "gh api repos/<dépôt>/rulesets (un ruleset de cible tag existe)" ;;
    T-434) echo "gh api orgs/<org> : 2FA exigée, permission de base none, création de dépôts coupée" ;;
    *) echo "aucune sonde : le geste ne sera jamais PASS sans preuve ajoutée" ;;
  esac
}

probe() { # id -> « STATUT|détail » ; lecture seule, jamais de corps de réponse
  local id="$1" out rc slug org
  case "$id" in
    T-305)
      if fx; then out="$(cat "$GESTES_FIXTURES/tag-core-baseline" 2>/dev/null || true)"; rc=0
      else out="$(timeout 20 git -C "$ROOT" ls-remote --tags origin core-baseline 'core-baseline^{}' 2>/dev/null)" && rc=0 || rc=$?; fi
      [ "$rc" = 0 ] || { echo "NOT_TESTED|lecture du dépôt distant impossible"; return; }
      if grep -q 'refs/tags/core-baseline^{}' <<<"$out"; then echo "PASS|tag annoté présent (signature non vérifiée)"
      elif grep -q 'refs/tags/core-baseline' <<<"$out"; then echo "FAIL|tag léger, non annoté"
      else echo "FAIL|tag core-baseline absent"; fi ;;
    T-431)
      if fx; then
        rc="$(cat "$GESTES_FIXTURES/apply-check.rc" 2>/dev/null || echo 3)"
      else
        [ -f "$ROOT/.github/settings/repo.json" ] || { echo "NOT_TESTED|T-431 non livré (.github/settings/repo.json absent)"; return; }
        slug="$(repo_slug)"
        "$ROOT/tools/github/apply.sh" --check dev "$slug" >/dev/null 2>&1 && rc=0 || rc=$?
      fi
      case "$rc" in 0) echo "PASS|--check dev conforme" ;; 1) echo "FAIL|--check dev diffère" ;; *) echo "NOT_TESTED|--check non comparable" ;; esac ;;
    T-433)
      if fx; then out="$(cat "$GESTES_FIXTURES/rulesets.json" 2>/dev/null || true)"; rc=0
      else slug="$(repo_slug)"; out="$(timeout 20 gh api "repos/$slug/rulesets" 2>/dev/null)" && rc=0 || rc=$?; fi
      [ "$rc" = 0 ] && [ -n "$out" ] || { echo "NOT_TESTED|lecture des rulesets impossible"; return; }
      if [ "$(jq '[.[] | select(.target == "tag")] | length' <<<"$out" 2>/dev/null || echo err)" = err ]; then echo "NOT_TESTED|réponse illisible"
      elif [ "$(jq '[.[] | select(.target == "tag")] | length' <<<"$out")" -ge 1 ]; then echo "PASS|ruleset de cible tag présent (contenu non comparé)"
      else echo "FAIL|aucun ruleset de cible tag"; fi ;;
    T-434)
      if fx; then out="$(cat "$GESTES_FIXTURES/org.json" 2>/dev/null || true)"; rc=0
      else
        slug="$(repo_slug)"; org="${GESTES_ORG:-${slug%%/*}}"
        out="$(timeout 20 gh api "orgs/$org" 2>/dev/null)" && rc=0 || rc=$?
      fi
      [ "$rc" = 0 ] && [ -n "$out" ] || { echo "NOT_TESTED|lecture de l'organisation impossible"; return; }
      if [ "$(jq -r 'if .two_factor_requirement_enabled == null then "null" else "set" end' <<<"$out" 2>/dev/null || echo null)" = null ]; then
        echo "NOT_TESTED|champs réservés aux propriétaires (droit insuffisant)"; return
      fi
      if jq -e '.two_factor_requirement_enabled == true and .default_repository_permission == "none" and .members_can_create_repositories == false' <<<"$out" >/dev/null 2>&1
      then echo "PASS|2FA exigée, permission de base none, création de dépôts coupée"
      else echo "FAIL|un des trois réglages diffère (2FA, permission de base, création de dépôts)"; fi ;;
    *) echo "NOT_TESTED|aucune sonde de lecture définie" ;;
  esac
}

# --------------------------------------------------------------------------- génération du document

guard() { # lit stdin ; code 3 si un motif de secret apparaît, sans l'afficher
  local text pat
  text="$(cat)"
  for pat in 'ghp_[A-Za-z0-9]{20,}' 'github_pat_[A-Za-z0-9_]{20,}' 'gh[osu]_[A-Za-z0-9]{20,}' 'sk-[A-Za-z0-9_-]{20,}' \
    'AKIA[0-9A-Z]{16}' '-----BEGIN [A-Z ]*PRIVATE KEY' 'xox[abprs]-[A-Za-z0-9-]{10,}' 'eyJ[A-Za-z0-9_-]{20,}\.'; do
    if grep -qE -- "$pat" <<<"$text"; then
      echo "gestes: motif de secret détecté (garde fermée), sortie refusée" >&2
      return 3
    fi
  done
  printf '%s\n' "$text"
}

render_one() { # n id
  local n="$1" id="$2" f="${FILE[$2]}" line
  printf '### %s. %s : %s\n\n' "$n" "$id" "${TITLE[$id]}"
  printf -- '- Durée estimée : %s min\n- Classe : %s\n' "${MIN[$id]}" "${CLASS[$id]}"
  [ -z "${DEPS[$id]// /}" ] || printf -- '- Dépend de : %s\n' "$(tr -s ' ' <<<"${DEPS[$id]}" | sed 's/^ //; s/ $//; s/ /, /g')"
  printf -- '- Intention : %s\n' "$(section "$f" Intention | sed '/^[[:space:]]*$/d' | tr '\n' ' ' | sed 's/ *$//')"
  printf -- '- Vérification en lecture seule : %s\n' "$(probe_desc "$id")"
  local todo reste links
  todo="$(section "$f" "Critères de fin" | grep -E '^- \[ \]' || true)"
  if [ -n "$todo" ]; then printf '\nÀ obtenir (critères non cochés du ticket) :\n\n%s\n' "$todo"; fi
  reste="$(section "$f" Notes | grep -E '^Reste' || true)"
  if [ -n "$reste" ]; then printf '\n%s\n' "$reste"; fi
  links="$({ grep -oE 'https?://[^ )>"]+' "$f" || true; } | sort -u)"
  if [ -n "$links" ]; then printf '\nLiens :\n\n'; while read -r line; do printf -- '- %s\n' "$line"; done <<<"$links"; fi
  printf '\n'
}

render() { # budget
  local budget="$1" total n=0 id verdict
  total="$(total_min)"
  if [ "$total" -le "$budget" ]; then verdict="dans le budget"; else verdict="DÉPASSE le budget"; fi
  printf '<!-- Généré par tools/factory/gestes.sh (T-325) : ne pas éditer à la main. '
  printf 'Régénérer : tools/factory/gestes.sh generate --stage %s --out docs/GESTES-PAUL.md -->\n' "$STAGE"
  printf '# Gestes de Paul : séance %s\n\n' "$STAGE"
  printf 'Conclusion : %s gestes, %s min estimées pour un budget de %s min (%s).\n\n' "${#ORDER[@]}" "$total" "$budget" "$verdict"
  printf 'Règles : Paul fait chaque geste. Aucune valeur de secret dans ce document ni dans la sortie du script. '
  printf '%s' "Le script relit l'effet en lecture seule (\`tools/factory/gestes.sh check\`, ou \`seance\` pour la séance guidée) "
  printf '%s' "et marque chaque geste \`PASS\`, \`FAIL\` ou \`NOT_TESTED\` avec un horodatage. "
  printf 'La durée est une estimation : 3 min par ticket sauf mention « environ N minutes » ou « Durée : N min » dans le ticket.\n\n'
  printf '%s\n\n' "## Séance, dans l'ordre"
  if [ "${#ORDER[@]}" -eq 0 ]; then printf '%s\n\n' 'Aucun geste MANDAT ou human ouvert pour cette étape.'; fi
  for id in "${ORDER[@]+"${ORDER[@]}"}"; do n=$((n + 1)); render_one "$n" "$id"; done
  printf '## Hors séance (geste de Paul, moment de son choix, hors chemin critique)\n\n'
  if [ "${#LATER[@]}" -eq 0 ]; then printf 'Aucun.\n'; fi
  for id in "${LATER[@]+"${LATER[@]}"}"; do printf -- '- %s : %s (%s min, non comptées dans le total)\n' "$id" "${TITLE[$id]}" "${MIN[$id]}"; done
}

cmd_generate() {
  local out="" budget=30 strict=0 text rc=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --out) shift; out="${1:?--out exige un fichier}" ;;
      --budget) shift; budget="${1:?--budget exige un nombre}" ;;
      --strict) strict=1 ;;
      *) die "option inconnue : $1" ;;
    esac
    shift
  done
  [[ "$budget" =~ ^[0-9]+$ ]] || die "budget invalide : $budget"
  load
  text="$(render "$budget" | guard)" || return 3
  if [ -n "$out" ]; then printf '%s\n' "$text" >"$out"; else printf '%s\n' "$text"; fi
  if [ "$strict" = 1 ] && [ "$(total_min)" -gt "$budget" ]; then rc=1; fi
  return "$rc"
}

cmd_list() {
  local n=0 id
  load
  for id in "${ORDER[@]+"${ORDER[@]}"}"; do n=$((n + 1)); printf '%s\t%s\t%s\n' "$n" "$id" "${MIN[$id]}"; done
}

cmd_verify_doc() {
  local doc="$ROOT/docs/GESTES-PAUL.md" cur
  while [ $# -gt 0 ]; do
    case "$1" in
      --doc) shift; doc="${1:?--doc exige un fichier}" ;;
      *) die "option inconnue : $1" ;;
    esac
    shift
  done
  [ -f "$doc" ] || { echo "gestes: document absent : $doc" >&2; return 1; }
  load
  cur="$(render 30 | guard)" || return 3
  if [ "$cur" = "$(cat "$doc")" ]; then echo "PASS : $doc à jour"; else echo "FAIL : $doc périmé, régénérer" >&2; return 1; fi
}

# --------------------------------------------------------------------------- check et séance

LOG=""
record() { # id statut détail
  local line
  line="$(now) | $1 | $2 | $3"
  echo "$line"
  if [ -n "$LOG" ]; then echo "$line" >>"$LOG"; fi
  case "$2" in FAIL) FAILS=$((FAILS + 1)) ;; esac
}

parse_run_opts() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --log) shift; LOG="${1:?--log exige un fichier}" ;;
      *) die "option inconnue : $1" ;;
    esac
    shift
  done
}

FAILS=0
cmd_check() {
  local id r
  parse_run_opts "$@"
  load
  for id in "${ORDER[@]+"${ORDER[@]}"}"; do r="$(probe "$id")"; record "$id" "${r%%|*}" "${r#*|}"; done
  [ "$FAILS" -eq 0 ]
}

cmd_seance() {
  local id r st n=0 total ans todo
  parse_run_opts "$@"
  load
  total="${#ORDER[@]}"
  echo "Séance $STAGE : $total gestes, $(total_min) min estimées. Aucune valeur de secret ne doit être saisie ici."
  for id in "${ORDER[@]+"${ORDER[@]}"}"; do
    n=$((n + 1))
    echo
    echo "[$n/$total] $id : ${TITLE[$id]} (${MIN[$id]} min)"
    r="$(probe "$id")"; st="${r%%|*}"
    if [ "$st" = PASS ]; then record "$id" PASS "${r#*|} (déjà fait)"; continue; fi
    todo="$(section "${FILE[$id]}" "Critères de fin" | grep -E '^- \[ \]' || true)"
    [ -z "$todo" ] || printf '%s\n' "$todo"
    echo "Vérification : $(probe_desc "$id")"
    ans=""
    printf 'Fait ? [o]ui / [n]on / [s]auter : '
    read -r ans || ans=EOF
    case "$ans" in
      o | O | oui)
        r="$(probe "$id")"; st="${r%%|*}"
        if [ "$st" = NOT_TESTED ]; then record "$id" NOT_TESTED "déclaré fait par Paul, non vérifié : ${r#*|}"
        else record "$id" "$st" "${r#*|}"; fi ;;
      n | N | non) record "$id" FAIL "geste déclaré non fait" ;;
      EOF) record "$id" NOT_TESTED "aucune réponse" ;;
      *) record "$id" NOT_TESTED "geste sauté" ;;
    esac
  done
  echo
  [ "$FAILS" -eq 0 ]
}

# --------------------------------------------------------------------------- entrée

[ $# -ge 1 ] || die "usage : gestes.sh list|generate|verify-doc|check|seance [--stage S0] [--backlog DIR] [options]"
CMD="$1"; shift
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --stage) shift; STAGE="${1:?--stage exige une étape}" ;;
    --backlog) shift; BACKLOG="${1:?--backlog exige un dossier}" ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done
case "$CMD" in
  list) cmd_list "${ARGS[@]+"${ARGS[@]}"}" ;;
  generate) cmd_generate "${ARGS[@]+"${ARGS[@]}"}" ;;
  verify-doc) cmd_verify_doc "${ARGS[@]+"${ARGS[@]}"}" ;;
  check) cmd_check "${ARGS[@]+"${ARGS[@]}"}" ;;
  seance) cmd_seance "${ARGS[@]+"${ARGS[@]}"}" ;;
  *) die "sous-commande inconnue : $CMD" ;;
esac
