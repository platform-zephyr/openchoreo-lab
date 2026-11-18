"""T-003 (ADR-0004, ecart G3) : Environments development/production, pins de release par environnement,
`appgen promote` et `appgen rollback`.

Lancer : python3 -m unittest discover -s tests/appgen -v   (depuis la racine du depot)
Aucun cluster : tout est statique (rendu en memoire, manifeste de plateforme, script de bootstrap lu en texte).

Regles testees :
  - development suit toujours la release courante ;
  - production suit le pin `pins/component-releases.yaml` (`<composant>/production`) ;
  - sans pin, une app production seule garde la release courante (sortie de generated/ inchangee) ;
  - une app en development ET production sans pin de production est refusee (G3 : la meme release partirait
    dans les deux environnements) ;
  - promote = pin de production sur la release du ReleaseBinding development de generated/ ;
  - rollback = pin de production sur une release conservee (A2) du composant.
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "appgen"))
sys.path.insert(0, str(ROOT / "tests" / "appgen"))

import appgen  # noqa: E402
from appgenlib import config as appgen_config  # noqa: E402
from test_extensions import Base, whoami  # noqa: E402
from test_gitops_fixes import BASE_WHOAMI, releases_of, write_generated  # noqa: E402

MANIFEST = ROOT / "platform" / "install" / "manifests" / "40-openchoreo-env.yaml"
BOOTSTRAP = ROOT / "tools" / "k3d" / "ci-bootstrap.sh"
RB_DIR = f"{BASE_WHOAMI}/components/whoami/release-bindings"


def rb(files: dict, env: str) -> str:
    return files[f"{RB_DIR}/whoami-{env}.yaml"]["spec"]["releaseName"]


def both_envs() -> dict:
    doc = whoami()
    doc["spec"]["environments"] = ["development", "production"]
    return doc


def dev_only() -> dict:
    doc = whoami()
    doc["spec"]["environments"] = ["development"]
    return doc


class PromotionBase(Base):
    def setUp(self):
        super().setUp()
        self.pins = self.sb.root / "pins" / "component-releases.yaml"
        old_root, old_pins = appgen_config.ROOT, appgen_config.RELEASE_PINS_PATH
        appgen_config.ROOT, appgen_config.RELEASE_PINS_PATH = self.sb.root, self.pins
        self.addCleanup(setattr, appgen_config, "ROOT", old_root)
        self.addCleanup(setattr, appgen_config, "RELEASE_PINS_PATH", old_pins)

    def write_pins(self, pins: dict) -> None:
        self.pins.parent.mkdir(parents=True, exist_ok=True)
        self.pins.write_text(yaml.safe_dump({"pins": pins}), encoding="utf-8")

    def deploy(self, doc: dict) -> dict:
        """Rend et ecrit generated/ (etat apres merge d'une PR)."""
        self.sb.add(doc)
        files = self.sb.render()
        write_generated(self.sb, files)
        return files

    def change_image_env(self, doc: dict, value: str) -> dict:
        doc["spec"]["runtime"]["env"] = {"WHOAMI_NAME": value}
        return doc


class PinsPerEnvironment(PromotionBase):
    def test_production_only_without_pin_follows_current_release(self):
        # Non-regression : les apps existantes (production seule, aucun pin) gardent leur rendu.
        self.sb.add(whoami())
        files = self.sb.render()
        self.assertEqual(rb(files, "production"), Path(next(iter(releases_of(files)))).stem)

    def test_dev_and_prod_without_production_pin_refused(self):
        self.sb.add(both_envs())
        with self.assertRaisesRegex(appgen.AppError, "promote"):
            self.sb.render()

    def test_dev_change_leaves_production_release_unchanged(self):
        first = self.deploy(dev_only())
        v1 = rb(first, "development")
        self.write_pins({"whoami/production": v1})
        second = self.deploy(both_envs())
        self.assertEqual(rb(second, "production"), v1)
        changed = self.change_image_env(both_envs(), "v2")
        self.sb.add(changed)
        third = self.sb.render()
        self.assertNotEqual(rb(third, "development"), v1, "development suit la release courante")
        self.assertEqual(rb(third, "production"), v1, "production reste sur la release epinglee")
        self.assertIn(f"{BASE_WHOAMI}/components/whoami/releases/{v1}.yaml", third)

    def test_pin_to_unknown_release_refused(self):
        self.write_pins({"whoami/production": "whoami-0123456789"})
        self.sb.add(both_envs())
        with self.assertRaisesRegex(appgen.AppError, "whoami-0123456789"):
            self.sb.render()

    def test_pin_on_production_only_app_applies(self):
        first = self.deploy(whoami())
        v1 = rb(first, "production")
        self.write_pins({"whoami/production": v1})
        self.sb.add(self.change_image_env(whoami(), "v2"))
        self.assertEqual(rb(self.sb.render(), "production"), v1)

    def test_render_is_stable_with_pins(self):
        first = self.deploy(dev_only())
        self.write_pins({"whoami/production": rb(first, "development")})
        second = self.deploy(both_envs())
        self.assertEqual(self.sb.render(), second)


class PromoteCommand(PromotionBase):
    def test_promote_pins_development_release(self):
        first = self.deploy(dev_only())
        v1 = rb(first, "development")
        self.assertEqual(appgen.main(["promote", "whoami"]), 0)
        self.assertEqual(appgen.load_yaml(self.pins)["pins"], {"whoami/production": v1})
        self.sb.add(both_envs())
        files = self.sb.render()
        self.assertEqual(rb(files, "production"), v1)
        self.assertEqual(rb(files, "development"), v1)

    def test_promote_moves_production_to_new_dev_release(self):
        first = self.deploy(dev_only())
        self.write_pins({"whoami/production": rb(first, "development")})
        self.deploy(both_envs())
        second = self.deploy(self.change_image_env(both_envs(), "v2"))
        v2 = rb(second, "development")
        self.assertEqual(appgen.main(["promote", "whoami"]), 0)
        self.assertEqual(appgen.load_yaml(self.pins)["pins"]["whoami/production"], v2)
        self.assertEqual(rb(self.sb.render(), "production"), v2)

    def test_promote_without_development_binding_fails(self):
        self.deploy(whoami())
        self.assertEqual(appgen.main(["promote", "whoami"]), 1)
        self.assertFalse(self.pins.exists())

    def test_promote_unknown_app_fails(self):
        self.assertEqual(appgen.main(["promote", "absente"]), 1)


class RollbackCommand(PromotionBase):
    def _two_releases(self) -> tuple[str, str]:
        first = self.deploy(dev_only())
        v1 = rb(first, "development")
        self.write_pins({"whoami/production": v1})
        self.deploy(both_envs())
        second = self.deploy(self.change_image_env(both_envs(), "v2"))
        v2 = rb(second, "development")
        self.assertEqual(appgen.main(["promote", "whoami"]), 0)
        return v1, v2

    def test_rollback_repoints_previous_release(self):
        v1, v2 = self._two_releases()
        self.assertEqual(appgen.main(["rollback", "whoami", v1]), 0)
        self.assertEqual(appgen.load_yaml(self.pins)["pins"]["whoami/production"], v1)
        files = self.sb.render()
        self.assertEqual(rb(files, "production"), v1)
        self.assertEqual(rb(files, "development"), v2, "le rollback de production ne touche pas development")

    def test_rollback_to_unknown_release_refused(self):
        _, v2 = self._two_releases()
        self.assertEqual(appgen.main(["rollback", "whoami", "whoami-0123456789"]), 1)
        self.assertEqual(appgen.load_yaml(self.pins)["pins"]["whoami/production"], v2)

    def test_rollback_to_release_of_other_component_refused(self):
        self._two_releases()
        self.assertEqual(appgen.main(["rollback", "whoami", "miniflux-0123456789"]), 1)


class EnvironmentManifest(unittest.TestCase):
    def setUp(self):
        self.docs = [d for d in yaml.safe_load_all(MANIFEST.read_text(encoding="utf-8")) if d]

    def env(self, name: str) -> dict:
        return next(d for d in self.docs if d["kind"] == "Environment" and d["metadata"]["name"] == name)

    def test_development_environment_declared(self):
        dev, prod = self.env("development"), self.env("production")
        self.assertIs(dev["spec"]["isProduction"], False)
        self.assertIs(prod["spec"]["isProduction"], True)
        self.assertEqual(dev["metadata"]["namespace"], "default")
        self.assertEqual(dev["metadata"]["labels"]["openchoreo.dev/name"], "development")
        # Meme data plane (ADR-0004 §1) et meme passerelle que production (rendu des apps privees, G1).
        self.assertEqual(dev["spec"]["dataPlaneRef"], prod["spec"]["dataPlaneRef"])
        self.assertEqual(dev["spec"]["gateway"], prod["spec"]["gateway"])

    def test_pipeline_promotes_development_to_production(self):
        pipe = next(d for d in self.docs if d["kind"] == "DeploymentPipeline")
        self.assertEqual(pipe["metadata"]["name"], appgen_config.PIPELINE)
        self.assertEqual(pipe["spec"]["promotionPaths"], [{
            "sourceEnvironmentRef": {"kind": "Environment", "name": "development"},
            "targetEnvironmentRefs": [{"kind": "Environment", "name": "production"}],
        }])

    def test_environments_match_appgen_contract(self):
        names = {d["metadata"]["name"] for d in self.docs if d["kind"] == "Environment"}
        self.assertEqual(names, appgen_config.ALLOWED_ENVIRONMENTS)


class K3dBootstrapNoInvention(unittest.TestCase):
    def test_bootstrap_does_not_derive_development(self):
        text = BOOTSTRAP.read_text(encoding="utf-8")
        self.assertFalse('.metadata.name = "development"' in text, "Environment development derive par yq")
        self.assertFalse("CONTOURNEMENT CI" in text, "contournement CI encore present")
        self.assertTrue('"$M/40-openchoreo-env.yaml"' in text, "le bootstrap doit appliquer le manifeste")
        self.assertFalse(any(line.lstrip().startswith(("yq ", "need ")) and " yq" in f" {line}"
                             for line in text.splitlines()), "yq ne sert plus au bootstrap")


if __name__ == "__main__":
    unittest.main()
