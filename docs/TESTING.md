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

## Godot smoke check (manual for now)

1. Open the repository root as a Godot 4.x project.
2. Run `examples/hello/Hello.tscn` or the configured main scene.
3. Confirm a near-dark background, purple panel, and teal stripe.
4. Confirm the remote scene tree has **one Estragon host `Node`**, and no `Control` instances generated for each Gogo element.
5. Edit `examples/hello/Main.gogo`, regenerate the JSON with Bun, and run the scene again. Verify that rectangle changes appear.
6. If editor extension support is desired, enable the optional plugin and confirm `.gogo` appears in the file browser (see [EDITOR.md](EDITOR.md)).

## Known gaps

Compiler checks do not exercise GDScript against a running Godot binary. Automated visual snapshots, multi-platform testing, and benchmarks do not exist yet. **Passing CI does not establish that the Godot renderer was exercised.**
