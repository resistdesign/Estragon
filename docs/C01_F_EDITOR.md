# C01-F native editor startup and lifecycle

C01-F [#49](https://github.com/resistdesign/Estragon/issues/49) merged in
[PR #62](https://github.com/resistdesign/Estragon/pull/62) at `95efa45`, based
on C01-E merge `c17902a`. This is a scoped editor fix, not full Godot 4.0+ certification.

## Cause and correction

Merged-main startup reproduces two distinct API failures: Godot 4.0/4.1 reject
static EditorInterface calls; later pre-4.7 engines can produce a valid build
report while still emitting an error for the unavailable
`EditorFileSystem.is_importing()`. A successful report alone is insufficient.

The plugin now uses its owning EditorPlugin's EditorInterface instance, public
filesystem scanning and native class metadata, and capability checks for optional
import-status/settings-change APIs. Cold old editors must register the runtime
before validating generated inheritance. Newer editors already load class names
before plugins, so their first native build remains synchronous: unconditionally
deferring it lets the editor restore a scene before its generated Script exists.
Saved-disk changes wait for scanning/import readiness and share the existing
coalescing timer. Generated files' native CodeEdit buffers are refreshed after
successful validation using public `editor_script_changed`/current-editor
associations. Otherwise old native buffers overwrite current cached source and
can save stale bytes on shutdown. Only build-owned output paths are eligible;
weak editor/Script references are released on disable, cursor/scroll positions
are retained, and authored buffers are untouched. No UI hierarchy/path heuristic,
compiler, generated-code, runtime or renderer changes. The
[pre-fix trace](../tests/compatibility/c01-f-buffer-before.json) retains the
stale cache/shutdown failure. Godot's own 4.0
[ScriptTextEditor implementation](https://github.com/godotengine/godot/blob/4.0.4-stable/editor/plugins/script_text_editor.cpp)
explains why: both ordinary code application and validation assign the buffer's
text to the Script; refreshing the resource alone does not refresh that buffer.

Committed-output filesystem refresh uses a pending idle scan rather than
reentrant per-file `update_file()` calls: the latter reproduced duplicate native
`update_script_paths_documentation` tasks in a graphical editor. Import/class
notifications must settle within the test's explicit 15-second bound, then idle
build count must remain unchanged.

Disable disconnects filesystem/resource hooks, stops/frees pending work, releases
the diagnostics panel and unregisters/stops highlighting. Re-enable creates a
fresh integration and rebuilds current disk sources. Existing extension settings
are preserved, including after disable and restart. Native builds retain C01-E
transactional validation, rollback, source freshness and cached Script identity.

## Reproduce

```sh
python3 tools/check-editor-lifecycle.py \
  --engine 4.0.4=/absolute/path/to/official/godot \
  --engine 4.7=/absolute/path/to/pinned/godot \
  --output /tmp/estragon-c01-f-new
```

Use all nine versions in `tests/compatibility/engines.json`, including pinned
4.7.0 and latest tested 4.7.2. The harness verifies exact native versions and
pristine macOS executable hashes before signing only its temporary copies.
Isolated projects/settings and an empty executable PATH prove no external
compiler is used. Python is contributor orchestration, not an addon dependency.
Every required stage must PASS and unexpected native errors fail the command.

Two actual editor processes test cold build and restart. The scene fixture
starts with a deliberately stale valid generated Counter (count -1); startup must
replace it with the current authored default (0), then subsequent edits reach 4.
This models the versioned sample's generated-resource contract. The collector
separately tests source-only startup with no generated output or main scene. The first exercises
saved-resource notification bursts, external filesystem scanning, real PNG import,
new Gogo discovery, invalid-source diagnostics/last-valid-output retention,
repair, cached Script identity, pending-work cancellation and repeated
plugin enable/disable. Both check unique hooks/timers, panel cleanup, preference
preservation, no idle rebuild loop and normal automatic highlighting. Separate
fresh headless runtimes instantiate the published Counter, check current saved
state, invoke its callback and check independent component ownership.

The saved-resource test emits the plugin's notification signal after writing
current disk bytes. It tests that integration contract; it does not claim a
native text buffer was saved on an older editor. The existing 4.7 suite separately
covers actual buffer saves, F5/F6, negative native diagnostics and recovery.

## Evidence and remaining boundaries

The [strict lifecycle snapshot](../tests/compatibility/c01-f-lifecycle.json)
records all 36 required stages PASS on the nine official engines. It was collected
from clean `026ddcf` with hashes of the plugin, harness and native test scripts.
Production code is unchanged from `7a97255`; the later commit fixes the test
runner's installed-baseline provenance field and records earlier failure evidence.
The [full audit](../tests/compatibility/c01-f-results.json) uses clean
`7a97255`, and [native visual evidence](../tests/compatibility/c01-f-visual.json)
records the same production revision. Raw report/log hashes are retained; CI
artifacts contain full logs. Exact regression commands accompany the handoff.

| Official engine | Addon startup | Lifecycle + fresh runtimes | Existing Play/recovery |
| --- | --- | --- | --- |
| 4.0.4 | PASS | 4/4 PASS | UNTESTED (#50) |
| 4.1.4 | PASS | 4/4 PASS | UNTESTED (#50) |
| 4.2.2 | PASS | 4/4 PASS | UNTESTED (#50) |
| 4.3 | PASS | 4/4 PASS | UNTESTED (#50) |
| 4.4.1 | PASS | 4/4 PASS | UNTESTED (#50) |
| 4.5.2 | PASS | 4/4 PASS | UNTESTED (#50) |
| 4.6.3 | PASS | 4/4 PASS | UNTESTED (#50) |
| 4.7.0 baseline | PASS | 4/4 PASS | PASS |
| 4.7.2 | PASS | 4/4 PASS | PASS |

The full collector also retains unrelated red test-context stages: the older
`native_build.gd` fixture directly extends unavailable Logger on 4.0–4.4
(`generated_import` FAIL); editor-only highlighter construction in a non-editor
parse process fails on 4.0–4.2 (`shipped_scripts` FAIL). These are separate from
actual editor loading/native builds and C01-E's passing baseline/publication
probes. Preserve and port their test contexts in C01-H; do not silence the errors.
HybridEdges raw/lambda execution remains FAIL on 4.0–4.2 (#61). The compatibility collector's `--collect-only` exit
remains informational; inspect each stage. CI separately requires lifecycle
success on every pinned engine, alongside existing scoped C01-B…E gates.

C01-G #50 owns older-engine unsaved/unsavable buffer and fail-closed Play bridges.
The plugin's existing save/get-unsaved calls are unchanged here. Filtered,
never-associated tabs remain #44; generated raw/lambda grammar remains #61;
owner-approved native numeric and isolated-preflight limitations remain explicit.
An additional [missing-scene probe](../tests/compatibility/c01-f-missing-scene.json)
retains a real FAIL on 4.0.4: when a configured scene references a generated
Script that does not exist, the native editor attempts to open it before cold
class registration permits validation/build. The plugin subsequently supports
source-only builds; it cannot make that early missing-resource diagnostic a
compatibility PASS. Keep this distinction for C01-H disposition; do not remove
native validation or publish unchecked code to suppress the error.

No physical keyboard/interactive manual validation is implied by automated
editor/native-window tests. C01-H retains final release certification.

## Regression commands

The pinned 4.7 frontend/generation scripts were run with the verified copied,
self-contained engine, not against the owner's project/settings:

```sh
GODOT_BIN=/absolute/isolated/godot sh tools/check-native-frontend.sh
GODOT_BIN=/absolute/isolated/godot sh tools/check-native-generation.sh
GODOT_BIN=/absolute/isolated/godot bun run check:godot
bun run test:godot-harness
bun install --frozen-lockfile
bun run check
python3 -m unittest discover -s tests/compatibility
GODOT_BIN=/absolute/isolated/godot sh tools/check-editor.sh
ESTRAGON_EDITOR_NATIVE=1 ESTRAGON_KEEP_EDITOR_TEST=1 \
  GODOT_BIN=/absolute/isolated/godot sh tools/check-editor.sh
```

Results: frontend 103 cases/558 assertions; generation 3632 assertions; native
semantics 149 assertions; 180 reference tests/663 expectations; 18 Python
collector tests; runtime positive/negative checks and deliberate harness
failure-detection cases PASS. Both headless and native graphical editor suites
print `ESTRAGON_EDITOR_OK`, including actual buffer saves, F5/F6 negative/recovery,
transactional builds and restart. The native window captures show ordinary Gogo
highlighting and expected Counter increment/reset/resizing. Physical keyboard
and subjective owner interaction remain UNTESTED. No renderer/layout changes.
