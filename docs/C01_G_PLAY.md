# C01-G native unsaved-buffer Play

C01-G [#50](https://github.com/resistdesign/Estragon/issues/50) is active in
[PR #63](https://github.com/resistdesign/Estragon/pull/63), from main `393e91c`
after merged C01-F #62. Godot 4.0+ remains mandatory. This delivery addresses
saved-source freshness before both native Play commands, not release certification.

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

Final nine-engine results, exact regression commands, CI links and the durable
handoff are tracked in #50/#63. C01-F lifecycle/settings/refresh/restart gates and
existing compiler/runtime/editor/graphics regressions remain required. Automated
native Play proves both commands; physical/manual keypress tests are not required
under the owner's policy. Visual evidence remains separate from headless results.

No C01-H release distribution/gates, #44 positive filtered-tab implementation,
#61 grammar, T09, Box/padding or unit helpers are included. Owner-approved native
numeric and isolated-preflight limits remain explicit in their separate stages.
