import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { transpileGogo } from "./transpile-gogo.ts";

export const EXAMPLE_SOURCE = "examples/compiled/Layout.gogo";
export const EXAMPLE_OUTPUT = "examples/compiled/generated/Layout.gd";

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
}
