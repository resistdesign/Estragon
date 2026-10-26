# Architecture: a UI engine, not a scene generator

## Invariant

**No Estragon visual component maps by default to a Godot `Control` or `Node`.** The Godot scene tree may contain a single Estragon host, multiple UI surfaces or optional integration adapters. The UI component tree is an independent data structure managed by Estragon.

## Intended processing pipeline (not implemented)

The [design direction](DESIGN_DIRECTION.md) is **Gogo's XML-like markup and GDScript mixed in one authored `.gogo` source**, transpiled to GDScript—not JSON UI data interpreted by Godot.

~~~text
  *.gogo: GDScript + <Component> elements    authored *.gd with @Bindable
                  |                            (desired; parser hook TBD)
          hybrid source frontend                          |
                  |                          GDScript-aware preprocessing
          typed components, props,                        |
          expressions, signals, bindings -----------------+
                  |
         deterministic GDScript generator
                  |
        ordinary generated *.gd scripts
                  |
          Godot GDScript compilation
                  |
           Estragon component instances
            /           |          \
         layout      reactive       input
                     state/events
            \           |          /
             paint / retained display list
                        |
              renderer backend interface
                  /              \
        RenderingServer      RenderingDevice
            adapter           (research)
                  \              /
                  Godot Viewport
~~~

A typed *compiler-internal* AST or intermediate model is useful; that is **not** a mandate for serialized JSON as the runtime format. Component construction, typed references and signal connections should be produced as **GDScript code**. Estragon's component tree remains independent of Godot's `Control`/`Node` hierarchy.

**Current state:** the first prototype uses `tools/gogo.ts` to emit `*.gogo.json` for a minimal `RenderingServer` host. Keep this stage-0 demo working until a new Gogo-to-GDScript vertical slice is proven, then migrate it deliberately. Its namespace-prefixed XML is **not** the intended new Gogo syntax.

## Layer responsibilities

| Layer | Owns | Does not own |
| --- | --- | --- |
| Gogo frontend/codegen (planned) | Hybrid GDScript/markup parsing, component/type resolution, diagnostics, generated GDScript and source maps | Rendering, Godot nodes |
| Binding compiler (planned) | Observable properties, dependency descriptors and source transformation | Per-frame polling |
| Component runtime (foundations implemented; reconciliation planned) | Independent objects, identity, ownership, disposal and dirty flags | Godot scene tree |
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
- Compiler unit tests and pinned Godot 4.7 headless import/parse/runtime checks.
- Independent component ownership/disposal/invalidation foundations, described below.

The host renders **temporary JSON IR** positions directly. It does **not** compile Gogo into GDScript and is **not yet** the retained component tree, layout engine or event/binding system described above. There is no text, interaction, reactive compilation, hot reload, preview or other rendering backend yet.

## Component foundations (T02)

`addons/estragon/runtime/display_object.gd` defines `EstragonDisplayObject`;
`container.gd` defines `EstragonContainer`. Both are ordinary `RefCounted` objects.
They allocate no `Node`, `Control`, `CanvasItem` or RID. The prefixes avoid Godot's
built-in `Container` name; this does not settle future Gogo component resolution.
These foundations are tested independently and are **not integrated into the
stage-0 JSON renderer**. Geometry, layout, rendering, input, reconciliation and
reactive subscriptions remain future work.

The minimal runtime contract is:

- `get_instance_id()` supplies identity for an instance's lifetime. Reparenting
  does not recreate it. There is no authored-ID registry or persisted identity.
- A container strongly owns ordered children. `get_children()` returns a shallow
  snapshot and `get_child_count()` reports membership. Mutating the snapshot
  cannot mutate the tree.
- `get_parent()` resolves a weak reference, preventing ownership cycles. A new
  object is detached. `add_child(child)` appends, automatically moving a child
  from its previous owner only after validation. `remove_child(child)` detaches
  without disposal. Callers retain any detached object they want to keep.
- Operations return `Error`: `OK` on success, `ERR_INVALID_PARAMETER` for null
  children, cycles or disposed additions, `ERR_ALREADY_EXISTS` for a same-parent
  add, `ERR_DOES_NOT_EXIST` for removing a non-child, and `ERR_UNAVAILABLE` for a
  disposed destination/owner. Rejected operations do not mutate or invalidate the
  tree. Adding an already-owned child does not reorder it.
- `dispose()` is explicit, terminal and idempotent. It detaches from its owner,
  recursively disposes owned descendants, releases child references and clears
  dirty flags. External references may still refer to disposed objects, but
  cannot reattach them. Removing/reparenting first transfers cleanup ownership.
  A cleanup hook cannot move a pending sibling out of a disposing owner.
- Subclasses release additional resources in `_dispose_owned_resources()`;
  container subclasses must call `super._dispose_owned_resources()` to preserve
  recursive cleanup. `_set_parent()` and underscore fields are internal; only
  container operations may change membership. There are no mutation signals.
- Reference counting reclaims unreferenced objects without explicit disposal;
  the cleanup hook runs only through `dispose()`. A child retained externally
  after its parent is reclaimed becomes detached and remains usable. Owners
  requiring deterministic cleanup must call `dispose()` before releasing a root.

Dirty state uses independent bit flags `DIRTY_TREE`, `DIRTY_LAYOUT`, `DIRTY_PAINT`
and their union `DIRTY_ALL`. New objects start fully dirty. `invalidate(flags)`
accumulates flags locally and on every ancestor; unknown bits are ignored.
`clear_invalidations(flags)` acknowledges local work only. Repeated invalidation
still propagates through an already-dirty child to an ancestor that was cleared.
Membership changes dirty the child and affected old/new ancestor chains for all
three phases. Disposed objects ignore invalidation. These are invalidation
foundations, **not a layout algorithm, renderer, scheduler or binding system**.

`tests/godot/components.gd` tests this contract without adding component nodes to
its test process's scene tree; see [TESTING.md](TESTING.md).

## Performance model to implement later

Track independently dirtied state, layout and paint; retain component identities; batch paint primitives; minimize allocations and GPU submissions; manage scissoring/clips and cache glyphs/resources. Measure CPU and GPU cost, startup time, frame pacing and memory on concrete workloads instead of assuming lower-level drawing automatically means faster rendering.
