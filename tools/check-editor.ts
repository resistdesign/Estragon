/** Optional repository wrapper. The Godot-only shell harness is authoritative. */
import { resolve } from "node:path";
const child = Bun.spawn(["sh", resolve(import.meta.dir, "check-editor.sh")], {
    stdin: "inherit", stdout: "inherit", stderr: "inherit", env: process.env,
});
process.exitCode = await child.exited;
