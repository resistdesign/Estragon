"""Failure-detection contract for the C01 collector, independent of Godot."""
import importlib.util
import contextlib
import io
from pathlib import Path
import os
import sys
import tempfile
import unittest
from unittest.mock import patch

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

    def test_positive_error_stops_hung_engine_and_retains_diagnostic(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            result = collector.execute([sys.executable, "-u", "-c",
                "import time; print('SCRIPT ERROR: direct root cause'); time.sleep(10)"],
                directory, dict(os.environ), directory / "error.log", "OK",
                timeout=5, abort_on_error=True)
            self.assertEqual(result["status"], "FAIL")
            self.assertTrue(result["aborted_on_error"])
            self.assertFalse(result["timeout"])
            self.assertIn("direct root cause", result["diagnostics"][0])

    def test_failed_startup_is_never_promoted_by_successful_collection(self):
        # E01's evidence shell can exit successfully after detecting bad startup.
        # Prove both CLI modes preserve that failed product outcome in JSON.
        observation = {"label": "test", "stages": {
            "editor_fixture": {"status": "PASS"}, "addon_startup": {"status": "FAIL"}}}
        with tempfile.TemporaryDirectory() as directory:
            for collect_only in [False, True]:
                output = Path(directory) / ("audit" if collect_only else "gate")
                argv = ["collector", "--engine", "test=/unused", "--output", str(output)]
                if collect_only:
                    argv.append("--collect-only")
                with patch.object(sys, "argv", argv), patch.object(collector, "audit", return_value=observation), contextlib.redirect_stdout(io.StringIO()):
                    code = collector.main()
                self.assertEqual(code, 0 if collect_only else 1)
                report = collector.json.loads((output / "results.json").read_text())
                self.assertEqual(report["engines"][0]["stages"]["addon_startup"]["status"], "FAIL")


if __name__ == "__main__":
    unittest.main()
