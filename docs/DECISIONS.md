# Architecture decisions and open questions

This file is a lightweight decision log. Decisions marked **provisional** are not settled by the code scaffold.

## ADR-0001 — Own the UI stack

**Status: accepted. 2026-10-25.**

Estragon is **not** a declarative generator for Godot `Control` nodes. Estragon manages its own components, layout, styling, input handling, observable state and graphics rendering. Godot provides hosting, platform/window/input facilities and graphics APIs. A small host node is acceptable. Per-component node adapters, if they are ever introduced, must be **optional**.

## ADR-0002 — Naming

**Status: accepted. 2026-10-25.**

Estragon names the framework. Gogo names the language and its compiler; markup files end in `.gogo`. Inspiration comes from Adobe Flex's MXML and bindability, but the actual markup is a new language, not MXML compatibility mode.

## ADR-0003 — Graphics API and backends

**Status: provisional. 2026-10-25.**

The initial proof uses `RenderingServer` canvas primitives to render pixels without `Control` nodes. This is not a selection of the final engine backend. Investigate `RenderingDevice`, custom shaders, batching and native/GDExtension implementation when we have representative UI workloads. Keep IR, component tree, layout and binding independent of the graphics interface.

## ADR-0004 — Bindable syntax strategy

**Status: provisional. 2026-10-25.**

Prefer a compiler-assisted extended GDScript source format (working extension `.bgd`) over a Godot fork for the first experiment. Source-aware parsing and generated setters/signals are required. A true `@bindable` in stock `.gd` is not provided by this scaffold.

## ADR-0005 — Edit the original Gogo source

**Status: provisional. 2026-10-25.**

Favor Godot's editable text-file workflow plus editor plugin first; do not convert Gogo source to a `.tscn` tree. Later, add semantic editing, build integration and a preview backed by the actual Estragon renderer.

## ADR-0006 — Project license

**Status: accepted. 2026-10-25.**

Estragon is distributed under the [MIT License](../LICENSE). Do not distribute third-party fonts or other assets without confirming their separate rights. The source design uses letter shapes associated with LondonTwo, but the uploaded font binary is not distributed in this repository because its embedded notice says 'All rights reserved.'

## Unresolved, intentionally not invented

- **Final rendering implementation:** RenderingServer vs RenderingDevice/native backend, multi-platform strategy.
- **Source language for reactive scripts:** `.bgd` proposal vs alternative compiler frontend.
- **Gogo language:** XML shape, component tags, style/event syntax, expression grammar and interoperability.
- **Node integration:** which components, if any, deserve optional Godot node wrappers.
- **Layout/style semantics:** borrow selected Flex ideas, establish a new model, or align with modern UI layouts.
- **Text and accessibility:** text shaper/platform integration, IME, screen readers and testable semantics.
- **Editor architecture:** ScriptEditor plugin vs standalone Gogo authoring surface vs language server.

When any of these is decided, record the rationale and tradeoffs here before implementation.
