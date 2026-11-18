#!/usr/bin/env bash
# guard-check.sh : garde-fous de la Development Factory (docs/DEV-FACTORY.md). Exécuté DANS le conteneur de
# développement (dev up, dev test). Échoue (exit 1) si un accès OKE, OCI, Doppler, AWS, un cluster ou un
# identifiant administrateur est présent. N'affiche jamais de valeur : seuls les NOMS de variables et de chemins.
# Usage : tools/dev/guard-check.sh   (aucun argument ; aucun réseau ; aucun cluster contacté)
set -uo pipefail

fails=0
fail() { printf 'FAIL %s\n' "$*"; fails=$((fails + 1)); }
pass() { printf 'PASS %s\n' "$*"; }

# 1. Variables d'environnement interdites (noms seulement).
forbidden_re='^(KUBECONFIG|KUBE_[A-Z0-9_]*|OKE_[A-Z0-9_]*|OCI_[A-Z0-9_]*|DOPPLER_[A-Z0-9_]*|AWS_[A-Z0-9_]*|ARGOCD_[A-Z0-9_]*|AZURE_[A-Z0-9_]*|GOOGLE_APPLICATION_CREDENTIALS|GH_TOKEN|GITHUB_TOKEN|GITHUB_PAT|SSH_AUTH_SOCK)$'
bad_vars=""
while IFS= read -r name; do
  if [[ "$name" =~ $forbidden_re ]]; then bad_vars="$bad_vars $name"; fi
done < <(compgen -e)
if [[ -n "$bad_vars" ]]; then
  fail "variables interdites dans l'environnement :$bad_vars"
else
  pass "aucune variable OKE/OCI/Doppler/AWS/GitHub/SSH interdite"
fi

# 2. Chemins d'identifiants et de cluster (ne doivent exister dans le conteneur).
for p in "$HOME/.kube" "$HOME/.oci" "$HOME/.cache/oke-access" "$HOME/.config/gh" "$HOME/.config/doppler" \
         "$HOME/.doppler" "$HOME/.aws" "$HOME/.azure" "$HOME/.config/gcloud" "$HOME/.ssh" "$HOME/.netrc"; do
  if [[ -e "$p" || -L "$p" ]]; then fail "chemin d'identifiants présent : $p"; fi
done
# Le socket Docker n'est refusé que DANS le conteneur (DEV_FACTORY=1, posé par containerEnv) : un hôte ou un
# runner CI peut légitimement en exposer un. Le devcontainer ne le monte jamais.
if [[ -e /var/run/docker.sock ]]; then
  if [[ "${DEV_FACTORY:-}" == 1 ]]; then fail "socket Docker monté dans le conteneur (/var/run/docker.sock)"; else printf 'INFO socket Docker présent sur cet hôte (contrôle conteneur seulement)\n'; fi
fi
if [[ ! -e "$HOME/.kube" ]]; then pass "aucun ~/.kube"; fi

# 3. Aucun contexte kubectl : un conteneur de dev ne doit joindre aucun cluster (OKE, k3d partagé ou autre).
if command -v kubectl >/dev/null 2>&1; then
  ctx="$(kubectl config current-context 2>/dev/null || true)"
  if [[ -n "$ctx" ]]; then fail "kubectl a un contexte courant (un cluster est configuré)"; else pass "kubectl : aucun contexte (aucun cluster joignable)"; fi
else
  pass "kubectl absent du PATH"
fi

if [[ "$fails" -gt 0 ]]; then
  printf 'GUARD-CHECK: FAIL (%s point(s) bloquant(s))\n' "$fails"
  exit 1
fi
printf 'GUARD-CHECK: PASS\n'
