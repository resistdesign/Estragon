#!/usr/bin/env python3
"""C01-G real unsaved-buffer Play proof; contributor orchestration, not addon tooling."""
import argparse
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("compatibility", ROOT / "tools/check-compatibility.py")
compatibility = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compatibility)


def unexpected_errors(text):
    allowed = re.compile(r'(?:(?:SCRIPT ERROR: |ui/Counter\.gogo:\d+:\d+: )Parse Error: (?:Identifier "missing_handler" not declared|Cannot assign (?:a )?value of type)|^ERROR: An EditorPlugin build callback failed|^ERROR: Cannot save text file)')
    return [line for line in text.splitlines()
            if compatibility.ERROR.search(line) and not allowed.search(line)]


def audit(selection, output):
    label, executable = selection.split("=", 1)
    target = output / label
    target.mkdir()
    record = {"label": label, "stages": {}}
    with tempfile.TemporaryDirectory(prefix="estragon-play-") as temporary:
        workspace = Path(temporary)
        binary = workspace / "godot"
        shutil.copy2(Path(executable).resolve(), binary)
        record["input_binary_sha256"] = hashlib.sha256(binary.read_bytes()).hexdigest()
        if platform.system() == "Darwin":
            subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", str(binary)],
                           capture_output=True, check=True)
        (workspace / "_sc_").touch()
        (workspace / "no-tools").mkdir()
        env = dict(os.environ, PATH=str(workspace / "no-tools"))
        for key in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
            folder = workspace / key.lower()
            folder.mkdir()
            env[key] = str(folder)
        record["version"] = subprocess.check_output(
            [str(binary), "--headless", "--version"], env=env, text=True, timeout=60).strip()
        manifest = json.loads((ROOT / "tests/compatibility/engines.json").read_text())
        known = next((item for item in manifest if item["version"] == record["version"]), None)
        if not known or (platform.system() == "Darwin" and
                         known["binary_sha256"] != record["input_binary_sha256"]):
            raise ValueError("Engine differs from pinned official provenance")
        record["provenance"] = known.get("official_archive_url", known.get("provenance"))
        project = workspace / "project"
        shutil.copytree(ROOT / "addons/estragon", project / "addons/estragon")
        (project / "ui").mkdir()
        source = (ROOT / "examples/counter/Counter.gogo").read_text()
        proof = (ROOT / "tests/editor/play/proof.gd.txt").read_text()
        (project / "ui/Counter.gogo").write_text(source + proof)
        (project / "ui/Background.gogo").write_text("extends RefCounted\r\nfunc value() -> int: return 0\r\n")
        (project / "ui/Counter.tscn").write_text((ROOT / "examples/counter/Counter.tscn").read_text().replace(
            "res://examples/counter/generated/Counter.gd", "res://ui/generated/Counter.gd"))
        # The sample's scene references a versioned generated Script. Seed an
        # intentionally stale valid default, and require startup to replace it.
        # Source-only/no-output startup is separately covered by the collector.
        (project / "ui/generated").mkdir()
        (project / "ui/generated/Counter.gd").write_text(
            (ROOT / "examples/counter/generated/Counter.gd").read_text().replace(
                "var count: int = 0", "var count: int = -1"))
        driver = project / "tests/play"
        driver.mkdir(parents=True)
        shutil.copy2(ROOT / "tests/editor/play/driver.gd", driver / "driver.gd")
        (driver / "plugin.cfg").write_text(
            '[plugin]\nname="C01-G Play driver"\ndescription="Test only"\n'
            'author="Estragon"\nversion="1"\nscript="driver.gd"\n')
        (project / "gogo.config.json").write_text('{"version":1,"source_roots":["ui"]}\n')
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="C01-G isolated Play"\n'
            'run/main_scene="res://ui/Counter.tscn"\n'
            'config/features=PackedStringArray("4.0", "GL Compatibility")\n'
            '[editor]\nrun/main_run_args="--headless"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
            '[editor_plugins]\nenabled=PackedStringArray('
            '"res://tests/play/plugin.cfg", "res://addons/estragon/editor/plugin.cfg")\n')
        for phase in [1, 2]:
            name = "play_" + str(phase)
            record["stages"][name] = compatibility.execute(
                [str(binary), "--headless", "--editor", "--path", str(project)],
                workspace, env, target / (name + ".log"),
                "C01_G_PLAY_PHASE_" + str(phase) + "_OK", timeout=240,
                expected_errors=True)
            text = (target / (name + ".log")).read_text()
            checks = re.findall(r"^C01_G_CHECK (.*): (true|false)$", text, re.MULTILINE)
            record["stages"][name]["checks_total"] = len(checks)
            record["stages"][name]["failed_checks"] = [name for name, value in checks if value != "true"]
            unexpected = unexpected_errors(text)
            record["stages"][name]["unexpected_errors"] = unexpected
            if unexpected: record["stages"][name]["status"] = "FAIL"
            if record["stages"][name]["status"] != "PASS":
                if phase == 1:
                    record["stages"]["play_2"] = compatibility.unavailable("First Play phase failed")
                break
    (target / "report.json").write_text(json.dumps(record, indent=2) + "\n")
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", action="append", required=True, help="unique-label=/absolute/godot")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    labels = [item.split("=", 1)[0] for item in args.engine]
    if len(labels) != len(set(labels)) or any(not label or "/" in label or "\\" in label or label in [".", ".."] for label in labels):
        parser.error("engine labels must be unique plain directory names")
    args.output.mkdir(parents=True, exist_ok=False)
    source_commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    source_status = subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True)
    source_files = [ROOT / "addons/estragon/editor/plugin.gd", Path(__file__),
                    ROOT / "tests/editor/play/driver.gd", ROOT / "tests/editor/play/proof.gd.txt",
                    ROOT / "addons/estragon/editor/buffer_guard.gd"]
    source_hashes = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                     for path in source_files}
    records = [audit(selection, args.output) for selection in args.engine]
    result = {"schema_version": 1, "source_commit": source_commit,
              "source_dirty": bool(source_status), "source_hashes": source_hashes,
              "platform": platform.platform(),
              "collected_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "engines": records}
    (args.output / "results.json").write_text(json.dumps(result, indent=2) + "\n")
    for record in records:
        print(record["version"], {key: stage["status"] for key, stage in record["stages"].items()})
    raise SystemExit(0 if all(stage["status"] == "PASS" for record in records
                             for stage in record["stages"].values()) else 1)


if __name__ == "__main__":
    main()
