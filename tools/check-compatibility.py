#!/usr/bin/env python3
"""C01 evidence collector. Python is contributor tooling, never an addon dependency.

Default exit status is a compatibility gate: any FAIL/BLOCKED/UNTESTED is nonzero.
--collect-only writes the same red results but exits zero for an audit CI lane.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r"SCRIPT ERROR:|(?:^|\n)ERROR:|Parse Error:|Assertion failed:")
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def classify(code, output, marker=None, timed_out=False):
    if timed_out or code != 0 or ERROR.search(output):
        return "FAIL"
    if marker and marker not in output.splitlines():
        return "FAIL"
    return "PASS"


def execute(command, cwd, env, log, marker=None, timeout=60, expected_errors=False, abort_on_error=False):
    start = time.monotonic()
    with log.open("w") as stream:
        process = subprocess.Popen(command, cwd=cwd, env=env, stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        timed_out = False
        aborted = False
        while process.poll() is None:
            remaining = timeout - (time.monotonic() - start)
            if remaining <= 0:
                timed_out = True
                os.killpg(process.pid, signal.SIGKILL)
                break
            if abort_on_error and ERROR.search(ANSI.sub("", log.read_text(errors="replace"))):
                aborted = True
                os.killpg(process.pid, signal.SIGKILL)
                break
            try:
                process.wait(timeout=min(0.2, remaining))
            except subprocess.TimeoutExpired:
                pass
        code = process.wait()
    output = ANSI.sub("", log.read_text(errors="replace"))
    log.write_text(output)
    status = classify(code, "" if expected_errors else output,
                      None if expected_errors else marker, timed_out)
    if expected_errors and marker not in output.splitlines():
        status = "FAIL"
    return {"status": status, "command": command, "exit_code": code,
            "timeout": timed_out, "aborted_on_error": aborted,
            "seconds": round(time.monotonic() - start, 2),
            "log": log.name,
            "diagnostics": [line for line in output.splitlines()
                            if ERROR.search(line) or "at:" in line][:30]}


def unavailable(reason, status="BLOCKED"):
    return {"status": status, "reason": reason}


def audit(engine, output, editor):
    from callback_metadata_evidence import validate_metadata
    from numeric_evidence import validate_numeric
    label, executable = engine.split("=", 1)
    target = output / label
    target.mkdir(parents=True, exist_ok=True)
    result = {"label": label, "stages": {}}
    stages = result["stages"]
    with tempfile.TemporaryDirectory(prefix="estragon-c01-") as temporary:
        workspace = Path(temporary)
        binary = workspace / "godot"
        shutil.copy2(Path(executable).expanduser().resolve(), binary)
        result["input_binary_sha256"] = hashlib.sha256(binary.read_bytes()).hexdigest()
        if platform.system() == "Darwin":
            subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", str(binary)],
                           check=True, capture_output=True)
        (workspace / "_sc_").touch()
        (workspace / "no-tools").mkdir()
        env = dict(os.environ, PATH=str(workspace / "no-tools"))
        # Self-contained editor settings plus separate user-data/config roots.
        for key in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
            folder = workspace / key.lower()
            folder.mkdir()
            env[key] = str(folder)
        version = subprocess.run([str(binary), "--headless", "--version"], env=env,
                                 capture_output=True, text=True, timeout=60)
        result["version"] = version.stdout.strip()
        manifest = json.loads((ROOT / "tests/compatibility/engines.json").read_text())
        known = next((item for item in manifest if item["version"] == result["version"]), None)
        result["provenance"] = known
        if version.returncode or known is None:
            stages["engine_identity"] = unavailable("Unknown or failed engine version", "FAIL")
            return result
        if platform.system() == "Darwin" and result["input_binary_sha256"] != known["binary_sha256"]:
            stages["engine_identity"] = unavailable("Binary differs from verified official executable", "FAIL")
            return result
        stages["engine_identity"] = {"status": "PASS"}
        project = workspace / "project"
        project.mkdir()
        for name in ["addons", "examples"]:
            shutil.copytree(ROOT / name, project / name,
                            ignore=shutil.ignore_patterns("__pycache__"))
        shutil.copy2(ROOT / "project.godot", project)
        shutil.copy2(ROOT / "gogo.config.json", project)
        base = [str(binary), "--headless", "--path", str(project)]

        def run(name, args, marker=None, **kwargs):
            stages[name] = execute(base + args, workspace, env, target / (name + ".log"),
                                   marker, abort_on_error=(marker is not None and not kwargs.get("expected_errors")), **kwargs)
            return stages[name]["status"] == "PASS"

        run("import", ["--editor", "--quit"])
        # Parse each shipped addon/generated/example script independently. Do not
        # infer dependency validity from plugin.can_instantiate() or exit zero.
        parses = []
        paths = sorted((project / "addons/estragon").rglob("*.gd"))
        paths += sorted((project / "examples").rglob("*.gd"))
        for path in paths:
            relative = path.relative_to(project).as_posix()
            name = "parse-" + relative.replace("/", "_")
            record = execute(base + ["--script", "res://" + relative, "--check-only"],
                             workspace, env, target / (name + ".log"))
            record["source"] = relative
            parses.append(record)
        stages["shipped_scripts"] = {"status": "PASS" if all(
            row["status"] == "PASS" for row in parses) else "FAIL", "scripts": parses}
        # Tests are installed only after clean product import/parse, so a newer
        # test-only API cannot contaminate the addon startup/import verdict.
        for name in ["godot", "fixtures"]:
            shutil.copytree(ROOT / "tests" / name, project / "tests" / name)
        shutil.copy2(ROOT / "tests/compatibility/numeric_literals.gd", project / "numeric_literals.gd")
        shutil.copy2(ROOT / "tests/compatibility/numeric_cases.json", project / "numeric_cases.json")
        run("numeric_literals", ["--script", "res://numeric_literals.gd"], "C01_NUMERIC_OK")
        try:
            result["numeric_evidence"] = validate_numeric((target / "numeric_literals.log").read_text(),
                json.loads((project / "numeric_cases.json").read_text()))
            if any(row["status"] != "PASS" for row in result["numeric_evidence"]["cases"]):
                stages["numeric_literals"]["status"] = "FAIL"
                stages["numeric_literals"]["reason"] = "Independent numeric oracle mismatch; see numeric_evidence.cases"
            limitations = result["numeric_evidence"]["native_parser_limits"]
            stages["numeric_native_preservation"] = {"status": "PASS" if all(row["native_value_preserved"] for row in limitations) else "FAIL"}
            stages["numeric_native_conversion"] = unavailable(
                "Native decimal conversion loses representable binary64 values; see numeric_evidence.native_parser_limits",
                "BLOCKED" if any(row["status"] == "BLOCKED" for row in limitations) else "PASS")
        except (ValueError, KeyError, TypeError) as error:
            stages["numeric_literals"]["status"] = "FAIL"
            stages["numeric_literals"]["reason"] = str(error)
            stages["numeric_native_conversion"] = unavailable("Numeric evidence invalid")
            stages["numeric_native_preservation"] = unavailable("Numeric evidence invalid", "FAIL")
        shutil.copy2(ROOT / "tests/compatibility/callback_metadata.gd", project / "callback_metadata.gd")
        run("callback_metadata_probe", ["--script", "res://callback_metadata.gd"],
            "C01_CALLBACK_METADATA_OK", expected_errors=True)
        try:
            result["callback_metadata"] = validate_metadata(
                (target / "callback_metadata_probe.log").read_text(), int(known["minor"].split(".")[1]))
        except (ValueError, KeyError, TypeError) as error:
            stages["callback_metadata_probe"]["status"] = "FAIL"
            stages["callback_metadata_probe"]["reason"] = str(error)
        stages["callback_arity_api"] = ({"status": "PASS", "reason": "Native arity query available; generated-signals behavior is tested separately"}
            if int(known["minor"].split(".")[1]) >= 3 else unavailable(
                "Native proactive arity query unavailable; owner-approved normal invocation fallback, tested separately"))
        run("frontend", ["--script", "res://tests/godot/native_frontend.gd",
                         "--", "--require-no-bun"], "ESTRAGON_NATIVE_FRONTEND_OK")
        # Remove checked generated code before emission: the runtime must consume
        # native output, never accidentally test the committed TS output instead.
        for name in ["compiled", "mixed", "counter"]:
            shutil.rmtree(project / "examples" / name / "generated")
        emitted = run("emission_maps", ["--script", "res://tests/godot/native_generation.gd",
                                       "--", "--require-no-bun"], "ESTRAGON_NATIVE_GENERATION_OK")
        if emitted:
            run("generated_import", ["--editor", "--quit"])
        else:
            stages["generated_import"] = unavailable("Native emission failed")
        # Independent legacy/component/runtime processes still run on red import.
        for name, script, marker in [
            ("legacy_scene", "smoke", "ESTRAGON_SMOKE_OK"),
            ("components", "components", "ESTRAGON_COMPONENTS_OK"),
            ("layout", "layout", "ESTRAGON_LAYOUT_OK"),
            ("input_text", "interaction", "ESTRAGON_INTERACTION_OK"),
        ]:
            run(name, ["--script", "res://tests/godot/" + script + ".gd"], marker)
        # Runtime rejection is part of the supported sizing/text contract, even
        # where unrelated compiler/editor stages still fail. Count diagnostics
        # so an arbitrary parse error cannot satisfy an expected-error probe.
        for name, script, probe, marker, expected in [
            ("reject_width", "invalid_sizing", "width", "ESTRAGON_INVALID_SIZE_REJECTED", "width must be -1"),
            ("reject_height", "invalid_sizing", "height", "ESTRAGON_INVALID_SIZE_REJECTED", "height must be -1"),
            ("reject_negative_width", "invalid_sizing", "negative", "ESTRAGON_INVALID_SIZE_REJECTED", "width must be -1"),
            ("reject_gap", "invalid_sizing", "gap", "ESTRAGON_INVALID_SIZE_REJECTED", "gap must be finite"),
            ("reject_geometry", "invalid_sizing", "geometry", "ESTRAGON_INVALID_SIZE_REJECTED", "arranged geometry must be finite"),
            ("reject_null_font", "invalid_text", "font", "ESTRAGON_INVALID_TEXT_REJECTED", "font must not be null"),
            ("reject_font_size", "invalid_text", "font_size", "ESTRAGON_INVALID_TEXT_REJECTED", "font_size must be positive"),
        ]:
            run(name, ["--script", "res://tests/godot/" + script + ".gd", "--", probe],
                marker, expected_errors=True)
            errors = [line for line in (target / (name + ".log")).read_text().splitlines() if ERROR.search(line)]
            if len(errors) != 1 or "ERROR: Estragon: " + expected not in errors[0]:
                stages[name]["status"] = "FAIL"
                stages[name]["reason"] = "Expected exactly one runtime rejection: Estragon: " + expected
        for name, script, marker in [
            ("generated_layout", "generated_gogo", "ESTRAGON_GENERATED_GOGO_OK"),
            ("hybrid_runtime", "hybrid_gogo", "ESTRAGON_HYBRID_GOGO_OK"),
            ("generated_signals", "generated_signals", "ESTRAGON_SIGNALS_OK"),
            ("native_counter", "native_counter", "ESTRAGON_NATIVE_COUNTER_OK"),
            ("semantic_identity", "native_semantics", "ESTRAGON_NATIVE_SEMANTICS_OK"),
        ]:
            if not emitted:
                stages[name] = unavailable("Native emission failed")
            else:
                run(name, ["--script", "res://tests/godot/" + script + ".gd"], marker,
                    expected_errors=(name == "semantic_identity"))
        # Expected callback diagnostics differ only in proactive arity support.
        # Invalid/disposed targets are always rejected before connection.
        for mode in ["empty", "missing", "freed", "disposed", "required", "optional",
                     "lambda_required", "lambda_optional", "unbound"]:
            name = "callback_guard_" + mode
            if not emitted:
                stages[name] = unavailable("Native emission failed")
                continue
            run(name, ["--script", "res://tests/godot/callback_guards.gd", "--", mode],
                "C01_CALLBACK_GUARD_OK " + mode, expected_errors=True)
            errors = [line for line in (target / (name + ".log")).read_text().splitlines() if ERROR.search(line)]
            early = int(known["minor"].split(".")[1]) >= 3
            invalid = mode in ["empty", "missing", "freed", "disposed"]
            if early or invalid:
                correct = len(errors) == 1 and "signal-edges.gogo:34:" in errors[0] and "valid zero-argument Callable" in errors[0]
            elif mode in ["optional", "lambda_optional"]:
                correct = not errors
            else:
                # Old Godot logs an additional method-name lookup error while
                # formatting a failed opaque-lambda invocation. It is part of
                # the native error path, not an Estragon reflection call.
                invocation = errors[-1] if errors else ""
                expected_count = 2 if mode == "lambda_required" else 1
                correct = (len(errors) == expected_count and "Error calling from signal" in invocation
                           and "argument" in invocation.lower()
                           and (expected_count == 1 or ("Can't get method on CallableCustom" in errors[0]
                                                        and "lambda" in errors[0])))
            if not correct:
                stages[name]["status"] = "FAIL"
                stages[name]["reason"] = "Unexpected callback diagnostic sequence: " + repr(errors)
        # Export engine API metadata as additional audit evidence. This does not
        # execute unavailable methods or substitute capability presence for use.
        run("api_dump", ["--dump-extension-api"])
        api_file = project / "extension_api.json"
        if not api_file.exists():
            api_file = workspace / "extension_api.json"
        if api_file.exists():
            api = json.loads(api_file.read_text())
            wanted = {"EditorInterface": ["get_script_editor", "get_editor_settings"],
                      "ScriptEditor": ["save_all_scripts", "get_unsaved_files"],
                      "EditorFileSystem": ["is_importing", "is_scanning"],
                      "Resource": ["set_path_cache"], "Logger": [], "ScriptBacktrace": [],
                      "OS": ["add_logger", "remove_logger"], "ThemeDB": [],
                      "Callable": ["get_argument_count"], "Vector2": ["max"]}
            classes = {item["name"]: item for section in ["classes", "builtin_classes"]
                       for item in api.get(section, [])}
            result["api"] = {}
            for name, methods in wanted.items():
                item = classes.get(name)
                lookup = {method["name"]: method for method in item.get("methods", [])} if item else {}
                result["api"][name] = {"exists": item is not None, "methods": {
                    method: {"exists": method in lookup, "static": lookup[method].get("is_static", False)}
                    if method in lookup else {"exists": False} for method in methods}}
        else:
            stages["api_dump"] = unavailable("Engine did not produce extension_api.json", "FAIL")
        stages["graphics_physical_keys"] = unavailable(
            "Headless evidence does not certify pixels or physical F5/F6", "UNTESTED")
        if editor:
            # E01 shell launches its own copied, self-contained engine with empty
            # PATH. It deliberately exits zero after some failed capability probes.
            shell_env = dict(os.environ, GODOT_BIN=str(binary))
            shell_env.pop("ESTRAGON_KEEP_COMPAT_TEST", None)
            record = execute(["/bin/sh", str(ROOT / "tools/check-highlighting-compat.sh")],
                             workspace, shell_env, target / "editor.log", timeout=240,
                             marker="E01_ISOLATED_HIGHLIGHTING_OK", expected_errors=True)
            log = (target / "editor.log").read_text()
            stages["editor_fixture"] = record
            completed = record["status"] == "PASS"
            stages["normal_highlighting"] = {"status": "PASS"} if completed else unavailable("E01 fixture failed", "FAIL")
            stages["filtered_highlighting"] = unavailable("#44: never-associated filtered tab", "FAIL") if (
                "E01_FILTERED_UNASSOCIATED_UNMET" in log) else unavailable("No positive filtered-tab proof", "UNTESTED")
            stages["addon_startup"] = {"status": "PASS"} if completed and (
                "E01_FULL_ADDON_STARTUP_OK" in log) else unavailable("See editor.log: full addon failed startup", "FAIL")
            if known["minor"] == "4.7":
                shell_env["ESTRAGON_TEST_GODOT_VERSION"] = result["version"]
                stages["editor_play_recovery"] = execute(
                    ["/bin/sh", str(ROOT / "tools/check-editor.sh")], workspace, shell_env,
                    target / "editor_play_recovery.log", "ESTRAGON_EDITOR_OK", timeout=420,
                    expected_errors=True)
            else:
                stages["editor_play_recovery"] = unavailable(
                    "Startup failed" if stages["addon_startup"]["status"] == "FAIL" else
                    "Existing full Play harness pins 4.7.0; port test in C01 editor milestone",
                    "BLOCKED" if stages["addon_startup"]["status"] == "FAIL" else "UNTESTED")
        else:
            for name in ["normal_highlighting", "filtered_highlighting", "addon_startup", "editor_play_recovery"]:
                stages[name] = unavailable("Run with --editor", "UNTESTED")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", action="append", required=True, help="unique-label=/absolute/executable")
    parser.add_argument("--output", type=Path, required=True, help="new results directory (never overwritten)")
    parser.add_argument("--editor", action="store_true", help="also run isolated real headless editors")
    parser.add_argument("--collect-only", action="store_true", help="audit lane only; red JSON remains red")
    args = parser.parse_args()
    labels = [value.split("=", 1)[0] for value in args.engine]
    if len(set(labels)) != len(labels) or any(not re.fullmatch(r"[\w.-]+", label) for label in labels):
        parser.error("engine labels must be unique simple filenames")
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    report = {"schema_version": 1, "date": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "platform": platform.platform(), "source_commit": subprocess.check_output(
                  ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "source_dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT)),
              "collect_only": args.collect_only, "engines": []}
    for engine in args.engine:
        try:
            row = audit(engine, args.output, args.editor)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            row = {"label": engine.split("=", 1)[0], "stages": {
                "infrastructure": unavailable(str(error), "FAIL")}}
        report["engines"].append(row)
        (args.output / "results.json").write_text(json.dumps(report, indent=2) + "\n")
        print(row["label"], {key: value["status"] for key, value in row["stages"].items()}, flush=True)
    red = any(stage["status"] != "PASS" for row in report["engines"] for stage in row["stages"].values())
    return 0 if args.collect_only or not red else 1


if __name__ == "__main__":
    raise SystemExit(main())
