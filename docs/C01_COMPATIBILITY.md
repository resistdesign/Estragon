# C01-A: Godot 4.0–4.7 compatibility audit

Audit date: 2026-10-29. Parent [#41](https://github.com/resistdesign/Estragon/issues/41),
delivery [#42](https://github.com/resistdesign/Estragon/issues/42).
**Godot 4.0+ remains required; this audit does not certify release compatibility.**
No addon production fixes or T09 features are included. E01 PR #40 merged at
`41b43b4`; its normal isolated highlighting evidence remains valid and its
filtered-tab exception remains [#44](https://github.com/resistdesign/Estragon/issues/44).

C01-A PR #52 is merged. Subsequent [C01-B runtime evidence](C01_B_RUNTIME.md)
is recorded separately; the table and snapshot below retain the audit baseline.

C01-C's [callback investigation and fix](C01_C_CALLBACKS.md) records the owner-approved
progressive arity diagnostics. Its separate snapshot does not alter this original
audit baseline or certify full-addon compatibility.

C01-D's [numeric investigation and correction](C01_D_NUMBERS.md) separately
records avoidable formatting/leading-zero loss and the owner-approved native
conversion limits. The original audit baseline below is preserved.

## Reproduction and evidence

Use Python 3.9+ as optional contributor orchestration, the standard system shell,
and official Godot editor executables. The addon still uses only Godot.

```sh
python3 -m unittest discover -s tests/compatibility -p 'test_*.py'
python3 tools/check-compatibility.py \
  --engine 4.0.4=/absolute/path/to/official/godot-4.0.4 \
  --engine 4.7.2=/absolute/path/to/official/godot-4.7.2 \
  --output /new/empty/result-directory --editor
```

Repeat `--engine` for each selected executable. Labels must be unique. The output
directory must not exist, preventing accidental replacement of previous evidence.
The collector writes `results.json` after each engine and individual logs for
each command. Unknown version strings, wrong macOS executable hashes, missing
completion markers, timeouts, nonzero exits and engine errors fail their stage.
ANSI color codes are removed before diagnostic matching. Each child process has
a wall-clock deadline; timeouts kill its process group. Collector tests exercise
errors with exit zero and a success marker, missing markers, nonzero exit and a
real hung child process.

Default exit status is nonzero if any stage is FAIL, BLOCKED or UNTESTED.
`--collect-only` changes only the collector exit code for the informational audit
lane; it never changes the red results. A successful collection is not a successful
compatibility test. CI rejects infrastructure/identity/API-dump failures and
uploads all logs and JSON. The existing required 4.7 Linux jobs remain unchanged.

Each engine runs a copied, self-contained binary (`_sc_`), isolated project,
editor settings and XDG directories. macOS signing touches only that copied
binary. Official executable bytes are fingerprinted **before** signing. Existing
E01 executables had local signature changes, so this audit extracts pristine
executables again from the already verified archives. No user project, plugin
preference, source buffer or editor cache is changed. Every actual addon/compiler/
runtime process receives an empty executable PATH; E01/full-editor shell wrappers
enforce the same boundary inside their own isolated processes.

[Pinned engines](../tests/compatibility/engines.json) include versions, official
archive URLs, archive SHA-256, executable SHA-256 and patch-selection rationale.
The official `godot-builds` release API was checked on the audit date: selected
latest stable patches are 4.0.4, 4.1.4, 4.2.2, 4.3, 4.4.1, 4.5.2, 4.6.3 and
**4.7.2 `ed1daf0bf`**. Existing required 4.7.0 `5b4e0cb0f` is tested additionally.
The earlier E01 manifest is preserved as historical evidence, not overwritten.

## What the stages actually execute

1. Import the unmodified addon and checked examples in the copied root project,
   preserving its current 4.7 feature declaration. Tests are installed only
   afterward so newer test-only dependencies cannot contaminate product import.
2. Check all **33** shipped addon/example/generated GDScript files individually,
   including unused modules. Separate real editor startup remains necessary:
   some editor classes behave differently outside an actual editor.
3. Run the existing 103-case native frontend corpus and generation/map suite,
   including malformed input, deterministic output, source spans, copied ranges,
   Unicode/CRLF, callbacks and checked reference code/map digests. Remove checked
   generated example scripts before native generation; downstream runtime tests
   consume newly emitted code. Import that generated output separately.
4. Run separate existing legacy scene, component ownership, layout, text/input,
   generated layout/hybrid/signals, direct native Counter and semantic/identity
   processes. The semantic suite intentionally captures/counts expected errors
   and must reach its explicit success marker; parser errors without completion
   remain failures. An additional isolated numeric probe executes emitted float
   literals without runtime or Logger dependencies.
5. Dump actual engine extension API metadata for class/method existence and
   static/instance flags. This supplements execution; method presence is not
   proof of correct semantics.
6. Reuse E01's two real isolated headless editor processes for normal association,
   colors, Plain Text restore, disable/re-enable and preferences, then its
   separate complete-addon startup/build-report probe. Read both positive and
   unmet markers. Run the complete existing editor/unsaved Play/recovery suite
   on 4.7.0 and 4.7.2 with every assertion preserved. Older Play is BLOCKED by
   actual startup failure; its current harness also needs a cross-version port.

**PASS** means that stage executed and satisfied its assertions/error/marker
contract. **FAIL** means it executed and failed. **BLOCKED** means a prerequisite
prevented downstream acceptance. **UNTESTED** means no applicable proof ran.
Passing native emission does not establish generated-code validity; passing
script import does not establish plugin startup or unsaved Play correctness.

## Measured baseline

| Engine | Frontend / emission & maps | Legacy scene | Components / layout / text & input | Generated layout / hybrid / signals | Native Counter | Semantic / identity suite | Full addon startup | Unsaved Play / recovery |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 4.0.4 | PASS | PASS | FAIL | FAIL | FAIL | FAIL | FAIL | BLOCKED |
| 4.1.4 | PASS | PASS | FAIL | FAIL | FAIL | FAIL | FAIL | BLOCKED |
| 4.2.2 | PASS | PASS | FAIL | FAIL | FAIL | FAIL | FAIL | BLOCKED |
| 4.3 | PASS | PASS | PASS | PASS | FAIL | FAIL | FAIL | BLOCKED |
| 4.4.1 | PASS | PASS | PASS | PASS | FAIL | FAIL | FAIL | BLOCKED |
| 4.5.2 | PASS | PASS | PASS | PASS | PASS | FAIL | FAIL | BLOCKED |
| 4.6.3 | PASS | PASS | PASS | PASS | PASS | PASS | FAIL | BLOCKED |
| 4.7.0 (existing pin) | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| 4.7.2 (latest patch) | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |

Normal isolated E01 highlighting/restart is PASS across the matrix. The hidden,
never-associated filtered tab is **FAIL throughout**, including 4.7; the negative
capability probe is not a positive regression test. Product import and individual
script checks fail through 4.4; 4.5/4.6 parse successfully but still fail actual
editor startup. Raw stage results and diagnostics are summarized in
[results.json](../tests/compatibility/results.json). The snapshot includes exact
local report/log fingerprints; CI independently reproduces the same outcomes
with its own temporary paths and script IDs. Full per-stage logs are CI artifacts.

The isolated numeric probe fails on **4.0–4.5** for emitted decimal
`0.00000000000000000001` versus the intended `1e-20`; it passes on 4.6/4.7.
This exposes the mismatch even where the full semantic suite cannot load.

On 4.5 the semantic suite reaches **80** assertions, reports numeric/relative-load
failures and aborts before registered `class_name` checks. Those later checks are
not independently proved or disproved by that run. On 4.6/4.7 the full **83**
semantic assertions pass. Older missing Logger dependencies prevent that suite
from testing its individual semantic scenarios at all.

## Source-located inventory and focused remedies

These are measured defects or explicit remaining evidence gaps. Cascading
`Could not resolve class` errors are retained in logs, not counted as independent
API defects. No runtime/editor source was patched to obtain a green audit.

| Source / construct | Actual evidence and affected versions | Proposed remedy / task |
| --- | --- | --- |
| `runtime/container.gd:91`, `runtime/button.gd:56`: `Vector2.max()` | Parse/component/layout failures on 4.0–4.2; runtime suites pass on 4.3+ | Stable scalar/vector operations preserving geometry; [C01-B #45](https://github.com/resistdesign/Estragon/issues/45) |
| `compiler/emitter.gd:145`; generated Counter lines 61/73: `Callable.get_argument_count()` | Generated parse fails on 4.0–4.2; generated signals pass on 4.3+ | Equivalent typed callback validation, including optional/bound/lambda/invalid/disposed targets; [C01-C #46](https://github.com/resistdesign/Estragon/issues/46) |
| `compiler/emitter.gd:72`: numeric literal via `JSON.stringify` | Standalone emitted-literal probe fails on 4.0–4.5 for `1e-20`; 4.5 full semantic test also fails at `native_semantics.gd:80`; isolate serializer versus native parsing | Preserve exact numeric semantics with a minimized cross-version test; [C01-D #47](https://github.com/resistdesign/Estragon/issues/47) |
| `compiler/script_validation.gd:14,19,51,54`: `Logger`, `ScriptBacktrace`, OS logger API | Classes/methods unavailable through 4.4; actual parser/build dependency failure | Native diagnostic capture using common baseline or narrowly proved adapters; [C01-E #48](https://github.com/resistdesign/Estragon/issues/48) |
| `compiler/script_validation.gd:39`: `Resource.set_path_cache()` | Absent through 4.3; present in 4.4+. On 4.5 relative preload actually resolves beneath `gdscript://` and fails `native_semantics.gd:100` | Preserve real output-path relative resources, inheritance and cached/registered class identity; also #48 |
| `editor/plugin.gd:27,37,50…`: static `EditorInterface` access | Instance-only on 4.0/4.1; actual plugin parser failures | Use public owner-provided instance; [C01-F #49](https://github.com/resistdesign/Estragon/issues/49) |
| `editor/plugin.gd:60,126`: `EditorFileSystem.is_importing()` | Older actual editors fail startup; parser/import alone passes on 4.5/4.6 | Common-baseline filesystem lifecycle/capability handling; also #49 |
| `editor/plugin.gd:101–105`: `ScriptEditor.save_all_scripts()`, `get_unsaved_files()` | Absent throughout 4.0–4.6; full unsaved Play acceptance blocked | Prove freshness/unsavable-buffer failure through actual main/current Play; [C01-G #50](https://github.com/resistdesign/Estragon/issues/50) |
| `editor/highlighter_association.gd:62…`: optional `_get_edited_resource()` and native ItemList path/index adapter | E01 actual normal/restart association works on tested minors, private fallback is version-gated; filtered never-associated identity still fails | Keep isolated/capability-checked; solve [#44](https://github.com/resistdesign/Estragon/issues/44) with a true positive test or explicit owner disposition |
| Root `project.godot:19`, editor fixture: `config/features` includes 4.7 | Copied root imports/runs legacy scene on old engines despite marker; GUI conversion/prompt behavior is not certified | Align distribution declarations with required baseline and validate clean project import; [C01-H #51](https://github.com/resistdesign/Estragon/issues/51) |
| Scene format 3/config version 5, `res://` scripts, `.gd.uid` sidecars and scene resource UIDs | Legacy scene load/host lifecycle passes across all minors; generated scenes remain blocked by code APIs on 4.0–4.2. No separate format rejection identified | Verify fresh/cached/renamed/moved dependencies, identity and distribution/export in #51; do not infer older UID sidecar handling from 4.7 |

Pure native lexer/parser/model/source-map code has no additional measured language
syntax blocker in the corpus. `script_dependencies.gd` parses in the individual
checks. `ThemeDB` exists even on 4.0; text/component execution there is blocked by
the runtime dependency graph, so presence is not full font/render proof. Shared
RenderingServer rectangle/text rendering, surface input, resize and automatic
lifecycle are exercised by headless runtime tests on the passing minors. A pass
does not inspect GPU pixels. Broader GDScript syntax not covered by supported
Gogo grammar, future `@bindable`, T09-B Box/geometry, collections and two-way
bindings remain outside this audit.

## Proposed implementation sequence (issue-only backlog)

This PR proposes the plan for owner review; no subsequent implementation has
started and no second PR is allowed.

1. **C01-B #45:** common-baseline component/vector operations, unblocking runtime.
2. **C01-C #46:** generated callback guards, unblocking executable signal output.
3. **C01-D #47:** numeric-literal semantic fidelity, with the standalone probe.
4. **C01-E #48:** semantic diagnostics, imports/inheritance and script/class identity.
5. **C01-F #49:** full native editor startup/lifecycle with those dependencies valid.
6. **C01-G #50:** unsaved-buffer fail-closed F5/F6, rollback/recovery and harness port.
7. **E01-F #44:** remaining filtered identity requirement, coordinated with editor
   compatibility, preserving its separate issue and owner decision boundary.
8. **C01-H #51:** project/resource distribution, full integration, graphics/manual
   and platform evidence, support documentation and permanent required CI gate.

Individual issues include measured evidence, scope, prerequisites, non-goals and
acceptance. Only begin each after the current PR merges/closes. A simple scalar
runtime change must not become a Box/reactivity rewrite; a missing diagnostic API
must not become ignored semantic errors or an external compiler fallback.
T09-A #43 follows blocking compatibility foundations; T09-B/C/D remain in #5.

## Verification boundaries

Existing pinned 4.7.0 checks run separately: locked Bun install/check, Godot
import/every-script/runtime/negative mapping, harness failure probes, independent
native frontend/generation/semantics, R01 research and full editor/Play/restart.
The native graphics editor harness also passes separately on 4.7.0. Native
Counter highlighting, Count 1/enabled Reset and Count 0/disabled Reset after
resizing were visually inspected in its retained captures. Automated run commands and pointer injection are distinct
from manual physical-key F5/F6, mouse/window-manager and remote-tree inspection.

Older native graphics, export, physical keyboard interaction and non-macOS older
minors are **UNTESTED**. Existing 4.7 Linux CI supplies separate platform evidence.
The new macOS audit lane preserves failures and artifacts; it does not grant
4.0+ support from a green collection job. No accepted architecture or minimum
engine requirement has changed.

The initial complete CI reproduction is [audit run 40985106096](https://github.com/resistdesign/Estragon/actions/runs/40985106096):
all eight macOS collection jobs complete, with the actual red compatibility
stages preserved in artifacts. [Required 4.7 Linux/compiler run 40985106060](https://github.com/resistdesign/Estragon/actions/runs/40985106060)
passes both jobs. Final PR checks and handoff are linked in #42; collection green
is distinct from compatibility green.

To regenerate the committed compact snapshot after a complete multi-engine run:

```sh
python3 tools/summarize-compatibility.py \
  --report /first-run/results.json --report /second-run/results.json \
  --output tests/compatibility/results.json
```

Supply each raw report exactly once, with no duplicate engines. The summarizer
requires every pinned manifest version, retains every stage outcome and per-file
parse verdict, fingerprints raw evidence, and includes failure excerpts. It
never promotes a collected failure to PASS.

Primary API references: [4.0 EditorInterface](https://docs.godotengine.org/en/4.0/classes/class_editorinterface.html),
[4.0 ScriptEditor](https://docs.godotengine.org/en/4.0/classes/class_scripteditor.html),
[4.0 Resource](https://docs.godotengine.org/en/4.0/classes/class_resource.html),
[4.0 Vector2](https://docs.godotengine.org/en/4.0/classes/class_vector2.html).
Version conclusions above use actual executable metadata and executions, rather
than assuming today's stable documentation describes older engines.
