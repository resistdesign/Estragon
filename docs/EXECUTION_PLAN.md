# Estragon execution plan — Codex-sized delivery

**Plan version:** 1, 2026-10-26. **Status:** planned, not implemented. This is the *delivery plan*; [DESIGN_DIRECTION.md](DESIGN_DIRECTION.md) and [DECISIONS.md](DECISIONS.md) define product direction. [ROADMAP.md](ROADMAP.md) remains the broader, non-sequential product roadmap. **Live progress and handoffs** are managed under [WORK_STATUS.md](WORK_STATUS.md) and GitHub issues/PRs.

## Outcome: an actual Gogo UI in Godot

The first integrated milestone is a small interactive `Counter.gogo` running in Godot 4.7:

1. A developer authors one `.gogo` file combining GDScript methods/state and **unprefixed** component markup (e.g., `<VBox>`, `<Text>`, `<Button>`), with typed GDScript expressions and a callback.
2. The Bun/strict TypeScript toolchain transpiles it deterministically into valid, inspectable `.gd`. It resolves components, checks properties/events and generates signal connections. No runtime JSON UI parsing.
3. The generated code instantiates Estragon's own component objects. Layout (including `VBox`/`HBox`) responds to viewport resizing; components render through Estragon's Godot low-level graphics adapter. No Godot `Control` widgets or per-component `Node`.
4. A click invokes the generated handler and visibly updates the counter. The initial demo may use explicit state invalidation **until** the separate binding work is complete; do not mislabel it reactive.
5. The Godot editor recognizes Gogo, automatically transpiles before Run and clearly reports failures against the authored source. Failed builds must not run stale generated code.
6. CI covers strict TypeScript tests and actual Godot script/runtime checks; a documented visual check covers what headless CI cannot prove.

**Not required to claim this first milestone:** completed `@Bindable` support in ordinary authored `.gd`; full JSX grammar, full Flex compatibility, a complete component suite, sophisticated graphics backends, or polished visual editor. Those follow independent evidence and reviews.

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
T01 Godot CI/test harness
  └─ T02 Independent component bases
      └─ T03 VBox/HBox + rectangle layout/paint
          └─ T04 Unprefixed markup → runnable GDScript
              └─ T05 TSX-like GDScript/markup parser
                  └─ T06 Minimal Text/Button + input events
                      └─ T07 Generated signal wiring + Counter.gogo
                          ├─ T08 Editor build/run integration
                          │    └─ T10 Retire legacy JSON (also requires feature parity)
                          └─ T09 Observable binding integration
R01 @Bindable-in-.gd feasibility ─────────────┘ (informs T09, not T01–T08)
R02 GPU backend investigation (deferred; not a blocker for first milestone)
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

**Prerequisite:** T04.

- Support a *minimal, specified* `.gogo` hybrid: authored GDScript members/functions plus nested component expressions and braces holding GDScript value expressions.
- Test strings containing angle brackets, comparisons vs tags, nested braces, indentation, property types and malformed source. Preserve original source locations in diagnostics and generated-to-source mappings.
- Produce compilable `.gd` with tests and Godot headless validation. Record accepted grammar trade-offs in language docs/decisions.
- Keep the feature slice narrow; do not promise full TSX syntax, React behavior or arbitrary GDScript reflection.

### T06 — Minimal interactive primitives and input dispatch

**Related:** [issue #3](https://github.com/resistdesign/Estragon/issues/3). **Prerequisite:** T05 (may be independently prototyped after T03 with explicit coordination).

- Add only the foundational text display, button hit-testing/pointer dispatch, click signal and necessary layout/paint invalidation to support a small counter.
- Demonstrate basic text and pointer handling in Godot tests and a visual smoke test. Do not route application events through Godot's `Control` GUI.
- No full TextInput, touch gestures, accessibility, styling or general-purpose widget catalog in this PR.

### T07 — Compiler-generated signal wiring and first interactive demo

**Prerequisites:** T05 and T06.

- Support typed event/callback attributes, generate handler references/adapters and signal connections automatically in the resulting `.gd`, and verify handler signatures and lifecycle/disposal.
- Ship a **real mixed-source `Counter.gogo` demo**: click button → GDScript handler runs → visible counter changes. Explicit refresh is acceptable before T09 and must be documented.
- Test invalid handler names/signatures, no duplicate connections, and functioning Godot runtime. **This is the primary first-vertical-slice gate.**

### T08 — Godot editor language and compile-before-run integration

**Related:** [issue #6](https://github.com/resistdesign/Estragon/issues/6). **Prerequisite:** T07.

- Prove in Godot 4.7 that `.gogo` opens with useful mixed-language syntax highlighting and source-mapped diagnostics. Establish a source editor path that can grow to completion/navigation.
- Automate generation of `.gd` before running a project and clearly fail rather than executing stale compiled code; preserve authored source and existing editor settings.
- Test editor/build hooks and document the exact integration limitations. Completion, visual designers and polished live preview may be follow-up tasks, not false acceptance claims.

### T09 — Observable properties and Gogo bindings

**Related:** [issue #5](https://github.com/resistdesign/Estragon/issues/5). **Prerequisites:** T07 and findings of R01.

- Implement a minimal correctly scoped observable-property contract and generated Gogo dependency updates, including cleanup and no per-frame polling.
- Prove that a change to a model property updates a visible Estragon component; test nested dependency replacement, disposal, and feedback/cycle failure behavior before expanding to two-way/collection support.
- **Do not claim `@Bindable` works in ordinary `.gd` unless R01 proves a supported implementation path.** If the requested syntax cannot be met, split/stop the blocked annotation integration and seek a decision rather than quietly requiring `.bgd` or manual setters.

### T10 — Retire the legacy JSON prototype safely

**Prerequisites:** T07, T08, and tested feature parity for the old example. T09 is not a prerequisite to replacing the *legacy rectangle* example.

- Convert/replace the old sample with the new generated-GDScript pipeline and prove matching or improved rendering, CI and local editor behavior.
- Remove obsolete JSON runtime parsing/fixtures/commands only when no active consumer depends on them; update docs/tests/AGENTS together.
- Do not delete an otherwise useful example until a working replacement is merged.

### R01 — Research: `@Bindable` in ordinary authored `.gd` (parallel)

**Related:** [issue #4](https://github.com/resistdesign/Estragon/issues/4). **Prerequisite:** none.

- Test stock Godot 4.7 parsing and available addon/editor pre-parse hooks with a minimal reproducible experiment.
- Write down *verified* results, source/code links, trade-offs and a recommendation for retaining the normal `.gd` editing experience.
- If true native-looking annotation handling is impossible through current public hooks, clearly state that limitation and **seek a user decision** before choosing an alternate extension or Godot fork. No speculative production preprocessor.
- May be researched in parallel with T01–T07; findings inform the T09 contract and editor roadmap.

### R02 — Rendering backend research (deferred)

[Issue #2](https://github.com/resistdesign/Estragon/issues/2) remains a separate later research track. Do not hold the initial Gogo vertical slice hostage to `RenderingDevice` work or replace `RenderingServer` without measured evidence.

## Working with Codex

The implementation agent should be given a **work ID**, not a whole milestone. Example:

> Work on **T01**, using [issue #13](https://github.com/resistdesign/Estragon/issues/13). Read `AGENTS.md`, `docs/EXECUTION_PLAN.md` and `docs/WORK_STATUS.md`, follow the issue/PR progress and handoff process, open one focused PR, and do **not** merge.

A task begins by checking the *latest* main branch, its tracking issue, open PRs and the latest handoff. It ends with verified evidence and a durable handoff or an explicitly reviewed merge. See `AGENTS.md` for the required protocol.

## Changing the plan

- Task IDs are stable. Split large work by creating subtasks/issues with clear parent IDs; never silently redefine an existing ID or skip a dependency.
- Change acceptance criteria, dependencies, or sequencing via a focused reviewed PR updating this plan and the matching GitHub issue(s). Explain **why** and record any architectural decision in `DECISIONS.md`.
- Keep design direction separate from scheduling: a blocked or slow task does **not** authorize a different product architecture.
- GitHub issues/PRs hold **live execution state and session handoffs**; [WORK_STATUS.md](WORK_STATUS.md) is the concise, reviewed snapshot updated when plan/task completions land on `main`.
- Completing a task requires its acceptance tests and human-approved merged PR, not merely a Codex message that it is finished.
