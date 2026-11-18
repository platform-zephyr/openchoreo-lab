"""Tests du cliquet de maintenabilité (T-414) : dégradation refusée, refactor accepté, seuils du code neuf."""

import datetime
import importlib.util
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("quality_check", ROOT / "tools" / "quality" / "check.py")
assert SPEC and SPEC.loader
check = importlib.util.module_from_spec(SPEC)
sys.modules["quality_check"] = check
SPEC.loader.exec_module(check)


def _have(name: str) -> bool:
    if shutil.which(name) is not None:
        return True
    return subprocess.run([sys.executable, "-m", name, "--version"], capture_output=True, check=False).returncode == 0


HAVE_TOOLS = _have("radon") and _have("ruff")


def branchy(n: int, name: str = "f") -> str:
    """Source d'une fonction à n branches (complexité n + 1)."""
    lines = [f"def {name}(x):"]
    for i in range(n):
        lines += [f"    if x == {i}:", f"        return {i}"]
    return "\n".join([*lines, "    return -1"]) + "\n"


class PureRules(unittest.TestCase):
    @staticmethod
    def cur(funcs=None, files=None):
        return {"functions": funcs or {}, "files": files or {}}

    def test_new_function_hard_thresholds(self):
        ok = self.cur({"a.py::f": {"cc": 15, "len": 80}})
        bad = self.cur({"a.py::f": {"cc": 16, "len": 81}})
        self.assertEqual(check.check_functions({}, ok), [])
        self.assertEqual(len(check.check_functions({}, bad)), 2)

    def test_frozen_function_cannot_grow_but_can_shrink(self):
        base = {"functions": {"a.py::f": {"cc": 46}}}
        self.assertEqual(len(check.check_functions(base, self.cur({"a.py::f": {"cc": 47, "len": 10}}))), 1)
        self.assertEqual(check.check_functions(base, self.cur({"a.py::f": {"cc": 46, "len": 10}})), [])
        self.assertEqual(check.check_functions(base, self.cur({"a.py::f": {"cc": 20, "len": 10}})), [])

    def test_file_limits_and_tool_errors(self):
        base = {"files": {"a.py": {"lines": 700, "ruff": 3}}}
        same = self.cur(files={"a.py": {"lines": 700, "ruff": 3, "mypy": 0}})
        worse = self.cur(
            files={"a.py": {"lines": 701, "ruff": 4, "mypy": 1}, "b.py": {"lines": 601, "ruff": 0, "mypy": 0}}
        )
        self.assertEqual(check.check_files(base, same), [])
        self.assertEqual(len(check.check_files(base, worse)), 4)

    def test_baseline_keeps_only_what_exceeds(self):
        cur = self.cur(
            {"a.py::big": {"cc": 20, "len": 50}, "a.py::ok": {"cc": 3, "len": 5}, "a.py::long": {"cc": 4, "len": 90}},
            {"a.py": {"lines": 100, "ruff": 0, "mypy": 2}, "b.py": {"lines": 10, "ruff": 0, "mypy": 0}},
        )
        base = check.baseline_from(cur)
        self.assertEqual(base["functions"], {"a.py::big": {"cc": 20}, "a.py::long": {"len": 90}})
        self.assertEqual(base["files"], {"a.py": {"mypy": 2}})

    def test_diff_parsing_and_coverage(self):
        diff = "+++ b/tools/x.py\n@@ -1,0 +2,3 @@\n+a\n+b\n+c\n@@ -9 +12 @@\n+d\n+++ /dev/null\n"
        added = check.parse_added_lines(diff)
        self.assertEqual(added, {"tools/x.py": {2, 3, 4, 12}})
        cov = {"files": {"tools/x.py": {"executed_lines": [2, 3, 4], "missing_lines": [12]}}}
        self.assertEqual(check.diff_coverage(added, cov), (3, 4))

    @staticmethod
    def pkg_cov(**files):
        return {"files": {f"tools/appgen/appgenlib/{n}.py": {"summary": {"covered_lines": c, "num_statements": t}}
                          for n, (c, t) in files.items()}}

    def test_appgen_floor_targets_package(self):
        self.assertEqual(check.APPGEN, "tools/appgen/appgenlib/")
        self.assertEqual(check.check_coverage(self.pkg_cov(a=(85, 100))), [])
        self.assertEqual(len(check.check_coverage(self.pkg_cov(a=(84, 100)))), 1)

    def test_package_floor_aggregates_and_ignores_facade(self):
        cov = self.pkg_cov(a=(100, 100), b=(0, 100))  # agrégat 50 %
        cov["files"]["tools/appgen/appgen.py"] = {"summary": {"covered_lines": 5, "num_statements": 5}}
        self.assertEqual(len(check.check_coverage(cov)), 1)
        self.assertEqual(round(check.package_percent(self.pkg_cov(a=(9, 10), b=(1, 10))), 1), 50.0)

    def test_uncovered_package_fails_floor(self):
        self.assertEqual(len(check.check_coverage({"files": {}})), 1)
        facade_only = {"files": {"tools/appgen/appgen.py": {"summary": {"covered_lines": 5, "num_statements": 5}}}}
        self.assertEqual(len(check.check_coverage(facade_only)), 1)

    def test_report_fields(self):
        cur = self.cur(
            {"a::f": {"cc": 4, "len": 1}, "a::g": {"cc": 20, "len": 1}},
            {"a.py": {"lines": 401, "ruff": 2, "mypy": 1}},
        )
        rep = check.build_report(cur, None, "abc", datetime.datetime(2026, 11, 18, tzinfo=datetime.UTC))
        self.assertEqual(rep["schema"], "quality.v1")
        self.assertEqual((rep["cc_max"], rep["cc_p95"], rep["files_gt_400_lines"]), (20, 20, 1))
        self.assertEqual((rep["ruff_errors"], rep["mypy_errors"], rep["date"]), (2, 1, "2026-11-18T00:00:00Z"))


@unittest.skipUnless(HAVE_TOOLS, "radon et ruff requis")
class EndToEnd(unittest.TestCase):
    """Dégradation et refactor sur un mini-dépôt jetable, avec les vrais outils."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "tools").mkdir()
        (self.root / "tests").mkdir()
        self.src = self.root / "tools" / "m.py"
        self.base = self.root / "baseline.json"

    def tearDown(self):
        self.tmp.cleanup()

    def run_check(self, *extra):
        cmd = [sys.executable, str(ROOT / "tools" / "quality" / "check.py"), "--root", str(self.root)]
        return subprocess.run([*cmd, "--baseline", str(self.base), *extra], capture_output=True, text=True, check=False)

    def freeze(self, n):
        self.src.write_text(branchy(n))
        self.assertEqual(self.run_check("--write-baseline").returncode, 0)

    def test_degradation_fails(self):
        self.freeze(20)
        self.src.write_text(branchy(21))
        res = self.run_check()
        self.assertEqual(res.returncode, 1)
        self.assertIn("tools/m.py::f", res.stderr)

    def test_refactor_passes_without_touching_baseline(self):
        self.freeze(20)
        before = self.base.read_text()
        self.src.write_text(branchy(5))
        self.assertEqual(self.run_check().returncode, 0)
        self.assertEqual(self.base.read_text(), before)

    def test_new_complex_function_fails_and_simple_passes(self):
        self.freeze(3)
        self.src.write_text(branchy(3) + branchy(16, "g"))
        self.assertEqual(self.run_check().returncode, 1)
        self.src.write_text(branchy(3) + branchy(14, "g"))
        self.assertEqual(self.run_check().returncode, 0)

    def test_new_ruff_error_fails(self):
        self.freeze(2)
        self.src.write_text(branchy(2) + "import os\n")
        res = self.run_check()
        self.assertEqual(res.returncode, 1)
        self.assertIn("ruff", res.stderr)


if __name__ == "__main__":
    unittest.main()
