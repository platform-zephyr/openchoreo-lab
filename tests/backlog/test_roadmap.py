"""Tests de tools/backlog/roadmap.py : le script s'exécute à l'import (pas de fonction), donc il est lancé par `exec`
sur une racine factice (tmp) ; le vrai ROADMAP.md n'est jamais touché."""
import contextlib
import io
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "tools" / "backlog" / "roadmap.py"


def ticket(tid: str, status: str = "todo", stage: str = "S0", deps: str = "[]", cls: str = "AUTONOME",
           model: str = "claude-sonnet-5-5", velocity: str = "false", body: str = "") -> str:
    return (f"---\nid: {tid}\ntitle: \"Titre {tid}\"\nstatus: {status}\ndepends_on: {deps}\nclass: {cls}\n"
            f"velocity: {velocity}\nlane: ci\nstage: {stage}\nmodel: {model}\neffort: high\n---\n# {tid}\n{body}\n")


class RoadmapTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        (self.root / "backlog").mkdir()
        (self.root / "tools" / "backlog").mkdir(parents=True)

    def add(self, name: str, text: str) -> None:
        (self.root / "backlog" / name).write_text(text, encoding="utf-8")

    def run_roadmap(self) -> tuple[str, str]:
        fake = str(self.root / "tools" / "backlog" / "roadmap.py")
        # `__file__` est remplacé dans le source (et non dans les globals) pour que `coverage` rattache l'exécution
        # au vrai fichier ; la racine déduite par le script est alors la racine factice.
        src = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("__file__", src)
        code = compile(src.replace("__file__", repr(fake)), str(SCRIPT), "exec")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            exec(code, {"__file__": str(SCRIPT), "__name__": "roadmap"})
        return (self.root / "backlog" / "ROADMAP.md").read_text(encoding="utf-8"), out.getvalue()

    def test_ordre_vagues_et_sections(self):
        self.add("T-901-a.md", ticket("T-901", velocity="true"))
        self.add("T-902-b.md", ticket("T-902", deps="[T-901]", stage="S1", cls="MANDAT"))
        self.add("T-903-c.md", ticket("T-903", deps="[T-902]", stage="PORTE", cls="REVUE", model="claude-opus-5-5"))
        self.add("T-904-d.md", ticket("T-904", status="deferred"))
        self.add("T-905-e.md", ticket("T-905", status="dropped"))
        self.add("T-906-f.md", ticket("T-906", model="human", cls="MANDAT"))
        md, out = self.run_roadmap()
        self.assertIn("# Feuille de route", md)
        self.assertIn("## Chemin critique (3 vagues)", md)
        self.assertLess(md.index("## S0 —"), md.index("## PORTE —"))
        self.assertIn("Jusqu'à la porte (3 vagues)", md)
        self.assertIn("Gelés jusqu'à la porte ou bloqués par un déclencheur (1)", md)
        self.assertIn("Absorbés ou supprimés (1)", md)
        self.assertIn("Gestes purement humains", md)
        self.assertIn("opus/high", md)
        self.assertIn("todo 4 gelés 1 abandonnés 1", out)

    def test_seuls_les_todo_sont_planifies(self):
        self.add("T-901-a.md", ticket("T-901", status="done"))
        self.add("T-902-b.md", ticket("T-902", deps="[T-901]"))
        md, _ = self.run_roadmap()
        self.assertNotIn("| [T-901]", md)
        self.assertIn("| [T-902]", md)

    def test_pilote_t322_liste_figee_et_prerequis(self):
        self.add("T-901-a.md", ticket("T-901"))
        self.add("T-902-b.md", ticket("T-902", deps="[T-901]", stage="S1"))
        self.add("T-322-pilote.md", ticket("T-322", deps="[T-901]", stage="S1",
                                           body="Liste figée du pilote (2) : T-902, T-999\n"))
        md, _ = self.run_roadmap()
        self.assertIn("## Lancement 24/7", md)
        self.assertIn("Prérequis : S0 minimal (1 tickets)", md)
        self.assertIn("Liste figée du pilote (2 tickets", md)
        self.assertIn("| T-999 | (absent ou non `todo`)", md)  # ticket cité mais inexistant

    def test_sans_t322_pas_de_section_pilote(self):
        self.add("T-901-a.md", ticket("T-901"))
        md, _ = self.run_roadmap()
        self.assertNotIn("Lancement 24/7", md)

    def test_ticket_sans_champ_obligatoire_echoue(self):
        self.add("T-901-a.md", "---\nid: T-901\nstatus: todo\n---\n# x\n")
        with self.assertRaises(AttributeError):  # `g()` : champ absent, regex sans correspondance
            self.run_roadmap()

    def test_aucun_ticket_echoue(self):
        with self.assertRaises(ValueError):  # max() sur un ensemble vide
            self.run_roadmap()


if __name__ == "__main__":
    unittest.main()
