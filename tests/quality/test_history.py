"""Tests de l'historique quality.v1 (T-421) : schéma, cas négatifs, une ligne par merge, docstrings."""

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("quality_history", ROOT / "tools" / "quality" / "history.py")
assert SPEC and SPEC.loader
history = importlib.util.module_from_spec(SPEC)
sys.modules["quality_history"] = history
SPEC.loader.exec_module(history)

SCHEMA = json.loads((ROOT / "docs" / "schema" / "quality.v1.json").read_text(encoding="utf-8"))


def good() -> dict:
    return {
        "schema": "quality.v1", "date": "2026-11-18T10:00:00Z", "commit": "a" * 40, "cc_max": 20, "cc_p95": 7,
        "functions_gt_15": 3, "files_gt_400_lines": 2, "ruff_errors": 5, "mypy_errors": 1,
        "coverage": {"appgen_percent": 88.5, "total_percent": 70.0}, "shellcheck_issues": None,
        "docstring_percent": 61.2, "touched_files": ["tools/quality/check.py"],
    }


class Schema(unittest.TestCase):
    def test_valid_line(self):
        self.assertEqual(history.validate(good(), SCHEMA), [])

    def test_coverage_null_accepted(self):
        line = {**good(), "coverage": None}
        self.assertEqual(history.validate(line, SCHEMA), [])

    def test_missing_field(self):
        line = good()
        del line["cc_max"]
        self.assertIn("cc_max requis", history.validate(line, SCHEMA))

    def test_unknown_field_refused(self):
        self.assertIn("token inconnu", history.validate({**good(), "token": "x"}, SCHEMA))

    def test_wrong_type_and_bool(self):
        self.assertTrue(history.validate({**good(), "cc_max": "20"}, SCHEMA))
        self.assertTrue(history.validate({**good(), "cc_max": True}, SCHEMA))

    def test_negative_and_out_of_range(self):
        self.assertTrue(history.validate({**good(), "ruff_errors": -1}, SCHEMA))
        self.assertTrue(history.validate({**good(), "docstring_percent": 101}, SCHEMA))

    def test_bad_commit_and_date(self):
        self.assertTrue(history.validate({**good(), "commit": "xyz"}, SCHEMA))
        self.assertTrue(history.validate({**good(), "date": "hier"}, SCHEMA))

    def test_wrong_schema_const(self):
        self.assertTrue(history.validate({**good(), "schema": "quality.v2"}, SCHEMA))

    def test_nested_coverage_errors(self):
        line = {**good(), "coverage": {"appgen_percent": 120, "total_percent": 1, "x": 1}}
        errors = history.validate(line, SCHEMA)
        self.assertIn("coverage.x inconnu", errors)
        self.assertTrue(any("appgen_percent" in e for e in errors))


class Append(unittest.TestCase):
    def test_one_line_per_commit(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "h.jsonl"
            self.assertEqual(history.append_line(path, good(), SCHEMA), "ajoutee")
            self.assertEqual(history.append_line(path, good(), SCHEMA), "deja-presente")
            other = {**good(), "commit": "b" * 40}
            self.assertEqual(history.append_line(path, other, SCHEMA), "ajoutee")
            self.assertEqual(len(path.read_text(encoding="utf-8").splitlines()), 2)

    def test_invalid_line_not_written(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "h.jsonl"
            with self.assertRaises(ValueError):
                history.append_line(path, {**good(), "cc_max": -3}, SCHEMA)
            self.assertFalse(path.exists())


class Docstrings(unittest.TestCase):
    def test_percent(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "a.py").write_text('"""Module."""\n\ndef f():\n    """Doc."""\n\ndef g():\n    pass\n\ndef _p():\n    pass\n', encoding="utf-8")
            self.assertEqual(history.docstring_percent(root, ["a.py"]), 66.7)

    def test_empty_is_100(self):
        self.assertEqual(history.docstring_percent(Path("."), []), 100.0)

    def test_syntax_error_raises(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "b.py").write_text("def (:\n", encoding="utf-8")
            with self.assertRaises(SyntaxError):
                history.docstring_percent(Path(tmp), ["b.py"])


if __name__ == "__main__":
    unittest.main()
