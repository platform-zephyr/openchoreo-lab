#!/usr/bin/env bash
# T-481 : garde des skills tiers vendorés (mattpocock/skills, MIT) et de leur activation. Hors ligne, sans secret.
# Vérifie : SHA unique figé dans chaque en-tête, licence et NOTICE, liste fermée de skills, aucun script ni fichier
# hors Markdown, nom préfixé = dossier ; .claude/settings.json sans plugin ni marketplace flottants et sans règle Skill ;
# workflow de l'usine sans entrée plugins/plugin_marketplaces, Skill hors allowedTools, chemins cités existants.
# Puis des mutations (copies) doivent chacune faire échouer la vérification.
# Usage : tests/factory/external-skills-test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
W="$(mktemp -d "${TMPDIR:-/tmp}/external-skills-tests.XXXXXX")"
trap 'rm -rf "$W"' EXIT
export PYTHONDONTWRITEBYTECODE=1
fails=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

check() {  # $1 = racine d'un dépôt (réel ou copie mutée) ; code 0 si conforme
  python3 -I - "$1" <<'PY'
import json, pathlib, re, sys, yaml
root = pathlib.Path(sys.argv[1])
PIN = "5863806dd4e15c63174bee4e7515a4256792ecfa"
EXPECTED = {"tdd", "diagnosing-bugs", "code-review", "research", "grilling", "writing-for-agents"}
skills = root / ".agents/skills"

# 1. Liste fermée, préfixe, aucun nom amont nu (collision avec un skill intégré ou une autre source).
found = {p.name.removeprefix("mattpocock-") for p in skills.glob("mattpocock-*") if p.is_dir()}
assert found == EXPECTED, f"skills vendorés {sorted(found)} != {sorted(EXPECTED)}"
for n in EXPECTED:
    assert not (skills / n).exists(), f"nom amont nu : .agents/skills/{n}"

# 2. Provenance : chaque fichier porte l'en-tête au SHA figé ; seulement du Markdown (aucun script, aucun openai.yaml).
for d in sorted(skills.glob("mattpocock-*")):
    files = [f for f in d.rglob("*") if f.is_file()]
    assert files, d
    for f in files:
        assert f.suffix == ".md", f"fichier non Markdown vendoré : {f.relative_to(root)}"
        text = f.read_text(encoding="utf-8")
        shas = re.findall(r"Vendored from mattpocock/skills@([0-9a-f]{40})", text)
        assert shas == [PIN], f"en-tête de provenance absent ou SHA différent : {f.relative_to(root)} {shas}"
        assert "(MIT, Copyright (c) 2026 Matt Pocock" in text, f"licence absente de l'en-tête : {f.relative_to(root)}"
    s = (d / "SKILL.md").read_text(encoding="utf-8")
    front = yaml.safe_load(s.split("\n---\n", 1)[0].removeprefix("---\n"))
    assert front["name"] == d.name, f"name {front['name']} != dossier {d.name}"
    assert str(front.get("license", "")).startswith("MIT"), f"license absente : {d.name}"
    assert front.get("description"), f"description absente : {d.name}"
    assert "disable-model-invocation" not in front and "allowed-tools" not in front, f"frontmatter élargi : {d.name}"

lic = (root / "LICENSES/MIT-mattpocock-skills.txt").read_text(encoding="utf-8")
assert lic.startswith("MIT License") and "Matt Pocock" in lic, "texte MIT absent"
assert PIN in (root / "NOTICE").read_text(encoding="utf-8"), "NOTICE sans le SHA figé"

# 3. Settings : JSON valide ; ni plugin ni marketplace mattpocock (les copies vendorées font foi, pas de version flottante) ;
#    aucune marketplace sans ref ; aucune règle Skill.
st = json.loads((root / ".claude/settings.json").read_text(encoding="utf-8"))
for k in st.get("enabledPlugins", {}):
    assert "mattpocock" not in k, f"plugin flottant activé : {k}"
for name, m in st.get("extraKnownMarketplaces", {}).items():
    src = m.get("source", {})
    assert "mattpocock" not in json.dumps(src), f"marketplace mattpocock déclarée : {name}"
    assert src.get("ref") or src.get("sha"), f"marketplace non épinglée : {name}"
perms = st.get("permissions", {})
for r in perms.get("allow", []):
    assert not r.startswith("Skill"), f"allow Skill : {r}"

# 4. Workflow de l'usine : pas d'installation de plugin à l'exécution, Skill hors allowedTools, chemins cités réels.
wf = yaml.safe_load((root / ".github/workflows/claude-agent.yml").read_text(encoding="utf-8"))
steps = wf["jobs"]["dev"]["steps"]
claude = next(s for s in steps if s.get("id") == "claude")
w = claude["with"]
assert "plugins" not in w and "plugin_marketplaces" not in w, "entrée plugins/plugin_marketplaces dans l'action"
for s in steps:
    assert "plugin install" not in s.get("run", "") and "marketplace add" not in s.get("run", ""), "plugin installé par run:"
args = w["claude_args"]
tools = args.split('--allowedTools "', 1)[1].split('"', 1)[0].split(",")
assert not any(t == "Skill" or t.startswith("Skill(") for t in tools), "Skill dans allowedTools"
cited = set(re.findall(r"\.agents/skills/(mattpocock-[a-z-]+)/SKILL\.md", args))
assert {"mattpocock-tdd", "mattpocock-diagnosing-bugs"} <= cited, f"consigne de l'usine sans les skills : {cited}"
for c in cited:
    assert (skills / c / "SKILL.md").is_file(), f"chemin cité absent : {c}"
assert "jamais une permission" in args, "consigne : méthode, jamais permission"
PY
}

if check "$ROOT" >"$W/real.out" 2>&1; then ok "skills vendorés, settings et workflow conformes (T-481)"; else ko "garde T-481"; sed 's/^/  /' "$W/real.out"; fi

# Copie minimale du dépôt pour les mutations.
copy() {
  rm -rf "$W/r"; mkdir -p "$W/r/.agents" "$W/r/.claude" "$W/r/.github/workflows"
  cp -R "$ROOT/.agents/skills" "$W/r/.agents/"
  cp -R "$ROOT/LICENSES" "$W/r/"
  cp "$ROOT/NOTICE" "$W/r/"
  cp "$ROOT/.claude/settings.json" "$W/r/.claude/"
  cp "$ROOT/.github/workflows/claude-agent.yml" "$W/r/.github/workflows/"
}
mutant() {  # $1 = libellé ; la commande suivante mute $W/r ; le contrôle doit échouer
  local label="$1"; shift
  copy
  "$@"
  if check "$W/r" >/dev/null 2>&1; then ko "mutation non détectée : $label"; else ok "mutation détectée : $label"; fi
}
R="$W/r"
sk="$R/.agents/skills"
sub() { python3 -I -c 'import sys,pathlib; p=pathlib.Path(sys.argv[1]); t=p.read_text(encoding="utf-8"); assert sys.argv[2] in t, sys.argv[2]; p.write_text(t.replace(sys.argv[2], sys.argv[3], 1), encoding="utf-8")' "$@"; }
jqw() { jq "$2" "$1" >"$1.new" && mv "$1.new" "$1"; }

mutant "SHA d'en-tête différent" sub "$sk/mattpocock-tdd/tests.md" "@5863806dd4e15c63174bee4e7515a4256792ecfa" "@0000000000000000000000000000000000000000"
mutant "en-tête retiré d'un fichier" sub "$sk/mattpocock-grilling/SKILL.md" "Vendored from mattpocock" "Copied from somewhere"
mutant "script vendoré" eval 'mkdir -p "$sk/mattpocock-diagnosing-bugs/scripts" && printf "#!/bin/sh\n" >"$sk/mattpocock-diagnosing-bugs/scripts/hitl-loop.template.sh"'
mutant "agents/openai.yaml vendoré" eval 'mkdir -p "$sk/mattpocock-tdd/agents" && echo "x: 1" >"$sk/mattpocock-tdd/agents/openai.yaml"'
mutant "skill hors liste" eval 'cp -R "$sk/mattpocock-research" "$sk/mattpocock-triage"'
mutant "nom amont nu (collision)" eval 'cp -R "$sk/mattpocock-code-review" "$sk/code-review"'
mutant "name différent du dossier" sub "$sk/mattpocock-research/SKILL.md" "name: mattpocock-research" "name: research"
mutant "license retirée du frontmatter" sub "$sk/mattpocock-research/SKILL.md" "license: MIT" "x-license: none"
mutant "allowed-tools ajouté au frontmatter" sub "$sk/mattpocock-grilling/SKILL.md" "name: mattpocock-grilling" $'name: mattpocock-grilling\nallowed-tools: Bash'
mutant "NOTICE sans le SHA" sub "$R/NOTICE" "5863806dd4e15c63174bee4e7515a4256792ecfa" "main"
mutant "texte MIT retiré" eval ': >"$R/LICENSES/MIT-mattpocock-skills.txt"'
mutant "plugin flottant activé dans settings" jqw "$R/.claude/settings.json" '.enabledPlugins = {"mattpocock-skills@claude-plugins-official": true}'
mutant "marketplace mattpocock déclarée" jqw "$R/.claude/settings.json" '.extraKnownMarketplaces = {"mattpocock": {"source": {"source": "github", "repo": "mattpocock/skills"}}}'
mutant "marketplace tierce non épinglée" jqw "$R/.claude/settings.json" '.extraKnownMarketplaces = {"x": {"source": {"source": "github", "repo": "example/plugins"}}}'
mutant "allow Skill ajouté" jqw "$R/.claude/settings.json" '.permissions.allow += ["Skill(mattpocock-tdd)"]'
mutant "settings JSON invalide" eval 'printf "{" >"$R/.claude/settings.json"'
mutant "entrée plugins dans l'action" sub "$R/.github/workflows/claude-agent.yml" "          base_branch: main" $'          plugins: "mattpocock-skills@claude-plugins-official"\n          base_branch: main'
mutant "entrée plugin_marketplaces dans l'action" sub "$R/.github/workflows/claude-agent.yml" "          base_branch: main" $'          plugin_marketplaces: "https://github.com/mattpocock/skills.git"\n          base_branch: main'
mutant "Skill dans allowedTools" sub "$R/.github/workflows/claude-agent.yml" '--allowedTools "Edit,' '--allowedTools "Skill,Edit,'
mutant "consigne de l'usine retirée" sub "$R/.github/workflows/claude-agent.yml" ".agents/skills/mattpocock-tdd/SKILL.md" "le skill tdd"
mutant "chemin cité inexistant" sub "$R/.github/workflows/claude-agent.yml" ".agents/skills/mattpocock-diagnosing-bugs/SKILL.md" ".agents/skills/mattpocock-diagnosing-bugz/SKILL.md"

if [[ "$fails" -gt 0 ]]; then printf '%s test(s) en echec\n' "$fails"; exit 1; fi
echo "tous les tests des skills tiers (T-481) passent"
