# Estragon reactivity and component architecture contract

**Owner direction accepted 2026-10-29; implementation pending.** This document is the durable brief for staged T09 delivery. It extends [the binding design](BINDING.md), [the execution plan](EXECUTION_PLAN.md), [accepted decisions](DECISIONS.md), and the live [T09 umbrella issue #5](https://github.com/resistdesign/Estragon/issues/5). It does **not** claim that reactivity, collections, x/y positioning, keyed repeaters or `EstragonBox` exist yet. **Version baseline:** ADR-0014 requires Godot **4.0+** for all future implementations. [C01 #41](https://github.com/resistdesign/Estragon/issues/41) must close current API gaps and prove native editor/runtime/compiler compatibility before releases claim 4.0+. Current 4.7 checks are insufficient.

## Language boundary and authoring

- **Only official annotation:** `@bindable`, exactly lowercase, **in authored `.gogo` files only**. This intentionally supersedes the former `@Bindable` in arbitrary authored `.gd` requirement. Gogo is a GDScript-like source language with XML-like component expressions; generated `.gd` must remain ordinary Godot-parseable GDScript. No Godot parser patches, native custom annotation registration, `.bgd` requirement, Bun/Node compiler, authored-source replacement or runtime Gogo interpreter.
- `@bindable` may annotate typed properties in a Gogo component/surface **or a code-only Gogo model class**, with no markup required. Model objects are not Estragon display components and must not require Godot `Node` inheritance (at minimum, typed `RefCounted`; investigate appropriate `Resource` semantics).
- The compiler generates typed property storage/accessors/change notifications. Ordinary operations such as `count += 1` and assignments to another Gogo model's bindable property must notify relevant subscribers without manual signals, setter invocation or complete UI reconstruction. Initial values do not spuriously fire change notifications; equal-value assignments can be suppressed under a defined equality contract.
- `@bindable` is an authoring/compiler feature, **not a claim that native Godot accepts the annotation in `.gd`**. R01 [research PR #38](https://github.com/resistdesign/Estragon/pull/38) contains the stock-Godot counterevidence.

Proposed source illustration (not currently valid/executable):

```gdscript
# Counter.gogo
extends EstragonSurface
@bindable var count: int = 0

func increment() -> void:
    count += 1

func build_view() -> EstragonVBox:
    return <VBox>
        <Text text={"Count: %d" % count}/>
        <Button text="+" pressed={increment}/>
    </VBox>
```

The existing brace expressions evaluate at construction time. T09 must define a **typed, source-aware dependency-aware binding contract** for reactive expressions; adding an annotation must not silently pretend all current construction-time expressions are reactive.

## Binding behavior, data and geometry

1. **Property updates:** generated subscriptions track read dependencies, update only affected live component properties, and reconcile nested paths when intermediates (e.g. `model.player`) change. Cover `null`, replacing the model, repeated expressions, re-entrant updates and cyclic dependencies. Prevent duplicate callbacks; unsubscribe on unmount/replace/disposal and support transfers correctly. No per-frame polling.
2. **Visual and layout:** reactive values may drive any supported typed visual/layout property, including `width`, `height`, `gap`, sizing flags, `color`, `text`, disabled state, and **future** positioning `x`/`y`. Preserve the existing dirty-tree/layout/paint phases so position/dimension changes cause only required remeasure/rearrange/repaint, while paint-only changes do not spuriously remeasure. Coalesce multiple changes.
3. **Positioning is an explicit design task:** `x`/`y` are *not implemented* on current `EstragonDisplayObject`. Define whether coordinates are relative offsets, absolute placement inside a dedicated container, or controlled layout inputs. Do not have HBox/VBox child bindings quietly fight the parent layout algorithm. Prove nested offsets, hit-testing, surface coordinates and viewport resizing.
4. **Bindable models:** code-only `.gogo` modules should compile to ordinary typed scripts with reliable imports/class names, cache/dependency ordering, inheritance, source maps, initialization and property semantics. Bindable values may contain other models or collection references; nested observers follow replacement and clean up automatically.
5. **Collections:** offer an observable, ArrayCollection-inspired `EstragonArrayCollection` (final API subject to typed Godot proof), not an assumption that native `Array.append()` can emit change notifications. A bindable variable holding a collection only detects **reference replacement**; the observable collection itself must publish *structural mutations* (insert/add/remove/replace/move/reset) and changes in bindable item models, with well-defined event kind/item/index/identity. Preserve stable item identity for incremental/efficient list rendering; optional view sort/filter may follow a tested base contract. Do not advertise generics syntax that stock GDScript cannot parse.
6. **Repeaters/data-driven components:** an iterable/collection expression used to build children needs explicit keyed reconciliation semantics. An item edit updates its component; an add/remove/move creates, removes or moves only affected children. Preserve component identity, pointer/handler ownership and subscription lifetimes; do not redraw the entire tree unnecessarily or cause leaked references.

For inspiration, Apache Flex [ArrayCollection and data providers](https://flex.apache.org/doc/flex/using/flx_about_dataproviders_ab.html) describe collection change events, item-property notifications and data views. Estragon should implement its own deliberately scoped contracts, not promise API parity with ActionScript.

## Inheritance and shared component behavior

**Verified existing Godot classes:**

```text
EstragonDisplayObject
    └── EstragonContainer
          └── EstragonStack
                ├── EstragonVBox
                └── EstragonHBox
```

`EstragonStack` already shares measurement/arrangement and gap logic. The owner wants an explicit **`Box` base** in the public abstraction:

```text
EstragonDisplayObject
    └── EstragonContainer
          └── EstragonBox
                ├── EstragonVBox
                └── EstragonHBox
```

Use `EstragonBox` as a shared layout-policy type (orientation, gap and eventual alignment/padding if specified). Preserve the existing `EstragonStack` contract through a deliberate compatibility strategy; don't duplicate HBox/VBox layout logic or break existing scenes/generated scripts silently. This mirrors the inheritance *concept* of Apache Flex 3's [Box](https://svn.apache.org/repos/infra/websites/production/flex/content/asdoc/mx/containers/Box.html), which extends Container and is the base class for HBox/VBox, without importing its full layout API.

Other Estragon classes should continue to share behavior through cohesive inheritance or composition: e.g. `EstragonButton` currently extends `EstragonText`, while independent `EstragonRect` extends DisplayObject. Any future hierarchy changes require scoped compatibility and lifecycle tests. **None** of these logical objects should default to one Godot `Control` or `Node` each.

## Recommended task boundaries and proofs

**E01 #37 first (editor correctness, 4.0+ evidence required):** auto-select Gogo highlighting for new/restored/already-open tabs. The bug is reproduced by the owner; selecting the Gogo highlighter manually works. Real-editor tests must fail before the fix and pass after. Do not hide it inside binding work.

**T09-A — observable Gogo property and data-model foundation:** code-only Gogo modules, explicit lowercase annotation parsing/typechecking, generated setters/notifications, typed non-Node model proof and native editor/semantic tests. Confirm no implicit UI rebuild is needed to observe a plain property. Define/verify custom accessors, inheritance and equality. One scoped issue/PR.

**T09-B — reactive component props and layout:** bind expressions/dependency graph, nested replacement, automatic lifecycle, batching, layout versus paint invalidation. Determine x/y semantics, add geometry only with tests. Introduce `EstragonBox` in a focused compatible checkpoint/PR as appropriate, not through incidental code churn. Show a value change updating text **and** geometry with no explicit `set_root()`.

**T09-C — observable collections and repeaters:** item change/structural change events, bindable model contents, incremental keyed child updates/moves/removal, replacement and disposal. Prove event counts, stable identities and no leaks; allow collection reference changes. Sort/filter/view features can be staged independently, but their contract must be considered in the model.

**T09-D — two-way bindings and hardening:** assignable paths, event adapters, null handling, feedback/cycle guards, batching across nested objects/collections, integrated editor demonstration. Separate reviewable PRs if needed.

### Acceptance and quality gate across stages

- Tests include 1) typed scalar update without manual refresh, 2) non-Node model update, 3) nested-object replacement, 4) layout/position dirty-phase behavior, 5) collection insert/remove/replace/move/item update, 6) keyed repeat behavior and owner cleanup, 7) fail-closed source diagnostics, 8) fresh Godot-only editor F5/F6 without Bun/Node, **including the 4.0 baseline and each supported 4.x minor per C01**.
- Keep native compiler, source maps, callback evaluation semantics and independent component tree. Stage only supported properties/syntax; unknown types and unsupported mutations should fail visibly rather than pretend to be reactive.
- Protect the shipped Counter and legacy demo during migration. Never merge on behalf of the user. Maintain linked GitHub issues, scoped PRs, CI, checked acceptance evidence and durable session handoffs per `AGENTS.md`.

**Status/merge ordering:** R01 #38 and architecture PR #39 are merged. E01 #40 is the sole active PR. After its owner-controlled merge/closure, C01-A #42 audits compatibility and queues focused fixes; T09-A #43 follows blocking compatibility work. One PR at a time, no automatic merges. The staged architecture above remains planned, not implemented.
