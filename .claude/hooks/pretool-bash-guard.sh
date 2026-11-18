#!/usr/bin/env bash
# Hook PreToolUse (Bash) : garde de commandes (T-331, SL-5). Refus déterministe (rc 2, raison sur stderr) de :
# push forcé ou vers main, --no-verify, `gh pr merge --admin`, outils cluster/secrets/accès distant (kubectl, helm, oc,
# occ, argocd, tofu, terraform, doppler, oci, ssh, scp, sftp), `curl | sh`, lecture d'identifiants, env/printenv nus,
# écriture shell de STATE.md / backlog/ROADMAP.md hors session coordinatrice (LAB_COORDINATOR_SESSION=1).
# Cohérent avec permissions.deny de .claude/settings.json (ne l'affaiblit pas : les couches s'additionnent).
# Limite : analyse textuelle d'une commande, pas un bac à sable ; sandbox et CI restent la preuve.
set -u
deny() { echo "T-331 garde Bash : refusé : $1" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || deny "jq absent (le garde échoue fermé)"
input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)" || deny "entrée illisible"
[[ -n "$cmd" ]] || exit 0

NL=$'\n'
# Position de commande : début, ou après ; & | ( ` $( ou fin de ligne ; préfixes sudo/env/xargs... tolérés.
SEP="(^|[;&|(\`]|\\\$\\(|${NL})[[:space:]]*"
PFX='(([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|sudo|env|command|exec|nohup|time|xargs|-[^[:space:]]+)[[:space:]]+)*'
END='([[:space:]]|$|[;&|)])'

if [[ "$cmd" =~ ${SEP}${PFX}(kubectl|helm|oc|occ|argocd|tofu|terraform|doppler|oci|ssh|scp|sftp)${END} ]]; then
  deny "outil cluster, secrets ou accès distant interdit à l'agent (${BASH_REMATCH[$((${#BASH_REMATCH[@]} - 2))]}) ; passer par une PR"
fi
[[ "$cmd" =~ ${SEP}${PFX}printenv${END} ]] && deny "printenv expose l'environnement"
ENVRE="${SEP}env[[:space:]]*(\$|[;&|)])"
[[ "$cmd" =~ $ENVRE ]] && deny "env nu expose l'environnement"

[[ "$cmd" =~ \|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da)?sh${END} ]] && deny "tube vers un shell (curl | sh)"
[[ "$cmd" =~ (^|[[:space:]])(sh|bash)[[:space:]]+-s([[:space:]]|$) ]] && deny "shell lisant son script sur stdin"

if [[ "$cmd" =~ git[[:space:]]+(-[^[:space:]]+[[:space:]]+)*push${END} ]]; then
  [[ "$cmd" =~ push[^\;\&\|]*[[:space:]](--force|--force-with-lease|--force-if-includes|--mirror|--delete)([=[:space:]]|$) ]] && deny "git push forcé ou destructif"
  [[ "$cmd" =~ push[^\;\&\|]*[[:space:]]-[a-zA-Z]*f[a-zA-Z]*([[:space:]]|$) ]] && deny "git push -f (forcé)"
  [[ "$cmd" =~ push[^\;\&\|]*[[:space:]]\+[^[:space:]]+ ]] && deny "git push +refspec (forcé)"
  [[ "$cmd" =~ push[^\;\&\|]*[[:space:]]([A-Za-z0-9_./-]+:)?(refs/heads/)?main([[:space:]]|$) ]] && deny "git push vers main"
fi
[[ "$cmd" =~ git[[:space:]]+(-[^[:space:]]+[[:space:]]+)*(commit|push|merge)[^\;\&\|]*--no-verify ]] && deny "--no-verify contourne les contrôles"
[[ "$cmd" =~ git[[:space:]]+(-[^[:space:]]+[[:space:]]+)*commit[^\;\&\|]*[[:space:]]-[a-zA-Z]*n[a-zA-Z]*([[:space:]]|$) ]] && deny "git commit -n (= --no-verify)"
[[ "$cmd" =~ gh[[:space:]]+pr[[:space:]]+merge[^\;\&\|]*--admin ]] && deny "gh pr merge --admin contourne les protections"
[[ "$cmd" =~ gh[[:space:]]+(secret|repo[[:space:]]+delete)${END} ]] && deny "gh secret / gh repo delete"
[[ "$cmd" =~ gh[[:space:]]+auth[[:space:]]+token ]] && deny "gh auth token expose un jeton"
[[ "$cmd" =~ gh[[:space:]]+api[^\;\&\|]*(-X|--method)[[:space:]=]*DELETE ]] && deny "gh api DELETE"

# Identifiants : toute mention d'un chemin d'identifiants dans une commande.
CRED_A='(^|[[:space:]=:"'"'"'/])\.env(\.[A-Za-z0-9_-]+)?([[:space:]"'"'"';|&)]|$)'
CRED_B='\.(pem|key|tfstate)(\.[A-Za-z0-9_-]+)?([[:space:]"'"'"';|&)]|$)'
CRED_C='kubeconfig'
CRED_D='(^|[[:space:]=:"'"'"'/~])\.(ssh|kube|aws|oci)(/|[[:space:]"'"'"';|&)]|$)'
CRED_E='\.config/(gh|doppler)(/|[[:space:]"'"'"';|&)]|$)|\.docker/config\.json|\.claude/\.credentials\.json'
for re in "$CRED_A" "$CRED_B" "$CRED_C" "$CRED_D" "$CRED_E"; do
  [[ "$cmd" =~ $re ]] && deny "chemin d'identifiants (.env, clé, tfstate, kubeconfig, ~/.ssh, ~/.kube, ~/.aws, ~/.oci, gh, doppler)"
done

# Fichiers réservés à la session coordinatrice, écrits par le shell.
if [[ "${LAB_COORDINATOR_SESSION:-}" != "1" ]]; then
  W='(>|(^|[[:space:];&|])(tee|mv|cp|rm|truncate|dd)|sed[[:space:]]+-[a-zA-Z]*i|perl[[:space:]]+-[a-zA-Z]*i)'
  if [[ "$cmd" =~ ${W}[^\;\&\|]*(^|[[:space:]/\"\'])(STATE\.md|ROADMAP\.md)([[:space:]\"\';|&]|$) ]]; then
    deny "STATE.md et backlog/ROADMAP.md : réservés à la session coordinatrice"
  fi
fi
exit 0
