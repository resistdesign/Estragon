# Tests and verification

## Compiler typechecking and tests

Requires **Bun 1.4.4**. From the repository root:

```sh
bun install --frozen-lockfile
bun run typecheck
bun run test
bun run verify:ir
bun run verify:gdscript
```

The TypeScript suite covers successful compilation, deterministic IR, alternate/default XML namespace prefixes, invalid source, schema errors, duplicate IDs, dimensions/colors, CLI failure handling, and the checked-in example. Typechecking is **mandatory**: Bun's TypeScript execution alone does not validate types.

The convenience command `bun run check` runs the typecheck, tests, and IR fixture verification together.

## T04 compiler and generated GDScript

The Bun suite also tests the namespace-free markup-expression parser, typed
literal validation, exact source spans/CRLF diagnostics, malformed/unsupported
source, nesting bounds, deterministic emission, injection rejection and CLI
failure/output preservation. `bun run verify:gdscript` independently compares
`examples/compiled/Layout.gogo` compilation against its checked-in `.gd` fixture
without rewriting it. The compiler job runs this alongside the legacy IR check.
`bun run check` includes both fixture checks.

Regenerate intentionally changed output with:

```sh
bun run transpile examples/compiled/Layout.gogo --output examples/compiled/generated/Layout.gd
```

`check:godot` recompiles that source in its temporary copy **before import** and
also emits fresh empty-container and large-number/RGBA variants. Every resulting
script is parsed by Godot. `tests/godot/generated_gogo.gd` then runs 21 assertions
against the actual generated code: runtime class/property resolution, mounting,
nested/absolute paint geometry, colors, automatic resizing, root/component
unmount and renderer cleanup, zero-size/large-number literals and an empty root.
It requires `ESTRAGON_GENERATED_GOGO_OK` under the same exit/error/timeout rules.
No generated probe files or UID/cache changes are written into the working tree.

For graphics verification, compile first and run `examples/compiled/Compiled.tscn`
in Godot 4.7. Expect the same responsive header/sidebar/content as the T03 layout
example. The graphics capture procedure below also applies with that scene path.
The .gogo source is never interpreted at runtime. Compiler generation is explicit;
automatic editor compilation/stale-run blocking remain T08 work.

## T05 hybrid frontend, maps and Godot semantics

`tests/hybrid-gogo.test.ts` adds lexical composition, expression-boundary,
malformed-source, determinism, range mapping and CLI-sidecar tests. The complete
Bun suite currently has 100 tests (all previous 81 preserved). Fixtures include
`examples/mixed/generated/Mixed.gd` and its `.map.json`, verified byte-for-byte by
`verify:gdscript` without rewriting old T04 output.

```sh
bun run transpile examples/mixed/Mixed.gogo --output examples/mixed/generated/Mixed.gd
```

The isolated Godot runner recompiles that source and the adversarial
`tests/fixtures/hybrid-edges.gogo` before import. Every generated script is
parsed. `tests/godot/hybrid_gogo.gd` runs 29 assertions, requiring
`ESTRAGON_HYBRID_GOGO_OK`: member/local/parameter scope, helper/lambda/static
methods, inferred and member-initializer component variables, nested markup,
component-valued/conditional children, integer division, side-effect order,
multiline comparisons, dictionaries, raw/triple strings, for-loops, explicit
continuation, name collisions, actual viewport resize, explicit rebuild and
framework-owned cleanup without component disposal calls.

Six separate negative scripts are generated **after** positive import/parse:
malformed GDScript expression, incompatible property type, incompatible child
type, undefined identifier, null dynamic child and invalid dynamic width. Each
must produce its expected real Godot error and a mapped authored `.gogo` line;
runtime probes must also finish explicitly. Unexpected failures/timeouts do not
satisfy these tests. Expected-error scripts never enter the working project.

The validator prints `Gogo source: file:line:column` annotations for registered
fresh hybrid scripts while retaining raw Godot diagnostics. This demonstrates
available Godot syntax/type checking and source tracing, **not** a TypeScript
GDScript semantic checker or editor/debugger integration. Dynamic Variant values
and numeric constraints can fail only at runtime. No reactive binding guarantee
is made.

For a real graphics check, run `examples/mixed/Mixed.tscn` after compilation.
Expect a computed purple header, helper-created teal sidebar and remaining
content. The capture procedure below works with this scene path. Record whether
a graphics capture was inspected and whether the separate interactive editor
resize/remote-tree check actually ran.

## T06 text/button/input verification

`tests/godot/interaction.gd` runs 78 assertions in the isolated Godot validator with the same
error/timeout rules and requires `ESTRAGON_INTERACTION_OK`. It uses real fonts,
canvas drawing and the Godot Viewport input bridge, plus the public surface
input adapter for deterministic interaction sequences. Assertions cover:

- Shaped-string metrics, explicit multiline baselines, font/size/color/text
  invalidation, fixed/intrinsic sizing, empty/zero-area text and label padding.
- Interleaved rectangle/text paint order and normal/hover/down/disabled visuals.
- Nested local/absolute coordinates, half-open bounds, spacing gaps, topmost
  overlays, disabled occlusion and unclipped overflow.
- Resizing/current layout before the next event, distinct button handlers,
  duplicate/unmatched down/up, press-outside, release-outside/over-another,
  leave/reenter, secondary/keyboard exclusion and window focus/exit cancellation.
- Reparenting across containers/surfaces, remove/replace/unmount, terminal signal
  disconnection/Font release, weak reference reclamation, exit/re-entry and window
  subscription teardown. No application component disposal calls.
- Reentrant root replacement, queued host teardown, and the actual runnable
  example's Add one/Reset GDScript handlers updating visible text.

`invalid_text.gd` separately proves null Font and nonpositive font-size errors
preserve previous values. Each must emit exactly the expected diagnostic and
`ESTRAGON_INVALID_TEXT_REJECTED`; unrelated errors/timeouts fail the check.
All previous runtime suites and the 100 Bun tests/fixtures remain required.

## Interactive components visual check (T06)

Run `examples/interactive/Interactive.tscn` in Godot 4.7 (the legacy main scene
remains unchanged). No compilation is needed: this example is authored ordinary
GDScript and deliberately uses direct `button.pressed.connect(handler)`.

1. Confirm heading, count/status text, Add one/Reset labels, a dimmed Disabled
   button and two instruction lines. Hover brightens a button; holding darkens it.
2. Click Add one several times: status increments and reports its handler.
   Click Reset: status returns to zero and reports the distinct Reset handler.
   Check the output log for the corresponding handler messages.
3. Press a button, move outside it, release: no activation. Press and leave then
   reenter before release: one activation. Release over the other button: neither
   activates. The Disabled button never activates. Rapid/repeated input must not
   produce an extra activation per completed press/release.
4. Resize: equal-width buttons share the row's remaining width. Text uses intrinsic
   size/explicit newlines; it does not wrap and can overflow tiny viewports. Click
   at the new button positions to verify targeting follows layout.
5. Alt-tab or leave the window during a press: it cancels. Stop/restart without
   debugger errors. Inspect the remote tree: one surface Node, no component Nodes
   or Controls. Component cleanup is owned by the framework.

For real graphics evidence use the existing isolated-capture procedure with this
scene. A fixed-resolution movie can show states, but dynamically resizing during
movie recording may crop/scale its fixed output. For resize evidence instead save
`get_viewport().get_texture().get_image().save_png(...)` after
`RenderingServer.frame_post_draw` in an isolated native graphics run. Viewport
`push_input(event, true)` can exercise the same `_input` bridge in that run;
record whether physical/editor interaction actually ran. Headless tests measure
geometry and check engine errors; they do not inspect text pixels or GPU output.

## T07 generated signals and Counter

`tests/signal-gogo.test.ts` adds 37 Bun tests for Text/Button literals and typed
expression properties, leaf/event compatibility, duplicate/unknown attributes,
safe string/integer emission, ordered property/callback evaluation, native
callable/lambda syntax, name collisions, deterministic Counter code/map fixtures
and event source mapping. The full Bun suite has 137 tests. One old unknown-Button
case now uses unknown Label because Button is intentionally supported.

```sh
bun run transpile examples/counter/Counter.gogo --output examples/counter/generated/Counter.gd
bun run verify:gdscript
```

The isolated Godot runner freshly compiles Counter, a signal edge module and
standalone Text/Button literals before import. `tests/godot/generated_signals.gd`
runs 44 assertions with `ESTRAGON_SIGNALS_OK`: actual Viewport input -> generated
handler -> count/text update, distinct Reset handler, repeated explicit rebuilds
without duplicate/stale connections, resizing/paint output, Callable-producing
attribute order, local/bound/lambda/static scope, direct target reparent/disposal,
captured-resource release, unmount/host destruction and standalone primitive props.
Application components are cleaned by owners, never manual disposal calls.

Ten new source-mapped Godot negatives join the previous six hybrid probes:
missing handler, non-Callable value, invocation returning the wrong type, wrong
text/disabled types, required/optional nonzero arity, empty Callable, nonexistent
Callable method and retained disposed direct target. Guards must reject without
connecting, emit exactly one expected engine error, reach the completion marker
and map to the authored event line. Other static errors come from Godot's actual
compiler. This does not claim full TypeScript GDScript checking, bound-argument
type proofs or arbitrary closure-effect/lifetime analysis.

### Counter visual check

1. Compile Counter with the command above; run `examples/counter/Counter.tscn`
   in Godot 4.7. Expect a purple heading, Count: 0, `+` and dimmed Reset buttons.
2. Click `+` repeatedly: each complete click increments once. Reset becomes
   enabled; click it and confirm Count: 0 and disabled Reset again. Authored
   Counter.gogo must have no `.pressed.connect(...)`; inspect generated `.gd`
   for the two guarded native connections.
3. Hold/leave/reenter/release and release outside as in the T06 procedure. Resize:
   both buttons share the row width and remain correctly targeted. Text does not
   wrap; narrow windows may overflow. Stop/restart without debugger errors.
4. Inspect remote scene tree: one surface Node, no component widgets. Rebuilds
   and signal teardown are covered by automated runtime tests, not manual cleanup.

Native graphics evidence can use an isolated imported copy, injected
`Viewport.push_input(event, true)` through the actual input bridge and viewport
PNG capture after `RenderingServer.frame_post_draw` (see T06). Capture count 0,
count 1/2, pressed state and Reset after resizing. Record physical/editor smoke
separately; headless checks do not certify pixels.

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
A second runtime process runs `tests/godot/components.gd` with the same timeout,
error and exit checks and requires `ESTRAGON_COMPONENTS_OK`. It checks standalone
RefCounted component identity, ordered/nested membership, snapshot isolation,
add/remove/reparent, null/duplicate/cycle/disposed rejection, dirty propagation
and clearing, recursive/idempotent cleanup, cleanup-hook adoption rejection and
strong/weak reference reclamation. Component tests create no component scene
nodes or RIDs. Failures produce diagnostics and exit 1; the completion marker is
emitted only if every assertion succeeds. The original prototype smoke remains
a separate process and still must pass.
`tests/godot/layout.gd` runs in a third bounded runtime process requiring
`ESTRAGON_LAYOUT_OK`. Its 64 assertions cover nested natural/fixed/fill geometry,
fractional gaps, zero/overflow sizing, ordered absolute paint commands, actual
SubViewport resizing, automatic property invalidation/repaint, surface canvas
ownership, re-entry, subscription teardown and cleanup on removal/replacement/
surface destruction (including cross-surface moves and pending deferred work).
Application-style lifecycle tests never call component disposal. The T02 suite
retains internal mechanism tests with deliberately updated unmount expectations.

Five separate `invalid_sizing.gd` probes attempt infinite width, NaN height,
illegal negative width, negative gap and invalid arranged geometry. Each must
emit exactly its expected error, retain the previous values and finish with an
explicit marker; other engine errors, timeout or unexpected exits fail validation.
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

## Independent layout/rendering visual check (T03)

The original JSON scene above remains the configured main scene. For the new
component runtime, open and run `examples/layout/Layout.tscn` in Godot 4.7:

1. Confirm a purple header, a teal fixed-width sidebar beneath it, and a muted
   purple content area filling the remaining space. Header height is 64 logical
   units, sidebar width 160; vertical gap 16 and horizontal gap 12.
2. Resize the window wider/narrower and taller/shorter. The header follows width;
   the sidebar follows remaining height; content follows both remaining axes.
   Very small viewports may overflow fixed sizes (no clipping or shrink yet).
3. Inspect the remote scene tree: one `EstragonLayoutSurface` Node, no component
   Nodes or Godot Controls. Stop/restart and check the debugger for errors.
4. Root replacement/removal and cleanup without disposal calls are covered by
   the automated lifecycle tests; no application-level cleanup is required.

For a repeatable graphics capture on a machine with a display/OpenGL driver,
use an isolated project copy, import it with the wrapper's documented import
command, then run:

```sh
godot --path "$PROJECT_COPY" --scene res://examples/layout/Layout.tscn \
  --write-movie /tmp/estragon-layout.png --quit-after 3 --resolution 640x360
```

Inspect the numbered PNG frames. `--write-movie` uses the configured movie output
size (960x540 here), which can differ from the window's logical viewport size.
This is a real graphics check, **not part of headless CI**. It does not replace
interactive editor resizing/remote-tree inspection. Record exactly which checks
actually ran in the PR/handoff; do not label headless geometry tests visual proof.

## T08 automatic editor compilation and highlighting

```sh
bun run test:editor
```

The harness copies the project and official editor executable into a temporary
self-contained directory (`_sc_`). It enables Estragon plus a test-only driver in
that copy, configures the absolute Bun executable and isolates EditorSettings.
On macOS it ad-hoc signs only the copied executable. The user's project plugin
state/global settings are untouched. `GODOT_BIN` selects the same pinned editor as
other checks. CI runs this in the Godot job with headless game subprocesses.

The real editor driver exercises native file-dock opening and automatic extension
highlighter selection, 16 lexical color/cache checks, saved-file and external
source builds, both `play_main_scene()` and `play_current_scene()` (the native
F5/F6 run paths), changed unsaved buffers, current game state/text, invalid Gogo
blocking both modes, recovery, mapped GDScript semantic errors, missing Bun,
compiler crash, timeout, plugin disable/re-enable, preserved extension settings,
restored highlighting and no endless rebuild loop. Test-only Counter `_ready`
records actual launched game state/text; checking only `_build()` is insufficient.
Failures exit nonzero or omit the required `ESTRAGON_EDITOR_OK` marker. Unexpected
script errors also fail; deliberately injected semantic/build failures are
expected diagnostics. The complete run has 31 integration assertions plus the
16 lexical checks. Authored examples and generated fixtures in the checkout are
never modified by these tests.

`tests/editor-build.test.ts` adds 13 Bun tests for explicit sorted/deduplicated
source discovery, excluded paths, strict config errors, source/output symlinks,
compile-all-before-write, recovery, stable code/maps/mtime, source preservation,
missing native compiler and CLI reports. Full Bun suite: 150 tests. Every new
GDScript is also parsed by check:godot; editor-only objects are tested in the real
editor, not instantiated in an ordinary game process.

### Manual Godot 4.7 procedure

1. Follow EDITOR's one-time setup. Enable the plugin, configure absolute Bun if
   needed, open Counter.gogo from FileSystem and confirm normal Script Editor
   with Gogo coloring (declarations/tags/props/braces/strings/comments).
   A tab already open before initial enable may need reopening.
2. Open Counter.tscn. Change `var count: int = 0` to 7 in Counter.gogo, leave it
   unsaved, and use Run Current Scene (F6/Command-R). Confirm Count: 7 and working
   buttons; stop. Set Counter.tscn as main scene locally, change to 9, press F5,
   and confirm Count: 9. No manual compiler command should be required.
3. Break a component/property, press each Play action and confirm no game starts;
   inspect the Gogo bottom panel for authored file/line/column. Fix it and confirm
   execution resumes with current values. Repeat using an undefined handler to
   verify native GDScript errors map back to Counter.gogo.
4. Save a valid source while stopped and inspect generated output updating.
   Change it externally and refocus/scan sources; confirm regeneration. Generated
   code/maps should not churn for unchanged source; never edit them by hand.
5. Configure an invalid Bun path: Play must fail with an actionable setup message.
   Restore the correct executable and recover. Disable/re-enable twice: no
   duplicate panel/hooks, editor errors or lost extension settings. Known open
   Gogo tabs should regain highlighting. Stop/restart the editor and repeat.
6. Restore count/main scene/Bun settings after the smoke test if desired. Inspect
   the remote tree while running: one host, no component Controls or Node tree.

For repeatable native graphics evidence, the same isolated harness supports:

```sh
ESTRAGON_KEEP_EDITOR_TEST=1 ESTRAGON_EDITOR_NATIVE=1 bun run test:editor
```

It saves a native editor screenshot and launched Count 7/9/0 PNGs under the
reported temporary project's `.godot/estragon`. Inspect them with the log/results;
these are local temporary artifacts, not committed golden images. This exercises
real editor/graphics APIs but does not certify physical keyboard shortcuts,
platform dialogs or every OS/window-manager behavior. Record whether manual
keyboard/remote-tree checks ran separately.

## Known gaps

Headless CI does not validate pixels, colors, GPU behavior, or the remote editor
scene tree. Automated visual snapshots, multi-platform CI and benchmarks do not
exist yet. **Passing headless CI does not establish visual correctness.**
