# AGENTS.md — Working on Estragon

> Repository-wide instructions for AI coding agents and automated contributors. Read this before editing code or opening a PR. These instructions describe the **current repository**, not an imaginary finished framework.

## Mission

**Estragon is an independent, self-rendered UI engine hosted by Godot.** Its declarative language is **Gogo** (`.gogo`), inspired by the authoring ergonomics of Adobe Flex 3/4. Gogo builds *Estragon* components—not Godot widgets or scene nodes.

The long-term direction is a compiler, independent retained component tree, reactive dependency graph, layout/input/paint systems, and pluggable renderer. **The present code is a stage-0 proof of concept**, not that completed stack.

```text
.gogo source → strict Gogo compiler → versioned Estragon JSON IR
                                            ↓
                         Godot host Node → RenderingServer canvas
```

The current host reads precompiled IR and renders fixed rectangles directly. The retained runtime and display-list abstraction in the architecture documents are **planned**, not implemented.

## Non-negotiable architecture

1. **Own the UI.** Never implement Gogo by generating Godot `Control`, `Container`, `Label`, `Button`, or `.tscn` widget trees. Do not delegate Estragon's application layout, styling, hit testing, focus, or visual semantics to Godot's GUI system.
2. **No node per component.** Estragon components must not require a corresponding Godot `Node` or `CanvasItem`. A small Godot host, multiple surfaces, and optional integration adapters are acceptable; they must not define the UI model.
3. **Separate the layers.** Keep parsing, validation, typed/serialized IR, component identity, bindings, layout, input, paint/display lists, and renderer backends independently testable. Do not bake Godot APIs into the Gogo compiler or its IR.
4. **Compile and validate source.** Gogo is compiled ahead of rendering. No per-frame XML parsing, implicit Godot widget fallback, silently ignored attributes, or runtime interpretation of unsupported syntax.
5. **Choose graphics backends with evidence.** `RenderingServer` is the existing prototype backend, **not** an irreversible architecture decision. `RenderingDevice`, shaders, batching, and native extensions remain research topics. Keep backend-specific code behind clear boundaries.
6. **Reactivity must be real.** If implementing bindings, use dependency tracking and scoped subscriptions, not frame-by-frame expression polling or manual signal glue imposed on each consumer.
7. **Keep the editor exception clear.** Godot `Control` nodes are fine for *editor tooling UI*; they are not a substitute for Estragon's runtime renderer or application preview.
8. **Do not change accepted decisions by accident.** Read `docs/DECISIONS.md`. Treat provisional proposals as open questions; propose a focused decision instead of quietly redefining the architecture.

## Reality check: what exists today

**Implemented:**

- `tools/gogo.ts`: strict, namespace-aware TypeScript Gogo compiler and deterministic JSON IR generator, executed with Bun.
- A `View` document root containing zero or more `Rect` leaves at explicit canvas coordinates; no nested containers or component registry.
- `addons/estragon/runtime/gogo_view.gd`: a single Godot host `Node` drawing rectangles via `RenderingServer.canvas_item_add_rect()`.
- A checked-in Gogo example plus generated IR, Bun test coverage, strict TypeScript typechecking, and GitHub Actions compiler checks.
- An optional editor plugin that registers `.gogo` as an editable text extension.

**Not implemented:**

- A retained component runtime, reconciliation, generalized layout, styling, text widgets, events, focus, accessibility, or interactive controls.
- `@bindable` compilation, one-/two-way Gogo bindings, observable collections, or a dependency graph.
- A `.bgd` frontend, Gogo language server, syntax highlighting, live preview, automatic compile-on-save, or a `RenderingDevice` backend.

Do not write new examples, PR descriptions, or documentation that imply these proposed capabilities already work. `docs/ROADMAP.md` and tracking issues describe **desired outcomes**, not shipped behavior.

## Repository map

| Path | Responsibility |
| --- | --- |
| `tools/gogo.ts` | Source parsing, strict validation, canonical IR generation, CLI |
| `tests/gogo.test.ts` | Compiler behavior, negative cases, and checked-in example consistency |
| `examples/hello/Main.gogo` | Authoritative source for the stage-0 demo |
| `examples/hello/generated/Main.gogo.json` | Generated, versioned example IR; checked into Git |
| `addons/estragon/runtime/gogo_view.gd` | Experimental Godot host and low-level drawing |
| `examples/hello/Hello.tscn`, `project.godot` | Minimal Godot application host |
| `addons/estragon/editor/` | Optional text-extension registration only |
| `docs/GOGO_LANGUAGE.md` | Implemented Gogo subset vs speculative syntax |
| `docs/ARCHITECTURE.md`, `docs/VISION.md` | System boundaries and direction |
| `docs/BINDING.md`, `docs/EDITOR.md` | Planned reactivity and editor work |
| `docs/DECISIONS.md`, `docs/ROADMAP.md` | Accepted/provisional decisions and milestones |
| `docs/TESTING.md`, `CONTRIBUTING.md` | Verification and contribution standards |
| `Assets/` | Project-owned visual/source assets; preserve originals |

## How to approach a task

1. **Inspect first.** Read the affected source, tests, corresponding docs, and any relevant open issue. Read `docs/VISION.md`, `docs/ARCHITECTURE.md`, and `docs/DECISIONS.md` before making structural changes.
2. **Classify the work.** Is this a change to the implemented stage-0 contract, an experiment, or a proposed future capability? Say which; do not collapse those categories.
3. **Make the smallest coherent change.** Follow the user's actual request. Avoid unrelated refactors, speculative scaffolding, extra documentation, dependency churn, or changes to supplied assets.
4. **Preserve a working vertical slice.** Source, compiled IR, Godot consumer, tests, and docs must agree whenever their shared contract changes.
5. **Verify and report accurately.** Run the relevant checks; name checks you could not run. Never say a Godot runtime behavior was tested when only compiler tests ran.

Use ordinary engineering judgment for routine implementation details. Surface genuinely undecided architectural choices rather than assuming approval for a new language, backend, engine fork, or incompatible IR format.

## Stage-0 Gogo contract (do not break accidentally)

- All component tags must resolve to XML namespace `urn:estragon:gogo:1` (the prefix itself is arbitrary).
- Exactly one root `View`; required `width` and `height` are finite positive numbers; optional `id`.
- Only `Rect` leaves below `View`; required positive finite `width` and `height`, required `fill`; optional finite `x` and `y` default to `0`; optional `id`.
- IDs are unique and nonblank. Text content, unknown elements/attributes, nested `View`, and children of `Rect` are rejected.
- Colors accept `#RRGGBB` or `#RRGGBBAA`, normalized to lowercase `#rrggbbaa` (opaque alpha added when omitted).
- Invalid input raises `GogoError` with a useful diagnostic. Do not turn an error into a warning or silent default without an explicit specification change.
- IR currently uses `format: "estragon.gogo.ir"`, `version: 1`, and a `root` object with `type`, `props`, optional `id`, and `children` where applicable. The JSON emitter is deterministic and ends with a newline.
- IR is **not** a Godot `PackedScene` and should not include a Godot node type for every UI element.

If an IR change is incompatible, deliberately define/version the new contract and update its compiler, consumer, fixtures, tests, and docs **together**. Do not simply mutate version 1 and hope old consumers still work.

## Area-specific implementation rules

### Gogo compiler and language

- Work in `tools/gogo.ts` and `tests/gogo.test.ts`; keep the compiler independent of the running Godot editor.
- Preserve strict schema/type validation and deterministic output. Test both valid examples and malformed/unsupported input.
- Prefer minimal, pinned dependencies; use strict TypeScript types and a real namespace-aware XML parser. Keep the compiler independent of Godot.
- For syntax changes, update `docs/GOGO_LANGUAGE.md`, any example `.gogo`, and checked-in generated IR. Mark proposed syntax as non-executable until it actually compiles.
- Do not implement expressions with JavaScript `eval`, `new Function`, ad-hoc string substitution, or regex rewriting of GDScript. Parser/source-location and type semantics matter.

### Runtime, components, and rendering

- Keep logical UI state independent of the host `Node` and graphics API. New component/display-list systems should be testable without creating a Godot scene tree.
- The current host allocates one `RenderingServer` canvas RID, clears it before redraw, and frees it in `_exit_tree()`. Preserve resource ownership and cleanup.
- Treat `RenderingServer` as a backend adapter. Do not spread direct canvas calls through future layout/binding/component layers.
- Do not introduce one node or RID per logical component as an unquestioned default; justify representation and performance tradeoffs with measurements.
- For visual/runtime changes, include a repeatable Godot smoke test. A green compiler CI run does not prove rendering works.

### Reactive state (future work)

- `@bindable` in ordinary stock `.gd` is **not supported**. `.bgd` is only a proposed source-transformation approach; a Godot fork is not the default.
- Before implementation, establish observable-property semantics, typed setters, initialization/equality behavior, and inheritance/custom-accessor behavior.
- Account for nested path replacement, subscriptions and disposal, collection mutation, cycles, two-way feedback protection, and batched invalidation.
- Keep observable models usable without inheriting from a Godot `Node`. Test state changes independently from drawing.

### Editor integration (future work)

- The existing plugin only adds `gogo` to `docks/filesystem/textfile_extensions`. It does not compile, highlight syntax, provide diagnostics, or preview anything.
- That editor setting is **global and persists after disabling the plugin**. Never erase existing values, force-enable the plugin, or silently change someone's editor configuration in a test.
- Keep editable `.gogo` source accessible; do not replace it with imported `.tscn` widget trees.
- Source diagnostics and previews must ultimately come from the Gogo compiler and Estragon renderer, respectively.

### Documentation, examples, and assets

- Distinguish **implemented**, **experimental**, **proposed**, and **unverified** claims. Update docs only where behavior or a decision actually changed.
- Preserve original user-supplied assets byte-for-byte unless the requested task explicitly calls for transforming them.
- Do not add policy essays, attribution pages, reexports, or new asset organization that the user did not request.
- A settled design choice belongs in `docs/DECISIONS.md`; a speculative idea belongs in a proposal or issue, not silently in the supported language contract.

## Verification commands (repository root)

Bun 1.4.4 runs the TypeScript compiler and tests. The present automated checks do **not** require Godot:

```sh
bun install --frozen-lockfile
bun run typecheck
bun run test
bun run verify:ir
```

When intentionally changing the example, regenerate the committed IR from its source, then rerun the checks:

```sh
bun run gogo examples/hello/Main.gogo --output examples/hello/generated/Main.gogo.json
```

For Godot-facing changes, also perform or explicitly request a **manual Godot 4.x visual smoke check**: open the root `project.godot`, run `examples/hello/Hello.tscn`, confirm the dark background, purple block, and teal stripe, and inspect the remote scene tree for one Estragon host rather than per-element widgets. If you cannot run Godot, say **not tested** rather than claiming success.

GitHub Actions (`.github/workflows/ci.yml`) typechecks TypeScript, runs Bun tests, and verifies the example IR is up to date; it does **not** run Godot or certify visuals.

## Definition of done / PR hygiene

Before calling work complete, check:

- [ ] The change matches the user's request and does not introduce unrelated churn.
- [ ] The independent-component / self-rendered architecture remains intact.
- [ ] Existing implemented behavior is preserved, or a deliberate compatibility change is described.
- [ ] New behavior has positive, negative, and edge-case tests where appropriate.
- [ ] Example source and committed IR agree whenever either changes.
- [ ] Relevant documentation states what really works, without promoting proposals to features.
- [ ] The exact commands run and their results are reported; manual/runtime checks not run are called out.
- [ ] The PR has a concise purpose, change summary, verification, and any open design or compatibility questions.

Prefer a focused, reviewable PR over a sweeping rewrite. Do not merge it yourself unless explicitly requested. Avoid false confidence, unrequested side quests, and work that merely *looks* complete.

## Source of truth

- **Implemented behavior:** the relevant source code and passing tests.
- **Accepted architecture:** `docs/VISION.md`, `docs/ARCHITECTURE.md`, and accepted entries in `docs/DECISIONS.md`.
- **Language specification:** `docs/GOGO_LANGUAGE.md` (read its supported/proposed labels).
- **Planned work:** `docs/ROADMAP.md`, `docs/BINDING.md`, `docs/EDITOR.md`, and open issues.
- **Contributing and verification:** `CONTRIBUTING.md` and `docs/TESTING.md`.

If sources disagree, do not paper over the discrepancy. Identify whether it is a code bug, documentation drift, or an unresolved design decision, and resolve only what the task authorizes.
