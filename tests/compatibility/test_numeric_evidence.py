"""Failure detection for independent numeric oracles and native-semantic limits."""
import copy
import importlib.util
import json
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("numeric_evidence", ROOT / "tools/numeric_evidence.py")
evidence = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evidence)


class NumericEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.fixture = json.loads((ROOT / "tests/compatibility/numeric_cases.json").read_text())
        self.rows = {}
        for group in ["cases", "native_parser_limits"]:
            self.rows[group] = [dict(item, model_bits=item["expected_bits"], runtime_bits=item["expected_bits"],
                raw_conversion_bits=item["expected_bits"], direct_literal_bits=item["expected_bits"],
                storage_bits=item["expected_bits"], deterministic_and_mapped=True,
                native_value_preserved=True, status="PASS") for item in self.fixture[group]]

        self.rows["rejected_cases"] = [dict(source=text, rejected=True, no_output=True, source_located=True,
            finite_domain_diagnostic=True) for text in self.fixture["rejected_cases"]]

    def output(self):
        return "\n".join(prefix + json.dumps(row) for group, prefix in [
            ("cases", "C01_NUMERIC_CASE "), ("native_parser_limits", "C01_NUMERIC_NATIVE_LIMIT "),
            ("rejected_cases", "C01_NUMERIC_REJECTION ")]
            for row in self.rows[group])

    def test_checked_oracles_match_independent_binary64_conversion(self):
        for item in self.fixture["cases"] + self.fixture["native_parser_limits"]:
            number = float(item["source"])
            expected = struct.pack("<d", number if number != 0 else 0.0).hex()
            self.assertEqual(expected, item["expected_bits"], item["source"])

    def test_complete_correctly_rounded_engine_profile(self):
        result = evidence.validate_numeric(self.output(), self.fixture)
        self.assertEqual(len(result["cases"]), 27)

    def test_missing_and_duplicate_observations_rejected(self):
        original = copy.deepcopy(self.rows)
        for changed in [original["cases"][:-1], original["cases"] + original["cases"][:1]]:
            self.rows["cases"] = changed
            with self.assertRaises(ValueError):
                evidence.validate_numeric(self.output(), self.fixture)

    def test_false_pass_for_changed_runtime_rejected(self):
        self.rows["cases"][5]["runtime_bits"] = "ffffffffffffffff"
        with self.assertRaises(ValueError):
            evidence.validate_numeric(self.output(), self.fixture)

    def test_native_limit_preservation_does_not_claim_ieee_success(self):
        row = self.rows["native_parser_limits"][0]
        for field in ["model_bits", "runtime_bits", "raw_conversion_bits", "direct_literal_bits"]:
            row[field] = "0000000000000000"
        row["status"] = "BLOCKED"
        result = evidence.validate_numeric(self.output(), self.fixture)
        self.assertEqual(result["native_parser_limits"][0]["status"], "BLOCKED")
        row["runtime_bits"] = "ffffffffffffffff"
        with self.assertRaises(ValueError):
            evidence.validate_numeric(self.output(), self.fixture)

    def test_changed_oracle_storage_or_map_rejected(self):
        for field, value in [("expected_bits", "wrong"), ("storage_bits", "wrong"),
                             ("deterministic_and_mapped", False)]:
            original = self.rows["cases"][0][field]
            self.rows["cases"][0][field] = value
            with self.assertRaises(ValueError):
                evidence.validate_numeric(self.output(), self.fixture)
            self.rows["cases"][0][field] = original

    def test_invalid_numeric_value_cannot_pass_as_rejected(self):
        self.rows["rejected_cases"][0]["rejected"] = False
        with self.assertRaises(ValueError):
            evidence.validate_numeric(self.output(), self.fixture)
