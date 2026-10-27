import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { parseMarkup } from "./gogo/parser.ts";
import { validateComponent, validateHybrid } from "./gogo/validate.ts";
import { emitGdscript } from "./gogo/emit-gdscript.ts";
import { parseHybrid } from "./gogo/hybrid-parser.ts";
import { emitHybrid } from "./gogo/emit-hybrid.ts";
import { SourceFile } from "./gogo/source.ts";
import { MappedWriter, serializeSourceMap, type Compilation } from "./gogo/source-map.ts";

/** The first token selects standalone T04 markup or a GDScript-first module. */
export function compileGogo(source: string, sourceName = "<source>"): Compilation {
    const file = new SourceFile(source, sourceName);
    if (source.trimStart().startsWith("<") || source.trim() === "") {
        const node = validateComponent(parseMarkup(source, sourceName), sourceName);
        const writer = new MappedWriter(file);
        writer.append(emitGdscript(node, sourceName), node.span);
        return { mode: "markup", ...writer.finish() };
    }
    return { mode: "hybrid", ...emitHybrid(validateHybrid(parseHybrid(source, sourceName), sourceName), file) };
}

/** Stable T04 string API; hybrid consumers can also request range mappings. */
export function transpileGogo(source: string, sourceName = "<source>"): string {
    return compileGogo(source, sourceName).code;
}

async function main(): Promise<void> {
    const [sourcePath, option, outputPath, ...extra] = process.argv.slice(2);
    if (!sourcePath || option !== "--output" || !outputPath || extra.length) {
        throw new Error("Usage: bun run transpile <source.gogo> --output <generated.gd>");
    }
    if ([outputPath, outputPath + ".map.json"].some(path => resolve(sourcePath) === resolve(path))) throw new Error("Source and output paths must differ");
    if (!outputPath.endsWith(".gd")) throw new Error("Generated output must use the .gd extension");
    // Compile fully before touching existing output. T08 adds compile-before-run.
    const result = compileGogo(await readFile(sourcePath, "utf8"), sourcePath.replaceAll("\\", "/"));
    await mkdir(dirname(outputPath), { recursive: true });
    await writeFile(outputPath, result.code, "utf8");
    if (result.mode === "hybrid") await writeFile(outputPath + ".map.json", serializeSourceMap(result.sourceMap));
    else await rm(outputPath + ".map.json", { force: true });
}

if (import.meta.main) {
    await main().catch((error: unknown) => {
        console.error(error instanceof Error ? error.message : String(error));
        process.exitCode = 1;
    });
}
