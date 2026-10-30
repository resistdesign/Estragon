# Bindable properties and reactivity

**Status: planned; owner-approved source boundary 2026-10-29.** Only `@bindable` (lowercase) in **authored `.gogo`** is an accepted annotation. Ordinary authored `.gd` remains normal GDScript; it must not contain a custom Estragon annotation. The prior `@Bindable`-in-`.gd` direction is superseded by [ADR-0013](DECISIONS.md). [R01 research](BINDABLE_FEASIBILITY.md) is retained as evidence explaining why native Godot 4.7 did not support the old proposal. No observable property transformation or reactive binding is implemented yet.

Read the [T09 implementation contract](REACTIVITY_PLAN.md) for accepted goals, staging and tests, and the [live umbrella issue #5](https://github.com/resistdesign/Estragon/issues/5) for work status. Source examples below are **proposed, not executable**.

## Gogo authoring

A model may be a **code-only `.gogo` module**, not just a visual component:

```gdscript
# Player.gogo (proposed)
class_name Player
extends RefCounted

@bindable var name: String = "World"
@bindable var score: int = 0

func add_point() -> void:
    score += 1
```

A UI Gogo module can bind to its own state and to model state:

```gdscript
# Counter.gogo (proposed binding behavior)
extends EstragonSurface

@bindable var count: int = 0

func increment() -> void:
    count += 1

func build_view() -> EstragonVBox:
    return <VBox>
        <Text text={"Count: %d" % count} />
        <Button text="+" pressed={increment} />
    </VBox>
```

T09 must define the binding-expression contract precisely. **Current braced expressions are construction-time values**; syntax coloring or annotation recognition by itself does not make `{count}` reactive. The native compiler should emit typed accessors, property-change notifications, a dependency graph and scoped subscriptions; application code should not call `set_root(build_view())` or emit signals manually to make a bindable value refresh.

## Observable data and ArrayCollection-like semantics

- Support bindable properties on **non-Node data classes**, including typechecking, inheritance and suitable `RefCounted`/`Resource` behavior.
- Distinguish **collection reference replacement** (`@bindable var items`) from **mutation of its contents**. A raw `Array.append()` does not automatically become observable merely because the variable containing the Array is bindable.
- Provide an observable **EstragonArrayCollection-like** object publishing changes for addition, insertion, removal, replacement, movement, reset and changes to bindable item objects. Define event payloads, item identity and indexing, and subscription ownership.
- Repeated/list views should reconcile affected children with stable keys, preserve unaffected components and release observers automatically on removal/replacement. Sort/filter/view APIs can be staged but should be considered in event semantics.

## Layout and other dependent properties

Bindings should update **all supported typed component properties**, including text, color, enabled state, width/height, gap/fill flags and eventually position x/y, using correct layout vs paint invalidation. Current components do **not** expose x/y; design their semantics against parent-managed HBox/VBox layout, nested geometry and hit-testing before adding them. No per-frame polling, full-tree rebuild for every property change, duplicated signal hookups, or hand-disposed UI components.

### Future unit-to-pixel helpers (deferred)

The core layout/spacing API accepts **numeric pixels**, not percentages or unit strings. Later, an ordinary helper such as `to_pixels(parent, child, 50, "%", "height")` (conceptual API, not implemented) may compute pixels from parent/child geometry and an explicit reference dimension; the preferred shorter `to_pixels(parent, child, 50, "%")` form requires unambiguous axis context. Standard Gogo property bindings will use the returned pixel number and react to observed geometry changes through the **normal dependency system**, with no special unit-binding subsystem. Optional markup syntactic sugar may be designed afterward; `height="50%"` remains unsupported now. The full owner-approved direction and unresolved measurement/axis/cycle requirements are recorded in [REACTIVITY_PLAN.md](REACTIVITY_PLAN.md#deferred-pixel-conversion-helpers-and-possible-syntactic-sugar-owner-decision-2026-10-30) and [#54](https://github.com/resistdesign/Estragon/issues/54).

## Engineering contracts and explicit boundaries

- Generate deterministic, valid GDScript and source maps from the bundled native Godot-only Gogo compiler. Invalid declarations fail closed in the editor before F5/F6.
- Define property initialization, equality suppression, custom setter composition, nested dependency replacement, null/re-entrant states, batched notification and cycle/feedback behavior with native Godot tests.
- Keep Estragon runtime components independent of Godot `Control`/`Node`. For layout inheritance, the implemented shared `EstragonStack` already sits under `EstragonContainer` and above HBox/VBox; the approved target abstraction is a named `EstragonBox` base, introduced compatibly in its own tested checkpoint.
- E01 [issue #37](https://github.com/resistdesign/Estragon/issues/37) fixes automatic Gogo syntax-highlighter selection separately, before T09's final integrated authoring check.

**Do not** revive custom annotations in ordinary `.gd`, silently select `.bgd`, implement regex rewriting or require Bun/Node for user compilation. Use [R01 evidence](BINDABLE_FEASIBILITY.md) to explain the old parser limitation, not as a blocker to the accepted Gogo-only path.
