"""Language/compiler contract tests; runnable without Godot."""

import json
from pathlib import Path
import unittest

from tools.gogo import GogoError, compile_source

PREFIX = '<gogo:View xmlns:gogo="urn:estragon:gogo:1" width="100" height="80">'
SUFFIX = "</gogo:View>"


class GogoCompilerTests(unittest.TestCase):
    def compile_child(self, content: str):
        return compile_source(PREFIX + content + SUFFIX)

    def test_compiles_rect_into_ui_ir_not_godot_nodes(self):
        ir = self.compile_child(
            '<gogo:Rect id="r" x="2" y="3" width="20" height="12" '
            'fill="#AABBCC" />'
        )
        self.assertEqual(ir["format"], "estragon.gogo.ir")
        self.assertEqual(ir["version"], 1)
        self.assertEqual(ir["root"]["type"], "View")
        self.assertEqual(ir["root"]["children"], [{
            "type": "Rect",
            "id": "r",
            "props": {
                "x": 2, "y": 3, "width": 20, "height": 12,
                "fill": "#aabbccff",
            },
        }])
        self.assertNotIn("Control", str(ir))

    def test_optional_position_defaults_and_alpha_are_preserved(self):
        ir = self.compile_child(
            '<gogo:Rect width="1.5" height="2" fill="#11223380" />'
        )
        self.assertEqual(ir["root"]["children"][0]["props"], {
            "x": 0, "y": 0, "width": 1.5, "height": 2, "fill": "#11223380",
        })

    def test_rejects_unknown_component(self):
        with self.assertRaisesRegex(GogoError, "Unsupported Gogo component"):
            self.compile_child('<gogo:Button />')

    def test_rejects_godot_controls_in_markup(self):
        with self.assertRaisesRegex(GogoError, "Unsupported Gogo component"):
            self.compile_child('<gogo:VBoxContainer />')

    def test_rejects_duplicate_ids(self):
        with self.assertRaisesRegex(GogoError, "Duplicate component id"):
            self.compile_child(
                '<gogo:Rect id="same" width="1" height="1" fill="#ffffff" />'
                '<gogo:Rect id="same" width="1" height="1" fill="#000000" />'
            )

    def test_rejects_bad_color(self):
        with self.assertRaisesRegex(GogoError, "#RRGGBB"):
            self.compile_child(
                '<gogo:Rect width="1" height="1" fill="red" />'
            )

    def test_rejects_non_finite_dimensions(self):
        with self.assertRaisesRegex(GogoError, "finite"):
            self.compile_child(
                '<gogo:Rect width="nan" height="1" fill="#ffffff" />'
            )

    def test_rejects_zero_dimensions(self):
        with self.assertRaisesRegex(GogoError, "positive"):
            self.compile_child(
                '<gogo:Rect width="0" height="1" fill="#ffffff" />'
            )

    def test_rejects_unsupported_binding_expression_for_now(self):
        with self.assertRaisesRegex(GogoError, "must be a number"):
            self.compile_child(
                '<gogo:Rect width="{count}" height="1" fill="#ffffff" />'
            )

    def test_rejects_malformed_xml(self):
        with self.assertRaisesRegex(GogoError, "Malformed Gogo XML"):
            compile_source("<broken")

    def test_rejects_wrong_namespace(self):
        with self.assertRaisesRegex(GogoError, "Gogo namespace"):
            compile_source('<View width="1" height="1" />')

    def test_rejects_nested_view(self):
        with self.assertRaisesRegex(GogoError, "Unsupported Gogo component"):
            self.compile_child('<gogo:View width="1" height="1" />')

    def test_rejects_unknown_attribute(self):
        with self.assertRaisesRegex(GogoError, "unsupported attributes"):
            self.compile_child(
                '<gogo:Rect width="1" height="1" fill="#ffffff" '
                'godot_node="true" />'
            )

    def test_committed_example_matches_compiler(self):
        root = Path(__file__).resolve().parents[1] / "examples" / "hello"
        source = (root / "Main.gogo").read_text(encoding="utf-8")
        expected = json.loads(
            (root / "generated" / "Main.gogo.json").read_text(encoding="utf-8")
        )
        self.assertEqual(compile_source(source), expected)


if __name__ == "__main__":
    unittest.main()
