import { cp, mkdtemp, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join, relative, resolve } from "node:path";

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
    return { code, output, timedOut };
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
  // Recovery mode prevents enabled editor plugins from changing global settings.
  requireSuccess("project import", await run(project, ["--editor", "--recovery-mode", "--import"]));
  for (const path of await scriptsIn(project)) {
    const resource = `res://${relative(project, path).split("\\").join("/")}`;
    requireSuccess(`parse ${resource}`, await run(project, ["--script", resource, "--check-only"]));
  }
  requireSuccess("runtime smoke", await run(project, ["--script", SMOKE, "--quit-after", "120"]), COMPLETE);
  requireSuccess("component foundations", await run(project, ["--script", "res://tests/godot/components.gd", "--quit-after", "120"]), "ESTRAGON_COMPONENTS_OK");
  requireSuccess("layout, rendering and lifecycle", await run(project, ["--script", "res://tests/godot/layout.gd", "--quit-after", "120"]), "ESTRAGON_LAYOUT_OK");
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
