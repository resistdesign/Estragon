#!/usr/bin/env python3
"""Create the reviewable committed snapshot from complete raw collector reports.

Raw command logs/results remain CI artifacts. This snapshot preserves every
stage's status, engine API metadata and per-file parse outcomes without copying
temporary command paths or repeating successful engine banners.
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--report", type=Path, action="append", required=True)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--scope", default="C01-A audit; not release certification")
args = parser.parse_args()
snapshot = {"schema_version": 1, "scope": args.scope,
            "raw_reports": [], "engines": []}
versions = set()
for path in args.report:
    report = json.loads(path.read_text())
    assert report["schema_version"] == 1
    snapshot["raw_reports"].append({key: report[key] for key in [
        "date", "platform", "source_commit", "source_dirty", "collect_only"]} | {
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    for engine in report["engines"]:
        version = engine["version"]
        assert version not in versions, "duplicate engine: " + version
        versions.add(version)
        row = {key: engine[key] for key in ["label", "version", "input_binary_sha256", "api"]}
        if "numeric_evidence" in engine:
            row["numeric_evidence"] = engine["numeric_evidence"]
        row["stages"] = {}
        for name, stage in engine["stages"].items():
            assert stage["status"] in ["PASS", "FAIL", "BLOCKED", "UNTESTED"]
            compact = {key: stage[key] for key in ["status", "reason", "exit_code", "timeout",
                       "aborted_on_error", "log"] if key in stage}
            if "log" in stage:
                log = path.parent / engine["label"] / stage["log"]
                compact["log_sha256"] = hashlib.sha256(log.read_bytes()).hexdigest()
                if stage["status"] == "FAIL":
                    compact["diagnostics"] = stage["diagnostics"][:8]
                    compact["log_tail"] = log.read_text().splitlines()[-16:]
            if "scripts" in stage:
                compact["total"] = len(stage["scripts"])
                compact["passed"] = sum(item["status"] == "PASS" for item in stage["scripts"])
                compact["scripts"] = [{key: item[key] for key in ["source", "status", "log"]}
                                      for item in stage["scripts"]]
            row["stages"][name] = compact
        snapshot["engines"].append(row)
expected = {item["version"] for item in json.loads((ROOT / "tests/compatibility/engines.json").read_text())}
assert versions == expected, "snapshot must include every pinned engine: " + repr(expected - versions)
snapshot["engines"].sort(key=lambda item: [int(part) for part in item["version"].split(".stable")[0].split(".")])
args.output.write_text(json.dumps(snapshot, indent=2) + "\n")
print("Wrote", len(versions), "engine records to", args.output)
