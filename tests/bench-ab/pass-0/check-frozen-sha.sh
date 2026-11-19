#!/usr/bin/env bash
# Vérifie le SHA figé du bras O (T-501) : l'arbre de ce commit ne doit contenir NI `echo-bench` NI `miniflux`
# (M1, M2 et M4 demandent à l'agent de les créer : une app déjà présente rendrait la tâche triviale ou fausserait S2).
# Contrôle : `apps/<app>/` et toute entrée de `generated/` ou `golden-paths/` dont un segment de chemin est `<app>`
# ou commence par `<app>-` / `<app>.`. Hors ligne, lecture de l'objet Git seule : ni réseau, ni cluster, ni secret.
#
# Usage : check-frozen-sha.sh <SHA40> [--repo-dir D]
# Codes : 0 PASS (arbre vierge de ces apps) ; 1 FAIL (chemins listés) ; 2 usage ou SHA inconnu.
# Le SHA du bras K (bac à sable privé) n'est pas vérifié ici : autre dépôt (voir arm-k/DIFF.md).
set -euo pipefail

APPS=(echo-bench miniflux)
die() {
  printf 'check-frozen-sha.sh : %s\n' "$1" >&2
  exit 2
}

sha="" repo="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-dir)
      [[ $# -ge 2 ]] || die "--repo-dir sans valeur"
      repo="$2"
      shift 2
      ;;
    -h | --help)
      sed -n '2,10p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    -*) die "option inconnue : $1" ;;
    *)
      [[ -z "$sha" ]] || die "un seul SHA attendu"
      sha="$1"
      shift
      ;;
  esac
done
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "SHA complet (40 hexadécimaux) attendu : une branche ou un SHA court n'est pas un gel"
git -C "$repo" cat-file -e "$sha^{commit}" 2>/dev/null || die "commit $sha absent du dépôt $repo"

pattern="(^|/)($(IFS='|'; echo "${APPS[*]}"))([-.][^/]*)?(/|$)"
hits="$(git -C "$repo" ls-tree -r --full-tree --name-only "$sha" | grep -E "^(apps|generated|golden-paths)/" | grep -E "$pattern" | sort || true)"

if [[ -n "$hits" ]]; then
  printf 'FAIL : le commit %s contient des chemins de %s :\n' "$sha" "${APPS[*]}"
  printf '%s\n' "$hits" | sed 's/^/  /'
  exit 1
fi
printf 'PASS : le commit %s ne contient ni apps/echo-bench ni apps/miniflux (ni leur sortie generated/)\n' "$sha"
