# Roadmap and milestones

All milestone statuses below describe *project work*, not a claim of features available today. **For the actionable Codex work breakdown, dependencies, completion gates, issue links and cross-session handoff workflow, use [EXECUTION_PLAN.md](EXECUTION_PLAN.md), [WORK_STATUS.md](WORK_STATUS.md) and [AGENTS.md](../AGENTS.md).** This file is the wider product roadmap, not a live task tracker.

## Immediate direction: Gogo-to-GDScript and real runtime components

**Accepted product direction (2026-10-26):** Gogo should mix GDScript and unprefixed XML-like component expressions **like TSX**; it transpiles to GDScript that constructs Estragon components and connects signals. The JSON demo is temporary scaffolding. See [the design direction](DESIGN_DIRECTION.md).

- [ ] Prototype a GDScript-aware Gogo parser handling nested components, typed expression props and code/markup interleaving, with useful source locations.
- [ ] Emit deterministic **runnable GDScript** from a minimal `.gogo` hybrid source (not runtime JSON interpretation).
- [ ] Implement independent `DisplayObject`-like and `Container`-like runtime bases, avoiding naming collisions with Godot's built-in `Container` class.
- [ ] Implement responsive `VBox` and `HBox` layout using Estragon-owned objects rather than Godot `Control`/`Container` nodes.
- [ ] Compile typed component properties/refs and automatic signal handler connections.
- [ ] Give Godot 4.7 an editor surface that understands the mixed grammar, compilation errors, and source maps; integrate transpilation before Run.
- [ ] Investigate `@Bindable` inside **ordinary authored `.gd`** at the actual Godot parser boundary; record proof or explicitly evaluated fallbacks.
- [ ] Prototype code-first mixed markup/GDScript first; evaluate optional markup-only shorthand and separate code-behind second.
- [ ] Replace stage-0 JSON runtime only after the Gogo → generated `.gd` → Estragon runtime → Godot rendering vertical slice passes tests.

**Exit condition:** author a mixed `.gogo` component, compile it to valid GDScript, render a nested/resizing layout, and invoke a generated signal connection without manually wiring Godot GUI nodes or editing generated source.


## P0 — Foundation (this scaffold)

- [x] Record the vision: independent UI engine, no `Control`-based runtime.
- [x] Name Estragon + Gogo (`.gogo`).
- [x] Implement stage-0 Gogo parser to standalone versioned IR.
- [x] Check in a low-level `RenderingServer` rectangle rendering example.
- [x] Establish compiler tests and CI configuration.
- [x] Capture architecture, binding and editor strategy.
- [ ] Verify Godot demo visually on supported desktop platforms.
- [x] Select and document a project license (MIT; see [LICENSE](../LICENSE)).

## P1 — Independent component runtime

- [ ] Design retained component objects and reconciliation, without a Godot node per component.
- [ ] Introduce a renderer-independent display list and invalidation flags.
- [ ] Separate the experimental `RenderingServer` adapter from the component runtime.
- [ ] Add component identity, lifecycle hooks and deterministic test fixtures.
- [ ] Build a measurement/layout engine (including nested containers and constraints).
- [ ] Add scene-independent runtime unit tests and rendering snapshots.

**Exit condition:** updating an Estragon component relayouts/repaints only necessary regions; no Godot `Control` node or stock `Container` participates.

## P2 — Useful pixels and interaction

- [ ] Text/glyph shaping, font resources/fallback and DPI scaling strategy.
- [ ] Styling, images, clipping and stacking/compositing.
- [ ] Estragon-owned event dispatch, pointer hit testing and hover/pressed state.
- [ ] Keyboard focus, navigation, IME, touch, scroll and accessibility design.
- [ ] A genuine button/text field example built from Estragon components.

**Exit condition:** a small interactive UI is fully owned and rendered by Estragon.

## P3 — Compiler-assisted reactivity

- [ ] Prove a native-looking `@Bindable` source transformation path for ordinary `.gd` files (or record an explicitly approved alternative).
- [ ] Produce observable model properties and test notifications.
- [ ] Parse and validate binding expressions in Gogo.
- [ ] Handle nested dependencies, two-way bindings and observable collections.
- [ ] Integrate state changes with layout/paint invalidation.

**Exit condition:** a model update changes pixels without manually wiring signals.

## P4 — Native-feeling authoring

- [ ] Mixed Gogo/GDScript syntax highlighting and reliable `.gogo` file association.
- [ ] Diagnostics, completion, component/property checking and source maps.
- [ ] Automatic Gogo-to-GDScript transpilation and error-gated run/build.
- [ ] Live renderer preview and editor component inspector.
- [ ] Examples and end-to-end developer onboarding.

## P5 — GPU backend investigation and hardening

- [ ] Benchmark `RenderingServer` against a suitable `RenderingDevice`/native approach.
- [ ] Implement reusable batching, glyph atlas and composition strategy.
- [ ] Verify platform/render-method compatibility and fallback.
- [ ] Profiling, instrumentation, regression tests, documentation and API stabilization.

**Sequencing can change as experiments reveal constraints.** In particular, prototype graphics/text and editor integration early to catch fundamental feasibility issues.

## Definition of done for features

A feature requires documented behavior, automated tests appropriate to its layer, evidence that it does not silently reintroduce `Control`-based rendering, and a reproducible demo. Unsupported syntax must yield a clear error rather than a half-working UI.
