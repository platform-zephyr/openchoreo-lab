"""Tests de tools/backlog/next.py et admission.py (T-210). Lancer : python3 -m unittest discover -s tests/backlog"""
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "backlog"))
import admission  # noqa: E402
import next as nxt  # noqa: E402

CODEOWNERS = """\
/.github/ @owner
/docs/adr/ @owner
/platform/policies/ @owner
/tools/backlog/ @owner
/platform/install/argocd/apps/lab-apps.yaml
/platform/install/argocd/ @owner
"""


def ticket(tid, perimeter, deps="[]", status="todo", stage="S1", model="claude-sonnet-5-5", effort="high",
           klass="AUTONOME", velocity="false"):
    return f"""---
id: {tid}
title: "t {tid}"
status: {status}
phase: P0
depends_on: {deps}
class: {klass}
velocity: {velocity}
lane: l
stage: {stage}
model: {model}
effort: {effort}
---
# {tid}

## Périmètre de fichiers
{perimeter}

## Critères de fin
- [ ] x
"""


class Env:
    def __init__(self, case, specs):
        self.tmp = tempfile.TemporaryDirectory()
        case.addCleanup(self.tmp.cleanup)
        d = Path(self.tmp.name)
        (d / "backlog").mkdir()
        for tid, kw in specs.items():
            (d / "backlog" / f"{tid}.md").write_text(ticket(tid, **kw), encoding="utf-8")
        (d / "CODEOWNERS").write_text(CODEOWNERS, encoding="utf-8")
        self.backlog, self.core = d / "backlog", admission.load_core(d / "CODEOWNERS")

    def run(self, **kw):
        return nxt.compute(nxt.load_tickets(self.backlog), self.core, **kw)


class Perimeter(unittest.TestCase):
    def test_parse_ignores_notes_and_external(self):
        got = admission.parse_perimeter("tools/oke/verify.sh (lecture), docs/, kube-ops (PR séparées), apps/")
        self.assertEqual(got, ["tools/oke/verify.sh", "docs/", "apps/"])

    def test_overlap(self):
        o = admission.overlaps
        self.assertTrue(o("tests/", "tests/appgen/x.sh"))
        self.assertTrue(o("platform/", "platform/policies/"))
        self.assertTrue(o("docs/*.md", "docs/a.md"))
        self.assertFalse(o("tests/appgen/", "tests/vap/"))
        self.assertFalse(o("tools/a.py", "tools/b.py"))
        self.assertTrue(o("tools/a.py", "tools/a.py"))
        self.assertFalse(o("tools/a.py", "tools/a.py/x"))  # un fichier n'a pas de sous-arbre


class Classe(unittest.TestCase):
    def test_core_forces_revue_even_if_header_says_autonome(self):
        e = Env(self, {"T-1": dict(perimeter="platform/policies/, tests/", klass="AUTONOME")})
        self.assertEqual(e.run()["ready"][0]["class"], "REVUE")

    def test_non_core_is_autonome_even_if_header_says_revue(self):
        e = Env(self, {"T-1": dict(perimeter="apps/", klass="REVUE")})
        self.assertEqual(e.run()["ready"][0]["class"], "AUTONOME")

    def test_exception_codeowners_is_not_core(self):
        e = Env(self, {"T-1": dict(perimeter="platform/install/argocd/apps/lab-apps.yaml")})
        self.assertEqual(e.run()["ready"][0]["class"], "AUTONOME")


class Modele(unittest.TestCase):
    def test_header_below_floor_is_ignored(self):
        e = Env(self, {"T-1": dict(perimeter="platform/policies/", model="claude-haiku-5-5", effort="low")})
        r = e.run()["ready"][0]
        self.assertEqual((r["model"], r["effort"], r["routing"]), ("claude-opus-5-5", "high", "R1-sensible"))

    def test_header_above_floor_is_kept(self):
        e = Env(self, {"T-1": dict(perimeter="apps/", model="claude-opus-5-5", effort="max")})
        r = e.run()["ready"][0]
        self.assertEqual((r["model"], r["effort"]), ("claude-opus-5-5", "max"))

    def test_text_only_is_haiku_but_sonnet_header_wins(self):
        e = Env(self, {"T-1": dict(perimeter="docs/runbooks/", model="claude-haiku-5-5", effort="medium"),
                 "T-2": dict(perimeter="docs/guides/", model="claude-sonnet-5-5")})
        by = {r["id"]: r for r in e.run()["ready"]}
        self.assertEqual((by["T-1"]["routing"], by["T-1"]["model"]), ("R2-texte", "claude-haiku-5-5"))
        self.assertEqual(by["T-2"]["model"], "claude-sonnet-5-5")

    def test_default_sonnet_high_and_sonnet_cap(self):
        e = Env(self, {"T-1": dict(perimeter="apps/", model="claude-haiku-5-5", effort="low")})
        r = e.run()["ready"][0]
        self.assertEqual((r["routing"], r["model"], r["effort"]), ("R3-defaut", "claude-sonnet-5-5", "high"))
        self.assertEqual(admission.resolve_model(["apps/"], "S1", "claude-sonnet-5-5", "max", e.core)[2], "xhigh")

    def test_final_stage_is_sensitive(self):
        e = Env(self, {"T-1": dict(perimeter="apps/", stage="FINAL")})
        self.assertEqual(e.run(stage_open="FINAL")["ready"][0]["model"], "claude-opus-5-5")


class Admission(unittest.TestCase):
    def test_dependencies_must_be_done(self):
        e = Env(self, {"T-1": dict(perimeter="apps/a/", status="done"), "T-2": dict(perimeter="apps/b/", deps="[T-1]"),
                 "T-3": dict(perimeter="apps/c/", deps="[T-2]")})
        out = e.run()
        self.assertEqual([r["id"] for r in out["ready"]], ["T-2"])
        self.assertEqual(out["ready"][0]["unblocks"], ["T-3"])

    def test_overlap_between_candidates_is_held(self):
        e = Env(self, {"T-1": dict(perimeter="tests/appgen/"), "T-2": dict(perimeter="tests/"), "T-3": dict(perimeter="apps/")})
        out = e.run()
        self.assertEqual([r["id"] for r in out["ready"]], ["T-1", "T-3"])
        self.assertEqual(out["held_overlap"][0]["id"], "T-2")
        self.assertEqual(out["held_overlap"][0]["conflicts_with"], "T-1")

    def test_overlap_with_in_progress_is_held(self):
        e = Env(self, {"T-1": dict(perimeter="tools/x/", status="in-progress"), "T-2": dict(perimeter="tools/"),
                 "T-3": dict(perimeter="apps/")})
        out = e.run()
        self.assertEqual([r["id"] for r in out["ready"]], ["T-3"])
        self.assertEqual(out["held_overlap"][0]["conflicts_with"], "T-1")

    def test_state_and_roadmap_refused(self):
        e = Env(self, {"T-1": dict(perimeter="STATE.md"), "T-2": dict(perimeter="backlog/ROADMAP.md, docs/"),
                 "T-3": dict(perimeter="apps/")})
        out = e.run()
        self.assertEqual([r["id"] for r in out["ready"]], ["T-3"])
        self.assertTrue(all(x["reason"].startswith("chemin-refuse") for x in out["excluded"]))

    def test_human_gesture_and_closed_stage_excluded(self):
        e = Env(self, {"T-1": dict(perimeter="apps/", model="human", effort="none"),
                 "T-2": dict(perimeter="apps/b/", klass="REVUE + MANDAT"),
                 "T-3": dict(perimeter="apps/c/", stage="S0"), "T-4": dict(perimeter="apps/d/", stage="S2")})
        out = e.run()
        self.assertEqual([r["id"] for r in out["ready"]], ["T-3"])
        reasons = {x["id"]: x["reason"] for x in out["excluded"]}
        self.assertEqual(reasons["T-1"], "geste-humain-en-attente")
        self.assertEqual(reasons["T-4"], "etape-fermee:S2")

    def test_cycle_is_reported(self):
        e = Env(self, {"T-1": dict(perimeter="apps/a/", deps="[T-2]"), "T-2": dict(perimeter="apps/b/", deps="[T-1]")})
        with self.assertRaises(nxt.CycleError):
            e.run()

    def test_overlap_report_serialization(self):
        e = Env(self, {"T-1": dict(perimeter="tests/"), "T-2": dict(perimeter="tests/a/", deps="[T-1]"),
                 "T-3": dict(perimeter="tests/b/")})
        rep = nxt.overlap_report(nxt.load_tickets(e.backlog), ["T-1", "T-2", "T-3"])
        by = {(p["a"], p["b"]): p["serialized"] for p in rep["pairs"]}
        self.assertTrue(by[("T-1", "T-2")])
        self.assertFalse(by[("T-1", "T-3")])
        self.assertNotIn(("T-2", "T-3"), by)  # tests/a/ et tests/b/ ne se recoupent pas


class Sortie(unittest.TestCase):
    def test_json_is_stable_and_versioned_on_real_backlog(self):
        outs = []
        for _ in range(2):
            buf = io.StringIO()
            with redirect_stdout(buf):
                self.assertEqual(nxt.main([]), 0)
            outs.append(buf.getvalue())
        self.assertEqual(outs[0], outs[1])
        d = json.loads(outs[0])
        self.assertEqual(d["schema"], "ready.v1")
        self.assertEqual(set(d), {"schema", "open_stage", "ready", "held_overlap", "excluded", "in_progress"})
        ready = d["ready"]
        for a in ready:
            for b in ready:
                if a is not b:
                    self.assertIsNone(admission.any_overlap(a["perimeter"], b["perimeter"]))

    def test_next_launches_nothing(self):
        src = (ROOT / "tools" / "backlog" / "next.py").read_text(encoding="utf-8")
        for banned in ("subprocess", "os.system", "urllib", "requests", "open("):
            self.assertNotIn(banned, src)


if __name__ == "__main__":
    unittest.main()
