# Estragon

**An independent, graphics-rendered UI framework for Godot.**

*No more waiting for Godot. Gogo!*

Estragon is inspired by the declarative markup, data binding, and developer experience of Adobe Flex 3/4. Its markup language is **Gogo** (`.gogo`). Estragon **does not** compile markup to Godot's `Control` tree, use the stock GUI layout/rendering/widgets, or require one Godot node per UI component.

The design is a **standalone UI stack hosted by Godot**: Estragon owns its logical component tree, layout, styles, input/focus, accessibility semantics, reactive state and drawing. Godot provides application hosting and low-level graphics access. Optional bridges to Godot nodes may be considered, but are not the default representation of UI elements.

## Where we're going

**Gogo is XML-like markup with TSX-style GDScript composition.** Developers should be able to write unprefixed components such as `<VBox>` and `<Button>`, combine them directly with GDScript expressions and methods in `.gogo`, and have the compiler generate ordinary GDScript that instantiates Estragon's independent runtime objects and wires signals/bindings. **No `xmlns` or `<fx:...` prefixes** in the intended language. Minimal independent runtime/stack classes exist; a fuller component suite and Gogo-aware editor support remain planned. The desired `@Bindable` experience in ordinary `.gd` files requires a separate feasibility investigation.

Core Gogo-to-GDScript compilation, independent layout and interactive generated signal wiring work; **Bun-free Godot-native compilation** is the next unimplemented goal. Read the [Gogo-to-GDScript design direction](docs/DESIGN_DIRECTION.md) for the remaining decisions and technical constraints.

## Immediate priority: Godot-only Gogo compilation

**Accepted direction, 2026-10-28:** Estragon will compile Gogo **entirely inside Godot** with its bundled GDScript compiler. Normal users must never need Bun/Node, TypeScript, a configured executable, or a separately installed compiler.

**Not implemented yet.** The currently working T08 editor plugin still launches Bun. The owner manually verified editing Gogo font size and rerunning in Godot. That is a proven **temporary bridge**. The next tasks are **N01 native parser → N02 native emitter and source maps → N03 native editor cutover without Bun**. The TypeScript/Bun compiler may remain as optional contributor/CI reference tooling after cutover.

See [ADR-0012](docs/DECISIONS.md), [execution plan](docs/EXECUTION_PLAN.md) and [work status](docs/WORK_STATUS.md). T09 bindings and T10 legacy retirement wait until N03.

## Status: experimental vertical slices

T04 compiles a minimal namespace-free `VBox`/`HBox`/`Rect` markup subset to ordinary
GDScript constructing Estragon's independent components. The runtime supports
nested auto/fixed/fill stack layout, rectangle drawing and automatic lifecycle
through a single surface host. T05 adds GDScript-first hybrid modules with helper methods, nested markup,
braced construction-time expressions and range source maps. T06 adds text drawing, buttons and primary-mouse input through ordinary GDScript.
T07 adds Text/Button markup, generated pressed connections and an interactive Counter.gogo.
T08 adds optional native Gogo highlighting and automatic compilation before Play.
Bindings and broader editor services remain future work. See the [supported subset](docs/GOGO_LANGUAGE.md).

The earlier namespaced XML → JSON rectangle demo is preserved separately and
remains the configured main scene. It is temporary compatibility scaffolding,
not the new compiler's runtime format.

`RenderingServer` is the initial low-level graphics adapter. The intended render backend is pluggable; a more direct `RenderingDevice`/shader-driven backend is a future investigation, not a completed feature or final decision.

## Try the Gogo-to-GDScript slice

Requires Bun 1.4.4 and the pinned Godot 4.7 editor (see TESTING):

```sh
bun install --frozen-lockfile
bun run transpile examples/compiled/Layout.gogo --output examples/compiled/generated/Layout.gd
bun run check
bun run check:godot
```

Open `examples/compiled/Compiled.tscn` in Godot and run that scene. Edit `.gogo`
and recompile; do not edit generated `.gd`. The optional editor plugin compiles on save and before Play; see EDITOR for setup.
Generated code mounts components on an EstragonSurface; cleanup is automatic.

## Try hybrid GDScript/Gogo

```sh
bun run transpile examples/mixed/Mixed.gogo --output examples/mixed/generated/Mixed.gd
bun run check
bun run check:godot
```

Run `examples/mixed/Mixed.tscn`. The authored source contains typed GDScript
members, ordinary helper/build methods, nested markup and computed properties.
It mounts explicitly with `set_root(build_view())`; rebuild is explicit and
cleanup automatic. Generated `.gd.map.json` supports source tracing. This is
construction-time composition, not reactive binding; Godot checks GDScript types.

## Try interactive components

Run `examples/interactive/Interactive.tscn` in Godot 4.7. Add one and Reset update
visible text through ordinary GDScript handlers. Hover/hold for visual states,
release outside to cancel, and resize to see the button row follow the viewport.
No component Nodes, Godot Controls or manual component disposal are required.
For compiler-generated connections, run the Gogo Counter below. See the
[interactive test procedure](docs/TESTING.md#interactive-components-visual-check-t06).

## Try interactive Gogo

```sh
bun run transpile examples/counter/Counter.gogo --output examples/counter/generated/Counter.gd
bun run check
bun run check:godot
```

Run `examples/counter/Counter.tscn`. Click `+` to increment and Reset to return
to zero. The authored `.gogo` contains GDScript state/handlers and Text/Button
markup with `pressed={increment}`; Gogo generates all signal connections. Explicit
root rebuilding refreshes text/disabled state and automatically disconnects old
handlers. The optional T08 plugin automates editor builds after one-time setup; no bindings are implied. See the
[signal contract](docs/GOGO_LANGUAGE.md#t07-generated-signals-and-interactive-gogo-implemented).

## Try the initial slice

Requires **Bun 1.4.4** for compiling/testing and a compatible **Godot 4.x** editor/runtime to run the demo.

```sh
bun install --frozen-lockfile
bun run gogo examples/hello/Main.gogo --output examples/hello/generated/Main.gogo.json
bun run check
```

Open this directory as a Godot project (`project.godot`) and run the main scene. `examples/hello/Hello.tscn` contains **one host `Node`**, which reads the checked-in generated IR and draws rectangles directly using `RenderingServer.canvas_item_add_rect()`. The checked-in output lets the scene run without requiring Bun in the Godot process or at application runtime.

Enable **Estragon (experimental)** in Godot's Plugins settings for normal Gogo
authoring: mixed syntax highlighting, automatic saved-source builds and checked
compilation before F5/F6. Configure Bun once if needed; no compiler commands are
required during normal development. The plugin preserves existing editor
extension settings. See [editor setup and verified limits](docs/EDITOR.md).

## Read the design

- [Codex execution plan (sequenced PRs and acceptance gates)](docs/EXECUTION_PLAN.md)
- [Work status and cross-session handoffs](docs/WORK_STATUS.md)
- [Gogo-to-GDScript design direction](docs/DESIGN_DIRECTION.md)
- [Vision and non-goals](docs/VISION.md)
- [System architecture and rendering backends](docs/ARCHITECTURE.md)
- [Gogo markup language](docs/GOGO_LANGUAGE.md)
- [Bindable properties and reactivity](docs/BINDING.md)
- [Godot editor integration](docs/EDITOR.md)
- [Project roadmap](docs/ROADMAP.md)
- [Architecture decisions and open questions](docs/DECISIONS.md)
- [Contributing](CONTRIBUTING.md)

## Picking up development with Codex

**One task per PR.** Check the live [work register](docs/WORK_STATUS.md) and the latest [T08 handoff](https://github.com/resistdesign/Estragon/issues/28) before choosing work (or research [R01: `@Bindable` feasibility](https://github.com/resistdesign/Estragon/issues/4) in parallel). Point Codex to `AGENTS.md`, `docs/EXECUTION_PLAN.md`, `docs/WORK_STATUS.md` and the chosen issue ID. Those files define what to build, how to track progress, and how another session continues. **Do not ask Codex to implement the whole roadmap in one PR.**

## Naming

- **Estragon:** the overall framework and runtime
- **Gogo:** the declarative UI language and compiler; files end in `.gogo`
- **Godot:** the host engine, not the component library

This project is at the prototype stage; all syntax not explicitly described as supported is a **proposal**, not a working feature. Estragon is released under the [MIT License](LICENSE). See [Assets](Assets/) for the original logo files.
