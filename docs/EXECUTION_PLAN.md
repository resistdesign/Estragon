# Estragon execution plan — Codex-sized delivery

**Plan version:** 3, 2026-10-29. **Status:** active. T01–T08 are merged (#29), as is the native planning PR #31. The highest priority immediately after T08 is **N01 → N02 → N03: native Godot Gogo compilation**, before T09/T10. N01 (#32) and N02 (#34) are merged; N03 is merged in PR #36 (`a87c33b`), providing direct native editor compilation validated by fresh-project no-tools Play/restart tests. R01 provides feasibility evidence; the ordinary `.gd` annotation integration awaits an explicit owner decision. This is the *delivery plan*; [DESIGN_DIRECTION.md](DESIGN_DIRECTION.md) and [DECISIONS.md](DECISIONS.md) define product direction. [ROADMAP.md](ROADMAP.md) remains the broader, non-sequential product roadmap. **Live progress and handoffs** are managed under [WORK_STATUS.md](WORK_STATUS.md) and GitHub issues/PRs.

## Outcome: an actual Gogo UI in Godot

The first integrated milestone (T01–T08, **transitionally Bun-powered**) is an interactive `Counter.gogo` running in Godot 4.7:

1. A developer authors one `.gogo` file combining GDScript methods/state and **unprefixed** component markup (e.g., `<VBox>`, `<Text>`, `<Button>`), with typed GDScript expressions and a callback.
2. The Bun/strict TypeScript toolchain transpiles it deterministically into valid, inspectable `.gd`. It resolves components, checks properties/events and generates signal connections. No runtime JSON UI parsing.
3. The generated code instantiates Estragon's own component objects. Layout (including `VBox`/`HBox`) responds to viewport resizing; components render through Estragon's Godot low-level graphics adapter. No Godot `Control` widgets or per-component `Node`.
4. A click invokes the generated handler and visibly updates the counter. The initial demo may use explicit state invalidation **until** the separate binding work is complete; do not mislabel it reactive.
5. The Godot editor recognizes Gogo, automatically transpiles before Run and clearly reports failures against the authored source. Failed builds must not run stale generated code.
6. CI covers strict TypeScript tests and actual Godot script/runtime checks; a documented visual check covers what headless CI cannot prove.

**Not required to claim this first milestone:** completed `@Bindable` support in ordinary authored `.gd`; full JSX grammar, full Flex compatibility, a complete component suite, sophisticated graphics backends, or polished visual editor. Those follow independent evidence and reviews.


## Immediate priority: native Gogo compilation inside Godot (ADR-0012)

**Accepted owner decision, 2026-10-28:** A developer using Estragon in Godot must need **only Godot and the bundled Estragon addon**. **No Bun/Node/TypeScript installation or compiler executable configuration for editing, building, or running Gogo.** T08 originally used Bun as a **temporary bridge**; N03 replaces it with the bundled native compiler/validator. The owner has manually verified T08 by changing Counter.gogo's font size and rerunning the scene in Godot. That successful test triggers this priority shift.

Write the production compiler **in GDScript, bundled in the addon**. It should work without editor UI state, external processes, runtime JSON interpreters, one Godot Node/Control per component, GDExtension binaries, or Godot forks. Keep parsing, typed validation, code emission and source mapping separate from rendering and editor presentation. Preserve the accepted TSX-like GDScript + unprefixed markup language, evaluation order and generated signal behavior.

**Next three reviewable PRs:**

1. **N01:** native GDScript lexer/parser, typed model, validation and source-located diagnostics; parity cases for the existing hybrid grammar and callback/prop contract.
2. **N02:** native GDScript emitter and source maps; preserve T04–T07 language semantics and prove a generated interactive Counter executes in Godot. Differential parity against the TypeScript reference where useful.
3. **N03:** switch editor save/build and both Play modes from Bun to **direct native compilation**. Eliminate user-facing Bun executable settings and subprocesses, preserve source discovery, diagnostics, pre-Play checks and recovery, and demonstrate a **fresh Godot-only installation with Bun absent**.

**Acceptance gate for N03:** Fresh Godot 4.7 project + Estragon addon + Gogo sources; with Bun/Node unavailable (no PATH or configured executable), edit Gogo, press F5 and F6, and run the latest generated code. Deliberately break Gogo and prove both Play modes refuse stale output; repair it and confirm recovery. Run actual Godot-native tests without Bun. Bundled addon must work independently of the repository's optional development dependencies.

**Preserve the working T08 bridge until N03 is demonstrably ready.** Do not delete the current compiler, tests or generated fixtures prematurely. Bun/TypeScript may remain as **optional CI/reference/differential tooling** after cutover; there must be no silent Bun fallback in the editor. T09 reactive bindings and T10 legacy retirement are postponed until N03 passes. R01 may be researched independently and does not block this migration. One focused PR, tests, linked issue and durable handoff per task.

## Architectural constraints and review gates

- Gogo is **TSX-like GDScript + XML-like markup**, transpiled to **GDScript**. No mandatory XML namespaces (`<fx:VBox>` / `xmlns`), no TypeScript/JavaScript embedded in Gogo.
- Implement a real parser/typed representation with source positions; no regex replacement of mixed syntax or GDScript.
- Preserve the functioning **stage-0 namespaced XML → JSON demo** until a GDScript-generated equivalent is running and tested. Do not build the new architecture around the old JSON contract.
- Estragon owns component identity/lifecycle, layout, signals, input and painting. A Godot host is allowed; one Godot node or Control per UI component is not.
- Generated code is not hand-maintained. It must be deterministic, validated by Godot, and traceable to its authored Gogo source.
- Each task below is a **reviewable PR** with tests, documentation and evidence appropriate to its scope. Do not merge on behalf of the user without explicit permission.
- **Gate to start a dependent task:** the prerequisite is merged or the user explicitly authorizes isolated parallel development with a documented shared interface. Research `R01` is independent and may run alongside `T01`.
- If an acceptance criterion proves infeasible, record evidence and a blocker in the issue, propose options, and **stop rather than quietly change the product requirements**.

## Dependency map

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
                       T09 bindings (+R01)   T10 legacy JSON retirement
R01 @Bindable-in-.gd research: independent, informs T09
R02 graphics research: deferred
~~~

This is the preferred *merge order*, not a request to implement everything in one PR. With explicit coordination, compiler/runtime spikes may run on isolated branches in parallel after interface agreement; record that agreement in issues and do not silently stack dependent PRs.

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

### T09 — Observable properties and Gogo bindings

**Related:** [issue #5](https://github.com/resistdesign/Estragon/issues/5). **Prerequisites:** **N03 merged** and reviewed R01 findings plus an explicit owner decision on the unsupported ordinary `.gd` annotation path. **E01 #37 must land before T09's final integrated authoring milestone.**

- Implement a minimal correctly scoped observable-property contract and generated Gogo dependency updates, including cleanup and no per-frame polling.
- Prove that a change to a model property updates a visible Estragon component; test nested dependency replacement, disposal, and feedback/cycle failure behavior before expanding to two-way/collection support.
- **Do not claim `@Bindable` works in ordinary `.gd` unless R01 proves a supported implementation path.** If the requested syntax cannot be met, split/stop the blocked annotation integration and seek a decision rather than quietly requiring `.bgd` or manual setters.

### T10 — Retire the legacy JSON prototype safely

**Prerequisites:** **N03 merged** and verified parity for the old example. T09 is not a prerequisite to replacing the legacy rectangle example.

- Convert/replace the old sample with the new generated-GDScript pipeline and prove matching or improved rendering, CI and local editor behavior.
- Remove obsolete JSON runtime parsing/fixtures/commands only when no active consumer depends on them; update docs/tests/AGENTS together.
- Do not delete an otherwise useful example until a working replacement is merged.

### E01 — Automatic Gogo highlighting activation (separate editor fix)

**Tracking:** [issue #37](https://github.com/resistdesign/Estragon/issues/37). **Prerequisite:** N03 merged. **Schedule:** R01 is merged in #38; E01 is the focused editor fix before T09-A. T09 architecture remains in live #5 and open docs PR #39; do not mix it into E01.

- Reproduce the owner-confirmed restored-tab activation bug; prove automatic selection for new, existing and restored Gogo tabs, disable/re-enable and restart. Preserve unrelated user settings.
- Extend the real isolated editor tests to inspect actual highlighter attachment/colors without manual selection. Deliver a separate focused PR; no R01 implementation scope.
- E01 delivery: deferred exact-path association after tab creation/restoration and plugin enablement; Godot-only regressions seed persisted Plain Text state and check new/already-open/restored tabs, token colors, non-Gogo preservation and clean re-enable. Exact CI/checkpoints/handoff remain in #37 and its PR.

### R01 — Research: `@Bindable` in ordinary authored `.gd`

**Related:** [issue #4](https://github.com/resistdesign/Estragon/issues/4). **Prerequisite:** none.

- Test stock Godot 4.7 parsing and available addon/editor pre-parse hooks with a minimal reproducible experiment.
- Write down *verified* results, source/code links, trade-offs and a recommendation for retaining the normal `.gd` editing experience.
- If true native-looking annotation handling is impossible through current public hooks, clearly state that limitation and **seek a user decision** before choosing an alternate extension or Godot fork. No speculative production preprocessor.
- Findings: [R01 report](BINDABLE_FEASIBILITY.md) and Godot-only `sh tools/check-bindable.sh`. Native setters and partial remaps work, but no complete supported ordinary `.gd`/native-editor path was found. Research completion does not authorize a source-extension or syntax replacement. T09 annotation integration remains gated on owner decision.

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
