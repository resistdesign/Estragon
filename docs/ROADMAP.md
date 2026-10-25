# Roadmap and milestones

All milestone statuses below describe *project work*, not a claim of features available today.

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

- [ ] Decide source transformation vs GDScript engine support for `@bindable`.
- [ ] Produce observable model properties and test notifications.
- [ ] Parse and validate binding expressions in Gogo.
- [ ] Handle nested dependencies, two-way bindings and observable collections.
- [ ] Integrate state changes with layout/paint invalidation.

**Exit condition:** a model update changes pixels without manually wiring signals.

## P4 — Native-feeling authoring

- [ ] Gogo syntax highlighting and reliable file association.
- [ ] Diagnostics, completion, component/property checking and source maps.
- [ ] Automatic compilation and error-gated run/build.
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
