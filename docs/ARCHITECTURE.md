# Architecture: a UI engine, not a scene generator

## Invariant

**No Estragon visual component maps by default to a Godot `Control` or `Node`.** The Godot scene tree may contain a single Estragon host, multiple UI surfaces or optional integration adapters. The UI component tree is an independent data structure managed by Estragon.

## Intended mixed-source pipeline (T05 and later)

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
| Layout engine (minimal stacks implemented) | Natural/fixed/fill sizes and nested VBox/HBox; broader layout planned | `Container` nodes |
| Input system (planned) | Hit testing, event propagation, focus, pointer/keyboard/IME | `Control` event routing |
| Paint system (rectangle list implemented) | Ordered rectangle commands; broader display lists/clipping planned | Specific graphics API |
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
- Independent component ownership, stack layout, rectangle rendering and automatic lifecycle.
- T04 namespace-free markup-to-GDScript compiler and runnable generated surface.

The host renders **temporary JSON IR** positions directly. It does **not** compile Gogo into GDScript and is **not yet** the retained component tree, layout engine or event/binding system described above. There is no text, interaction, reactive compilation, hot reload, preview or other rendering backend yet.

## Markup-to-GDScript vertical slice (T04)

The implemented path is namespace-free `.gogo` markup → component-expression
syntax → typed component/literal IR → ordinary generated GDScript extending
`EstragonSurface`. No serialized UI IR is used on this path. The legacy stage-0
compiler/JSON host remain independent and unchanged.

`tools/gogo/parser.ts` is a recursive-descent markup-island parser with source
spans, not an XML document wrapper. `parseMarkupExpressionAt()` can consume one
expression inside a future hybrid parser's source; it does not parse GDScript.
`validate.ts` resolves exactly three runtime component names and validates
literal property types/child rules. `emit-gdscript.ts` emits stable typed
construction, property assignments, add-child calls and surface mounting.
`model.ts` separates syntax from typed literal/component expressions without
inventing unimplemented GDScript constructs. No Godot API is used by the compiler.

`tools/transpile-gogo.ts` is the explicit Bun CLI; `tools/check-gdscript.ts` checks
the committed example bytes. The Godot runner recompiles into its temporary
project before import, so its runtime suite tests actual new compiler output.
The generated surface uses T03's lifecycle; application code never disposes UI
components. `examples/compiled/Compiled.tscn` is the runnable example.

This implements **only** T04: no mixed GDScript, callbacks, binding generation,
editor build hooks or full source maps. The markup-only parser/IR does not define
the whole language. See [GOGO_LANGUAGE.md](GOGO_LANGUAGE.md) for exact grammar,
properties, commands and limitations; T05 remains the mixed-source work item.

## Independent runtime (T02/T03)

`EstragonDisplayObject` and `EstragonContainer` are typed `RefCounted` objects.
`EstragonVBox`, `EstragonHBox` and `EstragonRect` build on them. Components have
no Godot Node, Control, CanvasItem or RID. These runtime classes can be authored
in GDScript today; T04 also compiles a minimal markup subset to these classes. The legacy JSON
host is unchanged and remains the main scene. `examples/layout/Layout.tscn` is a
separate runnable demonstration.

### Identity, ownership and automatic lifecycle

- `get_instance_id()` is identity for the object's lifetime; moving a component
  preserves it. Authored IDs, reconciliation and persisted identity are future work.
- Containers strongly own ordered children with weak parent links. Enumeration
  returns a shallow snapshot. `add_child(child)` appends or transfers an existing
  child after validation; **move directly to the new owner, without removing first**.
- `remove_child(child)` unmounts and recursively cleans the child automatically.
  `replace_child(old, new)` preserves the old slot and cleans the replaced tree.
  An invalid replacement leaves the original tree intact. Replacing with itself
  is a no-op. An existing descendant may be moved out before its old tree is cleaned.
- One `EstragonSurface` Node owns a root and one renderer. `set_root(component)`
  mounts/replaces; `set_root(null)` unmounts. Replaced roots, surface tree exit,
  and surface destruction automatically clean their owned subtree. The framework
  disconnects root/viewport subscriptions and releases the canvas RID. The same
  host may re-enter with a fresh root. External references to unmounted components
  remain terminal/disposed; they cannot be remounted. Live roots have one surface
  owner and cannot simultaneously be container children.
- **Application developers do not call disposal during normal component usage.**
  `_dispose()` is an internal, idempotent mechanism. Subclasses release resources
  in `_dispose_owned_resources()`; container subclasses call super to preserve
  recursive cleanup. Transfers skip cleanup. Adoption from a disposing ancestor
  is rejected, including from cleanup hooks.
- Raw, never-mounted RefCounted trees can be constructed/tested independently;
  dropping references uses Godot reference counting, not a virtual cleanup hook.
  Resource/subscription lifecycle starts with framework ownership. Always mount
  application UI in a surface; callers need no manual component cleanup. The
  framework does not depend on unsafe RefCounted final-deletion method calls.

Tree operations return `Error`: `OK`, `ERR_INVALID_PARAMETER` (null, cycle or
terminal additions), `ERR_ALREADY_EXISTS` (same-parent add), `ERR_DOES_NOT_EXIST`
(non-child removal/replacement), `ERR_UNAVAILABLE` (disposing owners), or
`ERR_ALREADY_IN_USE` (dual surface ownership). Internal underscore fields and
methods are not application mutation APIs. This deliberately corrects T02's
remove-without-cleanup/manual-dispose convention; see ADR-0008.

### Minimal sizing and layout rules

- `width`/`height`: `-1` means intrinsic auto; finite nonnegative values are fixed
  sizes (zero is valid). `fill_width`/`fill_height` opt into the allocated space
  when that dimension is auto. Fixed dimensions take precedence over fill.
- `measure()` recursively computes natural sizes; `get_layout_rect()` reports
  arranged local coordinates. Plain containers overlay children at `(0, 0)` and
  naturally measure the maximum child dimensions.
- VBox/HBox sum natural main-axis sizes and gaps, and take the largest natural
  cross-axis size. `gap` is finite and nonnegative; empty stacks have no gap.
  Main-axis fill children equally divide the nonnegative space left after fixed
  or intrinsic children and gaps. Cross-axis fill uses the allocated cross size.
  Fill alone contributes no extra natural size. Fixed/intrinsic content may
  overflow; flexible sizes clamp to zero. There is no shrink, clipping, wrapping,
  percentage sizing, padding, alignment catalog or Flex/CSS compatibility claim.
- The surface allocates viewport dimensions to auto root dimensions; explicit
  root dimensions win. Geometry uses Godot `Vector2`/`Rect2`, without GUI layout.
  Invalid dimensions/gaps/arranged geometry emit engine errors and leave the
  previous value unchanged; the validation runner rejects such errors.

### Invalidation, paint boundary and rendering

New components start dirty. Tree/layout/paint flags propagate to ancestors;
property setters invalidate the affected phases automatically. Root invalidation
and viewport `size_changed` schedule one coalesced deferred surface update.
There is **no per-frame polling**. Layout runs for tree/layout dirtiness, while
color-only changes repaint without remeasurement. Local acknowledgement does
not clear descendants implicitly; traversal clears completed work.

`EstragonPaintList` contains typed ordered fill-rectangle commands in absolute
surface coordinates. Containers accumulate local offsets; zero-area rectangles
produce no command. This is an in-memory paint boundary, not serialized Gogo IR
or a general/versioned display-list format. `EstragonCanvasRenderer` alone uses
RenderingServer, clearing/redrawing one canvas item per surface. Backend ownership
and cleanup belong to the surface, not individual components. RenderingServer
remains a provisional backend; other backends are still research topics.

`tests/godot/components.gd` tests the foundations. `tests/godot/layout.gd` tests
nested geometry, paint output, real SubViewport resizing, renderer allocation and
automatic lifecycle paths. See [TESTING.md](TESTING.md) for error probes and visual
verification limits. No input, text, binding graph or widget suite is implemented.

## Performance model to implement later

Track independently dirtied state, layout and paint; retain component identities; batch paint primitives; minimize allocations and GPU submissions; manage scissoring/clips and cache glyphs/resources. Measure CPU and GPU cost, startup time, frame pacing and memory on concrete workloads instead of assuming lower-level drawing automatically means faster rendering.
