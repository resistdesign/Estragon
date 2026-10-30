# E01 compatibility evidence and review gate

E01 #37 / PR #40, 2026-10-29. **Historical review evidence: #40 has since merged at `41b43b4`.** The owner merge did not resolve the C01 release gate or filtered-tab #44. See the broader [C01-A audit](C01_COMPATIBILITY.md) for current matrix/queue. **Not a Godot 4.0+ release certification.**
ADR-0014 remains mandatory. R01 #38 and architecture #39 are merged; ADR-0013's
lowercase Gogo-only `@bindable` and the T09 roadmap are unchanged.

## Reproduce the two separate experiments

```sh
GODOT_BIN=/absolute/path/to/official/godot \
  ESTRAGON_KEEP_COMPAT_TEST=1 sh tools/check-highlighting-compat.sh
```

Official macOS binaries were actually executed for every minor 4.0–4.7.
[Engine manifest](../tests/editor/compatibility/engines.json) records exact
versions, official archive URLs and archive SHA-256 fingerprints. These are
selected available patches, not an audit of the newest patch of every minor;
C01-A #42 owns that broader inventory and release matrix. No binaries are bundled.

The harness copies the binary into a self-contained temporary editor (ad-hoc
signed only on macOS), supplies an empty executable PATH and never uses the
owner's settings. First it installs **only the E01 highlighter/association** and
a test plugin, without any compiler/runtime. It opens plain untagged files,
enables association, checks actual declaration/tag colors on open/background/new
files, independent instances, unchanged Gogo-looking `.txt`, filter preservation,
disable/re-enable and unchanged preferences. A native ConfigFile fixture seeds
persisted Plain Text state between **two actual editor processes**; startup
assertions inspect both restored tabs before reopening/navigation. No test
selects Gogo from the highlighter menu.

The 36 first-process and 10 restart assertions include an explicit **negative
capability probe**, not 46 certified supported behaviors. Filtering out a
never-associated Background.gogo *before* enabling association really removes its
path from the native list; it stays plain until exposed and shown. The marker
`E01_FILTERED_UNASSOCIATED_UNMET` records this unmet requirement. Already-associated
background tabs keep their colors while filtered. Clearing/exposing the file and
activating it restores colors automatically, without choosing Gogo manually.

Second, the harness copies the **complete addon** and enables its actual plugin.
It records public API availability, actual script validity and build report plus
all native errors. `E01_FULL_ADDON_BLOCKED` means startup compatibility failed;
it is not a skip or a successful end-to-end test. A loadable plugin script alone
is insufficient: dependency/runtime errors also block the result. The shell may
exit zero after collecting expected failure evidence; read the explicit statuses.
The required 4.7 CI step is named as an E01 fixture/startup diagnostic, not an
older-engine release gate.

## Actual results

| Official engine | Isolated E01 normal/restart cases | Hidden unassociated filtered tab | Complete addon startup / older end-to-end Play |
| --- | --- | --- | --- |
| 4.0.4 `fc0b241c9` | Pass, 46 assertions including expected negative | Unmet | Failed startup; Play blocked |
| 4.1.4 `fe0e8e557` | Pass, 46 assertions including expected negative | Unmet | Failed startup; Play blocked |
| 4.2.2 `15073afe3` | Pass, 46 assertions including expected negative | Unmet | Failed startup; Play blocked |
| 4.3 `77dcf97d8` | Pass, 46 assertions including expected negative | Unmet | Failed startup; Play blocked |
| 4.4.1 `49a5bc7b6` | Pass, 46 assertions including expected negative | Unmet | Failed startup; Play blocked |
| 4.5.2 `6ce3de25a` | Pass, 46 assertions including expected negative | Unmet | Failed startup; Play blocked |
| 4.6.3 `7d41c59c4` | Pass, 46 assertions including expected negative | Unmet | Failed startup; Play blocked |
| 4.7 `5b4e0cb0f` | Pass, 46 assertions including expected negative | Unmet | Startup + existing compiler/runtime/editor/Play suites pass |

Older-version Play/compilation acceptance is **blocked**, not tested successfully
by the isolated highlighter fixture. Full 4.0+ runtime, compiler, generated-code,
export and editor acceptance remains C01 work. Other operating systems and
physical keyboard/window-manager interaction were not tested in this matrix.
4.7 Linux runs the existing required CI; the multi-version measurements here are
macOS. Full 4.7 native editor/game graphical regression was also run separately.

## Measured pre-existing blockers (C01 #41)

- 4.0/4.1: `editor/plugin.gd:27,37,50…` calls instance-only EditorInterface
  methods statically; the full plugin fails parsing. E01's small helper now
  accepts the public `get_editor_interface()` result from its owner instead.
- 4.0–4.3: actual capability queries report `Resource.set_path_cache=false`;
  4.0–4.4: `Logger=false`. Native validation depends on those APIs.
  4.2–4.4 produce `build_service.gd:5,164,205` dependency/type errors resolving
  `script_validation.gd`, then `plugin.gd:115` cannot call `run_build`.
- 4.2 also rejects `runtime/button.gd:56` using unavailable `Vector2.max()`.
- 4.2, 4.5 and 4.6 explicitly log missing `EditorFileSystem.is_importing()`
  at `plugin.gd:60`. Its absence on those measured paths is not a claim that
  other old-version paths are valid.
- All tested 4.0–4.6 engines report `ScriptEditor.save_all_scripts=false` and
  `get_unsaved_files=false`; fail-closed unsaved-buffer Play needs separate C01
  proof/fixes. 4.7 reports both true, along with set_path_cache and Logger.

These are concrete E01 startup blockers, **not a complete C01 compatibility
inventory**. They are recorded in #41. E01 does not port the compiler/build/runtime
or raise the supported minimum. C01-A #42 remains the next scoped task.

## Public API investigation and adapter limits

The documented 4.0 APIs provide registration, open editor controls and current
**Script** access, but no TextFile edited-resource/path getter on ScriptEditorBase.
Registration explicitly does not repair existing tabs. The same gap exists in
the 4.7 published surface. No complete published-API-only path was found for the
required TextFile recovery. Evidence:
[4.0 ScriptEditor](https://docs.godotengine.org/en/4.0/classes/class_scripteditor.html),
[4.7 ScriptEditorBase](https://docs.godotengine.org/en/4.7/classes/class_scripteditorbase.html),
[pinned native path/index storage](https://github.com/godotengine/godot/blob/5b4e0cb0f/editor/script/script_editor_plugin.cpp#L2078).

The adapter stays isolated. It capability-checks the bound underscore resource
getter, validates a native list's path/index against the actual tab parent, and
only enables that UI fallback on the tested **4.0–4.7** minor range. Outside that
range it warns and disables the unverified UI fallback; future 4.x support still
requires new evidence rather than pretending certification. There is no fixed
child-node name or source-content/basename guessing. The inherited 4.0 parser
also required `not (value is int)` instead of newer `is not` syntax; that E01-only
change is tested by actual 4.0 loading.

The filtered, never-associated case exposes the remaining identity gap. The
addon must not clear the user's filter, alter authored text or choose a language
from content to conceal it. That case remains explicitly unmet across this matrix.

## Current disposition

The owner merged #40 at `41b43b4` on 2026-10-29. The narrow normal-highlighting
fix is delivered; full cross-version acceptance remains an unmet C01 release
gate and filtered identity remains #44. [C01-A #42](C01_COMPATIBILITY.md) records
the broader matrix and proposed sequential issues #45–51. T09-A #43 follows
blocking compatibility foundations. No second PR or automatic merge bypasses
that queue.
