/** Optional reference output transcript; native execution never runs this tool. */
import { readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { resolve } from "node:path";
import { compileGogo } from "./transpile-gogo.ts";

const root = resolve(import.meta.dir, "..");
const cases = ["examples/compiled/Layout.gogo", "examples/mixed/Mixed.gogo", "examples/counter/Counter.gogo", "tests/fixtures/hybrid-edges.gogo", "tests/fixtures/signal-edges.gogo", "tests/fixtures/native-named.gogo"];
const transcript = [];
for (const name of cases) {
    const source = await readFile(resolve(root, name), "utf8");
    const result = compileGogo(source, name);
    transcript.push({name, source, code: result.code, mapDigest: createHash("sha256").update(JSON.stringify(result.sourceMap)).digest("hex")});
}
const path = resolve(root, "tests/fixtures/native-generation.json");
const text = JSON.stringify(transcript, null, 2) + "\n";
if (process.argv.includes("--write")) await writeFile(path, text);
else if (await readFile(path, "utf8") !== text) throw new Error("Native generation transcript stale: bun tools/native-generation-cases.ts --write");
console.log(`Native generation reference examples: ${transcript.length}`);
