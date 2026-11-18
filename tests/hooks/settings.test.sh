#!/usr/bin/env bash
# T-330 : garde statique de .claude/settings.json (ADR-0022 §3, §Vérification).
# Le JSON est valide, aucun allow n'ouvre kubectl/helm/oc/occ/curl/ssh, les deny minimaux existent.
set -u
cd "$(dirname "$0")/../.." || exit 2
f=.claude/settings.json
fail=0
ko() { echo "FAIL: $*"; fail=1; }
ok() { echo "ok: $*"; }

jq -e . "$f" >/dev/null 2>&1 || { echo "FAIL: $f n'est pas un JSON valide"; exit 1; }
ok "JSON valide"

# 1. Aucune règle allow pour les outils interdits (nom de commande au début d'une règle Bash).
bad=$(jq -r '.permissions.allow // [] | .[]' "$f" \
  | grep -E '^Bash\((kubectl|helm|oc|occ|curl|wget|ssh|scp|sftp|argocd|tofu|terraform|doppler)([ :*)]|$)' || true)
if [ -z "$bad" ]; then ok "aucun allow kubectl/helm/oc/occ/curl/ssh"; else ko "allow interdit : $bad"; fi
for r in 'Bash' 'Bash(*)'; do
  if jq -e --arg r "$r" '(.permissions.allow // []) | index($r)' "$f" >/dev/null 2>&1; then ko "allow trop large : $r"; fi
done

# 2. Deny minimaux exigés par le ticket.
need=(
  'Bash(kubectl *)' 'Bash(helm *)' 'Bash(oc *)' 'Bash(occ *)' 'Bash(ssh *)' 'Bash(tofu *)'
  'Bash(* | sh)' 'Bash(* | bash)'
  'Bash(git push *--force*)' 'Bash(gh pr merge *--admin*)'
  'Read(.env)' 'Read(**/.env)' 'Read(~/.ssh/**)' 'Read(~/.kube/**)' 'Read(**/*.tfstate)'
  'Edit(/generated/**)'
)
for r in "${need[@]}"; do
  if jq -e --arg r "$r" '.permissions.deny | index($r)' "$f" >/dev/null 2>&1; then ok "deny $r"; else ko "deny manquant : $r"; fi
done

# 3. Sandbox et plafonds.
jq -e '.sandbox.enabled == true' "$f" >/dev/null || ko "sandbox.enabled doit valoir true"
jq -e '.sandbox.allowUnsandboxedCommands == false' "$f" >/dev/null || ko "allowUnsandboxedCommands doit valoir false"
jq -e '.permissions.disableBypassPermissionsMode == "disable"' "$f" >/dev/null || ko "bypassPermissions doit être désactivé"
jq -e '(.bashOutputMaxChars | type) == "number" and .bashOutputMaxChars >= 4000 and .bashOutputMaxChars <= 128000' "$f" >/dev/null \
  || ko "bashOutputMaxChars absent ou hors 4000-128000"
jq -e '.permissions.defaultMode | IN("acceptEdits","default","plan","dontAsk")' "$f" >/dev/null \
  || ko "defaultMode doit rester dans acceptEdits|default|plan|dontAsk (pas auto/bypassPermissions)"

if [ "$fail" -eq 0 ]; then echo "PASS: settings.json conforme"; else echo "FAIL: voir ci-dessus"; fi
exit "$fail"
