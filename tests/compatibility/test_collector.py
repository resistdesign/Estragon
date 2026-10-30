"""Failure-detection contract for the C01 collector, independent of Godot."""
import importlib.util
from pathlib import Path
import os
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("collector", Path(__file__).resolve().parents[2] / "tools/check-compatibility.py")
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)


class CollectorTests(unittest.TestCase):
    def test_engine_error_beats_zero_exit_and_success_marker(self):
        for message in ["SCRIPT ERROR: bad", "ERROR: bad", "Parse Error: bad", "Assertion failed: bad"]:
            self.assertEqual(collector.classify(0, message + "\nOK\n", "OK"), "FAIL")

    def test_missing_marker_nonzero_and_timeout(self):
        self.assertEqual(collector.classify(0, "almost OK", "OK"), "FAIL")
        self.assertEqual(collector.classify(1, "OK\n", "OK"), "FAIL")
        self.assertEqual(collector.classify(0, "OK\n", "OK", True), "FAIL")
        self.assertEqual(collector.classify(0, "OK\n", "OK"), "PASS")

    def test_real_child_errors_and_hangs(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            for code, marker, timeout in [
                ("print('ERROR: engine returned zero'); print('OK')", "OK", 5),
                ("print('exited early')", "OK", 5),
                ("import time; time.sleep(10)", None, 0.05),
            ]:
                result = collector.execute([sys.executable, "-c", code], directory,
                                           dict(os.environ), directory / "result.log", marker,
                                           timeout=timeout)
                self.assertEqual(result["status"], "FAIL")

    def test_expected_negative_still_requires_completion(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            result = collector.execute([sys.executable, "-c", "print('SCRIPT ERROR: parser broke')"],
                directory, dict(os.environ), directory / "negative.log", "EXPECTED_OK",
                expected_errors=True)
            self.assertEqual(result["status"], "FAIL")


if __name__ == "__main__":
    unittest.main()
