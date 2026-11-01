#!/usr/bin/env python3
"""C01-E research collector: unsafe alternatives stay FAIL, not certification.
Uses isolated projects, official engine provenance and empty executable PATH.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile

from importlib.util import module_from_spec, spec_from_file_location

ROOT = Path(__file__).resolve().parents[1]
spec = spec_from_file_location("compatibility", ROOT / "tools/check-compatibility.py")
compatibility = module_from_spec(spec)
spec.loader.exec_module(compatibility)


def collect(engine, output):
    label, executable = engine.split("=", 1)
    target = output / label
    target.mkdir()
    record = {"label": label, "stages": {}}
    with tempfile.TemporaryDirectory(prefix="estragon-context-") as temporary:
        workspace = Path(temporary)
        binary = workspace / "godot"
        shutil.copy2(Path(executable).resolve(), binary)
        record["input_binary_sha256"] = hashlib.sha256(binary.read_bytes()).hexdigest()
        if platform.system() == "Darwin":
            subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", str(binary)],
                           check=True, capture_output=True)
        (workspace / "_sc_").touch()
        (workspace / "no-tools").mkdir()
        env = dict(os.environ, PATH=str(workspace / "no-tools"))
        for key in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
            folder = workspace / key.lower()
            folder.mkdir()
            env[key] = str(folder)
        record["version"] = subprocess.check_output(
            [str(binary), "--headless", "--version"], env=env, text=True).strip()
        known = next((entry for entry in json.loads(
            (ROOT / "tests/compatibility/engines.json").read_text())
            if entry["version"] == record["version"]), None)
        if not known or (platform.system() == "Darwin" and
                         known["binary_sha256"] != record["input_binary_sha256"]):
            raise ValueError("Engine differs from pinned official provenance")
        project = workspace / "project"
        shutil.copytree(ROOT / "tests/compatibility/script_context", project)
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="C01-E context probe"\n')
        base = [str(binary), "--headless", "--path", str(project)]
        record["stages"]["import"] = compatibility.index_project(
            binary, project, workspace, env, target / "import.log")
        for mode in ["cache", "paired", "collision", "alias", "ignore", "fresh"]:
            stage = compatibility.execute(base + ["--script", "res://probe.gd", "--", mode],
                                          workspace, env, target / (mode + ".log"))
            lines = (target / (mode + ".log")).read_text().splitlines()
            evidence = [json.loads(line.removeprefix("ESTRAGON_CONTEXT_EVIDENCE "))
                        for line in lines if line.startswith("ESTRAGON_CONTEXT_EVIDENCE ")]
            if len(evidence) != 1:
                stage["status"] = "FAIL"
            else:
                stage["evidence"] = evidence[0]
                if stage["status"] == "PASS": stage["status"] = evidence[0]["status"]
            record["stages"][mode] = stage
    (target / "report.json").write_text(json.dumps(record, indent=2) + "\n")
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", action="append", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    records = [collect(engine, args.output) for engine in args.engine]
    (args.output / "results.json").write_text(json.dumps(records, indent=2) + "\n")
    # Unsafe alternatives intentionally fail. This is evidence collection only.
    for record in records:
        print(record["version"], {key: stage["status"] for key, stage in record["stages"].items()})


if __name__ == "__main__":
    main()
