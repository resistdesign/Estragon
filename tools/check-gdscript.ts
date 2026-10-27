import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { serializeSourceMap } from "./gogo/source-map.ts";
import { compileGogo, transpileGogo } from "./transpile-gogo.ts";

export const EXAMPLE_SOURCE = "examples/compiled/Layout.gogo";
export const EXAMPLE_OUTPUT = "examples/compiled/generated/Layout.gd";
export const HYBRID_SOURCE = "examples/mixed/Mixed.gogo";
export const HYBRID_OUTPUT = "examples/mixed/generated/Mixed.gd";
export async function compileHybridExample(project: string) {
    return compileGogo(await readFile(resolve(project, HYBRID_SOURCE), "utf8"), HYBRID_SOURCE);
}

export async function compileExample(project: string): Promise<string> {
    return transpileGogo(await readFile(resolve(project, EXAMPLE_SOURCE), "utf8"), EXAMPLE_SOURCE);
}

if (import.meta.main) {
    const root = resolve(import.meta.dir, "..");
    const actual = await compileExample(root);
    const expected = await readFile(resolve(root, EXAMPLE_OUTPUT), "utf8");
    if (actual !== expected) {
        console.error(`Generated GDScript is stale. Run: bun run transpile ${EXAMPLE_SOURCE} --output ${EXAMPLE_OUTPUT}`);
        process.exitCode = 1;
    } else console.log("Committed Gogo GDScript matches compiler output.");
    const hybrid = await compileHybridExample(root);
    if (hybrid.code !== await readFile(resolve(root, HYBRID_OUTPUT), "utf8")
        || serializeSourceMap(hybrid.sourceMap) !== await readFile(resolve(root, HYBRID_OUTPUT + ".map.json"), "utf8")) {
        console.error(`Hybrid GDScript/map is stale. Run: bun run transpile ${HYBRID_SOURCE} --output ${HYBRID_OUTPUT}`);
        process.exitCode = 1;
    } else console.log("Committed hybrid Gogo GDScript/source map match compiler output.");
}
