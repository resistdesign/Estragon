# Estragon execution plan — Codex-sized delivery

**Active target:** [ADR-0016 — Reactive Function Composition](REACTIVE_COMPOSITION_ARCHITECTURE.md), accepted 2026-11-05. **Roadmap:** [REACTIVITY_PLAN](REACTIVITY_PLAN.md), [issue #89](https://github.com/resistdesign/Estragon/issues/89), [T09 umbrella #5](https://github.com/resistdesign/Estragon/issues/5), [AGENTS.md](../AGENTS.md). ADR-0016 supersedes earlier statements forbidding a Virtual DOM, requiring only one-time GGX construction, or demanding permanent preservation of old compiler/binder implementations. **This is an unreleased project; no backwards-compatibility requirement.**

**Latest merged composition prerequisite:** F06 [PR #105](https://github.com/papercraftgames/Estragon/pull/105), `55156fb`; F05-B [PR #102](https://github.com/papercraftgames/Estragon/pull/102), `52a3255`; F05-A [PR #100](https://github.com/resistdesign/Estragon/pull/100), `3487d86`; F04 [PR #99](https://github.com/resistdesign/Estragon/pull/99), `f655fac`; F03 #97 is merged. F02 [PR #95](https://github.com/resistdesign/Estragon/pull/95), merge `d957003`; F01 #93 is also merged. T09-B [PR #87](https://github.com/resistdesign/Estragon/pull/87), merge `fa27a2749ca9d124eacbcaff55da993c38cfde5b`. T09-A [PR #85](https://github.com/resistdesign/Estragon/pull/85) and native ADR-0015/C4 [PR #84](https://github.com/resistdesign/Estragon/pull/84) are merged. The native Godot-only compiler/editor, Gogo property signals, retained Node2D/Node3D runtime and bounded reactive GGX props work. F01/F02 ship dynamic getter observation, descriptions and conditional/nested retained reconciliation. F03 lists/keys are merged in #97 (`eb153f1`); F04 single-runtime cutover is merged #99 (`f655fac`); F05-A #90 class-wide annotation is merged #100; F05-B controlled bool input is merged #102; F06 native measurement is merged #105; P01 package preparation is active #104.

## Operative delivery queue — ADR-0016

1. **Design/approval (this docs-only architecture review):** land one complete ADR/spec/plan and reconcile active docs/AGENTS, with no production/runtime changes. [Design issue #89](https://github.com/resistdesign/Estragon/issues/89). Owner merges manually. Do not start a successor until review closes.
2. **F01 — minimal native signal→view→reconcile spike:** merged scope is [#92](https://github.com/resistdesign/Estragon/issues/92) after merged design PR #91 (`a43fba8`); [concrete F01 contract](F01_COMPOSITION.md). Validate generated Gogo getter read tracking on both approved Godot versions; choose only a documented small source bridge if it genuinely fails. Have one `build_view` compute lightweight descriptions; observed state changes rerun that component, retain real Node identity, and commit at a safe frame point. No duplicate runtime and no new language outside the agreed GDScript/GGX semantics. Prefer a real working Counter as proof.
3. **F02 — dynamic nested GGX conditionals, merged #95 / closed #94 after merged F01 #93 (`1d6b9c5`):** [bounded contract](F02_CONDITIONALS.md). compile a GDScript-native conditional child expression; diff sibling type/position/optional key; preserve compatible native Nodes; nested dependency scopes, null/replacement and parent-first scheduling cancellation. Test actual scene ownership, foreign child boundaries, sources/maps and layout.
4. **F03 — mapped keyed collections, merged #97 / closed #96 after merged F02 #95 (`d957003`):** [Contract](F03_LISTS.md). ordinary GDScript `for`/`Array.map` descriptions; keyed insert/remove/reorder with stable native IDs and item-owned state; duplicate-key rejection. Start with `@bindable` Array **reference replacement**, not mandatory mutable list proxies. Add an opt-in observable collection only if in-place mutations must notify.
5. **F04 — final single runtime/compiler cutover, merged #99 / closed #98 after merged F03 #97 (`eb153f1`):** [Inventory/parity contract](F04_CUTOVER.md). migrate Counter/GGX examples, editor, generated sources, distribution and tests; **delete** obsolete eager Node construction, T09-B target-owned `property_binding.gd` helpers, redundant static path evaluator, duplicate subscriptions and old fixture dependencies after proven parity. Preserve meaningful native/editor/runtime semantics and historical facts, not pre-release compatibility.
6. **F05-A — class-wide bindables, merged #100 / closed #90 after merged F04 #99 (`f655fac`):** implement scoped [class-level `@bindable` issue #90](https://github.com/resistdesign/Estragon/issues/90), then **F05-B**, merged #102 / closed [#101](https://github.com/resistdesign/Estragon/issues/101) after F05-A owner merge `3487d86`: [bounded typed bool binding and native toggle](TWO_WAY_BINDINGS.md), existing reconciler/lifecycle/feedback guard. F06 starts only after owner merge. JSON/Resource typed hydration/serialization is **optional and separately scoped**, not part of F01–F04.
7. **F06 — instrument/profile, merged #105 / closed [#103](https://github.com/papercraftgames/Estragon/issues/103) after merged F05-B #102 (`52a3255`):** [Measurement contract/evidence](F06_PROFILING.md). representative inventory/HUD/deep nested 2D/3D workloads; measure composition passes, descriptor allocation, native Node creations/frees/reorders, unchanged props/layout work and memory; only then add React Compiler-inspired memoization or Svelte/Solid-style targeted optimizations when they clearly simplify or speed things up.

**One authoring model:** normal readable Gogo/GDScript function composition; ordinary mutable `@bindable` writes trigger automatic recomposition through native signals, no hooks or manual invalidation; a **real lightweight Virtual DOM** describes desired tree and reconciles retained Godot Nodes. **No reconciliation fields, keys, fibers, or per-property helper Nodes on application Nodes/Resources/models.** Virtual records are independent runtime data. Godot's native physics, transforms, render pipeline, Node.add_child and composed layout remain authoritative. **No per-frame composition/diff**.

**Commit protocol:** scoped issue with checkpoints/acceptance/provenance, one open PR total, owner review/merge; Linux CI with only official Godot 4.0.4 and pinned 4.7.0, no macOS/other minor sweeps. End users compile with the bundled Godot addon only; new contributor tooling TypeScript/Yarn, never Python. Native source-mapped semantic validation, saved/unsaved Play rollback/repair, real graphics/metadata and source-only addon pack export remain acceptance gates.

## P01 — cleanup and scoped addon package preparation

After merged F06 #105 (`55156fb`), [#104](https://github.com/papercraftgames/Estragon/issues/104) delivered an addon-only `@papercraftgames/estragon` artifact, live docs/examples, explicit Yarn/copy installation, native consumer/editor/rendered proof and GitHub Release-triggered publishing in merged PR #106. The owner locally published the first beta on 2026-11-06 and configured package-specific npm Trusted Publisher. The next owner-reviewed single-source version change enables its first OIDC GitHub Release/publish, provenance and fresh public-registry Godot consumer acceptance. The only committed release version is in `addons/estragon/editor/plugin.cfg`; npm package metadata is generated during packaging. [Contract/inventory](PACKAGING.md). Root tooling remains private; preserve all 73 strict stages on each approved Linux Godot engine. No automatic merge/public tag/release from a version PR. Issue remains open until the public CI release is verified; the broader UI roadmap stays separate.

## CI01 — CI performance after P01 repair

[#109](https://github.com/papercraftgames/Estragon/issues/109), after owner-merged #108 (`b473bdb`), optimizes PR scope, bounded editor readiness and immutable verified engine caching; instruments and compares suite/stage/editor time and directly orchestrated launches. [Policy and measurement contract](CI_PERFORMANCE.md). Updated owner #109 policy: routine PR AND main <=60seconds, static/policy plus tiny smoke only. Move full two-engine73-stage/exact-artifact certification to a mandatory pre-publication gate; preserve security and post-publish consumers. One review PR, no product/version/publication change.

## Historical milestones and preserved acceptance contracts

The T01–T08 and N01–N03 sections below preserve their original scope and implementation evidence. Past no-Node/RefCounted renderer requirements describe what was built, not the approved future. Subsequent C01 history is archival sequencing; use the operative queue above and live issues for pickup. Existing Bun commands/manifests remain historical tooling; future contributor tooling is TypeScript/Yarn, conversion separately scoped. Product compilation remains Godot-only. Only 4.0.4 and pinned 4.7.0 may be launched; physical keypresses are not acceptance requirements.

## Outcome: an actual Gogo UI in Godot

The first integrated milestone (T01–T08, **transitionally Bun-powered**) is an interactive `Counter.gogo` running in Godot 4.7:

1. A developer authors one `.gogo` file combining GDScript methods/state and **unprefixed** component markup (e.g., `<VBox>`, `<Text>`, `<Button>`), with typed GDScript expressions and a callback.
2. The Bun/strict TypeScript toolchain transpiles it deterministically into valid, inspectable `.gd`. It resolves components, checks properties/events and generates signal connections. No runtime JSON UI parsing.
3. The generated code instantiates Estragon's own component objects. Layout (including `VBox`/`HBox`) responds to viewport resizing; components render through Estragon's Godot low-level graphics adapter. No Godot `Control` widgets or per-component `Node`.
4. A click invokes the generated handler and visibly updates the counter. The initial demo may use explicit state invalidation **until** the separate binding work is complete; do not mislabel it reactive.
5. The Godot editor recognizes Gogo, automatically transpiles before Run and clearly reports failures against the authored source. Failed builds must not run stale generated code.
6. CI covers strict TypeScript tests and actual Godot script/runtime checks; a documented visual check covers what headless CI cannot prove.

**Not required to claim this first milestone:** Gogo `@bindable` or completed reactive bindings, full JSX grammar, full Flex compatibility, a complete component suite, sophisticated graphics backends or polished visual editor. Those follow independent evidence and reviews. Ordinary `.gd` custom annotations are no longer an accepted requirement (ADR-0013).


## Immediate priority: native Gogo compilation inside Godot (ADR-0012)

**Accepted owner decision, 2026-10-28:** A developer using Estragon in Godot must need **only Godot and the bundled Estragon addon**. **No Bun/Node/TypeScript installation or compiler executable configuration for editing, building, or running Gogo.** T08 originally used Bun as a **temporary bridge**; N03 replaces it with the bundled native compiler/validator. The owner has manually verified T08 by changing Counter.gogo's font size and rerunning the scene in Godot. That successful test triggers this priority shift.

Write the production compiler **in GDScript, bundled in the addon**. It should work without editor UI state, external processes, runtime JSON interpreters, one Godot Node/Control per component, GDExtension binaries, or Godot forks. Keep parsing, typed validation, code emission and source mapping separate from rendering and editor presentation. Preserve the accepted TSX-like GDScript + unprefixed markup language, evaluation order and generated signal behavior.

**Next three reviewable PRs:**

1. **N01:** native GDScript lexer/parser, typed model, validation and source-located diagnostics; parity cases for the existing hybrid grammar and callback/prop contract.
2. **N02:** native GDScript emitter and source maps; preserve T04–T07 language semantics and prove a generated interactive Counter executes in Godot. Differential parity against the TypeScript reference where useful.
3. **N03:** switch editor save/build and both Play modes from Bun to **direct native compilation**. Eliminate user-facing Bun executable settings and subprocesses, preserve source discovery, diagnostics, pre-Play checks and recovery, and demonstrate a **fresh Godot-only installation with Bun absent**.

**Acceptance gate for N03:** Fresh Godot 4.7 project + Estragon addon + Gogo sources; with Bun/Node unavailable (no PATH or configured executable), edit Gogo, invoke both Play modes through automated isolated editor/game tests, and run the latest generated code. Deliberately break Gogo and prove both Play modes refuse stale output; repair it and confirm recovery. Run actual Godot-native tests without Bun. Bundled addon must work independently of the repository's optional development dependencies.

**Preserve the working T08 bridge until N03 is demonstrably ready.** Do not delete the current compiler, tests or generated fixtures prematurely. Bun/TypeScript may remain as **optional CI/reference/differential tooling** after cutover; there must be no silent Bun fallback in the editor. T09 reactive bindings and T10 legacy retirement are postponed until N03 passes. R01 may be researched independently and does not block this migration. One focused PR, tests, linked issue and durable handoff per task.

## Architectural constraints and review gates

- Gogo is **TSX-like GDScript + XML-like markup**, transpiled to **GDScript**. No mandatory XML namespaces (`<fx:VBox>` / `xmlns`), no TypeScript/JavaScript embedded in Gogo.
- Implement a real parser/typed representation with source positions; no regex replacement of mixed syntax or GDScript.
- Preserve the functioning **stage-0 namespaced XML → JSON demo** until a GDScript-generated equivalent is running and tested. Do not build the new architecture around the old JSON contract.
- ADR-0015 targets native Node composition, Node2D/Node3D visual participants and composed layout, with Godot retaining native lifetime/transforms/rendering. The older no-per-component-Node constraint is superseded; preserve current runtime compatibility during migration.
- Generated code is not hand-maintained. It must be deterministic, validated by Godot, and traceable to its authored Gogo source.
- Each task below is a **reviewable PR** with tests, documentation and evidence appropriate to its scope. Do not merge on behalf of the user without explicit permission.
- **Gate to start a dependent task:** its prerequisites and the current repository PR are merged/closed. Keep future research/dependencies in issues while the sole PR is active; do not start competing implementation.
- If an acceptance criterion proves infeasible, record evidence and a blocker in the issue, propose options, and **stop rather than quietly change the product requirements**.

## Historical dependency map (current successor gates above)

~~~text
T01 → T02 → T03 → T04 → T05 → T06 → T07 (merged)
                                      │
                       T08 editor integration (merged PR #29)
                                      │
                       N01 native lexer/parser (merged PR #32)
                                      │
                       N02 native codegen + source maps + parity (merged PR #34)
                                      │
                       N03 native editor cutover (no Bun)
                              ├───────┴────────┐
                       E01 #40 merged → C01-A #42 audit → C01-B…H #45–51 (+ #44) → T09-A #43 models → T09-B UI/layout → T09-C collections → T09-D two-way
                        T10 legacy JSON retirement (independent)
R01 #38 research: merged; historical evidence, no longer a T09 syntax blocker
R02 graphics research: deferred
~~~

This records the earlier sequential delivery order; the operative ADR-0015 queue and NODE_MIGRATION_PLAN now control successors. It is not a request to implement everything in one PR. Maintain issue-only research/backlog while the single PR is active; do not open stacked or competing PRs.

## Work packages and acceptance

### T01 — Godot 4.7 validation and CI foundation

**Tracking:** [issue #13](https://github.com/resistdesign/Estragon/issues/13). **Prerequisites:** none. **Merged:** PR #15.

- Add a repeatable headless Godot 4.7 project import, GDScript parse and runtime smoke-test route in CI and local documentation.
- Prove malformed GDScript and a failing test genuinely fail the job (not just write errors to logs).
- Preserve all existing Bun 1.4.4, `tsc --noEmit`, `bun test`, and JSON fixture checks.
- Document the manual Godot visual smoke test separately; don't claim headless CI renders correctly.
- **Not in this PR:** language redesign, new runtime classes, changes to the old JSON demo.

### T02 — Estragon-owned display-object and container foundations

**Tracking:** [issue #16](https://github.com/resistdesign/Estragon/issues/16). **Related umbrella:** [issue #1](https://github.com/resistdesign/Estragon/issues/1). **Prerequisite:** T01 (merged in PR #15).

- Add independent display-object and container-like GDScript classes (e.g., named with `Estragon` prefixes to avoid Godot's `Container` collisions), child ownership, parent links, identity, cleanup and invalidation foundations.
- Exercise add/remove/reparent, nested children, disposal and no-per-component-node guarantees with Godot tests.
- Define the smallest contract needed by subsequent layout and code generation; do **not** prematurely implement all widgets, reconciliation, bindings or backend optimizations.

### T03 — Responsive VBox/HBox and basic drawing

**Tracking:** [issue #18](https://github.com/resistdesign/Estragon/issues/18). **Related umbrella:** [issue #3](https://github.com/resistdesign/Estragon/issues/3). **Prerequisite:** T02 (merged in PR #17).

- Implement minimal measured/layout behavior for nested `VBox`/`HBox`, dimensions, gaps and a rectangle primitive using Estragon component objects.
- Adapt the existing Godot `RenderingServer` approach behind an Estragon paint/render boundary; resize the viewport and verify children relayout without Godot `Control` nodes.
- Add deterministic layout tests and a repeatable Godot manual rendering check. Advanced text, focus, accessibility and graphics backend research are not part of this PR.
- **User-directed T03 correction (2026-10-26, ADR-0008):** framework owners automatically clean components/resources on unmount, replacement and surface destruction; normal application code never calls disposal. Transfers between owners preserve components. Include lifecycle cleanup tests and update the T02 removal contract deliberately. This necessary integration stays within T03, without changing task dependencies.

### T04 — Minimal Gogo → GDScript transpiler

**Tracking:** [issue #20](https://github.com/resistdesign/Estragon/issues/20). **Prerequisite:** T03 (merged in PR #19).

- Add an unprefixed, markup-only **transpilation slice** (e.g., `<VBox>` / `<HBox>` / `<Rect>`) that emits valid, deterministic GDScript constructing real T02/T03 classes.
- Validate component names, property types, children and malformed source with useful locations. Feed generated output to the Godot validation added in T01.
- Design an intermediate model compatible with later GDScript/markup interleaving; do **not** canonize the stage-0 strict XML parser/JSON format as the new grammar.
- Keep the legacy compiler and sample working side by side. No auto-editor integration in this task.

### T05 — TSX-like GDScript and Gogo in one source

**Tracking:** [issue #22](https://github.com/resistdesign/Estragon/issues/22). **Prerequisite:** T04 (merged in PR #21).

- Support a *minimal, specified* `.gogo` hybrid: authored GDScript members/functions plus nested component expressions and braces holding GDScript value expressions.
- Test strings containing angle brackets, comparisons vs tags, nested braces, indentation, property types and malformed source. Preserve original source locations in diagnostics and generated-to-source mappings.
- Produce compilable `.gd` with tests and Godot headless validation. Record accepted grammar trade-offs in language docs/decisions.
- Keep the feature slice narrow; do not promise full TSX syntax, React behavior or arbitrary GDScript reflection.

### T06 — Minimal interactive primitives and input dispatch

**Tracking:** [T06 / issue #24](https://github.com/resistdesign/Estragon/issues/24). **Related umbrella:** [#3](https://github.com/resistdesign/Estragon/issues/3). **Prerequisite:** T05 (merged in PR #23).

- Add only the foundational text display, button hit-testing/pointer dispatch, click signal and necessary layout/paint invalidation to support a small counter.
- Demonstrate basic text and pointer handling in Godot tests and a visual smoke test. Do not route application events through Godot's `Control` GUI.
- No full TextInput, touch gestures, accessibility, styling or general-purpose widget catalog in this PR.

### T07 — Compiler-generated signal wiring and first interactive demo

**Tracking:** [T07 / issue #26](https://github.com/resistdesign/Estragon/issues/26). **Prerequisites:** T05 and T06 (merged in PRs #23/#25).

- Support typed event/callback attributes, generate handler references/adapters and signal connections automatically in the resulting `.gd`, and verify handler signatures and lifecycle/disposal.
- Ship a **real mixed-source `Counter.gogo` demo**: click button → GDScript handler runs → visible counter changes. Explicit refresh is acceptable before T09 and must be documented.
- Test invalid handler names/signatures, no duplicate connections, and functioning Godot runtime. **This is the primary first-vertical-slice gate.**

### T08 — Godot editor language and compile-before-run integration

**Tracking:** [T08 / issue #28](https://github.com/resistdesign/Estragon/issues/28). **Related umbrella:** [#6](https://github.com/resistdesign/Estragon/issues/6). **Prerequisite:** T07 (merged PR #27).

- Prove in Godot 4.7 that `.gogo` opens with useful mixed-language syntax highlighting and source-mapped diagnostics. Establish a source editor path that can grow to completion/navigation.
- Automate generation of `.gd` before running a project and clearly fail rather than executing stale compiled code; preserve authored source and existing editor settings.
- Test editor/build hooks and document the exact integration limitations. Completion, visual designers and polished live preview may be follow-up tasks, not false acceptance claims.


### N01 — Godot-native Gogo frontend

**Tracking:** [issue #30](https://github.com/resistdesign/Estragon/issues/30). **Prerequisites:** T08 PR #29 and planning PR #31 (both merged).

- Implement a GDScript-only scanner/parser for the currently accepted standalone and mixed GDScript/Gogo syntax: nested unprefixed elements, balanced braced expressions/children, strings/raw/multiline strings, comments, comparisons and other lexical ambiguities.
- Build typed component/property/signal AST validation and original source spans. Reproduce supported VBox/HBox/Rect/Text/Button and Button.pressed contracts, reject unknown/duplicate/invalid markup, and retain Godot as the authority for GDScript semantics.
- Add native Godot positive/negative/adversarial tests and a documented compatibility matrix. A minimal generated-code proof is useful; **complete code generation belongs to N02**.
- Keep T08 functioning. No direct editor cutover, external executable, GDExtension, bindings or other widgets. Create one focused implementation PR, verify and hand off.

### N02 — Native emitter and current Gogo behavior parity

**Prerequisite:** N01 merged PR #32. **Tracking:** [N02 / issue #33](https://github.com/resistdesign/Estragon/issues/33).

- Generate deterministic ordinary GDScript and original-source maps for both markup-only and hybrid files, including typed factories, native expression scope, property/child evaluation order, collision-safe names and generated Button.pressed connections.
- Match T04–T07 supported behavior through tests against existing fixtures, positive and negative sources, mapped diagnostics, callbacks, expression edge cases and resource cleanup. Document deliberate formatting differences rather than pretending byte-for-byte equivalence where it is not required.
- **Compile Counter.gogo with the native compiler**, run it in Godot, click +/Reset, resize, and verify correct state, no duplicate handlers, and automatic lifecycle. All these checks must work without Bun; optional TypeScript reference checks may run in CI.
- Do not switch the editor yet; preserve the current Bun-backed T08 code until N03.

### N03 — Godot-native editor cutover, Bun removed from user workflow

**Prerequisite:** N02 merged PR #34. **Tracking:** [N03 / issue #35](https://github.com/resistdesign/Estragon/issues/35).

- Replace the editor's external Bun/build-gogo process with **direct native compiler calls**. Keep the same configured source-root policy, generated script/maps, unchanged output handling, native GDScript validation, source-located diagnostics, error panel and F5/F6 fail-closed gate.
- Maintain save/unsaved buffer handling, filesystem changes, resource refresh, plugin enable/disable, recovery and lifecycle. Remove the Bun executable setting/discovery and all compiler subprocess usage; do not use a hidden Bun fallback.
- Require a **clean Godot-only project without Bun/Node installed/configured** to complete the accepted N03 gate above. Test malformed markup/semantic errors and recovery through both Play paths, including in isolated real Godot editor integration tests.
- Keep Bun/TypeScript only as optional repository/CI reference tooling, never as an addon requirement. Update user docs and AGENTS after successful migration. Do not retire the legacy JSON demo in this PR.

### T09 — Completed foundations and ADR-0016 successors

**Merged:** T09-A typed Gogo-only `@bindable` property/model foundation ([#43](https://github.com/resistdesign/Estragon/issues/43), PR #85) and T09-B scoped reactive GGX existing-Node property/layout updates ([#86](https://github.com/resistdesign/Estragon/issues/86), PR #87). They are current shipped code, but T09-B's helper-Node/static dependency implementation is **not** a compatibility promise.

**Next accepted architecture:** [ADR-0016](REACTIVE_COMPOSITION_ARCHITECTURE.md). Function composition produces cheap virtual element descriptions; Gogo signals automatically rerun affected functions; a small reconciler preserves actual Godot Nodes, with external (not Node-injected) identity/subscription records. F01–F04 replace old eager construction/property-binding paths with one engine; F05 adds [class-level `@bindable` #90](https://github.com/resistdesign/Estragon/issues/90) and two-way binding. Optional observable in-place collections and data serialization require explicit bounded use cases, not a mandatory Repeater or AMF clone. **No React hooks, no per-frame composition, no pre-release backwards compatibility.**

**Delivery:** serial F01–F06 issues and owner-reviewed PRs, only two approved Linux engines, native compiler/editor and strict addon gates. Do not start implementation while the ADR-0016 docs review PR is open. Historical T09 Box/RefCounted display and universal Flex model proposals are superseded; code-only RefCounted data models remain valid.

### T10 — Retire the legacy JSON prototype safely

**Prerequisites:** **N03 merged** and verified parity for the old example. T09 is not a prerequisite to replacing the legacy rectangle example.

- Convert/replace the old sample with the new generated-GDScript pipeline and prove matching or improved rendering, CI and local editor behavior.
- Remove obsolete JSON runtime parsing/fixtures/commands only when no active consumer depends on them; update docs/tests/AGENTS together.
- Do not delete an otherwise useful example until a working replacement is merged.

### C01 — Godot 4.0+ compatibility (owner baseline requirement; project-wide)

**Tracking:** [C01 #41](https://github.com/resistdesign/Estragon/issues/41). **Owner decision:** ADR-0014. **Target:** Godot 4.0 through all later 4.x minors, not just 4.7. **Status:** measured failures remain a release gate; [C01-A evidence](C01_COMPATIBILITY.md) separates actual passes from failures, blocked Play and untested graphics/platforms.

- Audit GDScript syntax, plugin lifecycle, all compiler/emitter/validation methods, editor APIs, generated resource/UID/scene formats, and runtime component/graphics APIs using **Godot 4.0 as the minimum**. Known gaps: `ScriptEditor.save_all_scripts()`, `get_unsaved_files()` and `Resource.set_path_cache()` are documented in 4.7 but not 4.0; the E01 4.7 editor association adapter reaches undocumented UI internals; `project.godot` advertises a 4.7 feature.
- Implement public-API 4.0-compatible paths where possible; version-gate any unavoidable private adapter with real-engine proof. Never compromise source freshness, F5/F6 fail-closed behavior, generated-script/class identity, startup/restart highlighting, component lifecycle or user configuration.
- **Owner verification cap (2026-11-02): run only official Godot 4.0.4 and pinned 4.7.0**, both locally and in CI; this replaces every-minor testing requirements for C01-H, T09 and later work. Never require complete/nine-version local, agent, CI or release suites. Run focused tests during edits and one relevant two-version verification before review. Preserve archived nine-version evidence and actual failure statuses without reruns; only tested engines can be claimed as freshly verified. Verify fresh install with only Godot/addon, no Bun/Node.
- E01 PR #40 merged with its narrow measured scope; remaining compatibility evidence is a shipping gate for T09/Estragon releases; do not silently raise the minimum engine. Keep C01 as separate scoped work as needed, with issue/PR and durable handoff.

**Verification-budget precedence:** The [owner's 2026-11-02 decision](DECISIONS.md)
supersedes any earlier C01 issue, historical evidence report, test recipe or
PR acceptance text demanding all eight/nine minor versions. Maintain only
**4.0.4 + 4.7.0** as selected engines; do not run others locally or in CI.
C01-H still owns the distribution/graphics/release work and must not falsely
claim proof for untested versions. Keep stage-level evidence truthful.

### C01-A — Compatibility audit and reusable test matrix

**Tracking:** [#42](https://github.com/resistdesign/Estragon/issues/42). **Predecessor:** E01 PR #40 merged `41b43b4`. **Scope:** audit, isolated test infrastructure and planning; no addon compatibility rewrite. [Measured report](C01_COMPATIBILITY.md), `tests/compatibility/{engines,results}.json`, selectable `tools/check-compatibility.ts`, and informational macOS CI provide durable evidence. Actual latest patches 4.0–4.7 are tested, plus the required 4.7.0 regression pin.

- Native frontend/emission/maps pass on all tested minors; downstream generated validity, runtime, semantic identity and editor startup are independent stages with honest FAIL/BLOCKED/UNTESTED results.
- Test clean product import before adding test fixtures, all 33 shipped scripts, existing runtime/compiler suites and actual isolated editor behavior with empty tool PATH. Existing required 4.7 Linux suites remain intact; graphics/manual/platform evidence is separate.
- Default collector exit rejects any unmet stage. `--collect-only` is audit-only and retains red JSON/artifacts; it is not release certification.
- Complete delivery requires one reviewed PR, exact engine provenance/commands/results, queued follow-ups and durable issue/PR handoff. No automatic merge or next implementation before closure.

### C01-B…H — Proposed focused compatibility implementation queue

C01-A PR #52 merged `46bc752`. C01-B #45 now supplies the [focused runtime correction](C01_B_RUNTIME.md); subsequent issues remain queued. The additional explicit incoming-signal dictionary key is required for 4.0 runtime parsing and preserves cleanup semantics. Cold Text-first inherited-field compile failures remain recorded under #48/#41, not suppressed by C01-B.

| Work ID / issue | Scope / observed failure | Prerequisites |
| --- | --- | --- |
| C01-B [#45](https://github.com/resistdesign/Estragon/issues/45) | Vector2.max in container/button blocks 4.0–4.2 runtime | C01-A merged |
| C01-C [#46](https://github.com/resistdesign/Estragon/issues/46) | Generated Callable argument-count guards unavailable through 4.2 | C01-B |
| C01-D [#47](https://github.com/resistdesign/Estragon/issues/47) | Numeric literal semantic mismatch, including measured 4.5 small double | C01-C |
| C01-E [#48](https://github.com/resistdesign/Estragon/issues/48) | Logger/path APIs, real relative loads and script/class/cache identity | C01-D |
| C01-F [#49](https://github.com/resistdesign/Estragon/issues/49) | EditorInterface instance APIs, import lifecycle, actual plugin startup | C01-E |
| C01-G [#50](https://github.com/resistdesign/Estragon/issues/50) | Unsaved/unsavable buffers, native fail-closed F5/F6 and recovery | C01-F |
| E01-F [#44](https://github.com/resistdesign/Estragon/issues/44) | True positive filtered never-associated highlighter proof or owner disposition | Compatible editor foundation; coordinate after C01-G |
| C01-H [#51](https://github.com/resistdesign/Estragon/issues/51) | Gate/distribution infrastructure **merged PR #66**, release BLOCKED pending #61, cold scene, #65 and standalone export scope | Infrastructure merged; #61 first |
| **#61 static lambda-helper** | **Scoped Done:** merged PR #67; full raw-syntax/release boundary remains blocked | C01-H strict gate merged PR #66 |

Each issue contains measurable acceptance and exact evidence. Preserve semantic diagnostics, callback order, native no-tools workflow and framework-owned runtime. Do not replace unavailable APIs with unchecked no-ops. The historical compatibility queue is superseded for current delivery by merged C4 and the current-addon gate. T09-A #43 is merged and T09-B #86 is active; collection/two-way stages remain queued, with layout adapted to composed native Nodes by ADR-0015.

### C01-C progressive diagnostics

C01-B #53 and documentation #56 are merged. The [C01-C investigation](C01_C_CALLBACKS.md)
proved public 4.0 reflection cannot recover opaque lambda arity. The owner
[approved pragmatic compatibility bridges and progressive enhancement](https://github.com/resistdesign/Estragon/issues/46#issuecomment-6534935109):
skip only unsupported proactive arity introspection on 4.0–4.2; preserve valid
Callables, other available safeguards and normal invocation errors. 4.3+ retains
early required/optional rejection. Test both paths with actual engines, source
maps, invalid/disposed targets, connection ownership and lifecycle. No elaborate
adapter or external-Callable restriction is authorized or needed. Full-addon
compatibility remains gated by later C01 tasks; no successor starts before merge.
Unit helpers, Box/padding and reactivity remain outside this milestone.

### C01-D numeric contract and focused correction

C01-C #57 merged at `68f1ec4`. C01-D #47 follows the owner's 2026-10-31 decision:
**preserve native Godot numeric parsing semantics; fix avoidable loss; document
and test inherent limitations; do not build a full custom decimal parser.**
[Root cause and contract](C01_D_NUMBERS.md): normalize validated decimal text before
native conversion and retain its token through typed IR/emission, eliminating
lossy JSON formatting. Require exact independent bytes for ordinary cases and no
additional emission loss for separately reported native parser limitations.
The correctly-rounded conversion capability remains BLOCKED where measured;
that diagnostic is distinct from approved native-value preservation acceptance.
Preserve zero policy, float32 finite validation, maps, callbacks and Godot-only
workflow. C01-D is merged in #59; C01-E subsequently merged in #60.
C01-F #62 and C01-G #63 are merged. E01-F #44 has an [owner-approved accepted limitation](https://github.com/resistdesign/Estragon/issues/44#issuecomment-6568383818) and is **closed not planned**, with [PR #64 merged](https://github.com/resistdesign/Estragon/pull/64) at `e837557`. The two-version **4.0.4 / 4.7.0** CI and TypeScript-only tooling are now on `main`. **C01-H #51 gate/distribution slice merged as PR #66** (`ecee892`), while strict release remains **BLOCKED**. **#61 scoped helper fix merged as PR #67; #61 closed completed. ADR-0015-A #69 is current docs-only work.** Remaining separate release tasks include 4.0.4 cold-scene missing-generated restoration, #65 resource-pack export cleanup and standalone executable export/platform scope. The owner permits only 4.0.4 and pinned 4.7.0, no Python and no all-minor sweeps; T09 remains queued.

### E01 — Automatic Gogo highlighting activation (separate editor fix)

**Tracking:** [issue #37](https://github.com/resistdesign/Estragon/issues/37), focused [#44](https://github.com/resistdesign/Estragon/issues/44). **State:** normal fix merged PR #40; owner accepted a precisely bounded hidden never-associated case on 2026-11-02 ([evidence](E01_F_FILTERED.md)). Full release support remains C01-H #51. Do not mix E01 into T09.

- Reproduce the owner-confirmed restored-tab activation bug; prove automatic selection for new, existing and restored Gogo tabs, disable/re-enable and restart. Preserve unrelated user settings.
- Extend the real isolated editor tests to inspect actual highlighter attachment/colors without manual selection. PR #40 merged; future #44 delivery follows the one-open-PR rule.
- [Measured E01 matrix](E01_COMPATIBILITY.md): normal/restart behavior verified across the minors. Older full-addon startup and unsaved Play were fixed in C01-F/G. E01-F still measures fresh hidden/never-associated FAIL on all nine official engines; the owner **approves waiting until reveal and activation** rather than an unsafe private identity workaround. Preserve historical FAIL and a separate accepted-exception classification; normal, revealed/activated and already-associated highlighting remain required. C01-H's other release gates are unchanged.

### R01 — Research: `@Bindable` in ordinary authored `.gd`

**Related:** [issue #4](https://github.com/resistdesign/Estragon/issues/4). **Prerequisite:** none.

- Test stock Godot 4.7 parsing and available addon/editor pre-parse hooks with a minimal reproducible experiment.
- Write down *verified* results, source/code links, trade-offs and a recommendation for retaining the normal `.gd` editing experience.
- If true native-looking annotation handling is impossible through current public hooks, clearly state that limitation and **seek a user decision** before choosing an alternate extension or Godot fork. No speculative production preprocessor.
- Findings: [R01 report](BINDABLE_FEASIBILITY.md) and Godot-only `sh tools/check-bindable.sh`. Native setters and partial remaps work, but no complete supported ordinary `.gd`/native-editor path was found. Research completion did not authorize an alternate source extension. **The owner has since accepted lowercase `@bindable` in authored Gogo only (ADR-0013), so T09's source boundary is no longer blocked on ordinary `.gd` annotations.**

### R02 — Rendering backend research (deferred)

[Issue #2](https://github.com/resistdesign/Estragon/issues/2) remains a separate later research track. Do not hold the initial Gogo vertical slice hostage to `RenderingDevice` work or replace `RenderingServer` without measured evidence.

## Working with Codex

The implementation agent should be given a **work ID**, not a whole milestone. Example:

> Continue **N03** from the latest handoff on [issue #35](https://github.com/resistdesign/Estragon/issues/35). Read `AGENTS.md`, this plan and `docs/WORK_STATUS.md`; keep the T08 bridge working, use Godot-only tests, open one focused PR and leave a handoff. Do **not** merge.

A task begins by checking the *latest* main branch, its tracking issue, open PRs and the latest handoff. It ends with verified evidence and a durable handoff or an explicitly reviewed merge. See `AGENTS.md` for the required protocol.

## Changing the plan

- Task IDs are stable. Split large work by creating subtasks/issues with clear parent IDs; never silently redefine an existing ID or skip a dependency.
- Change acceptance criteria, dependencies, or sequencing via a focused reviewed PR updating this plan and the matching GitHub issue(s). Explain **why** and record any architectural decision in `DECISIONS.md`.
- Keep design direction separate from scheduling: a blocked or slow task does **not** authorize a different product architecture.
- GitHub issues/PRs hold **live execution state and session handoffs**; [WORK_STATUS.md](WORK_STATUS.md) is the concise, reviewed snapshot updated when plan/task completions land on `main`.
- Completing a task requires its acceptance tests and human-approved merged PR, not merely a Codex message that it is finished.

**Historical delivery queue (superseded by the operative ADR-0015 sequence above):** C01-A #42 → focused C01 work → T09-A #43 → T09-B/C/D #5. One open PR total, including drafts/docs/research; E01 #40 is merged. Future tasks remain issues until the current PR merges or closes; a blocked PR requires an owner decision, never a bypass PR.

### C01-E delivery and accepted compatibility contract

C01-D #59 merged at `bf2c426`; C01-E #48 merged in PR #60 at `c17902a`. The focused scope includes
semantic validation, relative paths and script/cache identity, plus the measured
cold Text-first dependency cycle. [Investigation evidence](C01_E_VALIDATION.md)
separates optional diagnostics from mandatory correctness. The owner explicitly distinguishes unavailable isolated preflight on 4.0–4.3
from mandatory actual-path transactional publication validation. Reports retain
BLOCKED isolated capability; no build may succeed without native validation and
rollback/recovery guarantees. See the live #48 decision and DECISIONS amendment.

C01-E's final nine-engine snapshot verifies native semantics, Counter, actual
registered/cached publication, dependency/inheritance updates, no-op freshness,
rollback/recovery and cold Text loading. Keep optional capability observations
and unrelated red editor/grammar stages separate. PR #66 and scoped helper PR #67 are merged; #61 is closed completed for that scope. Full raw-syntax/release acceptance remains separate under #51. C01-F #49 merged in PR #62 at `95efa45`. Its scoped acceptance is
actual native editor startup, saved-disk builds, filesystem/import recovery,
coalescing, clean enable/disable/re-enable and restart on every pinned engine.
See [C01_F_EDITOR.md](C01_F_EDITOR.md) and [C01_G_PLAY.md](C01_G_PLAY.md).
C01-G's native unsaved-buffer/Play bridge is merged; #44 filtered tabs and
#61 grammar remain separate. C01-H and T09 still require sequential
reviewed delivery; no automatic merges.

### C01-G unsaved-buffer delivery

C01-G #50 / PR #63 merged at `110c9b7`, after C01-F.
Use a synchronous native buffer identity/save/verification boundary before both
Play commands, preserving native semantic transactions and source/cache freshness.
[C01_G_PLAY.md](C01_G_PLAY.md) records the minimal capability bridge and exact
nine-engine editor/child-game evidence. Require actual newest unsaved foreground/
background execution with autosave off, pathless/unsavable/markup/semantic/type
failure blocking and repair, no-op outputs/maps/UIDs/timestamps and lifecycle
regressions. C01-H/#44/#61/T09 remained outside merged PR #63.
No physical/manual keypress gate. E01-F #44's accepted exception is closed and
PR #64 merged; C01-H #51 has a gate/distribution review slice; release remains blocked. See C01_H_RELEASE.md and the live issue for continuation.

### C01-H gate/distribution slice — review scope, release still blocked

C01-H #51 now has a focused release-gate/distribution implementation. See
[C01_H_RELEASE](C01_H_RELEASE.md) for actual two-engine evidence and preserved
failures. This slice corrects baseline project features and obsolete test
contexts, verifies fresh examples/UIDs/native graphics/resource packs, and
requires explicit matching source/engine artifacts for release assessment.
It does **not** complete C01-H or advance T09-A.

**Historical gate continuation, amended by ADR-0015:** PR #66 and scoped #61/PR #67 are merged.
Remaining release work includes #65, cold missing-generated-scene restoration and explicit
standalone-export/platform scope in separately reviewable steps under #51.
The strict gate remains blocking until their requirements are verified or an
explicit owner disposition is recorded; no new exception is assumed.
Only 4.0.4 + pinned 4.7.0 are authorized. No competing implementation PR,
automatic merge, Python, syntax reduction or intermediate-minor certification.

Owner-directed PR #66 follow-through separates development verification from
publishing authorization. Ordinary CI checks exact known-blocker expectations
and evidence integrity while retaining release BLOCKED; strict release mode
remains mandatory before publishing. This does not waive the serial #61/cold
scene/#65/export prerequisites or advance T09. See C01_H_RELEASE.md and #51.

### P02 — location-independent native addon and direct Yarn consumption

Owner-directed [#111](https://github.com/papercraftgames/Estragon/issues/111), after merged CI01 #110. Replace fixed internal resource roots and emitted dependency paths, preserve native transactions/UIDs, prove full-path editor activation outside addons on official Linux 4.0.4/pinned4.7.0, and replace copy/ignore consumer tests with direct Yarn plus nonstandard relocation/standard-path evidence. One review PR; no version change/publication/merge. Seven package stages aggregate all three layouts; all73 full certification stages and both post-publish registry consumers remain required. Routine checks retain their60-second budget. Exact evidence/handoff lives on #111/its sole PR; any engine limitation must be reported without copy/symlink workarounds.


## CI02 — bounded release cost (review task)

[#113](https://github.com/papercraftgames/Estragon/issues/113) updates the earlier CI01/P02 release-cost policy. Routine PR/main still require <=60s. Every owner-authorized release still requires exact-source tests on official Linux 4.0.4 and pinned 4.7.0, real direct Yarn package/editor/rendering acceptance, verified identical package bytes, OIDC and public-registry consumers. The former mandatory 73-stage two-engine, three-install-layout battery becomes an **explicit opt-in** regression tool, not a routine release or local-development requirement. Historical descriptions above capture what was required at the time; follow the current CI02 contract in [CI_PERFORMANCE](CI_PERFORMANCE.md) and live #113. No version bump, publication or merge in this task.

## E02 — native Gogo editor experience

[#115](https://github.com/papercraftgames/Estragon/issues/115), sole [PR #116](https://github.com/papercraftgames/Estragon/pull/116), extends the implemented editor with tolerant theme-aware GDScript/GGX highlighting, native contextual CodeEdit completion, authored-span gutter/panel diagnostics and a public Project > Tools creation dialog with working 2D/3D templates. Preserve transactional save/Play, stable UIDs, ordinary `.gd` services and #44's accepted hidden-tab exception. No LSP, engine extension, external compiler or runtime redesign.

Acceptance is a fresh direct Yarn stock editor with real menu/dialog/caret/popup insertion/undo, diagnostics/repair/navigation, multiple tabs/ordinary `.gd`, disable/re-enable/restart and actual main/current game execution plus invalid-source rollback. Focused template-only probes cover standard and nonstandard addon paths. Only official Linux 4.0.4 and pinned 4.7.0; focused development then bounded two-engine acceptance. The opt-in editor workflow does not expand routine <=60s CI or CI02's seven-stage release gate. No full 73-stage prerequisite, Docker, extra engine, version change, merge or publication. See [editor contract](EDITOR.md); live issue/PR carry checked results, limitations and handoff. E02 is not Done until owner review and merge.

## P04 — tag-authoritative packaged versions

[#119](https://github.com/papercraftgames/Estragon/issues/119) supersedes P01's source-version authority. The owner explicitly schedules this before pending editor release #117; merged #118 is not a release prerequisite. Git plugin metadata is development-only. Actual owner-published tags determine both staged Godot and npm versions before certification/hashing. Preserve exact-source plus narrowly authorized deterministic overlay verification, OIDC, previews, seven-stage direct Yarn proof on only official Linux 4.0.4/pinned 4.7.0, matching reproducible artifacts and both post-publish registry consumers. One implementation PR, focused tests and bounded readonly preview; routine <=60s unchanged. No merge, version-only bump, tag or publication during implementation. Live issue/sole PR hold checkpoints and final handoff; not Done before owner merge.

## E03 — component intelligence and explicit import acceptance

[#121](https://github.com/papercraftgames/Estragon/issues/121), after merged E02 #116 and P04 #120, adds installed-resource component discovery and synchronous explicit imports through the public CodeEdit acceptance virtual, plus honest native/highlighter/metadata reuse and resource paths. No magic tag remapping or separate analyzer/runtime. Reuse the focused editor harness for a blank direct-Yarn screen, native popup/import/undo/cancel/collision/live-buffer/lifecycle proof and actual rendered main/current Play. Standard/nonstandard locations get bounded import-path probes only. Record a two-engine capability table distinguishing native delegation from metadata fallback. Keep routine <=60s, only official Linux 4.0.4/pinned 4.7.0, no Docker/full 73-stage requirement, version bump, tag, publication or release-flow change. One review PR and durable handoff; not Done before owner review/merge.
