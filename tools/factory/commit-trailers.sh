#!/usr/bin/env bash
# Trailers de commit injectes par un hook git (T-474) : l'agent n'a plus a se souvenir de Ticket, Model, Effort,
# Escalated-from ni Claude-Session. Le controle `run-ticket.sh check-trailers` reste le juge final.
# Sous-commandes :
#   install <repertoire>   -> copie ce script comme hooks prepare-commit-msg et commit-msg dans <repertoire> (hors depot),
#                             ecrit les valeurs dans <repertoire>/trailers.values, retire l'ecriture, puis verifie le hook
#                             sur un commit d'essai dans un depot temporaire. Valeurs lues dans l'environnement du job :
#                             TICKET_ID (T-NNN), MODEL, EFFORT, CLAUDE_SESSION (URL https du run), ESCALATED_FROM
#                             (facultatif). Valeur absente ou invalide : code 2, message explicite, rien d'installe.
# Mode hook (appele par git sous le nom prepare-commit-msg ou commit-msg) :
#   - lit les valeurs dans trailers.values a cote du hook, jamais dans l'environnement (l'agent ne peut pas les changer) ;
#   - refuse (code 1, donc commit annule) si l'e-mail auteur ou committer n'est pas noreply@anthropic.com ;
#   - message vide (hors commentaires) : inchange, git annule le commit comme d'habitude ;
#   - sinon `git interpret-trailers --in-place --no-divider --if-exists replace --if-missing add` : trailer absent
#     ajoute a la fin, dans l'ordre Ticket, Model, Effort, Escalated-from, Claude-Session ; trailer deja present retire
#     puis rajoute a la fin avec la valeur du workflow (aucun doublon, ordre canonique). Les autres trailers
#     (Co-Authored-By...) restent a leur place.
# prepare-commit-msg n'est pas supprime par --no-verify (githooks(5)) ; commit-msg repasse apres l'editeur.
set -euo pipefail

EMAIL="noreply@anthropic.com"
die() { echo "commit-trailers (T-474) : $*" >&2; exit "${2:-2}"; }

# Valeurs acceptees : une ligne, sans caractere de controle, au format attendu.
valid() {
  local key="$1" val="$2"
  case "$key" in
    TICKET_ID) [[ "$val" =~ ^T-[0-9]+$ ]] ;;
    MODEL | ESCALATED_FROM) [[ "$val" =~ ^claude-(haiku|sonnet|opus)-[0-9]+(-[0-9]+)*$ ]] ;;
    EFFORT) [[ "$val" =~ ^(low|medium|high|xhigh|max)$ ]] ;;
    CLAUDE_SESSION) [[ "$val" =~ ^https://[A-Za-z0-9._~:/?#@!\$\&\'()*+,\;=%-]+$ ]] ;;
    *) return 1 ;;
  esac
}

cmd_install() {
  local dir="${1:?repertoire des hooks requis}" key val probe
  for key in TICKET_ID MODEL EFFORT CLAUDE_SESSION; do
    val="${!key:-}"
    [[ -n "$val" ]] || die "variable ${key} absente : hook non installe"
    valid "$key" "$val" || die "variable ${key} invalide ('${val}') : hook non installe"
  done
  if [[ -n "${ESCALATED_FROM:-}" ]]; then
    valid ESCALATED_FROM "$ESCALATED_FROM" || die "variable ESCALATED_FROM invalide ('${ESCALATED_FROM}') : hook non installe"
  fi
  mkdir -p "$dir"
  chmod u+w "$dir"
  {
    echo "TICKET_ID=${TICKET_ID}"
    echo "MODEL=${MODEL}"
    echo "EFFORT=${EFFORT}"
    echo "ESCALATED_FROM=${ESCALATED_FROM:-}"
    echo "CLAUDE_SESSION=${CLAUDE_SESSION}"
  } >"$dir/trailers.values"
  install -m 0555 "${BASH_SOURCE[0]}" "$dir/prepare-commit-msg"
  install -m 0555 "${BASH_SOURCE[0]}" "$dir/commit-msg"
  chmod 0444 "$dir/trailers.values"
  chmod 0555 "$dir"
  # Essai : un commit sans trailer dans un depot temporaire doit ressortir avec les trailers requis.
  probe="$(mktemp -d "${TMPDIR:-/tmp}/commit-trailers-probe.XXXXXX")"
  (
    cd "$probe"
    git init -q
    GIT_AUTHOR_NAME=Claude GIT_AUTHOR_EMAIL="$EMAIL" GIT_COMMITTER_NAME=Claude GIT_COMMITTER_EMAIL="$EMAIL" \
      git -c core.hooksPath="$dir" commit -q --allow-empty -m "essai du hook T-474"
    out="$(git log -1 --format=%B | git interpret-trailers --parse --no-divider)"
    for k in Ticket Model Effort Claude-Session; do
      grep -q "^${k}: ." <<<"$out" || { echo "commit-trailers (T-474) : essai : trailer ${k} absent" >&2; exit 1; }
    done
  ) || { rm -rf "$probe"; die "essai du hook en echec" 1; }
  rm -rf "$probe"
  echo "hook des trailers installe dans ${dir} (${TICKET_ID}, ${MODEL}, ${EFFORT})"
}

# Retire Ticket, Model, Effort, Escalated-from et Claude-Session du dernier paragraphe (hors commentaires `#`) s'il
# n'est fait que de trailers (`Cle: valeur`, lignes de suite indentees) et n'est pas le sujet. Le reste est inchange.
strip_keys() {
  awk '
    BEGIN { split("ticket model effort escalated-from claude-session", a, " "); for (i in a) K[a[i]] = 1 }
    { L[NR] = $0 }
    END {
      e = 0; s = 0
      for (i = NR; i >= 1; i--) {
        if (L[i] ~ /^#/) continue
        if (L[i] ~ /^[[:space:]]*$/) { if (e) break; continue }
        if (!e) e = i
        s = i
      }
      first = 0
      for (i = 1; i <= NR; i++) if (L[i] !~ /^#/ && L[i] !~ /^[[:space:]]*$/) { first = i; break }
      block = (e > 0 && s > first)
      for (i = s; block && i <= e; i++) {
        if (L[i] ~ /^#/ || L[i] ~ /^[[:space:]]+[^[:space:]]/) continue
        if (L[i] !~ /^[A-Za-z0-9-]+:[[:space:]]/) block = 0
      }
      drop = 0
      for (i = 1; i <= NR; i++) {
        if (block && i >= s && i <= e && L[i] !~ /^#/) {
          if (L[i] ~ /^[A-Za-z0-9-]+:/) { k = tolower(substr(L[i], 1, index(L[i], ":") - 1)); drop = (k in K) }
          if (drop) continue
        }
        print L[i]
      }
    }'
}

ident_email() { sed -n 's/^.*<\([^>]*\)>.*$/\1/p' <<<"$1"; }

cmd_hook() {
  local msg="${1:?fichier du message requis}" values key val t m e esc s ident who
  values="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/trailers.values"
  [[ -r "$values" ]] || die "fichier de valeurs absent (${values}) : commit refuse" 1
  t="" m="" e="" esc="" s=""
  while IFS='=' read -r key val; do
    case "$key" in
      TICKET_ID) t="$val" ;; MODEL) m="$val" ;; EFFORT) e="$val" ;; ESCALATED_FROM) esc="$val" ;; CLAUDE_SESSION) s="$val" ;;
    esac
  done <"$values"
  valid TICKET_ID "$t" || die "valeur TICKET_ID absente ou invalide dans ${values} : commit refuse" 1
  valid MODEL "$m" || die "valeur MODEL absente ou invalide dans ${values} : commit refuse" 1
  valid EFFORT "$e" || die "valeur EFFORT absente ou invalide dans ${values} : commit refuse" 1
  valid CLAUDE_SESSION "$s" || die "valeur CLAUDE_SESSION absente ou invalide dans ${values} : commit refuse" 1
  [[ -z "$esc" ]] || valid ESCALATED_FROM "$esc" || die "valeur ESCALATED_FROM invalide dans ${values} : commit refuse" 1

  for who in GIT_AUTHOR_IDENT GIT_COMMITTER_IDENT; do
    ident="$(git var "$who")" || die "identite ${who} illisible : commit refuse" 1
    [[ "$(ident_email "$ident")" == "$EMAIL" ]] || die "e-mail ${who} different de ${EMAIL} : commit refuse" 1
  done

  # Message vide hors commentaires : rien a annoter ; git annule le commit (sauf --allow-empty-message, refuse ensuite
  # par check-trailers).
  [[ -n "$(git stripspace --strip-comments <"$msg")" ]] || exit 0

  # `--if-exists replace` ne retire qu'une occurrence : les exemplaires de ces cles dans le bloc final de trailers sont
  # d'abord retires (comparaison sans casse, comme git), puis rajoutes une fois avec la valeur du workflow.
  local tmp="${msg}.t474"
  strip_keys <"$msg" >"$tmp" && cat "$tmp" >"$msg"
  rm -f "$tmp"
  local args=(--trailer "Ticket: ${t}" --trailer "Model: ${m}" --trailer "Effort: ${e}")
  [[ -z "$esc" ]] || args+=(--trailer "Escalated-from: ${esc}")
  args+=(--trailer "Claude-Session: ${s}")
  git interpret-trailers --in-place --no-divider --where end --if-exists replace --if-missing add "${args[@]}" "$msg"
}

case "$(basename "$0")" in
  prepare-commit-msg | commit-msg) cmd_hook "$@" ;;
  *)
    sub="${1:-}"
    shift || true
    case "$sub" in
      install) cmd_install "$@" ;;
      *) die "usage : commit-trailers.sh install <repertoire>" ;;
    esac
    ;;
esac
