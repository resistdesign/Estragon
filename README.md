# Estragon

**An independent, graphics-rendered UI framework for Godot.**

*No more waiting for Godot. Gogo!*

Estragon is inspired by the declarative markup, data binding, and developer experience of Adobe Flex 3/4. Its markup language is **Gogo** (`.gogo`). Estragon **does not** compile markup to Godot's `Control` tree, use the stock GUI layout/rendering/widgets, or require one Godot node per UI component.

The design is a **standalone UI stack hosted by Godot**: Estragon owns its logical component tree, layout, styles, input/focus, accessibility semantics, reactive state and drawing. Godot provides application hosting and low-level graphics access. Optional bridges to Godot nodes may be considered, but are not the default representation of UI elements.

## Status: experimental scaffold

This repository contains a tiny, **working-in-principle** compiler slice: a strict TypeScript Gogo parser (executed by Bun) generates a versioned UI intermediate representation (IR), which a minimal Godot `Node` host draws through **`RenderingServer`** using its 2D canvas primitives. That draws pixels without creating any Godot `Control` nodes. It is a rendering spike, *not* the finished component/layout engine. This starter has only `View` and fixed-position `Rect` elements; no binding, text, layout, events or authoring-time preview yet.

`RenderingServer` is the initial low-level graphics adapter. The intended render backend is pluggable; a more direct `RenderingDevice`/shader-driven backend is a future investigation, not a completed feature or final decision.

## Try the initial slice

Requires **Bun 1.4.4** for compiling/testing and a compatible **Godot 4.x** editor/runtime to run the demo.

```sh
bun install --frozen-lockfile
bun run gogo examples/hello/Main.gogo --output examples/hello/generated/Main.gogo.json
bun run check
```

Open this directory as a Godot project (`project.godot`) and run the main scene. `examples/hello/Hello.tscn` contains **one host `Node`**, which reads the checked-in generated IR and draws rectangles directly using `RenderingServer.canvas_item_add_rect()`. The checked-in output lets the scene run without requiring Bun in the Godot process or at application runtime.

The optional editor plugin in `addons/estragon/editor/` only makes `.gogo` recognizable as an editor text-file extension when enabled. Syntax highlighting, source diagnostics and preview integration are on the roadmap. The plugin changes the global Godot Editor Settings text-extension list; see [editor integration](docs/EDITOR.md) before enabling it.

## Read the design

- [Vision and non-goals](docs/VISION.md)
- [System architecture and rendering backends](docs/ARCHITECTURE.md)
- [Gogo markup language](docs/GOGO_LANGUAGE.md)
- [Bindable properties and reactivity](docs/BINDING.md)
- [Godot editor integration](docs/EDITOR.md)
- [Project roadmap](docs/ROADMAP.md)
- [Architecture decisions and open questions](docs/DECISIONS.md)
- [Contributing](CONTRIBUTING.md)

## Naming

- **Estragon:** the overall framework and runtime
- **Gogo:** the declarative UI language and compiler; files end in `.gogo`
- **Godot:** the host engine, not the component library

This project is at the prototype stage; all syntax not explicitly described as supported is a **proposal**, not a working feature. Estragon is released under the [MIT License](LICENSE). See [Assets](Assets/) for the original logo files.
