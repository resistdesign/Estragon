# C01-E semantic validation investigation

C01-E [#48](https://github.com/resistdesign/Estragon/issues/48) is active on
`codex/c01-e-semantic-validation`, based on C01-D merge `bf2c426`.
This is an investigation checkpoint, **not compatibility certification**.
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

## Decision needed before changing the older-engine contract

The current requirement combines an unpublished independent candidate, an exact
already-cached output/class path and no cache mutation. No safe public-API
implementation for that combination has been demonstrated on 4.0–4.3.
Do not replace it with cache takeover, ignored engine errors, stale cached code,
a custom parser, external compiler, or silently removed `class_name`.

Two possible directions require owner review:

1. Keep the exact isolated-candidate contract and leave that older-engine case
   blocked while pursuing an engine/API solution. Existing newer engines can
   still receive the proven small path bridge and diagnostic isolation.
2. Explicitly distinguish isolated preflight from transactional publication on
   older engines. Preflight must report the exact cached-path capability as
   unavailable; final native semantic validation at the real output path must
   remain mandatory inside rollback/recovery before publication is committed.
   This requires a reviewed contract/API change and tests of live instances,
   dependent types, failure rollback and recovery. It does **not** authorize
   returning a cached application Script as an isolated candidate.

Neither option is implemented or accepted by this document. Better diagnostic
capture is optional under progressive enhancement; actual validity, freshness,
dependency resolution and identity are correctness requirements.

The draft now isolates the bundled Logger/ScriptBacktrace adapter as trusted
text, compiled only when those native classes and OS logger methods exist.
Older engines still perform real native reload and expose native errors; a
generic diagnostic explicitly states that an exact authored location is
unavailable. On 4.4+ the proved paired path assignment restores relative paths
and registered-class candidate context. On 4.0–4.3 `validate()` currently returns
an explicit unsupported-path diagnostic with no executable or cache mutation;
it does **not** bypass the pending correctness requirement. Explicit publication
`reload_script()` remains separately testable on all versions. No editor routing
or legacy transactional fallback has been introduced.

`semantic_baseline.gd` checks a real valid native reload, an unknown-identifier
rejection (exactly one native error; mapped authored line 3 on Logger engines),
and separate candidate identity with relative preload and relative/absolute
inheritance. Unavailable legacy isolation is a BLOCKED stage, never PASS.

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

Full semantic, transactional/editor and graphical acceptance remain outstanding
at this checkpoint. See issue #48 for actual commands, results and next action.

Recorded checkpoint evidence: [path API matrix](../tests/compatibility/c01-e-context.json)
and [runtime cold-load sweep](../tests/compatibility/c01-e-cold.json). The runtime
sweep passes component (63), layout (72), interaction (96), cold-positive and
both strict font rejections on all nine engines. Its minimal-project editor
import exits nonzero on 4.0–4.2 despite producing only warnings; those import
outcomes remain FAIL. They are not silently converted into successful addon
imports. The full collector is rerun from frozen source snapshots; an earlier
in-progress run that read changing source between engines is excluded from
before/after certification.

Pinned 4.7 local verification: Bun 180 tests / 663 expectations, Python 17,
native generation 3632, semantics 127, signals 49, full Godot runtime/negative
harness and fresh native editor build/Play/rollback/restart suite PASS at the
cold-cycle checkpoint. Three native Counter captures (0, 1, reset/resized) were
inspected: label centering, disabled Reset, responsive layout and rendering are
preserved. This is scripted native graphics, not physical F5/F6 or mouse proof.
Adapter changes have a separate native suite run; final-head CI and complete
semantic/publication acceptance remain pending.
