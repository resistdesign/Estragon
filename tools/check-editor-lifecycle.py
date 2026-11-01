#!/usr/bin/env python3
"""C01-F native startup/lifecycle proof; contributor orchestration, not addon tooling."""
import argparse
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("compatibility", ROOT / "tools/check-compatibility.py")
compatibility = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compatibility)


def audit(selection, output):
    label, executable = selection.split("=", 1)
    target = output / label
    target.mkdir()
    record = {"label": label, "stages": {}}
    with tempfile.TemporaryDirectory(prefix="estragon-lifecycle-") as temporary:
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
            [str(binary), "--headless", "--version"], env=env, text=True).strip()
        manifest = json.loads((ROOT / "tests/compatibility/engines.json").read_text())
        known = next((item for item in manifest if item["version"] == record["version"]), None)
        if not known or (platform.system() == "Darwin" and
                         known["binary_sha256"] != record["input_binary_sha256"]):
            raise ValueError("Engine differs from pinned official provenance")
        project = workspace / "project"
        shutil.copytree(ROOT / "addons/estragon", project / "addons/estragon")
        (project / "ui").mkdir()
        shutil.copy2(ROOT / "examples/counter/Counter.gogo", project / "ui/Counter.gogo")
        (project / "ui/Counter.tscn").write_text((ROOT / "examples/counter/Counter.tscn").read_text().replace(
            "res://examples/counter/generated/Counter.gd", "res://ui/generated/Counter.gd"))
        # The sample's scene references a versioned generated Script. Seed an
        # intentionally stale valid default, and require startup to replace it.
        # Source-only/no-output startup is separately covered by the collector.
        (project / "ui/generated").mkdir()
        (project / "ui/generated/Counter.gd").write_text(
            (ROOT / "examples/counter/generated/Counter.gd").read_text().replace(
                "var count: int = 0", "var count: int = -1"))
        driver = project / "tests/lifecycle"
        driver.mkdir(parents=True)
        shutil.copy2(ROOT / "tests/editor/lifecycle/driver.gd", driver / "driver.gd")
        shutil.copy2(ROOT / "tests/editor/lifecycle/runtime.gd", driver / "runtime.gd")
        (driver / "plugin.cfg").write_text(
            '[plugin]\nname="C01-F lifecycle driver"\ndescription="Test only"\n'
            'author="Estragon"\nversion="1"\nscript="driver.gd"\n')
        (project / "gogo.config.json").write_text('{"version":1,"source_roots":["ui"]}\n')
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="C01-F isolated lifecycle"\n'
            'run/main_scene="res://ui/Counter.tscn"\n'
            'config/features=PackedStringArray("4.0", "GL Compatibility")\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
            '[editor_plugins]\nenabled=PackedStringArray('
            '"res://tests/lifecycle/plugin.cfg", "res://addons/estragon/editor/plugin.cfg")\n')
        for phase in [1, 2]:
            name = "lifecycle_" + str(phase)
            record["stages"][name] = compatibility.execute(
                [str(binary), "--headless", "--editor", "--path", str(project)],
                workspace, env, target / (name + ".log"),
                "C01_F_LIFECYCLE_PHASE_" + str(phase) + "_OK", timeout=120,
                abort_on_error=True)
            if record["stages"][name]["status"] != "PASS":
                if phase == 1:
                    record["stages"]["lifecycle_2"] = compatibility.unavailable("First lifecycle phase failed")
                break
            record["stages"]["runtime_after_" + str(phase)] = compatibility.execute(
                [str(binary), "--headless", "--path", str(project), "--script",
                 "res://tests/lifecycle/runtime.gd"], workspace, env,
                target / ("runtime_after_" + str(phase) + ".log"),
                "C01_F_PUBLISHED_RUNTIME_OK", abort_on_error=True)
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
    records = [audit(selection, args.output) for selection in args.engine]
    result = {"schema_version": 1, "source_commit": source_commit,
              "source_dirty": bool(source_status), "platform": platform.platform(),
              "collected_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "engines": records}
    (args.output / "results.json").write_text(json.dumps(result, indent=2) + "\n")
    for record in records:
        print(record["version"], {key: stage["status"] for key, stage in record["stages"].items()})
    raise SystemExit(0 if all(stage["status"] == "PASS" for record in records
                             for stage in record["stages"].values()) else 1)


if __name__ == "__main__":
    main()
