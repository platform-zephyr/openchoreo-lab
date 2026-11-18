#!/usr/bin/env bash
# leak-guard.sh : garde de donnees sensibles du depot public (T-303). Meme script en local, en CI (job leak-guard) et
# dans le hook Stop (T-331). Scanne l'ARBRE de travail avec gitleaks (regles par defaut + .gitleaks.toml : OCID Oracle,
# IPv4 non documentaire, e-mail hors noreply, chemin /Users/<nom>, hote interne). N'affiche JAMAIS une valeur :
# seulement la regle, le fichier et la ligne. Aucun reseau, aucun cluster.
#
# Usage : tools/dev/leak-guard.sh [CHEMIN]     (CHEMIN = racine a scanner, defaut : racine du depot)
# Environnement :
#   LEAK_GUARD_BIN                     binaire gitleaks (defaut : gitleaks du PATH ; la CI installe la version epinglee).
#   LEAK_GUARD_EXTRA_PATTERNS        motifs propres au proprietaire (domaine, nom, e-mail...), un regex RE2 par ligne,
#                                    insensibles a la casse. Secret CI : JAMAIS ecrits dans le depot. Absent ou vide =
#                                    regles generiques seules (le script fonctionne, avec un avertissement INFO).
#   LEAK_GUARD_EXTRA_PATTERNS_FILE   idem depuis un fichier HORS depot (poste de Paul) ; cumulable avec la variable.
# Codes de sortie : 0 propre, 1 fuite detectee, 2 erreur d'outil ou d'usage (ne jamais lire 2 comme un PASS).
set -uo pipefail

root_default="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
scan_root="${1:-$root_default}"
[[ -d "$scan_root" ]] || { echo "LEAK-GUARD: ERREUR chemin introuvable" >&2; exit 2; }
scan_root="$(cd "$scan_root" && pwd)"
cfg="$root_default/.gitleaks.toml"
ignore="$root_default/.gitleaksignore"
bin="${LEAK_GUARD_BIN:-gitleaks}"

command -v "$bin" >/dev/null 2>&1 || { echo "LEAK-GUARD: ERREUR gitleaks introuvable (LEAK_GUARD_BIN ou PATH)" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "LEAK-GUARD: ERREUR python3 introuvable" >&2; exit 2; }
bin="$(command -v "$bin")"
[[ "$bin" == /* ]] || bin="$PWD/$bin"
[[ -f "$cfg" ]] || { echo "LEAK-GUARD: ERREUR .gitleaks.toml introuvable" >&2; exit 2; }

umask 077
work="$(mktemp -d "${TMPDIR:-/tmp}/leak-guard.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# Motifs du proprietaire : lus depuis l'environnement, ecrits seulement dans un fichier temporaire (mode 600, supprime).
patterns="${LEAK_GUARD_EXTRA_PATTERNS:-}"
if [[ -n "${LEAK_GUARD_EXTRA_PATTERNS_FILE:-}" ]]; then
  if [[ -r "$LEAK_GUARD_EXTRA_PATTERNS_FILE" ]]; then
    patterns+=$'\n'"$(cat "$LEAK_GUARD_EXTRA_PATTERNS_FILE")"
  else
    echo "LEAK-GUARD: ERREUR LEAK_GUARD_EXTRA_PATTERNS_FILE illisible" >&2
    exit 2
  fi
fi

use_cfg="$cfg"
n_extra=0
if [[ -n "${patterns//[$' \t\r\n']/}" ]]; then
  use_cfg="$work/config.toml"
  {
    printf 'title = "leak-guard avec motifs du proprietaire"\n[extend]\npath = "%s"\n' "$cfg"
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%$'\r'}"
      [[ -z "${line//[$' \t']/}" || "$line" == \#* ]] && continue
      if [[ "$line" == *"'''"* ]]; then
        echo "LEAK-GUARD: ERREUR un motif propre contient ''' (non supporte)" >&2
        exit 2
      fi
      n_extra=$((n_extra + 1))
      printf '[[rules]]\nid = "owner-pattern-%s"\ndescription = "motif propre au proprietaire (secret CI)"\nregex = %s\n' \
        "$n_extra" "'''(?i)${line}'''"
    done <<<"$patterns"
  } >"$use_cfg" || exit 2
fi
if [[ "$n_extra" -eq 0 ]]; then
  use_cfg="$cfg"
  echo "INFO motifs du proprietaire absents (LEAK_GUARD_EXTRA_PATTERNS non defini) : regles generiques seules"
else
  echo "INFO $n_extra motif(s) du proprietaire charge(s) depuis l'environnement"
fi

report="$work/report.json"
rc=0
# Depuis la racine scannee avec "dir ." : les chemins (donc les empreintes de .gitleaksignore) sont relatifs.
(cd "$scan_root" && "$bin" dir . --config "$use_cfg" --gitleaks-ignore-path "$ignore" --no-banner --redact=100 \
  --report-format json --report-path "$report" --log-level error) >"$work/out.log" 2>&1 || rc=$?
# gitleaks : 0 = rien, 1 = fuite(s) ; autre = erreur d'outil. Le journal peut citer des lignes : jamais affiche.
if [[ "$rc" -ne 0 && "$rc" -ne 1 ]]; then
  echo "LEAK-GUARD: ERREUR gitleaks a echoue (code $rc ; journal non affiche, il peut citer des valeurs)" >&2
  exit 2
fi

# Affiche regle, fichier, ligne ; rien d'autre (ni Secret, ni Match, ni Line). Code 1 si au moins un emplacement.
prc=0
python3 -I - "$report" "$scan_root" <<'PY' || prc=$?
import json, os, sys
path, root = sys.argv[1], sys.argv[2]
try:
    findings = json.load(open(path)) or []
except OSError:
    findings = []
except ValueError:
    sys.exit(2)
seen = set()
for f in findings:
    file = f.get("File", "?")
    try:
        file = os.path.relpath(file, root)
    except ValueError:
        pass
    key = (f.get("RuleID", "?"), file, f.get("StartLine", 0))
    if key not in seen:
        seen.add(key)
        print("LEAK %s %s:%s" % key)
if seen:
    print("LEAK-GUARD: FAIL (%d emplacement(s) ; valeurs non affichees)" % len(seen))
    sys.exit(1)
PY
if [[ "$prc" -eq 2 ]]; then echo "LEAK-GUARD: ERREUR rapport illisible" >&2; exit 2; fi
if [[ "$prc" -eq 1 || "$rc" -eq 1 ]]; then exit 1; fi
echo "LEAK-GUARD: PASS"
