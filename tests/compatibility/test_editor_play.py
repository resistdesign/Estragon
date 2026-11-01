"""Reject false-positive expected-error Play runs without starting Godot."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("editor_play", Path(__file__).resolve().parents[2] / "tools/check-editor-play.py")
play = importlib.util.module_from_spec(spec)
spec.loader.exec_module(play)


class PlayErrors(unittest.TestCase):
    def test_only_scoped_negative_errors_are_allowed(self):
        expected = '\n'.join([
            'SCRIPT ERROR: Parse Error: Identifier "missing_handler" not declared in the current scope.',
            '    at: GDScript::reload (res://ui/generated/Counter.gd:26)',
            'SCRIPT ERROR: Parse Error: Cannot assign a value of type "String" as "int".',
            '    at: GDScript::reload (res://ui/generated/Counter.gd:3)',
            'ERROR: An EditorPlugin build callback failed.',
            'ui/Counter.gogo:3:1: Parse Error: Cannot assign a value of type String to variable count with specified type int.',
            "ERROR: Cannot save text file 'res://ui/Counter.gogo'.",
        ])
        self.assertEqual(play.unexpected_errors(expected), [])
        for error in ['SCRIPT ERROR: Invalid call. Nonexistent function save_all_scripts',
                      'SCRIPT ERROR: Assertion failed.', 'ERROR: unrelated failure',
                      'other.gogo:3:1: Parse Error: Cannot assign a value of type String']:
            self.assertEqual(play.unexpected_errors(expected + '\n' + error), [error])

    def test_same_message_from_other_script_is_rejected(self):
        error = 'SCRIPT ERROR: Parse Error: Cannot assign a value of type "String" as "int".'
        self.assertEqual(play.unexpected_errors(error + '\n at: GDScript::reload (res://unrelated.gd:3)'), [error])
        self.assertEqual(play.unexpected_errors(error), [error])
        failure = "ERROR: Cannot save text file 'res://unrelated.gd'."
        self.assertEqual(play.unexpected_errors(failure), [failure])


if __name__ == '__main__':
    unittest.main()
