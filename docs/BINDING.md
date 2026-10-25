# Bindable properties and reactivity

**Status: planned. None of these annotations or bindings compile yet.**

Estragon aims to bring the key ergonomics of Adobe Flex 3.x/4.x's `[Bindable]` and MXML binding expressions to GDScript and Gogo. Unlike a shallow signal wrapper, this needs a compiler-assisted, **object-independent** observable property system.

## Proposed authoring experience

```gdscript
# Model.bgd (proposed extended GDScript, not executable stock .gd)
extends RefCounted

@bindable var name: String = "World"
@bindable var count: int = 0

func increment() -> void:
    count += 1
```

```xml
<!-- Proposed Gogo, NOT supported by stage-0 compiler -->
<gogo:Text value="{model.name}" />
<gogo:TextInput value="@{model.name}" />
```

`.bgd` is a **working proposal** for a distinct, preprocessed source file extension, not a finalized language choice. In stock GDScript, arbitrary custom annotations like `@bindable` cannot simply be registered by an `EditorPlugin`; using that spelling inside ordinary `.gd` would require a Godot/GDScript parser change or an external source transformation step.

## Proposed generated behavior

A setter with a typed change signal is one possible generated target:

```gdscript
signal count_changed(value: int)

var count: int = 0:
    set(value):
        if count == value:
            return
        count = value
        count_changed.emit(value)
```

The compiler must preserve types, custom setters, inheritance and assignment semantics instead of blindly replacing text with regex. It must document whether notification happens for equal values, when initialized, and when state is changed through collections or nested references.

## Dependency graph requirements

Given `{model.user.display_name}`, Estragon must subscribe to the appropriate property changes, rewire when `user` or `model` is replaced, and unsubscribe when the consuming component is destroyed. Nothing here should depend on a `Node`; observable plain objects and resources must be supported.

Additional required capabilities:

- One-way expressions and safe initialization.
- Two-way assignable expressions, event adapters and loop prevention.
- Observable collection mutations; `items.append(...)` bypasses an ordinary property setter.
- Batched/coalesced invalidation and explicit scheduling semantics.
- Circular dependency detection and bounded recomputation.
- Error messages pointing to original `.gogo` / reactive source locations.
- Memory-safe subscription lifetimes and explicit cleanup.
- No per-frame polling as the primary binding mechanism.

## Implementation sequence

1. Define property-change behavior, source language and test matrix.
2. Prototype a source-aware GDScript preprocessor (not regex rewriting).
3. Generate typed setters/signals and test runtime semantics.
4. Add binding-expression parsing and compile dependency descriptors.
5. Add observable paths, collections, two-way adapters and batching.
6. Integrate binding invalidation into the independent component/layout/paint pipeline.

A custom Godot engine build remains an alternative only if it yields materially better integration than source transformation.
