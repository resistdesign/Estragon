# Tests and verification

## Compiler tests

Run from repository root:

```sh
python3 -m unittest discover -s tests -v
```

The suite covers successful compilation, deterministic UI IR, namespace/schema errors, unknown component types, ID uniqueness, dimensions/colors and the checked-in example. The only toolchain needed is Python 3.10+.

Check generated sample freshness:

```sh
python3 tools/gogo.py examples/hello/Main.gogo --output /tmp/Main.gogo.json
diff -u examples/hello/generated/Main.gogo.json /tmp/Main.gogo.json
```

GitHub Actions repeats both checks on pushes and pull requests.

## Godot smoke check (manual for now)

1. Open the repository root as a Godot 4.x project.
2. Run `examples/hello/Hello.tscn` or the configured main scene.
3. Confirm a near-dark background, purple panel and teal stripe.
4. Confirm the remote scene tree has **one Estragon host `Node`**, and no `Control` instances generated for each Gogo element.
5. Edit `examples/hello/Main.gogo`, regenerate the JSON via Python and run the scene again. Verify that rectangle changes appear.
6. If editor extension support is desired, enable the optional plugin and confirm `.gogo` appears in the file browser (see [EDITOR.md](EDITOR.md)).

## Known gaps

This scaffold's Python tests do not validate the GDScript host against a running Godot binary. There is no automated visual snapshot test, multi-platform test or benchmark yet. Do not interpret a passing Python CI job as proof that the Godot UI runtime has been comprehensively tested.
