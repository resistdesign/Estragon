# Tests and verification

## Native Godot compiler/editor acceptance (N01–N03)

Normal Godot authoring uses the bundled native compiler and editor build gate;
Bun/Node/TypeScript are not user prerequisites. The standalone native frontend,
generation/runtime and fresh-project editor harnesses below run independently
of Bun. Existing TypeScript tests remain optional contributor/CI parity tooling.

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

## Native editor compilation, Play and restart (T08/N03)

```sh
GODOT_BIN=/absolute/path/to/godot sh tools/check-editor.sh
# Optional repository wrapper for the same independent harness:
bun run test:editor
```

The shell creates a fresh project containing the addon, Counter.gogo/scene and
necessary test resources, with no tools/TypeScript/package files, configuration
or generated application scripts. It copies the official Godot executable into
a self-contained directory (`_sc_`) so project/plugin/editor preferences are
isolated. macOS ad-hoc signing applies only to that copied test binary. Every
editor, game and build-test process uses an empty executable PATH; no Bun/Node
or fallback compiler can be discovered. The owner's project/plugin/settings are
never changed. CI runs the shell directly in its Godot job.

The real editor driver opens Gogo through FileSystem, verifies automatic native
highlighting (plus 16 lexical checks), saved/unsaved/external changes (including with Godot pre-run autosave disabled), and actual
`play_main_scene()`/`play_current_scene()` run commands. The launched Counter
records initial state/text and verifies +/Reset through viewport pointer events,
new labels, responsive geometry after viewport resize, one host/connection and
cleanup of old buttons. Invalid markup and GDScript semantics block **both**
Play modes without producing a game proof; repair recovers. It checks unchanged
output/cache identity, generated class registration, disable/re-enable, preserved
extension settings and lack of rebuild loops. A second full editor process proves
restart still builds/runs current source without external tools.

E01 additionally opens untagged plain Gogo tabs while the plugin is disabled,
then enables it without reopening them or selecting Gogo manually. It checks
actual attached highlighter classes and declaration/markup token colors, two
independent editors, fresh tabs, repeated disable/re-enable and exact preservation
of Markdown/plain-text highlighters (including Gogo-looking `.gogo.txt`). Before
the second process, `seed_plain.gd` changes **only the temporary project's** native
per-file cache entries to `Plain Text`, reproducing older restored-tab state.
Startup assertions inspect restored buffers before any navigation/reopening.
This fixture does not modify the owner's cache or persistent editor preferences.

`native_build.gd` runs in the same isolated project/PATH and covers sorted/default
and explicit discovery, exclusions/dedup, bad config/roots, symlink rejection,
no-op code/maps/UID/timestamps, all-file frontend failure, semantic rollback,
repair, mode/map transition and changed multi-file dependency types/cached code.
It counts expected engine diagnostics; unexpected errors fail. The editor shell
also rejects unexpected script/game errors and requires phase/build markers.

The optional TypeScript `tests/editor-build.test.ts` coverage remains intact as
reference tooling. It does not participate in native compilation. Authored
examples and checked generated fixtures in the checkout are never modified.

### Graphics evidence and manual Godot 4.7 procedure

```sh
GODOT_BIN=/absolute/path/to/godot ESTRAGON_KEEP_EDITOR_TEST=1 \
  ESTRAGON_EDITOR_NATIVE=1 sh tools/check-editor.sh
```

This captures the native highlighted editor and actual launched Counter's initial,
incremented and reset/resized states under the temporary project's
`.godot/estragon`. The test changes **only its isolated** editor preference to
run games in separate native windows, enabling actual window/viewport resizing.
Godot's default embedded **Fixed Size** deliberately keeps a fixed viewport;
use the Game bar's Stretch to Fit (or unembedded play) when manually checking
responsive resize. The plugin never changes this user preference. See
[Godot's game-embedding sizing contract](https://docs.godotengine.org/en/4.7/tutorials/editor/game_embedding.html).

Automated run commands/graphics/pointer injection do not certify physical keys,
mouse/window-manager behavior or every platform dialog. Manual procedure:

1. Enable the addon in Godot 4.7, open Counter.gogo from FileSystem, and verify
   mixed highlighting. Also open it before enabling Estragon, then enable the
   plugin with the tab still open; colors should appear automatically. Restart
   with the tab open and verify colors without menu selection. Check a Markdown
   or plain text tab keeps its own highlighter. No compiler install is needed.
2. Open Counter.tscn; edit count or label without saving, press F6, then F5 with
   this scene set as main. Verify newest text, +/Reset and viewport resizing.
3. Break a tag/property, then a handler name/type; both keys must refuse Play
   with authored diagnostics. Repair and rerun. Check saved/external changes too.
4. Rebuild unchanged source: no generated file churn. Disable/re-enable and
   restart: no duplicate hooks, lost extension settings or stale outputs.
5. Inspect the remote tree: one host, independent components; restore local
   source/main scene settings if desired.

Record whether this physical-key/manual procedure ran separately from automated
native graphics captures. Compiler/semantic errors remain engine log entries;
the Gogo panel presents the current authored-source report.

## Native frontend without Bun (N01)

```sh
GODOT_BIN=/absolute/path/to/godot sh tools/check-native-frontend.sh
```

This requires only the pinned Godot 4.7 editor and standard system shell tools.
It copies only the native compiler, test script and committed reference transcript
into a fresh minimal project, without an import pass or editor plugin. Godot runs
with `/usr/bin:/bin` PATH; the test asserts Bun is unavailable there. Success
requires exit zero, no engine errors, and both `NATIVE_FRONTEND_NO_BUN` and
`ESTRAGON_NATIVE_FRONTEND_OK`. The full Godot harness also runs these frontend
tests. CI checks the optional TypeScript transcript separately with
`bun tools/native-frontend-cases.ts`; that check is not needed for native use.

The native test checks reference acceptance, typed trees/source spans and first
error starts, lossless tokens, truncations, recursion limits, independent calls,
and a tiny test-only literal-to-executable-GDScript proof. N02 adds general generation and Counter execution through the independent harness below. There is no
editor or visual behavior change in N01; manual editor/visual smoke testing is
not evidence of native emission or native Play integration yet.

## Native generation and runtime without Bun/Node (N02)

```sh
GODOT_BIN=/absolute/path/to/godot sh tools/check-native-generation.sh
```

The shell copies only the native compiler/runtime, authored examples, checked
reference transcripts and tests into a temporary project. All Godot invocations
for import, compilation and execution use an **empty tool directory as PATH**:
Bun, Node and external compiler executables are unavailable. No TypeScript is
run, even to generate fixtures. Checked-in generated application scripts are
excluded from the temporary project before native generation. The native emitter builds all example outputs
before the existing standalone/hybrid/signal runtime tests execute them.
`native_counter.gd` additionally reads the real Counter.gogo, compiles/validates
it and instantiates it in a single Godot process.

Positive stages reject engine error text/nonzero exit/missing markers. The
semantic-negative stage intentionally logs errors: its logger counts expected
errors across the whole test, verifies mapped diagnostics and unavailable
executables, and requires its own marker. Unexpected errors fail that stage.
The native suite covers the N01 corpus, code/maps determinism, exact reference
hybrid output/map digests, copied ranges/UTF-16 coordinates, numeric precision,
Unicode/control literals, relative preloads, registered class_name/cache isolation, semantic failures,
callback runtime guards, +/Reset pointer input, refreshed text/paint, resizing
and automatic ownership/signal cleanup. Optional transcript freshness:

```sh
bun tools/native-generation-cases.ts        # no native execution dependency
bun tools/native-generation-cases.ts --write # intentional reference refresh
```

For native graphics captures, retain the temporary project, then run its direct
Counter test without `--headless`:

```sh
export GODOT_BIN=/absolute/path/to/godot
ESTRAGON_KEEP_NATIVE_TEST=1 sh tools/check-native-generation.sh
# Copy the reported temporary path into this variable:
task_native_project=/reported/temporary/project
env PATH="$task_native_project/no-tools" "$GODOT_BIN" --path "$task_native_project" \
  --script res://tests/godot/native_counter.gd -- --visual
```

This saves `native-counter-zero.png`, `native-counter-one.png`, and
`native-counter-reset-resized.png` in that isolated project. N02's local Godot
4.7 Vulkan run produced and inspected all three: Count 0/disabled Reset, Count 1/
enabled Reset, then Count 0 and a wider row at 800×400 (initially 640×360).
These are native graphics captures with synthesized pointer events, not a manual
physical-mouse/editor F5/F6 test. The independent editor suite above proves native editor Play without external tools.

## Known gaps

Headless CI does not validate pixels, colors, GPU behavior, or the remote editor
scene tree. Automated visual snapshots, multi-platform CI and benchmarks do not
exist yet. **Passing headless CI does not establish visual correctness.**

## R01 annotation feasibility research

Run `GODOT_BIN=/absolute/path/to/Godot sh tools/check-bindable.sh` with the pinned 4.7 binary. This standalone harness needs no Bun/Node: fresh projects, empty executable PATH and self-contained real editor settings. It asserts expected parser/dependency/language/import failures alongside successful typed setter and remap execution, exact authored diagnostics and unchanged authored bytes. `ESTRAGON_KEEP_BINDABLE_TEST=1` retains isolated logs. See [findings and limits](BINDABLE_FEASIBILITY.md); a passing research suite does not mean `@Bindable` is supported.

## E01 focused cross-version proof (not the C01 release matrix)

Run `GODOT_BIN=/path/to/official/godot ESTRAGON_KEEP_COMPAT_TEST=1 sh tools/check-highlighting-compat.sh` on a supplied engine. It executes two real isolated editor processes with only E01 modules, 46 assertions including an explicit negative filtered-identity probe, then a separate complete-addon startup diagnostic. Empty executable PATH, no Bun/Node or owner setting/cache changes. `E01_FILTERED_UNASSOCIATED_UNMET` and `E01_FULL_ADDON_BLOCKED` are unmet/failed acceptance results even if the evidence-collection script exits zero; do not interpret that as older-version certification. Unexpected isolated script errors or missing markers fail the harness.

See [exact 4.0–4.7 versions, checksums, results and limits](E01_COMPATIBILITY.md). Existing required compiler/runtime/editor/graphics checks still target 4.7. C01-A #42 owns the broader compatibility inventory/matrix after #40 merges or closes; this E01 fixture does not implement it.


## C01-A reusable compatibility matrix

See [C01_COMPATIBILITY.md](C01_COMPATIBILITY.md) for exact engine provenance,
source-located failures, stage meanings and follow-up ordering. The E01 fixture
above is historical focused evidence, not the full audit.

```sh
python3 -m unittest discover -s tests/compatibility -p 'test_*.py'
python3 tools/check-compatibility.py \
  --engine 4.0.4=/absolute/official/godot-4.0.4 \
  --engine 4.7.2=/absolute/official/godot-4.7.2 \
  --output /new/result-directory --editor
```

Python 3.9+ is contributor orchestration only; actual Godot processes have empty
PATH and isolated self-contained settings/projects. No Bun/Node is used. Supply
verified executables matching `tests/compatibility/engines.json`; macOS hashes refer to
verified pre-signing bytes; only the copied test binary is signed. Repeat `--engine` for each
minor. Results/logs are written incrementally; output directories cannot already
exist. Engine errors, nonzero exits, deadlines and missing markers are failures,
including errors printed before an exit-zero success marker.

The default command exits nonzero for any FAIL/BLOCKED/UNTESTED stage, including
unproved graphics/manual interaction. **`--collect-only` is an informational
collection mode**, preserving all red JSON results. Its zero exit is never a
compatibility pass. `.github/workflows/compatibility.yml` runs official latest
selected patches for each minor on macOS, checks archive/executable checksums,
rejects infrastructure failures and uploads every stage log/result. The existing
required 4.7 Linux job remains required; C01-H will establish the final supported
release gate after defects are fixed and remaining evidence is supplied.

The matrix checks clean product import, every shipped script, native frontend,
code/maps, isolated numeric semantics, legacy/runtime/generated examples,
semantic diagnostics/cache/relative-load/class identity, real headless editor
startup and E01 restoration. Full unsaved Play/recovery runs on 4.7.0 and 4.7.2;
older startup failures block that acceptance. `ESTRAGON_TEST_GODOT_VERSION` permits
an explicitly verified newer patch in the unchanged full editor harness, while
its default stays pinned to 4.7.0. This override is test-only; it is not a product
version fallback. Physical F5/F6, other-platform older engines, export and older
GPU pixels remain separately UNTESTED. Preserve #44's explicit filtered-tab FAIL.

For a compact committed snapshot, pass the complete nonoverlapping raw reports
to `python3 tools/summarize-compatibility.py --report /run/results.json --output
tests/compatibility/results.json` (repeat `--report` for split runs). It requires
all pinned manifest versions, preserves every stage and per-file parse outcome,
and fingerprints the raw reports/logs. CI artifacts retain the full commands and
logs. Local and CI fingerprints differ when temporary paths or script IDs differ.


## C01-B sizing and lifecycle regression gates

[Runtime evidence](C01_B_RUNTIME.md) describes the scalar maxima, fractional/zero
geometry, incoming-signal cleanup and all-engine matrix checks. The existing
collector now runs five invalid-sizing and two invalid-text probes in separate
cold processes and requires exactly one expected diagnostic plus completion.
An extra parser/compile error fails the probe, even if the expected marker appears.
The matrix CI requires scoped component/layout/input, sizing rejections and both
affected script parses to pass. Other red compiler/editor stages remain visible.
Cold Text-first invalid-text failures are tracked in #48/#41 and retained as FAIL;
they are not silently waived by successful collection or warmed by fixture loads.
The C01-A baseline snapshot is preserved; C01-B results are stored separately.


## C01-C callback checks

The C01 collector runs `callback_metadata.gd`: 21 observations without candidate
invocation. Exact expected metadata errors are counted; unexpected diagnostics
or missing observations fail. `callback_metadata_probe=PASS` means evidence
integrity, not callback portability. `callback_arity_api=BLOCKED` on 4.0–4.2
records an absent API, not failure of the approved normal-invocation fallback.

`generated_signals` checks real native-generated Counter behavior, callback order,
bound/lambda/static inputs, duplicate prevention and automatic cleanup.
`callback_guard_*` runs nine isolated expected-diagnostic processes: empty,
missing, freed, disposed, required/optional methods and lambdas, and unbound.
Every version rejects invalid/disposed targets before connection. 4.3+ rejects
nonzero arity early; 4.0–4.2 invokes optional callbacks normally and reports required
argument errors at activation. Exact error count/content plus completion and
connection/cleanup assertions prevent arbitrary failures from passing.
See [C01_C_CALLBACKS.md](C01_C_CALLBACKS.md) and the structured C01-C snapshot.


## C01-D numeric value and native-limit checks

[Numeric contract/evidence](C01_D_NUMBERS.md) records the owner-approved native
semantics. The isolated probe executes canonical tokens and checks model/runtime
bytes against 27 independent binary64 oracles, deterministic maps and binary
storage controls. Three additional native parser discrepancies retain their IEEE
oracles as BLOCKED and must preserve source-native values through emission.
CI requires `numeric_literals` and `numeric_native_preservation` PASS; the separate
`numeric_native_conversion` BLOCKED capability is never presented as IEEE success.
The native generation harness also runs this probe with Bun/Node unavailable;
its semantic suite checks real component properties. Collector unit tests detect
missing records, corrupted oracles, false PASS claims and extra emission loss.

To preserve numeric details in a committed nine-engine snapshot, use
`python3 tools/summarize-compatibility.py --report /run/results.json --output
 tests/compatibility/c01-d-results.json --scope "C01-D native numeric semantics;
 not full-addon certification"` (repeat `--report` for split runs). All pinned
engines are required, every stage remains intact and logs/reports are hashed.
