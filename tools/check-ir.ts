import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { compileSource, serializeIr } from "./gogo.ts";

const sourcePath = fileURLToPath(new URL("../examples/hello/Main.gogo", import.meta.url));
const fixturePath = fileURLToPath(
    new URL("../examples/hello/generated/Main.gogo.json", import.meta.url)
);

async function main(): Promise<void> {
    const source = await readFile(sourcePath, "utf8");
    const expected = await readFile(fixturePath, "utf8");
    const actual = serializeIr(compileSource(source));

    if (actual !== expected) {
        console.error("Generated sample IR is stale. Regenerate it with:");
        console.error(
            "bun run gogo examples/hello/Main.gogo --output " +
            "examples/hello/generated/Main.gogo.json"
        );
        process.exitCode = 1;
        return;
    }
    console.log("Committed Gogo sample IR matches TypeScript compiler output.");
}

if (import.meta.main) {
    await main();
}
