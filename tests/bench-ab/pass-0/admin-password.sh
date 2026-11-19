#!/usr/bin/env bash
# Clé `MINIFLUX_ADMIN_PASSWORD` du banc A/B (M2, T-501) : pose et usage, sans jamais afficher ni écrire la valeur.
# Convention de lab-store (fournisseur ESO kubernetes, T-499) : Secret `miniflux-admin-password` dans `lab-secrets`,
# clé `MINIFLUX_ADMIN_PASSWORD` (remoteRef key = nom du Secret, property = clé). Opérateur ou session cluster seulement :
# ce script écrit un Secret de harnais (hors GitOps, comme `openchoreo-status`), il n'est jamais lancé par la CI.
#
# Usage :
#   admin-password.sh seed --context CTX [--namespace lab-secrets] [--dry-run]
#       crée le Secret avec une valeur aléatoire (32 octets, base64 URL-safe) ; ne remplace jamais un Secret existant
#       (le compte administrateur de miniflux est créé au premier démarrage : changer la valeur le casserait).
#   admin-password.sh exec --context CTX [--namespace lab-secrets] -- COMMANDE...
#       lance COMMANDE avec MINIFLUX_ADMIN_PASSWORD dans son environnement (ex. : observe.py api-row ...).
# La valeur transite par un tube (jamais en argument, jamais sur disque ni sur la sortie). --dry-run n'appelle que `get`.
# Codes : 0 ok ; 2 usage ; 3 Secret absent (exec) ; 4 outil manquant.
set -euo pipefail

SECRET="miniflux-admin-password"
KEY="MINIFLUX_ADMIN_PASSWORD"
die() {
  printf 'admin-password.sh : %s\n' "$1" >&2
  exit "${2:-2}"
}

[[ $# -ge 1 ]] || die "attendu : seed|exec --context CTX"
mode="$1"
shift
ctx="" ns="lab-secrets" dry=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --context | --namespace)
      [[ $# -ge 2 ]] || die "$1 sans valeur"
      if [[ "$1" == "--context" ]]; then ctx="$2"; else ns="$2"; fi
      shift 2
      ;;
    --dry-run)
      dry=1
      shift
      ;;
    --)
      shift
      break
      ;;
    -h | --help)
      sed -n '2,15p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *) die "option inconnue : $1" ;;
  esac
done
[[ -n "$ctx" ]] || die "--context obligatoire (jamais le contexte courant par défaut)"
case "$mode" in seed | exec) ;; *) die "mode inconnu : '$mode' (seed ou exec)" ;; esac
command -v kubectl >/dev/null || die "kubectl absent" 4

kc() { kubectl --context "$ctx" "$@"; }

case "$mode" in
  seed)
    if kc -n "$ns" get secret "$SECRET" -o name >/dev/null 2>&1; then
      printf 'Secret %s/%s déjà présent : conservé (valeur non lue)\n' "$ns" "$SECRET"
      exit 0
    fi
    if [[ "$dry" -eq 1 ]]; then
      printf 'dry-run : créerait le Secret %s/%s, clé %s, valeur aléatoire non affichée\n' "$ns" "$SECRET" "$KEY"
      exit 0
    fi
    command -v openssl >/dev/null || die "openssl absent" 4
    # Valeur : tube openssl -> client cluster ; aucune variable shell, aucun fichier.
    openssl rand -base64 32 | tr '+/' '-_' | tr -d '=\n' \
      | kc -n "$ns" create secret generic "$SECRET" --from-file="$KEY=/dev/stdin" >/dev/null
    printf 'Secret %s/%s créé, clé %s (valeur non affichée)\n' "$ns" "$SECRET" "$KEY"
    ;;
  exec)
    [[ $# -ge 1 ]] || die "exec : COMMANDE absente après --"
    kc -n "$ns" get secret "$SECRET" -o name >/dev/null 2>&1 || die "Secret $ns/$SECRET absent (lancer seed)" 3
    value="$(kc -n "$ns" get secret "$SECRET" -o "jsonpath={.data.$KEY}" | base64 -d)"
    [[ -n "$value" ]] || die "clé $KEY vide dans $ns/$SECRET" 3
    export MINIFLUX_ADMIN_PASSWORD="$value"
    unset value
    exec "$@"
    ;;
esac
