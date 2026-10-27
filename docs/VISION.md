# Estragon vision

## One sentence

**Estragon is a new, self-rendered, reactive UI engine that runs inside Godot, not a wrapper around Godot's GUI system.**

Its source language is Gogo (`.gogo`): **XML-like component expressions woven directly into GDScript, inspired by TSX, and transpiled into runnable GDScript**. Flex 4 informs its component system, automatic event wiring and bindable state. No XML namespace prefixes are required in the target language. See the [design direction](DESIGN_DIRECTION.md). T05 implements a minimal hybrid authoring subset; T06 adds basic text/buttons and primary-mouse input using ordinary GDScript. The full reactive UI/editor vision remains future work.

## Why build it?

The purpose is to own the design and behavior of the UI stack instead of inheriting the constraints, layout model, styling model or widget behavior of Godot's `Control` system. This is a deliberate architectural independence goal, not a claim that the stock system is unusable for every project.

Writing markup should be a convenient way to construct **Estragon components**. Those components should be rendered by **Estragon**, through a lower-level graphics interface supplied by Godot, with the minimum amount of Godot scene machinery necessary to host them.

## Principles

1. **Render ourselves.** No conversion of Gogo components into Godot `Control` widgets. Estragon owns paint, composition and visual behavior.
2. **Own a logical UI tree.** Component identity, lifecycle, layout, hit testing and accessibility must not depend on a Godot node per visual element.
3. **Reactive by default, explicit when necessary.** Observed properties and dependency expressions should work without manual signal glue or per-frame binding polling.
4. **Declarative authoring, generated GDScript execution.** Compile typed Gogo markup and GDScript expressions into ordinary GDScript before runtime; never interpret XML or a serialized JSON UI tree on each frame.
5. **A real editor experience.** Mixed GDScript/markup highlighting, errors tied to authored source, completion, navigation, automatic compilation and previews are product features. Native-looking `@Bindable` in authored `.gd` files remains a separate technical challenge.
6. **Separate concerns.** Parser, semantic model, runtime components, layout, binding graph, input routing and renderer must have clean interfaces.
7. **Make backend choices by evidence.** Design a renderer abstraction; benchmark available graphics paths instead of prematurely claiming one is best.

## What Flex contributes

We want **TSX-like GDScript/markup composition** with unprefixed component names, typed expressions and callbacks, combined with Flex 4-inspired component classes, generated signal connections, `[Bindable]`-style observables and one-/two-way binding. We are **not** promising direct MXML, ActionScript, TSX, React or Spark compatibility, or React's runtime rerender model.

## Explicit non-goals

- Generating `.tscn` trees of `Control`, `Label`, `Button`, etc.
- Depending on Godot's GUI focus, layout, input, theme and widget implementations for Estragon UI.
- Requiring one `Node` per Estragon component. Optional node adapters may exist later, if useful.
- Building a web browser or blindly adopting CSS/HTML semantics.
- Maintaining a fork of Godot before it is actually needed.
- Claiming performance, accessibility or platform coverage before it has been tested.

## Quality bar for a real UI engine

Beyond drawing colored rectangles, Estragon must eventually handle text shaping, font fallback, localization and RTL, layout constraints and measurement, high-DPI scaling, animation, clipping, focus/navigation, keyboard/IME, pointer/touch/drag, scrolling, hit testing, accessible semantics, data binding and efficient redraw.

These are **requirements to research and implement**, not capabilities of the current prototype.
