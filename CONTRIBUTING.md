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
python3 tools/gogo.py examples/hello/Main.gogo --output examples/hello/generated/Main.gogo.json
python3 -m unittest discover -s tests -v
```

When changing Gogo, update the language specification, examples, golden IR and tests. When changing graphics behavior, document the backend assumptions and add reproducible smoke-test steps. CI currently covers only the Python compiler.

Pull requests should explain intent, changes, verification, compatibility and whether an architecture decision is affected. Keep speculative features in issues/docs until a functioning prototype demonstrates their viability.

## License

Estragon is licensed under the [MIT License](LICENSE). By contributing, you agree that your contributions will be distributed under this license. Please do not submit third-party assets, fonts, or source files without confirming redistribution rights.
