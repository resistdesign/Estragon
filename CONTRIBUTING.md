# Contributing to Estragon

Estragon is at an experimental design and scaffold stage. Read [VISION.md](docs/VISION.md), [ARCHITECTURE.md](docs/ARCHITECTURE.md) and [DECISIONS.md](docs/DECISIONS.md) before proposing implementation changes.

## Project invariants

- Estragon renders UI itself. Do **not** generate Godot `Control` widget trees from `.gogo`.
- Do **not** implement a per-element Godot `Node` requirement. A small host and optional integration adapters are acceptable.
- Keep the compiler and intermediate representation independent from the renderer.
- Label unimplemented syntax as proposals in docs and examples.
- Prefer compile-time validation and tests over implicit magic or silent fallback.

## Development

```sh
bun install --frozen-lockfile
bun run gogo examples/hello/Main.gogo --output examples/hello/generated/Main.gogo.json
bun run check
```

**Future direction:** Gogo uses TSX-like GDScript-plus-XML-like expressions, unprefixed component tags and generated GDScript. The current namespaced XML-to-JSON compiler is a temporary demo. See [the design direction](docs/DESIGN_DIRECTION.md), including the unresolved native `@Bindable` parsing problem.

When changing the **stage-0** compiler, update the supported language specification, examples, golden JSON IR and tests. New Gogo-to-GDScript work should generate tests and a runnable Godot proof. When changing graphics behavior, document the backend assumptions and add reproducible smoke-test steps. CI typechecks the TypeScript tooling, runs Bun compiler tests, and checks generated IR. It does not run Godot.

Pull requests should explain intent, changes, verification, compatibility and whether an architecture decision is affected. Keep speculative features in issues/docs until a functioning prototype demonstrates their viability.

## License

Estragon is licensed under the [MIT License](LICENSE). By contributing, you agree that your contributions will be distributed under this license. Please do not submit third-party assets or source files without confirming redistribution rights.
