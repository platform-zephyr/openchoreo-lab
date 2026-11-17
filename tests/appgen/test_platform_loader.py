"""Régression : platform/ contient des blueprints Authentik (tags !Find, !KeyOf) que le chargeur doit tolérer."""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools" / "appgen"))
import appgen  # noqa: E402


class PlatformLoaderTolerance(unittest.TestCase):
    def test_authentik_tags_do_not_break_loading(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "identity").mkdir()
            (root / "identity" / "bp.yaml").write_text(
                "version: 1\nentries:\n  - model: x\n    identifiers: {pk: !Find [a.b, [name, n]]}\n    attrs: {g: !KeyOf grp}\n",
                encoding="utf-8")
            (root / "t.yaml").write_text(
                "apiVersion: openchoreo.dev/v1alpha1\nkind: ClusterTrait\nmetadata: {name: demo}\nspec: {}\n", encoding="utf-8")
            index = appgen.load_platform(root)
            self.assertIn(("ClusterTrait", "demo"), index)


if __name__ == "__main__":
    unittest.main()
