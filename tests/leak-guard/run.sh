#!/usr/bin/env bash
# Tests de la garde de donnees sensibles (T-303) : tools/dev/leak-guard.sh + .gitleaks.toml.
#  - cas negatifs : OCID, IPv4 privee et publique non documentaires, e-mail hors noreply, chemin /Users/<nom>,
#    hote interne, jeton factice, motif propre au proprietaire (variable d'environnement) -> la garde ECHOUE ;
#  - cas positifs : valeurs documentaires (plages RFC 5737, example.com, noreply, placeholders) -> la garde PASSE ;
#  - la sortie ne contient jamais une valeur (seulement regle, fichier, ligne) ;
#  - sans motif propre (secret CI absent, PR de fork) la garde fonctionne avec les regles generiques ;
#  - aucun faux positif sur l'arbre actuel ; .gitleaks.toml lui-meme ne contient aucune valeur interdite.
# Les valeurs fautives sont ASSEMBLEES a l'execution (fragments) : ce fichier ne les contient pas en clair, donc la
# garde peut le scanner. Valeurs fictives uniquement. Aucun reseau, aucun cluster.
# Usage : LEAK_GUARD_BIN=/chemin/gitleaks tests/leak-guard/run.sh   (defaut : gitleaks du PATH)
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2
ROOT="$PWD"
GUARD="$PWD/tools/dev/leak-guard.sh"
BIN="${LEAK_GUARD_BIN:-gitleaks}"
if ! command -v "$BIN" >/dev/null 2>&1; then
  echo "NOT_TESTED gitleaks introuvable (LEAK_GUARD_BIN ou PATH) : ce n'est pas un PASS" >&2
  exit 1
fi
export LEAK_GUARD_BIN="$BIN"
W="$(mktemp -d "${TMPDIR:-/tmp}/leak-guard-tests.XXXXXX")"
trap 'rm -rf "$W"' EXIT
fails=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

# Valeurs fictives assemblees (aucune n'est reelle ; aucune ne figure en clair dans ce fichier).
V_OCID="ocid1.instance.oc1.""eu-frankfurt-1.""q7w3e9r2t5y8u4i6o1p0a7s3d5f2g9h4"
V_PRIV_A="10.20"".30.40"
V_PRIV_B="192.168"".77.5"
V_PUB="93.184"".216.34"
V_MAIL="prenom.nom""@""societe-fictive.fr"
V_PATH="/Us""ers/prenomfictif/work"
V_HOST="nas.hom""e.arpa"
V_TOKEN="ghp""_""a1B2c3D4e5F6g7H8i9J0k1L2m3N4o5P6q7R8"
V_OWNER="zz-proprietaire-""demo-9f3"

# scan NOM CONTENU [VAR=VAL ...] : ecrit CONTENU dans un dossier neuf et lance la garde ; sortie dans $W/out, code dans $RC.
RC=0
scan() {
  local name="$1" content="$2"
  shift 2
  local d="$W/case-$name"
  rm -rf "$d"
  mkdir -p "$d"
  printf '%s\n' "$content" >"$d/note.md"
  RC=0
  env "$@" bash "$GUARD" "$d" >"$W/out" 2>&1 || RC=$?
}
expect_fail() { # NOM CONTENU VALEUR [VAR=VAL ...]
  local name="$1" content="$2" value="$3"
  shift 3
  scan "$name" "$content" "$@"
  if [[ "$RC" -ne 1 ]]; then
    ko "refus attendu : $name (code $RC)"
  elif ! grep -q '^LEAK ' "$W/out"; then
    ko "refus sans ligne LEAK : $name"
  elif grep -qF -- "$value" "$W/out"; then
    ko "la sortie contient la VALEUR : $name"
  elif ! grep -q 'note.md:1' "$W/out"; then
    ko "fichier:ligne absents : $name"
  else
    ok "refus (fichier:ligne, sans valeur) : $name"
  fi
}
expect_pass() { # NOM CONTENU [VAR=VAL ...]
  local name="$1" content="$2"
  shift 2
  scan "$name" "$content" "$@"
  if [[ "$RC" -eq 0 ]] && grep -q '^LEAK-GUARD: PASS' "$W/out"; then
    ok "accepte : $name"
  else
    ko "faux positif : $name (code $RC)"
    sed 's/^/      | /' "$W/out"
  fi
}

# --- Cas negatifs (chacun doit echouer) ---
expect_fail ocid "instance : $V_OCID" "$V_OCID"
expect_fail ipv4-privee-10 "serveur $V_PRIV_A en LAN" "$V_PRIV_A"
expect_fail ipv4-privee-192 "passerelle $V_PRIV_B" "$V_PRIV_B"
expect_fail ipv4-privee-cidr "reseau ${V_PRIV_A}/24" "$V_PRIV_A"
expect_fail ipv4-publique "hote $V_PUB" "$V_PUB"
expect_fail email "contact : $V_MAIL" "$V_MAIL"
expect_fail chemin-local "voir $V_PATH/fichier" "$V_PATH"
expect_fail hote-interne "ssh $V_HOST" "$V_HOST"
expect_fail jeton-factice "export TOKEN=$V_TOKEN" "$V_TOKEN"
expect_fail motif-proprietaire-env "domaine $V_OWNER" "$V_OWNER" "LEAK_GUARD_EXTRA_PATTERNS=zz-proprietaire-demo-[0-9a-f]+"

# Motif propre fourni par un fichier hors depot (poste du proprietaire).
printf '# commentaire\n\nzz-proprietaire-demo-[0-9a-f]+\n' >"$W/owner-patterns.txt"
expect_fail motif-proprietaire-fichier "domaine $V_OWNER" "$V_OWNER" "LEAK_GUARD_EXTRA_PATTERNS_FILE=$W/owner-patterns.txt"

# --- Cas positifs (valeurs documentaires : doivent passer) ---
expect_pass doc-ipv4 "serveur 192.0.2.10, passerelle 198.51.100.7, hote 203.0.113.9/24, boucle 127.0.0.1, 0.0.0.0/0, IMDS 169.254.169.254"
expect_pass doc-ocid "instance : ocid1.instance.oc1..exampleuniqueid"
expect_pass doc-email "contact : user@example.com, Co-Authored-By: Claude <noreply@anthropic.com>, git@github.com:org/depot.git"
expect_pass doc-chemin "voir /Users/<nom>/work, /home/user/.cache, /Users/Shared, C:\\Users\\<nom>"
expect_pass doc-hote "svc.namespace.svc.cluster.local, host.docker.internal, serveur.example.internal"
expect_pass doc-plages "blocs 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10"
expect_pass doc-motif-proprietaire-absent "rien de sensible ici" "LEAK_GUARD_EXTRA_PATTERNS=zz-proprietaire-demo-[0-9a-f]+"

# --- Secret CI absent (PR de fork) : la garde fonctionne, signale l'absence, et refuse toujours le generique ---
scan sans-motif "domaine $V_OWNER"
if [[ "$RC" -eq 0 ]] && grep -q '^INFO motifs du proprietaire absents' "$W/out"; then
  ok "motif propre absent : regles generiques seules, code 0, avertissement INFO"
else
  ko "motif propre absent : comportement inattendu (code $RC)"
fi
scan sans-motif-generique "serveur $V_PRIV_A" "LEAK_GUARD_EXTRA_PATTERNS="
if [[ "$RC" -eq 1 ]] && grep -q '^INFO motifs du proprietaire absents' "$W/out"; then
  ok "variable vide : le refus generique reste actif"
else
  ko "variable vide : comportement inattendu (code $RC)"
fi

# --- T-483 : un worktree d'agent sous .claude/worktrees/ n'est pas aveugle ---
# Racine scannee situee sous un chemin .claude/worktrees/x/ (hors depot : copie dans $W, jamais le worktree reel).
wt="$W/.claude/worktrees/x"
mkdir -p "$wt"
printf 'serveur %s\n' "$V_PRIV_A" >"$wt/note.md"
RC=0
bash "$GUARD" "$wt" >"$W/out" 2>&1 || RC=$?
if [[ "$RC" -eq 1 ]] && grep -q '^LEAK ' "$W/out"; then ok "T-483 racine sous .claude/worktrees/x : valeur detectee"; else ko "T-483 racine sous .claude/worktrees/x : PASS a vide (code $RC)"; fi
# Meme racine scannee par chemin ABSOLU (gitleaks teste alors le chemin complet contre l'allowlist de chemins).
RC=0
(cd "$wt" && "$(command -v "$BIN")" dir "$wt" --config "$ROOT/.gitleaks.toml" --no-banner --redact=100 --log-level error) >/dev/null 2>&1 || RC=$?
if [[ "$RC" -eq 1 ]]; then ok "T-483 chemin absolu sous .claude/worktrees/x : valeur detectee"; else ko "T-483 chemin absolu sous .claude/worktrees/x : aveugle (code $RC)"; fi
# Un worktree imbrique DANS la racine scannee reste ignore (role d'origine de l'allowlist, ancree a la racine).
nest="$W/case-nested"
mkdir -p "$nest/.claude/worktrees/y"
printf 'serveur %s\n' "$V_PRIV_A" >"$nest/.claude/worktrees/y/note.md"
RC=0
bash "$GUARD" "$nest" >"$W/out" 2>&1 || RC=$?
if [[ "$RC" -eq 0 ]]; then ok "T-483 worktree imbrique sous la racine : ignore"; else ko "T-483 worktree imbrique : code $RC"; fi
# Garde de sanite : une configuration qui rend la sonde aveugle donne le code 2, jamais PASS.
printf 'title = "aveugle"\n[[allowlists]]\npaths = ["(?s).*"]\n' >"$W/blind.toml"
mkdir -p "$W/repo-blind/tools/dev"
cp "$GUARD" "$W/repo-blind/tools/dev/leak-guard.sh"
cp "$W/blind.toml" "$W/repo-blind/.gitleaks.toml"
: >"$W/repo-blind/.gitleaksignore"
mkdir -p "$W/repo-blind/src"
printf 'rien\n' >"$W/repo-blind/src/a.md"
RC=0
bash "$W/repo-blind/tools/dev/leak-guard.sh" "$W/repo-blind" >"$W/out" 2>&1 || RC=$?
if [[ "$RC" -eq 2 ]]; then ok "T-483 sonde aveugle : code 2 (pas un PASS a vide)"; else ko "T-483 sonde aveugle : code $RC"; fi

# --- Erreurs d'outil : jamais un PASS ---
RC=0
LEAK_GUARD_BIN="$W/absent" bash "$GUARD" "$W" >"$W/out" 2>&1 || RC=$?
if [[ "$RC" -eq 2 ]]; then ok "binaire absent : code 2 (pas un PASS)"; else ko "binaire absent : code $RC"; fi
RC=0
LEAK_GUARD_EXTRA_PATTERNS_FILE="$W/introuvable" bash "$GUARD" "$W" >"$W/out" 2>&1 || RC=$?
if [[ "$RC" -eq 2 ]]; then ok "fichier de motifs illisible : code 2"; else ko "fichier de motifs illisible : code $RC"; fi

# --- La configuration et la dette ne contiennent aucune valeur interdite ---
# (.gitleaks.toml est exclu par le scan par defaut de gitleaks : on le scanne sous un autre nom.)
mkdir -p "$W/self"
cp .gitleaks.toml "$W/self/config-copy.txt"
cp .gitleaksignore "$W/self/ignore-copy.txt"
RC=0
bash "$GUARD" "$W/self" >"$W/out" 2>&1 || RC=$?
if [[ "$RC" -eq 0 ]]; then ok ".gitleaks.toml et .gitleaksignore : aucune valeur interdite"; else ko ".gitleaks.toml/.gitleaksignore contiennent une valeur interdite"; sed 's/^/      | /' "$W/out"; fi

# --- Aucun faux positif sur l'arbre actuel ---
RC=0
bash "$GUARD" >"$W/out" 2>&1 || RC=$?
if [[ "$RC" -eq 0 ]]; then ok "arbre actuel : garde PASS (dette connue couverte par .gitleaksignore)"; else ko "arbre actuel : la garde echoue"; sed 's/^/      | /' "$W/out" | head -20; fi

if [[ "$fails" -gt 0 ]]; then
  printf 'LEAK-GUARD TESTS: FAIL (%s)\n' "$fails"
  exit 1
fi
printf 'LEAK-GUARD TESTS: PASS\n'
