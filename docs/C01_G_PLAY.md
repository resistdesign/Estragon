# C01-G native unsaved-buffer Play

C01-G [#50](https://github.com/resistdesign/Estragon/issues/50) is active in
[PR #63](https://github.com/resistdesign/Estragon/pull/63), from main `393e91c`
after merged C01-F #62. Godot 4.0+ remains mandatory. This delivery addresses
authored-buffer freshness before both native Play commands, not release certification.

## Cause and boundary

An unmodified-main official 4.0.4 editor reports both ScriptEditor save/unsaved
methods absent and raises `Nonexistent function 'save_all_scripts'` inside
`_build()`. The native C++ implementation exists but is not script-bound on old
editors. ScriptEditorBase exposes its TextEdit, but not its resource/save method;
TextFile itself is an internal virtual class with no public text setter.
Saving an unrelated scene is not a buffer-save substitute.

The isolated `buffer_guard.gd` snapshots native editors synchronously before
compilation. It uses the existing capability/version-tested resource/tab identity
adapter in strict mode: no cached highlighting-path fallback, basename/content
guesses or new widget hierarchy. When old highlighters expose no resource,
public ResourceLoader checks retrieve the already-cached native TextFile for the
exact current tab path. An unidentified or pathless buffer blocks Play, including
an unidentified clean/new buffer. Save/close that buffer to resolve the boundary;
filtered never-associated highlighting itself remains #44.

On older engines, core FileAccess persists dirty Gogo snapshots, flushes, closes
and independently rereads them. Saved bytes must match the current buffer before
it is marked saved. Clean CRLF files may retain their line endings when native
TextEdit's canonical LF text is the only difference; substantive clean disk/buffer
conflicts fail closed. On 4.7, native `save_all_scripts()` and `get_unsaved_files()`
remain capability-checked enhancements, including native normalization and saves
of ordinary scripts. Authored Gogo freshness is verified in both paths.

Failure leaves generated publication untouched and reports an authored path or
explicit unidentified/pathless-buffer diagnostic. A failed save blocks scheduled
background work from immediately erasing the diagnostic; a subsequent successful
save or Play retry restores normal operation. The existing native compiler,
actual-path transaction/rollback, dependency ordering, source maps, Script identity
and generated-buffer synchronization are unchanged. Background builds still use
saved source; this is not incremental compilation or live game hot reload.

## Reproduction and verification

```sh
python3 tools/check-editor-play.py \
  --engine 4.0.4=/absolute/path/to/official/godot \
  --engine 4.7=/absolute/path/to/pinned/godot \
  --output /tmp/estragon-play-new
```

Repeat `--engine` for the nine pinned builds in `tests/compatibility/engines.json`.
The contributor runner verifies version/provenance and pristine macOS binary
hashes, copies/signs only temporary executables, isolates projects/settings and
sets an empty executable PATH. The addon itself requires only Godot.

Each engine runs two real editor processes and real child games using both public
Play entry points. Native pre-Play and timed script autosave are disabled. Child
proof requires current foreground and background authored values, displayed text
and independent component ownership. Both modes must reject malformed markup,
undefined callbacks, native type errors and an inaccessible open file path, with
no stale child proof and unchanged generated code/map/UID/timestamp/cache identity.
Repair must execute again. The test also covers no-op outputs, re-enable and restart.

The pathless probe obtains a genuine cached native TextFile, clears its public
resource path to reproduce the in-memory state, and verifies both modes block;
assigning a valid project path repairs it and tests creation/persistence of the
new file. No fake editor, mock guard success or injected compiler result is used.
TextFile cannot be constructed through ClassDB on old engines, and the test does
not claim a native New File dialog creates that exact intermediate state.

The runner rejects missing completion markers, assertion failures, unexpected
engine errors and timeouts. Only the specified native negative-test diagnostics
and build-callback rejection are allowed; mapped diagnostics are limited to the
Counter fixture. Python tests explicitly verify rejection of unrelated failures.
The full compatibility collector remains separate: a successful `--collect-only`
exit does not certify any failing/unavailable stage.

## Remaining boundaries

[Strict Play evidence](../tests/compatibility/c01-g-play.json) records all
**18/18 editor process phases PASS**, with **864 actual native assertions**.
[Companion lifecycle evidence](../tests/compatibility/c01-g-lifecycle.json)
records **36/36 C01-F editor/fresh-runtime stages PASS**. The
[full audit](../tests/compatibility/c01-g-audit.json) retains each independent
PASS/FAIL/BLOCKED/UNTESTED outcome; successful collection is not certification.
[Native visual evidence](../tests/compatibility/c01-g-visual.json) records the
inspected 4.7 editor and Counter increment/reset/resizing captures.

| Official engine | Unsaved Play + recovery/restart | Startup | Companion lifecycle/runtime | Broader legacy editor regression |
| --- | --- | --- | --- | --- |
| 4.0.4 | 2/2 PASS | PASS | 4/4 PASS | UNTESTED (4.7-only fixture) |
| 4.1.4 | 2/2 PASS | PASS | 4/4 PASS | UNTESTED (4.7-only fixture) |
| 4.2.2 | 2/2 PASS | PASS | 4/4 PASS | UNTESTED (4.7-only fixture) |
| 4.3 | 2/2 PASS | PASS | 4/4 PASS | UNTESTED (4.7-only fixture) |
| 4.4.1 | 2/2 PASS | PASS | 4/4 PASS | UNTESTED (4.7-only fixture) |
| 4.5.2 | 2/2 PASS | PASS | 4/4 PASS | UNTESTED (4.7-only fixture) |
| 4.6.3 | 2/2 PASS | PASS | 4/4 PASS | UNTESTED (4.7-only fixture) |
| 4.7.0 baseline | 2/2 PASS | PASS | 4/4 PASS | PASS |
| 4.7.2 | 2/2 PASS | PASS | 4/4 PASS | PASS |

All actual execution records use clean frozen `9f218b5`. Interrupted audit logs
were retained separately; only complete reports were reused, and incomplete
steps were rerun in new directories. The evidence records raw report/log hashes,
exact engine/binary provenance and production/test hashes. Later commits only
clarify labels and strengthen contributor error classification; every recorded
Play log was independently reclassified with the stricter location-aware matcher.
The final CI reruns use that strict matcher directly. No old run is relabeled as
execution of a newer commit. Commands and final CI links are in #50/#63's handoff.

Physical/manual keypress tests are not required under the owner's policy. The
historical collector key `graphics_physical_keys` is retained with its source
records; it is not an outstanding manual-keypress acceptance requirement.

No C01-H release distribution/gates, #44 positive filtered-tab implementation,
#61 grammar, T09, Box/padding or unit helpers are included. Owner-approved native
numeric and isolated-preflight limits remain explicit in their separate stages.


## Regression commands and results

```sh
GODOT_BIN=/absolute/isolated/godot sh tools/check-native-frontend.sh
GODOT_BIN=/absolute/isolated/godot sh tools/check-native-generation.sh
bun install --frozen-lockfile
bun run check
GODOT_BIN=/absolute/isolated/godot bun run check:godot
bun run test:godot-harness
python3 -m unittest discover -s tests/compatibility
GODOT_BIN=/absolute/isolated/godot sh tools/check-editor.sh
ESTRAGON_EDITOR_NATIVE=1 ESTRAGON_KEEP_EDITOR_TEST=1 \
  GODOT_BIN=/absolute/isolated/godot sh tools/check-editor.sh
```

Results: native frontend 103 cases/558 assertions; generation 3632 assertions;
native semantics 149 assertions; 180 reference tests/663 expectations; 20 Python
tests; runtime positive/negative checks and intentional failure/timeout probes
PASS. Headless and graphical native editor/Play/transaction/restart suites print
`ESTRAGON_EDITOR_OK`; graphics captures were inspected. CI separately requires
new strict Play stages on every pinned engine and preserves previous scoped gates.

Unrelated full-audit outcomes remain visible: #44 filtered tabs FAIL, #61
HybridEdges runtime FAIL on 4.0–4.2, old `native_build.gd` Logger fixture import
FAIL on 4.0–4.4, non-editor parse-context failures for editor-only highlighting
on 4.0–4.2, native numeric conversion/live added defaults and unavailable isolated
preflight/arity capabilities BLOCKED where measured. These are not C01-G successes
or silently removed release criteria. See C01-E/F evidence and C01-H #51.
