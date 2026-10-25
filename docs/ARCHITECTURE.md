# Architecture: a UI engine, not a scene generator

## Invariant

**No Estragon visual component maps by default to a Godot `Control` or `Node`.** The Godot scene tree may contain a single Estragon host, multiple UI surfaces or optional integration adapters. The UI component tree is an independent data structure managed by Estragon.

## Intended processing pipeline

```text
             *.gogo                  *.bgd / bindings (planned)
                |                             |
          Gogo parser                 reactive source frontend
                |                             |
       type + schema validation       dependency analysis
                |                             |
                +----- compiler / typed UI IR-+
                              |
                     component creation
                              |
                 Estragon-owned retained tree
                   |       |       |        |
               bindings  styling  layout  input/focus
                   |       |       |        |
                 invalidation + reconciliation
                              |
                       paint / display list
                              |
                      renderer interface
                      /                \
       RenderingServer adapter       GPU/RenderingDevice
           (stage 0)                  (research)
                      \                /
                       Godot Viewport
```

The IR is **not** a serialized `PackedScene`. It represents Estragon components and properties.

## Layer responsibilities

| Layer | Owns | Does not own |
| --- | --- | --- |
| Gogo frontend | Markup parsing, namespaces, validation, diagnostics | Rendering, Godot nodes |
| Binding compiler (planned) | Observable properties and dependency descriptors | Per-frame polling |
| Component runtime (planned) | Logical objects, lifecycle, identity, reconciliation | Godot scene tree |
| Layout engine (planned) | Measurement, constraints, flex/stack/grid decisions | `Container` nodes |
| Input system (planned) | Hit testing, event propagation, focus, pointer/keyboard/IME | `Control` event routing |
| Paint system (planned) | Display list, dirty regions, clipping and stacking | Specific graphics API |
| Renderer backends | Translate display list to GPU drawing | Component semantics |
| Godot host | Surface/viewport hookup, input source, lifecycle, platform integration | Widget behavior |

## Low-level graphics choices

**Stage 0:** `RenderingServer` canvas items are used to prove that an independent source tree can cause pixels to be drawn in Godot **without Godot UI components**. One server-side canvas item is parented to the viewport's 2D canvas; rectangle primitives are submitted directly. `RenderingServer` is the engine's low-level rendering API, but it still uses Godot's 2D rendering pipeline; it is *not the same* as issuing raw Vulkan/Metal/OpenGL commands.

**Future investigation:** A `RenderingDevice` backend, potentially implemented through a GDExtension/native module, could issue lower-level GPU work and enable a custom batching/composition/text strategy. Render-to-viewport/presentation integration, hardware/platform support, synchronization and fallback paths must be designed and tested. Do not promise a zero-overhead or universal raw-GPU path before a prototype.

**Design requirement:** The retained tree, layout and bindings must not depend on which graphics backend paints the display list.

Official Godot references:
- [RenderingServer](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html)
- [RenderingDevice](https://docs.godotengine.org/en/stable/classes/class_renderingdevice.html)
- [Optimization using servers](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html)

## Planned render contract (illustrative, not yet code)

A backend should receive a **versioned display list** with commands such as fill rectangle, textured quad, glyph run, clip push/pop and compositing layer. It should not receive XML tags or component objects. Eventually the compiler/runtime should distinguish structure, style, geometry and paint so changes can invalidate only the necessary work.

## Node adapters: optional, not architectural

A Godot `Node` can host an Estragon root, expose state to a Godot scene or bridge an external event stream. If individual Estragon components later become optional Godot nodes, that must remain an opt-in adapter: component meaning, layout and rendering must still be implemented by Estragon, not by `Control`.

## What is actually implemented today?

- Strict TypeScript Gogo XML parser executed at build time by Bun.
- Tiny, versioned JSON IR: `View` root + absolute-positioned `Rect` leaves.
- A checked-in sample IR and a Godot host `Node` that submits rectangles through `RenderingServer.canvas_item_add_rect()`.
- Compiler unit tests and GitHub Actions test runner.

The host renders the IR's positions directly. This is **not yet** the retained component tree, style engine or layout engine described above. There is no text, interaction, reactive compilation, hot reload, preview or other rendering backend yet.

## Performance model to implement later

Track independently dirtied state, layout and paint; retain component identities; batch paint primitives; minimize allocations and GPU submissions; manage scissoring/clips and cache glyphs/resources. Measure CPU and GPU cost, startup time, frame pacing and memory on concrete workloads instead of assuming lower-level drawing automatically means faster rendering.
