import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { parseMarkup } from "./gogo/parser.ts";
import { validateComponent } from "./gogo/validate.ts";
import { emitGdscript } from "./gogo/emit-gdscript.ts";

/** Build-time pipeline. The legacy tools/gogo.ts remains independent. */
export function transpileGogo(source: string, sourceName = "<source>"): string {
    return emitGdscript(validateComponent(parseMarkup(source, sourceName), sourceName), sourceName);
}

async function main(): Promise<void> {
    const [sourcePath, option, outputPath, ...extra] = process.argv.slice(2);
    if (!sourcePath || option !== "--output" || !outputPath || extra.length) {
        throw new Error("Usage: bun run transpile <source.gogo> --output <generated.gd>");
    }
    if (resolve(sourcePath) === resolve(outputPath)) throw new Error("Source and output paths must differ");
    if (!outputPath.endsWith(".gd")) throw new Error("Generated output must use the .gd extension");
    // Compile fully before touching existing output. T08 adds compile-before-run.
    const code = transpileGogo(await readFile(sourcePath, "utf8"), sourcePath.replaceAll("\\", "/"));
    await mkdir(dirname(outputPath), { recursive: true });
    await writeFile(outputPath, code, "utf8");
}

if (import.meta.main) {
    await main().catch((error: unknown) => {
        console.error(error instanceof Error ? error.message : String(error));
        process.exitCode = 1;
    });
}
