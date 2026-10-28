# Architecture: a UI engine, not a scene generator

## Invariant

**No Estragon visual component maps by default to a Godot `Control` or `Node`.** The Godot scene tree may contain a single Estragon host, multiple UI surfaces or optional integration adapters. The UI component tree is an independent data structure managed by Estragon.

## Mixed-source direction (T05 subset implemented; later services planned)

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
| Gogo frontend/codegen (T04/T05 subset implemented) | Hybrid GDScript/markup parsing, component/type resolution, diagnostics, generated GDScript and source maps | Rendering, Godot nodes |
| Binding compiler (planned) | Observable properties, dependency descriptors and source transformation | Per-frame polling |
| Component runtime (foundations implemented; reconciliation planned) | Independent objects, identity, ownership, disposal and dirty flags | Godot scene tree |
| Layout engine (minimal stacks implemented) | Natural/fixed/fill sizes and nested VBox/HBox; broader layout planned | `Container` nodes |
| Input system (primary mouse implemented) | Reverse-order hit testing/capture; propagation/focus/keyboard/IME planned | `Control` event routing |
| Paint system (rectangles/text implemented) | Ordered rectangle/text commands; broader display lists/clipping planned | Specific graphics API |
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

The host renders **temporary JSON IR** positions directly. It does **not** compile Gogo into GDScript and is **not yet** the retained component tree, layout engine or event/binding system described above. Basic text and primary-pointer buttons are implemented in the independent runtime; reactive compilation, hot reload, preview and other rendering backends remain planned.

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

This section describes T04 only; T05 hybrid composition is described below.
T07 adds Button callbacks below; T08 adds editor build hooks. Binding generation remains future work. The markup-only parser/IR does not define
the whole language. See [GOGO_LANGUAGE.md](GOGO_LANGUAGE.md) for exact grammar,
properties, commands and limitations.

## Hybrid GDScript/markup composition (T05)

`hybrid-parser.ts` lexes GDScript strings/comments/identifiers/operators and
balanced delimiters, dispatching only expression-position markup to the extended
T04 parser. GDScript source ranges and component AST nodes coexist in one module.
Braced props/children recursively contain GDScript ranges and markup. This is a
lexical composition frontend; Godot still parses and typechecks the resulting
GDScript. It does not replace the GDScript language implementation.

`validate.ts` reuses component/property rules and distinguishes literals from
GDScript expressions. `emit-hybrid.ts` copies authored ranges and emits typed
static factory calls/methods for component construction. Dynamic arguments are
evaluated at the authored call site, preserving local/member scope and native
operators/control flow. Values are eager once per construction in source traversal
order; conditionals inside expressions remain native/lazy. No binding polling,
closure capture transformation or runtime markup interpretation is introduced.

`source.ts` provides UTF-16 indexing; `source-map.ts` emits a versioned range map
with source content and copied/generated spans. The CLI writes hybrid `.gd` and
`.gd.map.json`; validation annotates generated Godot diagnostics with original
Gogo coordinates. This is sufficient for source tracing, not a complete editor
source-map/breakpoint service. Literal-only T04 fixture bytes remain unchanged.

`examples/mixed/Mixed.gogo` extends EstragonSurface, mounts `build_view()` in its
ordinary `_init`, and exposes explicit rebuild. Surface ownership automatically
cleans old trees. Helper modules can remain RefCounted and return components.
No new runtime classes, widget Nodes, signal wiring or subscriptions are needed.
See [GOGO_LANGUAGE.md](GOGO_LANGUAGE.md) and ADR-0009 for the exact minimal grammar,
type/evaluation limits and unsupported nested named-class markup.

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

`EstragonPaintList` contains typed ordered fill-rectangle and text-run commands
in absolute surface coordinates. Containers accumulate local offsets; zero-area rectangles
produce no command. This is an in-memory paint boundary, not serialized Gogo IR
or a general/versioned display-list format. `EstragonCanvasRenderer` alone uses
RenderingServer, clearing/redrawing one canvas item per surface. Backend ownership
and cleanup belong to the surface, not individual components. RenderingServer
remains a provisional backend; other backends are still research topics.

`tests/godot/components.gd` tests the foundations. `tests/godot/layout.gd` tests
nested geometry, paint output, real SubViewport resizing, renderer allocation and
automatic lifecycle paths. See [TESTING.md](TESTING.md) for error probes and visual
verification limits. T06 adds text and buttons below; binding graphs and a broader
widget suite remain planned.

## Text, buttons and primary-pointer input (T06)

`EstragonText` extends DisplayObject; `EstragonButton` extends Text. Both remain
RefCounted logical components. `text`, `font_size` and `font` invalidate layout
and paint; `color` invalidates paint only. Text measures complete shaped strings
using Godot's low-level [Font resource](https://docs.godotengine.org/en/4.7/classes/class_font.html),
not a Label or Control. Default font is `ThemeDB.fallback_font`, size 20. Explicit
`\n` lines use maximum line width and summed font heights; empty text reserves
one line height. There is no wrapping, ellipsis, rich text, clipping or advanced
localization API. Font resources are shared, treated as immutable inputs; reassign
`font` (even the same resource) after editing its data to invalidate measurements.
Font must be nonnull and size positive; rejected assignments preserve prior values.

Button adds fixed padding `(14, 8)` per side to intrinsic text size; normal sizing
rules still apply. The label is centered in positive extra allocation. Normal,
hover, down-inside and disabled states have minimal fixed colors, exposed through
`get_visual_state()` / `get_background_color()`. `disabled` cancels any active
interaction. This is a small component contract, not a theme/style system.

The authoritative paint list is `commands`, interleaving FillRect and TextRun
snapshots in traversal order; `rectangles` is retained as a compatibility inspection
view. TextRun stores baseline, complete string, Font reference, size and color.
Only the renderer issues `Font.draw_string()` / RenderingServer calls to the same
surface canvas item. No component owns a Node, CanvasItem or graphics RID. Font
resources manage shared glyph data; no Estragon per-component glyph atlas exists.

### Targeting and gesture contract

The surface adapts Godot `_input` to `dispatch_pointer(event)` and marks a handled
event on its Viewport. Input is already in viewport coordinates; Estragon's
current surface is at the viewport origin. It synchronously resolves pending
layout before hit testing, so changes and resizes apply to the next input event.
`get_surface_rect()` accumulates nested local offsets. Containers traverse
children in reverse paint order. Only buttons are targets; noninteractive text/
rectangles pass through, and disabled buttons occlude buttons below. Bounds are
half-open (right/bottom excluded). Children can overflow/hit beyond parent bounds,
matching existing unclipped painting, but positions outside the viewport cancel.

`EstragonPointerDispatcher` has weak hover/capture references and no per-button
registrations. Its intentionally narrow model handles mouse motion and the left
button; other buttons, wheel, keyboard and touch are ignored. There is no bubbling,
keyboard focus, gesture recognition or public event-object catalog yet.

- A down captures the enabled button under the pointer. Repeated down events
  during that press are ignored. A down outside cannot become an inside press.
- Motion updates hover. While captured, down appearance is present only over the
  captured target; leaving/reentering is permitted within the viewport.
- Release emits the parameterless typed `pressed` signal exactly once **only**
  if the original target is still enabled/live and is the current topmost target.
  Release outside or over a different button activates neither. Unmatched and
  duplicate releases do nothing. Capture clears before application handlers run.
- Window focus loss/mouse exit cancels the gesture. The surface subscribes to
  native Window signals, independently of Godot GUI event routing. Layout updates
  refresh stationary hover without per-frame polling.

### Automatic interaction cleanup

Removal, replacement, root unmount, and surface destruction clear pointer state;
terminal components disconnect incoming direct method and outgoing signal connections (including closures)
and Text releases its Font reference. Disposal hooks in subclasses must call
`super` to preserve framework cleanup. Disposed objects cannot be hit or activated.
Transfers cancel the old gesture before changing parent links, including between
surfaces, but preserve component identity, signal connections and live resources.
Move directly to the new parent; no application disposal call is needed.

Window input subscriptions are removed on surface exit, alongside existing root/
viewport subscriptions and canvas cleanup. Re-entry starts with a fresh root.
Handlers may synchronously replace the root; use Godot's normal `queue_free()`
when destroying a host from its input/signal callback. Queued hosts reject input.

`examples/interactive/Interactive.tscn` uses ordinary GDScript `pressed.connect`
handlers to update text with Add one and Reset buttons. Text changes schedule
layout/redraw automatically; they are not reactive bindings. The Gogo compiler now accepts Text/Button and generates Button.pressed connections
in T07; the earlier ordinary GDScript example remains preserved. See TESTING for the interactive procedure and CI coverage.

## Generated interactive Gogo (T07)

The explicit compiler registry now maps five built-ins: VBox/HBox/Rect/Text/Button.
Text and Button share typed text/font_size/color and inherited sizing; Button adds
disabled and one compiled event, pressed. The hybrid IR uses ordered discriminated
property/signal attributes, preserving eager argument evaluation across both.
Factories receive typed String/int/Color/bool properties and Callable callbacks;
instance/local references evaluate at the original call site. Generated guards
check native validity/zero-remaining arity and reject terminal direct component
targets, then connect the native signal once. All emitted connection/guard ranges
map back to their authored event expression. Older fixtures remain unchanged.

`examples/counter/Counter.gogo` is the first complete interactive authored screen:
its generated connections invoke increment/reset methods, explicit root rebuilds
refresh text and disabled state, and automatic lifecycle disconnects old sources.
Direct target disposal also disconnects incoming method connections; ordinary
reparenting preserves them. Arbitrary lambdas can contain application effects not
visible to metadata checks. Full GDScript semantics remain Godot's responsibility.
No callback wrapper interpreter, per-component Node or new subscription service
is used. See GOGO_LANGUAGE/ADR-0010 for validation limits and TESTING for the gate.

## Performance model to implement later

Track independently dirtied state, layout and paint; retain component identities; batch paint primitives; minimize allocations and GPU submissions; manage scissoring/clips and cache glyphs/resources. Measure CPU and GPU cost, startup time, frame pacing and memory on concrete workloads instead of assuming lower-level drawing automatically means faster rendering.

## Godot editor compilation boundary (T08)

The optional EditorPlugin integrates the native Script Editor, lexical Gogo
highlighter and diagnostics bottom panel. Editor Controls are tooling only;
application components/rendering remain unchanged. Saved-source/filesystem events
coalesce a build; the common F5/F6 `_build` hook saves buffers and gates execution
on direct Bun/TypeScript compilation plus separate native Godot semantic checks.
An explicit gogo.config.json lists sorted project source roots; adjacent generated
code/maps preserve existing resource paths. Reports in .godot carry diagnostics,
outputs and changed paths; they are build metadata, never runtime UI data.

The build service bounds subprocess lifetime, detects missing/crashed compilers,
and fails closed. It does not rely on shell startup configuration. TypeScript
still owns the language pipeline, Godot owns generated GDScript semantics, and
the editor only presents/adapts them. Successful changed paths update the resource
filesystem; a fresh game executes them. No live game hot-reload or replacement
source editor is introduced. See EDITOR, TESTING and ADR-0011 for precise behavior.
