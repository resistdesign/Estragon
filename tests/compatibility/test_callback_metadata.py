"""Ensure collected evidence cannot hide missing controls or contradictory data."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("metadata", ROOT / "tools/callback_metadata_evidence.py")
metadata = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metadata)


class MetadataEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.engines = json.loads((ROOT / "tests/compatibility/c01-c-results.json").read_text())["engines"]

    def output(self, engine):
        evidence = engine["callback_metadata"]
        return "\n".join(
            ["ERROR: Can't get method on CallableCustom (lambda)"] * evidence["expected_metadata_errors"]
            + ["C01_CALLBACK_METADATA " + json.dumps(row) for row in evidence["observations"]])

    def test_all_recorded_engines(self):
        for engine in self.engines:
            with self.subTest(engine=engine["version"]):
                minor = int(engine["version"].split(".")[1])
                self.assertEqual(metadata.validate_metadata(self.output(engine), minor), engine["callback_metadata"])

    def test_missing_control_or_unexpected_engine_error_rejected(self):
        engine = self.engines[0]
        output = self.output(engine)
        for changed in ["\n".join(output.splitlines()[:-1]), output + "\nSCRIPT ERROR: unrelated failure"]:
            with self.assertRaises(ValueError):
                metadata.validate_metadata(changed, 0)

    def test_contradictory_reflection_connection_and_validity_rejected(self):
        for name, field, value in [("lambda_required", "method", "visible_signature"),
                                   ("method_required", "connect_error", 1),
                                   ("freed_target", "valid", True)]:
            engine = copy.deepcopy(self.engines[0])
            row = next(row for row in engine["callback_metadata"]["observations"] if row["name"] == name)
            row[field] = value
            with self.assertRaises(ValueError):
                metadata.validate_metadata(self.output(engine), 0)

    def test_wrong_modern_native_count_rejected(self):
        engine = copy.deepcopy(self.engines[-1])
        row = next(row for row in engine["callback_metadata"]["observations"] if row["name"] == "lambda_optional")
        row["native_count"] = 0
        with self.assertRaises(ValueError):
            metadata.validate_metadata(self.output(engine), 7)
