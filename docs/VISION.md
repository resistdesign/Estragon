# Estragon vision

## One sentence

**Estragon is a new, self-rendered, reactive UI engine that runs inside Godot, not a wrapper around Godot's GUI system.**

Its source language is Gogo (`.gogo`). Its authoring experience draws inspiration from the best parts of Adobe Flex 3.x/4.x: declarative components, automatically tracked state and compile-time wiring.

## Why build it?

The purpose is to own the design and behavior of the UI stack instead of inheriting the constraints, layout model, styling model or widget behavior of Godot's `Control` system. This is a deliberate architectural independence goal, not a claim that the stock system is unusable for every project.

Writing markup should be a convenient way to construct **Estragon components**. Those components should be rendered by **Estragon**, through a lower-level graphics interface supplied by Godot, with the minimum amount of Godot scene machinery necessary to host them.

## Principles

1. **Render ourselves.** No conversion of Gogo components into Godot `Control` widgets. Estragon owns paint, composition and visual behavior.
2. **Own a logical UI tree.** Component identity, lifecycle, layout, hit testing and accessibility must not depend on a Godot node per visual element.
3. **Reactive by default, explicit when necessary.** Observed properties and dependency expressions should work without manual signal glue or per-frame binding polling.
4. **Declarative authoring, compiled execution.** Parse and validate Gogo before runtime; do not parse XML on every frame.
5. **A real editor experience.** Language-aware editing, errors tied to source, completion, navigation and preview are product features, not afterthoughts.
6. **Separate concerns.** Parser, semantic model, runtime components, layout, binding graph, input routing and renderer must have clean interfaces.
7. **Make backend choices by evidence.** Design a renderer abstraction; benchmark available graphics paths instead of prematurely claiming one is best.

## What Flex contributes

We want MXML-like *declarative construction*, `[Bindable]`-like *observable properties*, generated observers, one-/two-way binding and strong editing ergonomics. We are **not** promising a drop-in implementation of MXML, ActionScript, Spark, Halo, Flex states/effects or Flex's exact compilation/runtime semantics.

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
