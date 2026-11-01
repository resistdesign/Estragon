# C01-E semantic validation investigation

C01-E [#48](https://github.com/resistdesign/Estragon/issues/48) is active on
`codex/c01-e-semantic-validation`, based on C01-D merge `bf2c426`.
The scoped implementation and verification are ready for owner review in PR #60;
**the PR is unmerged and this is not full-addon compatibility certification**.
No semantic-validation requirement has been weakened.

## Reproduced path and cache constraints

`tests/compatibility/script_context/` is an independent, tiny native project.
It imports a registered `EstragonContextProbe`, caches its Script and bytecode
(value 1), then tries an unpublished candidate with the same class name and a
relative preload (value 41). Every strategy runs in a separate process. A
successful `reload()` alone is insufficient: errors, changed source/bytecode,
or a reused application Script fail the probe.

The official 4.0.4–4.7.2 engines (including pinned 4.7.0) reproduce:

| Strategy | 4.0–4.3 | 4.4–4.5 | 4.6–4.7 | Meaning |
| --- | --- | --- | --- | --- |
| `set_path_cache(output)` | Unavailable | Wrong GDScript parser path | Works | The 4.5 failure is a real path-context defect, not just diagnostic capture |
| `set_path_cache(output)` then `resource_path = output` | Unavailable | Works in isolated probe | Works in isolated probe | Same-path Resource early return avoids ownership transfer; GDScript's setter establishes its parser path |
| `resource_path = occupied_output` | Engine cache-conflict error | Engine cache-conflict error | Engine cache-conflict error | An apparent successful reload after this error is **not** a passing solution |
| Distinct `output::candidate` path | Registered-class conflict | Registered-class conflict | Registered-class conflict | Candidate cannot claim the registered class at a different path |
| `ResourceLoader.load(output, ..., CACHE_MODE_IGNORE)` | Returns cached Script | Returns cached Script | Returns cached Script | Editing the result changes application source and bytecode; unsafe |
| Fresh unregistered path and no `class_name` | Works | Works | Works | Establishes ordinary relative imports, but does not prove registered/cached class identity |

The committed collector verifies exact versions and pristine macOS binary
hashes against `engines.json`, copies and locally signs each executable, uses a
separate project/settings directory and empty executable PATH, and writes raw
logs plus structured results. Its successful exit means **evidence collected**;
unsafe alternatives remain FAIL and missing capabilities remain BLOCKED.

```sh
python3 tools/check-script-context.py \
  --engine 4.0.4=/absolute/official/godot \
  --engine 4.5.2=/absolute/official/godot \
  --engine 4.7.2=/absolute/official/godot \
  --output /new/context-results
```

Engine source explains the results:

- [4.0 Resource::set_path](https://github.com/godotengine/godot/blob/4.0.4-stable/core/io/resource.cpp): an occupied path fails unless ownership is taken from the existing resource. Taking ownership, even briefly, violates isolated-validation cache nonmutation.
- [4.0 GDScript::set_path/reload](https://github.com/godotengine/godot/blob/4.0.4-stable/modules/gdscript/gdscript.cpp): native parsing uses the internal script path. The setter continues after Resource's conflict error; depending on that error-producing implementation is not a compatibility bridge.
- [4.0 analyzer](https://github.com/godotengine/godot/blob/4.0.4-stable/modules/gdscript/gdscript_analyzer.cpp): registered `class_name` validation requires the exact registered path. A subresource/temporary alias is not equivalent.
- [4.0 GDScript cache](https://github.com/godotengine/godot/blob/4.0.4-stable/modules/gdscript/gdscript_cache.cpp): `CACHE_MODE_IGNORE` updates the cached GDScript rather than producing an independent Script. This is also observed on the newer engines.
- [4.5 GDScript](https://github.com/godotengine/godot/blob/4.5.2-stable/modules/gdscript/gdscript.cpp): ordinary `set_path` updates the parser path; inherited Resource `set_path_cache` does not.
- [4.7 GDScript](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/gdscript/gdscript.cpp): an explicit `GDScript::set_path_cache` override now establishes that path without transferring cache ownership.

Native 4.0 introspection also confirms that `Engine.get_script_language(0)`
returns `ScriptLanguage` with neither `validate` nor `_validate` callable.
`ScriptLanguageExtension`'s extension hooks are not a public native GDScript
parser service. No alternate public parser API has been established.

## Accepted legacy preflight/publication contract

The owner selected the second option in issue #48 / PR #60 on 2026-10-31:
**distinguish legacy preflight from publication; report isolated cached-path
checks as unavailable; require actual-path native validation and rollback before
any build succeeds.** This explicitly replaces universal isolated-candidate
acceptance; it does not waive native validity, freshness, dependencies or identity.

On 4.0–4.3 `validate()` returns a clear unsupported-preflight diagnostic with no
executable or cache mutation. Build reports expose `isolated_preflight.status`
as BLOCKED independently of success. The build service must perform actual-path
native reload inside its file/cache rollback transaction, including no-op builds,
before reporting success. It never presents a cached application Script as an
isolated candidate. 4.4+ retains independent candidate validation with the proved
paired path assignment.

The bundled Logger/ScriptBacktrace adapter is trusted text compiled only when
its native classes and OS logger methods exist. Older engines still perform real
native reload and expose native errors; a generic diagnostic explicitly states
that an exact authored location is unavailable. Native Logger engines retain
mapped authored diagnostics. No errors are suppressed.

`semantic_baseline.gd` tests real valid reload, unknown-identifier rejection
(exactly one native error; authored line 3 on Logger engines), and separate
candidate identity with relative preload and relative/absolute inheritance.
Unavailable legacy isolation remains BLOCKED, never PASS. The dedicated
`native_publication.gd` suite tests final registered-class publication, cached
and live state, dependency-type rejection, rollback, no-op byte/UID/timestamps,
fresh failure cache cleanup, repair and inherited member updates.

An additional experiment reproduced an inherent native live-reload limit on
4.0.4 and 4.7.2: after adding inherited `second: int = 2`, a previously existing
derived instance retains `first = 17` but its new `second` slot is null; fresh
instances correctly receive `second = 2`. This is recorded separately as
`native_live_added_defaults` BLOCKED, with actual values. The publication gate
still requires unchanged Script identity, preserved existing state, correct
fresh defaults, and **current bytecode on the live instance** (setting second to
5 must produce 22). It does not fabricate successful live default initialization.
Estragon already requires stopping/re-running applications after edits; running
application hot reload is not implemented. No instance registry, custom default
initializer or architecture change is introduced to backport this engine feature.

The publication path also exposed two old-engine gaps: `entry.class` must use
`entry["class"]` on 4.0, and public `DirAccess.is_link()` is absent through 4.2.
The former is corrected without changing dependency semantics. Link inspection
is an optional filesystem guard, reported separately as `symlink_checks` BLOCKED
where unavailable. Symlink-free projects remain required; lexical path/root
checks, transactional rename/rollback, native validity and cache identity remain
mandatory. Newer engines retain explicit symlink rejection. No external tools or
platform-specific filesystem adapter are introduced to reproduce that diagnostic.

## Cold Text-first cycle

A runtime-only project reproduces the extra `_disposed` compile error in Button
on 4.0.4 and 4.1.4 when Text is the first component loaded. Changing an inherited
field reference only moves the failure. The compile-time dependency cycle is
`DisplayObject → Surface → PointerDispatcher → Button → Text → DisplayObject`.

Surface now resolves its private pointer adapter through `load()` when a Surface
is constructed and calls the adapter's `accepts()` method. This removes that
compile-time edge without changing component inheritance, public typed APIs,
ownership, hit testing or lifecycle. It is not an eager warm-up or ignored error.
`cold_text.gd` deliberately has no component type annotations/preloads: it loads
Text first, then Button, mounts both and checks automatic disposal. Existing
cold invalid-font probes still require exactly one intended diagnostic. The
matrix and current-engine regression harness gate these tests independently of
other C01 failures.

## Final version matrix

The [frozen before snapshot](../tests/compatibility/c01-e-before.json) uses merged
`bf2c426`; the [final scoped snapshot](../tests/compatibility/c01-e-results.json)
uses clean frozen `d397048`. Every official executable is verified against the
exact version and pristine binary SHA in `engines.json`, including both 4.7.0
and 4.7.2. Raw commands/logs and metadata remain in the corresponding local/CI
artifacts; snapshots retain all stage outcomes and log/report hashes.

| Official engine | Native semantics / Counter | Publication: registered / dependency / rollback / fresh repair | Cold Text / runtime | Isolated path preflight | Full addon startup |
| --- | --- | --- | --- | --- | --- |
| 4.0.4 | PASS / PASS | PASS / PASS / PASS / PASS | PASS | BLOCKED | FAIL |
| 4.1.4 | PASS / PASS | PASS / PASS / PASS / PASS | PASS | BLOCKED | FAIL |
| 4.2.2 | PASS / PASS | PASS / PASS / PASS / PASS | PASS | BLOCKED | FAIL |
| 4.3 | PASS / PASS | PASS / PASS / PASS / PASS | PASS | BLOCKED | FAIL |
| 4.4.1 | PASS / PASS | PASS / PASS / PASS / PASS | PASS | PASS | FAIL |
| 4.5.2 | PASS / PASS | PASS / PASS / PASS / PASS | PASS | PASS | FAIL |
| 4.6.3 | PASS / PASS | PASS / PASS / PASS / PASS | PASS | PASS | FAIL |
| 4.7.0 | PASS / PASS | PASS / PASS / PASS / PASS | PASS | PASS | PASS |
| 4.7.2 | PASS / PASS | PASS / PASS / PASS / PASS | PASS | PASS | PASS |

All nine also pass frontend/emission/maps, generated signals and nine callback
probes, component (63), layout (72), interaction (96), sizing/text negatives and
native numeric-value preservation. The full semantic suite executes nine bad
programs and lifecycle/callback guards with exactly 18 expected engine errors on
4.0–4.2 and 20 on 4.3+, including both native type diagnostics where applicable.
Mapped native locations are checked on Logger engines; older generic diagnostics
explicitly identify their location limitation. Isolated invalid candidates leave
cached application source and bytecode unchanged on supported engines; legacy
unavailability returns no executable and causes no mutation.

Additional research snapshots: [path API probes](../tests/compatibility/c01-e-context.json),
[initial cold sweep](../tests/compatibility/c01-e-cold.json), and
[semantic baseline](../tests/compatibility/c01-e-semantic-baseline.json).
The final full snapshot supersedes these checkpoint runs. An initial collector
that read changing source between engines is excluded; superseded `1aac73d`
CI remains visible as the evidence revealing native live-default behavior.

## Current-engine regressions and graphics

- `bun install --frozen-lockfile && bun run check`: 180 tests, 663 expectations,
  typecheck, canonical IR and generated examples/maps PASS.
- `python3 -m unittest discover -s tests/compatibility -p 'test_*.py'`: 18 PASS.
- `GODOT_BIN=<4.7.0> sh tools/check-native-generation.sh`: native generation
  3632, semantic 149, signals 49, Counter/lifecycle/numeric suites PASS.
- `GODOT_BIN=<4.7.0> bun run check:godot`: every-script parsing, full runtime,
  mapped negative diagnostics and callback regressions PASS.
- `GODOT_BIN=<4.7.0> sh tools/check-editor.sh`: fresh self-contained no-Bun
  editor, native build (31), both Play paths, rollback, recovery and restart PASS.
- [Native visual evidence](../tests/compatibility/c01-e-visual.json): 4.0.4
  transactional publication and 4.7.2 isolated validation both execute Counter
  with empty executable PATH. Inspected 0, 1 and reset/resized captures at
  640×360 and 800×400: centered labels, disabled Reset and responsive layout
  preserved. Earlier 4.7.0 captures were also inspected. These are scripted
  native graphics; physical F5/F6/mouse testing was not run.

Typical reproducible commands (fresh output directory required):

```sh
python3 tools/check-compatibility.py \
  --engine 4.0.4=/absolute/official/godot \
  --engine 4.7.0=/absolute/official/godot \
  --engine 4.7.2=/absolute/official/godot \
  --output /new/compatibility --editor --collect-only
```

Repeat `--engine` for every pinned version to reproduce the full matrix. The
collector's successful exit is collection only; CI independently gates the
required C01-B/C/D/E stages. Final-head CI links and exact branch/commit handoff
are published in #48 / #60, avoiding a self-referencing commit in this file.

## Remaining limitations and queue

- C01-F #49 still owns real older editor startup; C01-G #50 owns unsaved Play.
  Their red/BLOCKED stages remain visible. This PR does not implement them.
- #44's filtered never-associated tab remains FAIL even on 4.7.
- HybridEdges remains FAIL on 4.0/4.1 because native raw-string syntax is
  unavailable. 4.2 supports that syntax but fails unqualified generated static
  calls inside lambdas. Focused follow-up [#61](https://github.com/resistdesign/Estragon/issues/61)
  records the minimal native reproducer and type-validation constraints; #51
  must resolve broader authored-native syntax limits before certification.
- Native IEEE parsing limits from C01-D and newly added inherited defaults on
  existing live Script instances remain separate BLOCKED observations. Fresh
  defaults/current bytecode are verified; application hot reload is not offered.
- Earlier research import exits remain recorded unchanged. Final collection
  uses the test-only class-index observer described below, so early CLI shutdown
  is not confused with a failed component parse.
- On 4.0–4.2, public link inspection is unavailable. Reports disclose this
  optional missing guard; symlink-free projects remain required.

The next implementation after owner review/merge is C01-F #49. Do not merge
this PR automatically or start that milestone, C01-G or T09 from this branch.

## Import setup correction (final CI verification)

A 4.1 CI run at `245132a` passed every native semantic/publication/runtime check
but an earlier cold container parse failed because `EstragonDisplayObject` had
not yet been registered. Actual 4.0/4.1 `--help` defines `--quit` as quitting
after the **first iteration**, and neither exposes an `--import` flag. This made
the original initial-import setup race filesystem/class indexing.

The collector now temporarily adds a test-only EditorPlugin that waits for
`EditorFileSystem.is_scanning()` to finish and for all controlled class_name
metadata paths to match, then records that registry and quits gracefully. It
never preloads/instantiates runtime scripts, so subsequent parse and Text-first
processes remain cold. Existing enabled plugins are preserved; project bytes
are restored and the observer removed even if the editor fails (unit-tested).
Original parser errors still make import FAIL even with an index-ready marker
and exit 0. The C01-B container/button parse gates remain unchanged and strict.
No production editor-startup code is changed; C01-F remains queued.
