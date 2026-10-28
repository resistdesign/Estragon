import { cp, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join, resolve } from "node:path";

const root = resolve(import.meta.dir, "..");
const native = process.env.ESTRAGON_EDITOR_NATIVE === "1";
const godot = process.env.GODOT_BIN || "godot";
const workspace = await mkdtemp(join(tmpdir(), "estragon-editor test-"));
const project = join(workspace, "project");
try {
    await cp(root, project, { recursive: true, filter: path => ![".git", ".godot", "node_modules"].includes(basename(path)) });
    // Godot self-contained mode puts EditorSettings next to this copied binary.
    const binary = join(workspace, process.platform === "win32" ? "godot.exe" : "godot");
    const located = Bun.which(godot) || godot;
    await cp(located, binary, { dereference: true });
    if (process.platform === "darwin") {
        // macOS invalidates the copied universal binary's original signature.
        const signed = Bun.spawn(["/usr/bin/codesign", "--force", "--sign", "-", binary], { stdout: "ignore", stderr: "pipe" });
        if (await signed.exited !== 0) throw new Error(await new Response(signed.stderr).text());
    }
    await writeFile(join(workspace, "_sc_"), "");
    const version = Bun.spawn([binary, "--headless", "--version"], { stdout: "pipe", stderr: "pipe" });
    const [versionCode, versionText] = await Promise.all([version.exited, new Response(version.stdout).text()]);
    if (versionCode !== 0 || versionText.trim() !== "4.7.stable.official.5b4e0cb0f") throw new Error(`Expected official Godot 4.7 stable, got ${versionText.trim()}`);
    await mkdir(join(project, "tests/editor/driver"), { recursive: true });
    await writeFile(join(project, "tests/editor/driver/plugin.cfg"), '[plugin]\nname="Estragon integration test driver"\ndescription="Isolated test only"\nauthor="Estragon"\nversion="1"\nscript="driver.gd"\n');
    let config = await readFile(join(project, "project.godot"), "utf8");
    config = config.replace('run/main_scene="res://examples/hello/Hello.tscn"', 'run/main_scene="res://examples/counter/Counter.tscn"');
    config += `\n[editor]\nrun/main_run_args=${JSON.stringify(native ? "" : "--headless")}\n`;
    config += '\n[editor_plugins]\nenabled=PackedStringArray("res://addons/estragon/editor/plugin.cfg", "res://tests/editor/driver/plugin.cfg")\n';
    await writeFile(join(project, "project.godot"), config);
    await cp(join(root, "tests/editor/driver.gd"), join(project, "tests/editor/driver/driver.gd"));
    const child = Bun.spawn([binary, ...(native ? [] : ["--headless"]), "--path", project, "--editor", "--log-file", join(workspace, "editor.log")], {
        stdout: "pipe", stderr: "pipe", env: { ...process.env, ESTRAGON_TEST_BUN: process.execPath, ESTRAGON_EDITOR_TEST: "1", ESTRAGON_EDITOR_NATIVE: native ? "1" : "0" },
    });
    const timer = setTimeout(() => child.kill("SIGKILL"), 150_000);
    const [code, stdout, stderr] = await Promise.all([child.exited, new Response(child.stdout).text(), new Response(child.stderr).text()]);
    clearTimeout(timer);
    const output = stdout + "\n" + stderr;
    console.log(output);
    const unexpectedScripts = output.split(/\r?\n/).filter(line => line.includes("SCRIPT ERROR:")
        && !line.includes('Parse Error: Identifier "missing_handler" not declared'));
    const unexpectedErrors = output.split(/\r?\n/).filter(line => /^\s*ERROR:/.test(line)
        && !line.includes("An EditorPlugin build callback failed.")
        && !line.includes('Failed to load script "res://examples/counter/generated/Counter.gd"'));
    if (code !== 0 || unexpectedScripts.length || unexpectedErrors.length || !output.includes("ESTRAGON_EDITOR_OK")) throw new Error(`Editor integration failed (exit ${code})`);
    console.log("PASS isolated Godot editor integration");
} finally {
    if (process.env.ESTRAGON_KEEP_EDITOR_TEST === "1") console.log(`Retained isolated editor: ${workspace}`);
    else await rm(workspace, { recursive: true, force: true });
}
