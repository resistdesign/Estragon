# C01-B runtime sizing compatibility

Tracking: [#45](https://github.com/resistdesign/Estragon/issues/45).
Base: C01-A PR #52, merge `46bc752`. The immutable
[C01-A baseline](C01_COMPATIBILITY.md) and its `results.json` remain unchanged.
This focused fix does not certify full Godot 4.0+ addon support.

## Production change

Container measurement now combines each measured child's x/y with `maxf` on
the corresponding accumulated coordinate. Each child is measured once. Button
painting still computes half the label surplus, then clamps each coordinate
independently to zero with `maxf`. Both use Godot 4.0 operations and preserve
fractional values; no integer conversion, sizing policy or hierarchy changes.

The first actual 4.0 run exposed a second runtime parser blocker hidden by the
vector failures: `connection.signal` in DisplayObject's incoming signal cleanup.
Indexing the same dictionary with `connection["signal"]` lets the 4.0 runtime
class graph load, retaining the typed Signal and existing disconnect behavior.
Temporary runtime-only experiments isolated this exact access: changing only
the neighboring `callable` access or removing type inference did not repair it.
No temporary stubs, dynamic class API or inheritance workaround ships.

## Regression and matrix coverage

The existing suites now check:

- **Components: 63 assertions.** Direct incoming signals survive reparenting with
  target identity intact, disconnect automatically on owner unmount, and cannot
  invoke the retained disposed target. Previous ownership/disposal checks remain.
- **Layout: 72 assertions.** Different children supply independent fractional
  coordinate maxima; empty/zero content stays zero, shrinking content shrinks
  maxima, size changes propagate dirty flags, and unmount cleans owned children.
- **Text/input: 96 assertions.** Actual font metrics establish expected label
  offsets for mixed positive/negative, zero, both-positive and both-negative
  coordinate surplus, including fractional origins/backgrounds. Zero-area
  buttons emit neither text nor background. Existing pointer, resize, transfer,
  capture, invalidation and cleanup tests remain unchanged.

The existing C01 collector additionally runs all seven existing invalid sizing/
text probes as separate cold processes. Each requires exit zero, its exact
completion marker and **exactly one specific expected error**. Extra engine
errors remain FAIL even if the expected rejection/marker also appears.

CI now requires component, layout, input, five invalid-sizing stages, and direct
Container/Button parse outcomes to PASS on every matrix engine. Other stages
retain their actual outcomes; successful evidence collection does not certify
those stages or the addon. Full raw reports/logs are CI artifacts; the focused
[C01-B snapshot](../tests/compatibility/c01-b-results.json) retains statuses,
assertion counts, source commit and evidence fingerprints from the eight
latest-patch CI runs plus the local required 4.7.0 baseline. Independent local
collector runs also exercise every pinned version.

Reproduce with verified binaries from the existing engine manifest:

```sh
python3 tools/check-compatibility.py \
  --engine 4.0.4=/absolute/official/godot-4.0.4 \
  --engine 4.7.2=/absolute/official/godot-4.7.2 \
  --output /new/c01-b-results --editor --collect-only
```

Repeat `--engine` for all selected versions. Read individual stages; default
mode rejects any FAIL/BLOCKED/UNTESTED, and `--collect-only` retains them in JSON.
Use isolated temporary projects/settings; never enable the owner checkout's
plugin for tests. Actual Godot processes have no Bun/Node available on PATH.

## Measured results

Official versions/provenance remain in `tests/compatibility/engines.json`.

| Engine | Container / Button parse | Components / layout / text-input | Five sizing rejections | Cold invalid-text rejections |
| --- | --- | --- | --- | --- |
| 4.0.4 | PASS | PASS (63 / 72 / 96) | PASS | FAIL: extra inherited-field compile error |
| 4.1.4 | PASS | PASS (63 / 72 / 96) | PASS | FAIL: extra inherited-field compile error |
| 4.2.2 | PASS | PASS (63 / 72 / 96) | PASS | PASS |
| 4.3 | PASS | PASS (63 / 72 / 96) | PASS | PASS |
| 4.4.1 | PASS | PASS (63 / 72 / 96) | PASS | PASS |
| 4.5.2 | PASS | PASS (63 / 72 / 96) | PASS | PASS |
| 4.6.3 | PASS | PASS (63 / 72 / 96) | PASS | PASS |
| 4.7.0 existing pin | PASS | PASS (63 / 72 / 96) | PASS | PASS |
| 4.7.2 latest tested patch | PASS | PASS (63 / 72 / 96) | PASS | PASS |

[Eight-engine CI with scoped gates](https://github.com/resistdesign/Estragon/actions/runs/41093176494)
passes all jobs; [required compiler/Linux suites](https://github.com/resistdesign/Estragon/actions/runs/41093176204)
pass both jobs. Final PR checks/handoff are linked in #45. CI artifacts retain
complete raw commands/logs; this snapshot preserves every stage's actual status,
including the remaining failures and blocked/untested behavior.

## Remaining failures stay visible

Generated callback guards (#46), numeric precision (#47), native semantic
validation/import identity (#48), plugin startup (#49), older unsaved Play (#50),
final release acceptance (#51), and filtered highlighting (#44) are not fixed.
Their red stages do not invalidate independently passing sizing tests, and
passing sizing tests do not imply those features work.

Strict invalid-font probes exposed a separate **cold Text-first dependency
compilation** issue on older engines: `button.gd:17` reports inherited `_disposed`
missing before the expected text rejection. Replacing that field access with
`is_disposed()` in an experimental copy merely moves the error to `_layout_rect`.
The positive component-first and input suites pass. No eager load, warmed fixture,
extra-error allowance or skipped probe conceals this cold-load defect. It is
recorded in [#48](https://github.com/resistdesign/Estragon/issues/48) and parent
[#41](https://github.com/resistdesign/Estragon/issues/41), with exact version
outcomes retained in the snapshot. Invalid-text acceptance remains incomplete
on affected engines; this PR fixes baseline sizing, not all dependency loading.

## Verification boundaries

The pinned 4.7 locked Bun/check, Godot/runtime/harness negative, native
frontend/generation, R01 and graphical editor suites pass. The Bun suite retains
150 tests/510 expectations; native generation/semantics retain 3612/83 assertions. The matrix also runs full editor
Play/recovery on 4.7.0 and 4.7.2. Native graphical editor/Counter captures are
separate from headless geometry checks. The highlighted editor, Count 1/enabled Reset and Count 0/disabled Reset after
resizing were inspected in the isolated 4.7 graphical run. Exact commands, CI
links and local artifact paths are recorded in #45/its PR handoff. Physical-keyboard/window-manager/manual remote-tree
checks, older native graphics and export certification remain separate work.
No T09 reactive properties, Box migration, compiler language or editor production
changes are included. C01-C #46 follows only after this PR merges/closes.
