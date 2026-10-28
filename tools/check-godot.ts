import { cp, mkdir, mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join, relative, resolve } from "node:path";
import { compileExample, EXAMPLE_OUTPUT, compileHybridExample, HYBRID_OUTPUT, compileCounterExample, COUNTER_OUTPUT } from "./check-gdscript.ts";
import { compileGogo, transpileGogo } from "./transpile-gogo.ts";
import { traceGodotDiagnostics, type Compilation } from "./gogo/source-map.ts";
const compiledMaps = new Map<string, Compilation>();

// The official standard editor build; export templates cannot import projects.
const VERSION = "4.7.stable.official.5b4e0cb0f";
const GODOT = process.env.GODOT_BIN || "godot";
const ROOT = resolve(import.meta.dir, "..");
const SMOKE = "res://tests/godot/smoke.gd";
const COMPLETE = "ESTRAGON_SMOKE_OK";
const ENGINE_ERROR = /(?:SCRIPT ERROR:|(?:^|\n)\s*ERROR:|Parse Error:|Assertion failed:)/;

type Result = { code: number; output: string; timedOut: boolean };

async function run(project: string, args: string[], timeoutMs = 60_000): Promise<Result> {
  const child = Bun.spawn([GODOT, "--headless", "--path", project, ...args], {
    stdout: "pipe", stderr: "pipe",
  });
  let timedOut = false;
  const timer = setTimeout(() => {
    timedOut = true;
    child.kill("SIGKILL");
  }, timeoutMs);
  try {
    const [code, stdout, stderr] = await Promise.all([
      child.exited, new Response(child.stdout).text(), new Response(child.stderr).text(),
    ]);
    // Godot may color diagnostics even when redirected.
    const output = `${stdout}\n${stderr}`.replace(/\x1b\[[0-9;]*m/g, "");
    return { code, output: traceGodotDiagnostics(output, compiledMaps), timedOut };
  } finally {
    clearTimeout(timer);
  }
}

function requireSuccess(label: string, result: Result, marker?: string): void {
  if (result.timedOut || result.code !== 0 || ENGINE_ERROR.test(result.output)
      || (marker !== undefined && !result.output.split(/\r?\n/).includes(marker))) {
    throw new Error(`${label} failed (exit ${result.code}, timeout ${result.timedOut})\n${result.output}`);
  }
  console.log(`PASS ${label}`);
}

async function scriptsIn(directory: string): Promise<string[]> {
  const paths: string[] = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (entry.name === ".godot") continue;
    const path = join(directory, entry.name);
    if (entry.isDirectory()) paths.push(...await scriptsIn(path));
    else if (entry.name.endsWith(".gd")) paths.push(path);
  }
  return paths.sort();
}

async function validate(project: string): Promise<void> {
  // Prove freshly compiled source, not just the checked-in .gd fixture, executes.
  await writeFile(join(project, EXAMPLE_OUTPUT), await compileExample(project));
  const hybrid = await compileHybridExample(project);
  await writeFile(join(project, HYBRID_OUTPUT), hybrid.code);
  compiledMaps.set(`res://${HYBRID_OUTPUT}`, hybrid);
  const counter = await compileCounterExample(project);
  await writeFile(join(project, COUNTER_OUTPUT), counter.code);
  compiledMaps.set(`res://${COUNTER_OUTPUT}`, counter);
  const generated = join(project, "tests/godot/generated");
  await mkdir(generated, { recursive: true });
  for (const [name, source] of [
    ["Numbers", '<Rect width="1e20" height="0" fill="#12345678"/>'],
    ["Primitives", '<VBox><Text text="Literal text" font_size="21" color="#ff990080"/><Button text="Literal button" disabled="true"/></VBox>'],
    ["Empty", '<HBox width="auto" height="auto" gap="0" fill_width="false"/>'],
  ] as const) {
    await writeFile(join(generated, `${name}.gd`), transpileGogo(source, `<Godot ${name} probe>`));
  }
  const edges = compileGogo(await readFile(join(project, "tests/fixtures/hybrid-edges.gogo"), "utf8"), "tests/fixtures/hybrid-edges.gogo");
  await writeFile(join(generated, "HybridEdges.gd"), edges.code);
  compiledMaps.set("res://tests/godot/generated/HybridEdges.gd", edges);
  const signals = compileGogo(await readFile(join(project, "tests/fixtures/signal-edges.gogo"), "utf8"), "tests/fixtures/signal-edges.gogo");
  await writeFile(join(generated, "SignalEdges.gd"), signals.code);
  compiledMaps.set("res://tests/godot/generated/SignalEdges.gd", signals);
  // Recovery mode prevents enabled editor plugins from changing global settings.
  requireSuccess("project import", await run(project, ["--editor", "--recovery-mode", "--import"]));
  for (const path of await scriptsIn(project)) {
    const resource = `res://${relative(project, path).split("\\").join("/")}`;
    requireSuccess(`parse ${resource}`, await run(project, ["--script", resource, "--check-only"]));
  }
  requireSuccess("native Gogo frontend", await run(project, ["--script", "res://tests/godot/native_frontend.gd", "--quit-after", "120"]), "ESTRAGON_NATIVE_FRONTEND_OK");
  requireSuccess("runtime smoke", await run(project, ["--script", SMOKE, "--quit-after", "120"]), COMPLETE);
  requireSuccess("component foundations", await run(project, ["--script", "res://tests/godot/components.gd", "--quit-after", "120"]), "ESTRAGON_COMPONENTS_OK");
  requireSuccess("layout, rendering and lifecycle", await run(project, ["--script", "res://tests/godot/layout.gd", "--quit-after", "120"]), "ESTRAGON_LAYOUT_OK");
  requireSuccess("fresh Gogo-generated GDScript", await run(project, ["--script", "res://tests/godot/generated_gogo.gd", "--quit-after", "120"]), "ESTRAGON_GENERATED_GOGO_OK");
  requireSuccess("hybrid Gogo runtime", await run(project, ["--script", "res://tests/godot/hybrid_gogo.gd", "--quit-after", "120"]), "ESTRAGON_HYBRID_GOGO_OK");
  requireSuccess("text, buttons and pointer dispatch", await run(project, ["--script", "res://tests/godot/interaction.gd", "--quit-after", "120"]), "ESTRAGON_INTERACTION_OK");
  requireSuccess("generated signals and Counter", await run(project, ["--script", "res://tests/godot/generated_signals.gd", "--quit-after", "120"]), "ESTRAGON_SIGNALS_OK");
  for (const probe of ["width", "height", "negative", "gap", "geometry"]) {
    const result = await run(project, ["--script", "res://tests/godot/invalid_sizing.gd", "--", probe]);
    const expected = probe === "geometry" ? "arranged geometry must be finite with nonnegative size"
      : probe === "gap" ? "gap must be finite and nonnegative"
      : `${probe === "height" ? "height" : "width"} must be -1 (auto) or finite and nonnegative`;
    // Require the expected diagnostic AND successful post-error value checks.
    // Any additional engine error, assertion or timeout remains a failure.
    const errors = result.output.split(/\r?\n/).filter((line) => ENGINE_ERROR.test(line));
    if (result.timedOut || result.code !== 0 || errors.length !== 1
        || !errors[0]?.includes(`Estragon: ${expected}`)
        || !result.output.split(/\r?\n/).includes("ESTRAGON_INVALID_SIZE_REJECTED")) {
      throw new Error(`Invalid sizing probe ${probe} failed\n${result.output}`);
    }
    console.log(`PASS rejected invalid ${probe} without mutating sizing`);
  }
  for (const probe of ["font", "font_size"]) {
    const result = await run(project, ["--script", "res://tests/godot/invalid_text.gd", "--", probe]);
    const expected = probe === "font" ? "font must not be null" : "font_size must be positive";
    const errors = result.output.split(/\r?\n/).filter((line) => ENGINE_ERROR.test(line));
    if (result.timedOut || result.code !== 0 || errors.length !== 1
        || !errors[0]?.includes(`Estragon: ${expected}`)
        || !result.output.split(/\r?\n/).includes("ESTRAGON_INVALID_TEXT_REJECTED")) {
      throw new Error(`Invalid text probe ${probe} failed\n${result.output}`);
    }
    console.log(`PASS rejected invalid ${probe} without mutating text properties`);
  }
  await hybridRejections(project);
}

async function hybridRejections(project: string): Promise<void> {
  const cases = [
    { name: "Syntax", source: 'extends RefCounted\nfunc build():\n    return <Rect width={1 +}/>\n', evidence: /Parse Error/, line: 3 },
    { name: "Type", source: 'extends RefCounted\nfunc build():\n    return <Rect width={"wide"}/>\n', evidence: /Invalid argument/, line: 3 },
    { name: "ChildType", source: 'extends RefCounted\nfunc build():\n    return <VBox>{42}</VBox>\n', evidence: /Invalid argument/, line: 3 },
    { name: "Unknown", source: 'extends RefCounted\nfunc build():\n    return <Rect width={missing_value}/>\n', evidence: /missing_value/, line: 3 },
    { name: "NullChild", source: 'extends SceneTree\nfunc _initialize():\n    var value = <VBox>{null}</VBox>\n    print("EXPECTED_HYBRID_END")\n    quit(0)\n', evidence: /Gogo child must be a live/, line: 3, runtime: true },
    { name: "Range", source: 'extends SceneTree\nfunc _initialize():\n    var invalid: float = -2.0\n    var value = <Rect width={invalid}/>\n    print("EXPECTED_HYBRID_END")\n    quit(0)\n', evidence: /width must be -1/, line: 4, runtime: true },
  ];
  // Callable signatures are native Godot metadata, checked before connection.
  const callbackProbe = (callback: string, declarations = "", setup = "") => `extends SceneTree
${declarations}
func _initialize():
${setup}    var button = <Button pressed={${callback}}/>
    if not button.pressed.get_connections().is_empty():
        quit(1)
        return
    print("EXPECTED_HYBRID_END")
    quit(0)
`;
  for (const [name, source] of [
    ["CallbackMissing", 'extends RefCounted\nfunc build():\n    return <Button pressed={missing_handler}/>\n'],
    ["CallbackType", 'extends RefCounted\nfunc build():\n    return <Button pressed={42}/>\n'],
    ["CallbackCall", 'extends RefCounted\nfunc handler() -> int: return 1\nfunc build():\n    return <Button pressed={handler()}/>\n'],
    ["TextType", 'extends RefCounted\nfunc build():\n    return <Text text={42}/>\n'],
    ["DisabledType", 'extends RefCounted\nfunc build():\n    return <Button disabled={"yes"}/>\n'],
  ]) {
    cases.push({ name: name!, source: source!, evidence: name === "CallbackMissing" ? /missing_handler/ : /Invalid argument/,
      line: source!.split("\n").findIndex(line => line.includes("return <")) + 1 });
  }
  for (const [name, source] of [
    ["CallbackArity", callbackProbe("handler", "func handler(value: int) -> void: pass")],
    ["CallbackOptional", callbackProbe("handler", "func handler(value: int = 1) -> void: pass")],
    ["CallbackEmpty", callbackProbe("Callable()")],
    ["CallbackInvalid", callbackProbe('Callable(self, "not_a_method")')],
    ["CallbackDisposed", callbackProbe("receiver.receive", `class Receiver extends EstragonRect:
    func receive() -> void: pass
var receiver := Receiver.new()`, `    var owner := EstragonContainer.new()
    owner.add_child(receiver)
    owner.remove_child(receiver)
`)],
  ]) {
    cases.push({ name: name!, source: source!, evidence: /Button.pressed requires a valid zero-argument Callable/,
      line: source!.split("\n").findIndex(line => line.includes("var button =")) + 1, runtime: true });
  }
  // Invalid generated scripts appear only after positive project import/parsing.
  for (const probe of cases) {
    const sourceName = `tests/fixtures/negative-${probe.name}.gogo`;
    const compiled = compileGogo(probe.source, sourceName);
    const resource = `res://tests/godot/generated/Negative${probe.name}.gd`;
    const path = join(project, resource.slice("res://".length));
    await writeFile(path, compiled.code);
    compiledMaps.set(resource, compiled);
    const result = await run(project, ["--script", resource, ...(probe.runtime ? [] : ["--check-only"])]);
    if (result.timedOut || !ENGINE_ERROR.test(result.output) || !probe.evidence.test(result.output)
        || !result.output.includes(`Gogo source: ${sourceName}:${probe.line}:`)
        || (probe.runtime && (result.code !== 0 || !result.output.includes("EXPECTED_HYBRID_END")))
        || (probe.runtime && probe.name.startsWith("Callback") && result.output.split(/\r?\n/).filter(line => ENGINE_ERROR.test(line)).length !== 1)) {
      throw new Error(`Hybrid rejection ${probe.name} failed to prove its expected mapped diagnostic\n${result.output}`);
    }
    console.log(`PASS Godot rejected/mapped hybrid ${probe.name} to ${sourceName}:${probe.line}`);
    await rm(path);
  }
}

async function selfTest(): Promise<void> {
  // Deliberate failures live outside the real project; no invalid .gd fixtures
  // enter its importer. Each case must fail for its intended reason.
  const cases = [
    { name: "broken resource import", file: "broken.png", source: "not a PNG", phase: "import", evidence: /ERROR:.*(?:PNG|import|png)/ },
    { name: "malformed GDScript parse", source: "extends SceneTree\nfunc broken(\n", phase: "parse", evidence: /(?:SCRIPT ERROR:|Parse Error:)/ },
    { name: "failed runtime test", source: "extends SceneTree\nfunc _initialize():\n\tprint(\"DELIBERATE_TEST_FAILURE\")\n\tquit(1)\n", evidence: /DELIBERATE_TEST_FAILURE/ },
    { name: "error logged with exit zero", source: `extends SceneTree\nfunc _initialize():\n\tpush_error("DELIBERATE_LOGGED_ERROR")\n\tprint("${COMPLETE}")\n\tquit(0)\n`, evidence: /ERROR:.*DELIBERATE_LOGGED_ERROR/ },
    { name: "assertion failure", source: 'extends SceneTree\nfunc _initialize():\n\tassert(false, "DELIBERATE_ASSERTION")\n', evidence: /Assertion failed.*DELIBERATE_ASSERTION/ },
    { name: "early successful quit without completion", source: "extends SceneTree\nfunc _initialize():\n\tquit(0)\n", evidence: /exit 0/ },
    { name: "timeout", source: "extends SceneTree\n", timeout: 1000, evidence: /timeout true/ },
  ];
  for (const test of cases) {
    const project = await mkdtemp(join(tmpdir(), "estragon-godot-negative-"));
    try {
      await writeFile(join(project, "project.godot"), 'config_version=5\n[application]\nconfig/name="Estragon harness negative test"\n');
      await writeFile(join(project, test.file ?? "probe.gd"), test.source);
      const args = test.phase === "import" ? ["--editor", "--recovery-mode", "--import"]
        : test.phase === "parse" ? ["--script", "res://probe.gd", "--check-only"]
        : ["--script", "res://probe.gd", ...(test.timeout ? [] : ["--quit-after", "120"])];
      const result = await run(project, args, test.timeout);
      let failure: Error | undefined;
      try {
        requireSuccess(test.name, result, test.phase ? undefined : COMPLETE);
      } catch (error) {
        if (!(error instanceof Error)) throw error;
        failure = error;
      }
      if (!failure || !test.evidence.test(failure.message)) {
        throw new Error(`Harness did not reject ${test.name} for the expected reason\n${result.output}`);
      }
      console.log(`PASS harness rejected ${test.name} (Godot exit ${result.code}, timeout ${result.timedOut})`);
    } finally {
      await rm(project, { recursive: true, force: true });
    }
  }
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  if (args.length > 1 || (args.length === 1 && args[0] !== "--self-test")) {
    throw new Error("Usage: bun run tools/check-godot.ts [--self-test]");
  }
  const version = await run(ROOT, ["--version"]);
  requireSuccess("Godot version command", version);
  if (version.output.trim() !== VERSION) {
    throw new Error(`Expected Godot ${VERSION}, got ${version.output.trim()}`);
  }
  if (args[0] === "--self-test") return selfTest();
  const project = await mkdtemp(join(tmpdir(), "estragon-godot-check-"));
  try {
    // Fresh imports and isolated caches, including when the working tree has
    // a local .godot/editor configuration. Preserve all project-owned assets.
    await cp(ROOT, project, {
      recursive: true,
      filter: (path) => ![".git", ".godot", "node_modules"].includes(basename(path)),
    });
    await validate(project);
  } finally {
    await rm(project, { recursive: true, force: true });
  }
}

await main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
