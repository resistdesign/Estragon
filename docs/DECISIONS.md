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

The desired experience is `@Bindable` in ordinary user-authored `.gd`, transformed into typed getters/setters and notifications. **Stock GDScript does not accept arbitrary addon-defined annotations**, and a simple `EditorPlugin` cannot register them. Explore real pre-parse source transformation/editor integration before considering a separate source extension (`.bgd`) or engine/parser modification. None of these mechanisms is confirmed; do not silently replace the requested `.gd` experience with `.bgd`.

## ADR-0005 — Edit the original Gogo source

**Status: provisional. 2026-10-25.**

Favor Godot's editable text-file workflow plus editor plugin first; do not convert Gogo source to a `.tscn` tree. Later, add semantic editing, build integration and a preview backed by the actual Estragon renderer.

## ADR-0006 — Project license

**Status: accepted. 2026-10-25.**

Estragon is distributed under the [MIT License](../LICENSE).

## ADR-0007 — Gogo generates GDScript with TSX-like authoring

**Status: accepted direction. 2026-10-26.**

Gogo (`.gogo`) should support **XML-like component expressions directly mixed with GDScript**, borrowing TSX's compositional authoring model and Flex 4's runtime/component principles. Component tags are **unprefixed** (`<VBox>`, `<Button>`); mandatory XML namespace prefixes and `xmlns` declarations are rejected as the product direction. The transpiler generates valid GDScript for typed Estragon components, automatic event/signal wiring, and later bindings. The first prototype's JSON output and namespaced XML are **temporary scaffolding**, not the final language contract.

The *experience* is accepted; precise grammar, imports, binding semantics, parser architecture, editor integration, GDScript class organization, and handling `@Bindable` in ordinary `.gd` files are still open engineering decisions. See [design direction](DESIGN_DIRECTION.md).


## ADR-0008 — Framework-owned automatic component lifecycle

**Status: accepted user requirement, 2026-10-26; T03 implementation reviewed in its PR.**

Application developers must not call `dispose()` during normal Estragon usage.
A surface owns its root and renderer; unmounting/replacing a root or leaving the
scene tree automatically cleans components, subscriptions and rendering resources.
Container removal/replacement likewise unmounts and cleans; direct adoption into
a new parent transfers ownership without disposal. Live surface roots cannot
have another owner. Internal cleanup remains idempotent and terminal.

This explicitly supersedes T02's manual-dispose/remove-to-detach convention.
The user requested this correction for T03; it is not a compiler or binding change.
Keep root/child transfer checks separate from cleanup so moving a subtree does
not destroy it. Deterministic cleanup executes in live owners, not RefCounted
final-deletion callbacks (calling instance cleanup there failed in Godot 4.7).
Raw unmounted values remain reference-counted data; normal application UI is
mounted in a surface. No Node or graphics resource per component is introduced.

T03 uses deliberately narrow fixed/auto/fill sizing and stack gaps, documented
in ARCHITECTURE. These are the first tested rules, not automatic Flex/CSS semantics;
broader sizing/alignment remains an open future design.

## ADR-0009 — Minimal GDScript-first hybrid composition

**Status: T05 implementation contract, reviewed with its implementation PR.**

T05 composes lexically retained GDScript with parsed component expressions and
balanced braced GDScript property/child expressions. No XML document wrapper,
script block or mandatory code-behind is introduced. T04 standalone markup
continues unchanged. The full future language is not fixed by this initial slice.

Lower markup AST nodes to typed static factories within the authored module.
Arguments are evaluated once in authored scope/source traversal order before
construction; nested native conditionals remain lazy. This preserves local/member
references without rewriting variable names or depending on Callable Variant
return inference. Helper names avoid module identifiers and indentation follows
authored GDScript. Application surfaces mount explicitly with set_root; existing
automatic lifecycle remains intact. No reactive expression reevaluation is implied.

Godot supplies GDScript syntax/type authority; the TypeScript frontend supplies
markup/type compatibility, expression boundaries and range maps. Dynamic types
and runtime constraints are not falsely advertised as statically proven.
Range-map sidecars and mapped Godot checks provide traceability without claiming
editor/debugger integration. Named inner-class markup, collection expansion,
bindings, widget/signal features and full semantic analysis remain outside T05.

## Unresolved, intentionally not invented

- **Final rendering implementation:** RenderingServer vs RenderingDevice/native backend, multi-platform strategy.
- **Bindable source integration:** preserve the desired `@Bindable` annotation in ordinary authored `.gd`; prove a workable pre-parse/tooling mechanism or evaluate explicit fallbacks.
- **Gogo language:** TSX-like GDScript/markup grammar, component import/resolution, typed expression/event/binding semantics and optional markup-only shorthand.
- **Node integration:** which components, if any, deserve optional Godot node wrappers.
- **Layout/style semantics:** borrow selected Flex ideas, establish a new model, or align with modern UI layouts.
- **Text and accessibility:** text shaper/platform integration, IME, screen readers and testable semantics.
- **Editor architecture:** ScriptEditor plugin vs standalone Gogo authoring surface vs language server.
- **Mixed-authoring implementation:** reliable source mapping, parsing GDScript expressions alongside markup, and optional code-behind.

When any of these is decided, record the rationale and tradeoffs here before implementation.
