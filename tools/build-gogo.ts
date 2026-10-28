import { lstat, mkdir, readFile, readdir, realpath, rm, writeFile } from "node:fs/promises";
import { dirname, join, relative, resolve, sep } from "node:path";
import { compileGogo } from "./transpile-gogo.ts";
import { GogoCompileError } from "./gogo/model.ts";
import { serializeSourceMap, traceGodotDiagnostics } from "./gogo/source-map.ts";

export const CONFIG = "gogo.config.json";
export const EXCLUDED = new Set(["generated", "node_modules", "tests", "vendor"]);
export interface BuildReport { ok: boolean; outputs: string[]; changed: string[]; diagnostics: string[] }
const inside = (root: string, path: string) => path !== root && path.startsWith(root + sep);
const portable = (path: string) => path.split(sep).join("/");

/** Explicit roots only. Symlinks and paths escaping the project are rejected. */
export async function discoverSources(project: string): Promise<string[]> {
    project = await realpath(project);
    const config: unknown = JSON.parse(await readFile(join(project, CONFIG), "utf8"));
    if (!config || typeof config !== "object" || Array.isArray(config)) throw new Error(`${CONFIG}: expected an object`);
    const { version, source_roots, ...unknown } = config as Record<string, unknown>;
    if (version !== 1 || Object.keys(unknown).length || !Array.isArray(source_roots) || source_roots.length === 0
        || source_roots.some(root => typeof root !== "string" || !root || root.includes("\\") || root.includes(":"))) {
        throw new Error(`${CONFIG}: expected version 1 and nonempty project-relative source_roots only`);
    }
    const sources = new Set<string>();
    const visit = async (path: string) => {
        const info = await lstat(path);
        if (info.isSymbolicLink()) throw new Error(`${portable(relative(project, path))}: symlinks are not supported in Gogo source roots`);
        if (info.isDirectory()) {
            for (const name of (await readdir(path)).sort()) {
                if (!name.startsWith(".") && !EXCLUDED.has(name)) await visit(join(path, name));
            }
        } else if (info.isFile() && path.endsWith(".gogo")) sources.add(portable(relative(project, path)));
    };
    for (const root of source_roots as string[]) {
        const path = resolve(project, root);
        if (!inside(project, path) || root.startsWith("/") || root.split("/").some(part => part === ".." || part.startsWith(".") || EXCLUDED.has(part))) {
            throw new Error(`${CONFIG}: invalid source root ${JSON.stringify(root)}`);
        }
        for (let current = path; current !== project; current = dirname(current)) {
            if ((await lstat(current)).isSymbolicLink()) throw new Error(`${CONFIG}: symlink source roots are not supported`);
        }
        if (!inside(project, await realpath(path))) throw new Error(`${CONFIG}: source root escapes project`);
        await visit(path);
    }
    return [...sources].sort();
}

export function outputFor(source: string): string {
    return portable(join(dirname(source), "generated", source.split("/").at(-1)!.slice(0, -5) + ".gd"));
}

async function assertOutputPath(project: string, path: string): Promise<void> {
    const target = join(project, path);
    // Generated directories/outputs must not redirect writes outside the project.
    for (let current = target; current !== project; current = dirname(current)) {
        try { if ((await lstat(current)).isSymbolicLink()) throw new Error(`${path}: generated paths must not be symlinks`); }
        catch (error) { if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error; }
    }
}

async function publish(project: string, path: string, contents: string): Promise<boolean> {
    await assertOutputPath(project, path);
    const target = join(project, path);
    try { if (await readFile(target, "utf8") === contents) return false; }
    catch (error) { if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error; }
    await mkdir(dirname(target), { recursive: true });
    await writeFile(target, contents, "utf8");
    return true;
}

export async function buildProject(project: string, godot?: string): Promise<BuildReport> {
    const report: BuildReport = { ok: false, outputs: [], changed: [], diagnostics: [] };
    try {
        project = await realpath(project);
        const sources = await discoverSources(project);
        const compiled = [];
        for (const source of sources) {
            try { compiled.push({ source, output: outputFor(source), result: compileGogo(await readFile(join(project, source), "utf8"), source) }); }
            catch (error) {
                report.diagnostics.push(error instanceof GogoCompileError ? error.message : `${source}: ${String(error)}`);
            }
        }
        // No output is touched if any source fails the Gogo frontend.
        if (report.diagnostics.length) return report;
        for (const item of compiled) {
            await assertOutputPath(project, item.output);
            await assertOutputPath(project, item.output + ".map.json");
        }
        for (const item of compiled) {
            report.outputs.push(item.output);
            if (await publish(project, item.output, item.result.code)) report.changed.push(item.output);
            const map = item.output + ".map.json";
            if (item.result.mode === "hybrid") await publish(project, map, serializeSourceMap(item.result.sourceMap));
            else await rm(join(project, map), { force: true });
        }
        if (godot) {
            const maps = new Map(compiled.map(item => [`res://${item.output}`, item.result]));
            for (const item of compiled) {
                const child = Bun.spawn([godot, "--headless", "--path", project, "--script", `res://${item.output}`, "--check-only"], { stdout: "pipe", stderr: "pipe" });
                let timeout = false;
                const timer = setTimeout(() => { timeout = true; child.kill("SIGKILL"); }, 10_000);
                const [code, stdout, stderr] = await Promise.all([child.exited, new Response(child.stdout).text(), new Response(child.stderr).text()]);
                clearTimeout(timer);
                const output = (stdout + "\n" + stderr).replace(/\x1b\[[0-9;]*m/g, "");
                if (timeout || code !== 0 || /SCRIPT ERROR:|(?:^|\n)\s*ERROR:|Parse Error:/.test(output)) {
                    report.diagnostics.push(`${item.source}: Godot validation failed${timeout ? " (10s timeout)" : ""}\n${traceGodotDiagnostics(output, maps)}`);
                }
            }
        }
        report.ok = report.diagnostics.length === 0;
    } catch (error) { report.diagnostics.push(error instanceof Error ? error.message : String(error)); }
    return report;
}

if (import.meta.main) {
    const [, , projectFlag, project, reportFlag, reportPath, godotFlag, godot, ...extra] = process.argv;
    const safeReport = reportPath?.endsWith(".json") && (!project || resolve(reportPath) !== resolve(project, CONFIG));
    let report: BuildReport;
    if (!safeReport || projectFlag !== "--project" || !project || reportFlag !== "--report" || !reportPath || extra.length
        || (godotFlag !== undefined && (godotFlag !== "--godot" || !godot))) {
        report = { ok: false, outputs: [], changed: [], diagnostics: ["Usage: bun tools/build-gogo.ts --project <directory> --report <json> [--godot <executable>]"] };
    } else report = await buildProject(project, godot);
    if (safeReport && reportPath) { await mkdir(dirname(reportPath), { recursive: true }); await writeFile(reportPath, JSON.stringify(report) + "\n"); }
    else console.error(report.diagnostics.join("\n"));
    process.exitCode = report.ok ? 0 : 1;
}
