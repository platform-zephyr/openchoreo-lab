#!/usr/bin/env bash
# Executant minimal de l'usine (T-313, ADR-0021/0022) : plafonds par modele, arguments claude, controle des trailers,
# compte rendu mission-result.v1. Aucun secret lu, aucun reseau, aucun prompt consigne.
# Sous-commandes :
#   limits <model>                       -> timeout_minutes=N / max_turns=N (Opus 90/150 ; Sonnet, Haiku 45/60)
#   effort <model> <effort>              -> effort valide (Sonnet et Haiku plafonnes a xhigh), sinon code 2
#   claude-args <model> <effort>         -> lignes pour claude_args (--model, --effort, --max-turns)
#   check-trailers <git-range>           -> code 1 si un commit n'a pas noreply@anthropic.com ou un trailer requis
#   result <execution_file> <issue> <model> <effort> [escalated_from] [branch]
#                                        -> JSON mission-result.v1 sur stdout, resume Markdown sur $GITHUB_STEP_SUMMARY
set -euo pipefail

die() { echo "run-ticket: $*" >&2; exit 2; }

cmd_limits() {
  case "${1:-}" in
    claude-opus-5-5) echo "timeout_minutes=90"; echo "max_turns=150" ;;
    claude-sonnet-5-5 | claude-haiku-5-5) echo "timeout_minutes=45"; echo "max_turns=60" ;;
    *) die "modele inconnu : '${1:-}'" ;;
  esac
}

cmd_effort() {
  local model="${1:-}" effort="${2:-}"
  case "$effort" in low | medium | high | xhigh | max) ;; *) die "effort invalide : '$effort'" ;; esac
  cmd_limits "$model" >/dev/null
  if [[ "$model" != "claude-opus-5-5" && "$effort" == "max" ]]; then die "effort max interdit hors Opus (plafond xhigh)"; fi
  echo "$effort"
}

cmd_claude_args() {
  local model="${1:-}" effort="${2:-}" max_turns
  cmd_effort "$model" "$effort" >/dev/null
  max_turns="$(cmd_limits "$model" | sed -n 's/^max_turns=//p')"
  printf -- '--model %s\n--effort %s\n--max-turns %s\n' "$model" "$effort" "$max_turns"
}

cmd_check_trailers() {
  local range="${1:?plage git requise}" bad=0 sha msg field val
  for sha in $(git rev-list "$range"); do
    for field in "%ae" "%ce"; do
      val="$(git log -1 --format="$field" "$sha")"
      if [[ "$val" != "noreply@anthropic.com" ]]; then
        echo "REFUS ${sha:0:9} : e-mail ${field} different de noreply@anthropic.com" >&2
        bad=1
      fi
    done
    msg="$(git log -1 --format=%B "$sha" | git interpret-trailers --parse)"
    for field in Ticket Model Effort Claude-Session; do
      if ! grep -q "^${field}: ." <<<"$msg"; then
        echo "REFUS ${sha:0:9} : trailer ${field} absent" >&2
        bad=1
      fi
    done
  done
  return "$bad"
}

cmd_result() {
  local file="${1:?fichier execution requis}" issue="${2:?issue}" model="${3:?modele}" effort="${4:?effort}"
  EXEC_FILE="$file" ISSUE="$issue" MODEL="$model" EFFORT="$effort" ESC="${5:-}" BRANCH="${6:-}" python3 -I - <<'PY'
import json, os

def load(path):
    raw = open(path, encoding="utf-8").read().strip()
    if not raw:
        return []
    try:
        data = json.loads(raw)
        return data if isinstance(data, list) else [data]
    except json.JSONDecodeError:
        return [json.loads(l) for l in raw.splitlines() if l.strip()]

msgs = load(os.environ["EXEC_FILE"])
res = next((m for m in reversed(msgs) if m.get("type") == "result"), {})
init = next((m for m in msgs if m.get("type") == "system" and m.get("subtype") == "init"), {})
usage = res.get("usage") or {}
out = {
    "schema": "mission-result.v1",
    "ticket_issue": int(os.environ["ISSUE"]),
    "model_requested": os.environ["MODEL"],
    "model_observed": init.get("model") or "",
    "effort": os.environ["EFFORT"],
    "escalated_from": os.environ["ESC"] or None,
    "status": "FAIL" if (res.get("is_error") or not res) else "PASS",
    "branch": os.environ["BRANCH"] or None,
    "num_turns": int(res.get("num_turns") or 0),
    "duration_ms": int(res.get("duration_ms") or 0),
    "total_cost_usd": float(res.get("total_cost_usd") or 0.0),
    "tokens": {k: int(usage.get(k) or 0) for k in
               ("input_tokens", "output_tokens", "cache_read_input_tokens", "cache_creation_input_tokens")},
    "ci_failures": 0,
    "checks": {"static": "NOT_TESTED", "ci": "NOT_TESTED", "runtime": "NOT_TESTED"},
}
obs, req = out["model_observed"], out["model_requested"]
if obs and not obs.startswith(req):
    out["status"] = "FAIL"
    out["failure"] = "model_mismatch"
print(json.dumps(out, indent=2, sort_keys=True))
summ = os.environ.get("GITHUB_STEP_SUMMARY")
if summ:
    with open(summ, "a", encoding="utf-8") as f:
        f.write(f"### mission-result.v1 issue #{out['ticket_issue']}\n\n| champ | valeur |\n|---|---|\n"
                f"| statut | {out['status']} |\n| modele | {obs or 'NOT_TESTED'} |\n"
                f"| total_cost_usd | {out['total_cost_usd']} |\n| num_turns | {out['num_turns']} |\n"
                f"| duree_ms | {out['duration_ms']} |\n")
PY
}

sub="${1:-}"
shift || true
case "$sub" in
  limits) cmd_limits "$@" ;;
  effort) cmd_effort "$@" ;;
  claude-args) cmd_claude_args "$@" ;;
  check-trailers) cmd_check_trailers "$@" ;;
  result) cmd_result "$@" ;;
  *) die "usage : run-ticket.sh limits|effort|claude-args|check-trailers|result ..." ;;
esac
