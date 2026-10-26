# Tests and verification

## Compiler typechecking and tests

Requires **Bun 1.4.4**. From the repository root:

```sh
bun install --frozen-lockfile
bun run typecheck
bun run test
bun run verify:ir
```

The TypeScript suite covers successful compilation, deterministic IR, alternate/default XML namespace prefixes, invalid source, schema errors, duplicate IDs, dimensions/colors, CLI failure handling, and the checked-in example. Typechecking is **mandatory**: Bun's TypeScript execution alone does not validate types.

The convenience command `bun run check` runs the typecheck, tests, and IR fixture verification together.

## Generated IR

The checked-in JSON is generated, not hand-maintained. `bun run verify:ir` compares compiler output against the committed fixture **byte-for-byte without rewriting it**.

When intentionally changing the Gogo sample, regenerate it with:

```sh
bun run gogo examples/hello/Main.gogo --output examples/hello/generated/Main.gogo.json
bun run check
```

GitHub Actions uses `bun install --frozen-lockfile` and these checks on pushes and pull requests. The Bun lockfile is committed for reproducibility.

## Godot 4.7 headless validation

Use the **standard Godot 4.7 stable editor**, version string
`4.7.stable.official.5b4e0cb0f` (not an export template or a different patch).
Download the matching platform binary from the [official 4.7 archive](https://godotengine.org/download/archive/4.7-stable/).
CI downloads the official Linux x86_64 release ZIP and verifies its pinned SHA-256
in `.github/workflows/ci.yml`. No third-party Godot test framework is needed.

From the repository root, with Bun 1.4.4 and `godot` on PATH:

```sh
bun run check:godot
bun run test:godot-harness
```

Or set `GODOT_BIN` to the executable, including paths containing spaces:

```sh
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot" bun run check:godot
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot" bun run test:godot-harness
```

`check:godot` copies the project to a temporary directory, omitting `.git`,
`.godot` and `node_modules`. It imports from a fresh cache without changing the
working project's generated files, UID files or editor configuration. Import uses
recovery mode so enabled editor plugins cannot change global editor settings.
It then runs these engine operations against that copy:

```sh
godot --headless --path "$PROJECT_COPY" --editor --recovery-mode --import
# Repeated for every .gd, including unreferenced and generated scripts:
godot --headless --path "$PROJECT_COPY" --script res://path/to/script.gd --check-only
godot --headless --path "$PROJECT_COPY" --script res://tests/godot/smoke.gd --quit-after 120
```

These are the underlying operations, **not substitutes for the wrapper**.
Godot can exit zero after import, parse or runtime errors. The wrapper fails on
nonzero exits, engine error diagnostics on stdout/stderr, a 60-second timeout per
process, or a runtime run missing the exact `ESTRAGON_SMOKE_OK` line. The frame
limit also bounds a test that never finishes; reaching it without completion fails.
Full diagnostics from a failed operation appear in the job log. See the
[Godot command-line reference](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html).

`tests/godot/smoke.gd` loads the unchanged `Hello.tscn`, instantiates the existing
host, checks its script and no-child/no-Control structure, verifies canvas RID
allocation, calls redraw, and frees the host through its normal exit lifecycle.
The wrapper rejects engine errors even if the test reaches its success marker.
This exercises the headless RenderingServer API path; it does not inspect pixels
or prove GPU rendering, and the RID check does not independently prove deallocation.
Future component assertions can extend this script, failing with an explicit
nonzero `quit(1)` and emitting the completion marker only after all checks finish.
New `.gd` files anywhere in the project copy are automatically parsed.

`test:godot-harness` uses isolated temporary projects to prove rejection of:

- A corrupt PNG import, even when Godot exits zero.
- Malformed GDScript, even when `--check-only` exits zero.
- A deliberately failed runtime test (`quit(1)`).
- `push_error` followed by the success marker and `quit(0)`.
- A failing GDScript assertion.
- An early `quit(0)` without the completion marker.
- A hung test (killed after one second in this probe).

It checks each failure's expected evidence, so a missing binary or unrelated error
cannot satisfy the negative tests. Both commands fail if the engine version differs.
CI runs both commands in a separate Godot job and preserves every compiler check.
The existing `bun run check` remains the compiler-only convenience command.

## Godot visual smoke check (manual, separate from CI)

1. Open the repository root as a **Godot 4.7** project.
2. Run `examples/hello/Hello.tscn` or the configured main scene.
3. Confirm a near-dark background, purple panel, and teal stripe.
4. Confirm the remote scene tree has **one Estragon host `Node`**, and no `Control` instances generated for each Gogo element.
5. If checking compiler-to-visual changes, edit `examples/hello/Main.gogo`, regenerate the JSON with Bun, and run the scene again. Verify that rectangle changes appear, then restore any temporary edits.
6. If editor extension support is desired, enable the optional plugin and confirm `.gogo` appears in the file browser (see [EDITOR.md](EDITOR.md)). This optional step changes persistent global editor settings; automated checks never enable the plugin.

Record whether this manual check actually ran in every Godot-facing PR/handoff.

## Known gaps

Headless CI does not validate pixels, colors, GPU behavior, or the remote editor
scene tree. Automated visual snapshots, multi-platform CI and benchmarks do not
exist yet. **Passing headless CI does not establish visual correctness.**
