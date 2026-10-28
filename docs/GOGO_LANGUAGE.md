# Gogo language: `*.gogo`

**Status:** T04 implements a small namespace-free markup-to-GDScript slice targeting the independent component runtime. The legacy namespaced XML-to-JSON demo is preserved separately. T05 adds a GDScript-first hybrid subset with component/property/child expressions and range source maps. T07 adds Text/Button properties and generated pressed connections; T08 adds optional automatic editor compilation/highlighting; bindings and broader editor services remain future work.

**Compiler migration:** N01 implements the bundled GDScript-native frontend. Native emission/maps (N02) and editor cutover (N03) remain pending under ADR-0012; the working editor still uses Bun. Supported Gogo syntax, generated signals and source maps must not change as a side effect. Bun remains optional developer/test reference tooling.

## Native frontend (N01)

`addons/estragon/compiler/frontend.gd` exposes a synchronous, scene-independent API:

```gdscript
const Frontend = preload("res://addons/estragon/compiler/frontend.gd")
var result = Frontend.analyze(source, "res://Counter.gogo")
if result.ok:
    var module = result.module
else:
    print(result.diagnostics[0].format()) # original filename:line:column
```

No imports, editor services, runtime components, external executables or packages
are needed to analyze source. This API does **not** emit or execute applications.
T08's compiler commands and editor behavior below remain unchanged until N03.

`model.gd` defines typed RefCounted data: `Module` retains source-ordered `Code`
and `Component` parts; `GdExpression` recursively retains code/component parts.
Components carry resolved runtime class names, ordered property/signal attributes,
typed literals/expressions, children and spans. Attribute `type_name` describes the
expected runtime type; dynamic expressions are not proven to have that type.
Literal colors are normalized hex strings for later emission, not renderer objects.
`Result` contains lossless tokens and either a validated module or one diagnostic;
failed results never expose a partially validated module. Tokens on failure may
cover only the scanned prefix. Diagnostic wording is useful but not a stable API.

Positions expose zero-based Godot Unicode scalar `index` for slicing, zero-based
UTF-16 `offset`, and one-based UTF-16 `line`/`column` coordinates compatible with
the reference compiler. Ends are exclusive; CRLF counts as one newline. Code
text remains in the original source and is recovered through these spans.

Measured compatibility against the TypeScript frontend is recorded in the
checked test transcript `tests/fixtures/native-frontend.json`:

| Area | Native coverage / boundary |
| --- | --- |
| Standalone markup | Nested VBox/HBox, Rect/Text/Button leaves, quoted typed literals, comments, matching tags; no namespaces/entities/escapes |
| Hybrid GDScript | Authored declarations/control flow preserved as ranges; operand-position component islands, comparison/shift operators, explicit continuations |
| Lexical boundaries | Single/double/raw/triple strings, escapes, comments, Unicode identifiers and balanced delimiters |
| Braces | Construction-time property expressions and component-valued children, including nested markup; empty/unclosed expressions rejected |
| Contracts | All five built-ins, inherited sizing, component-specific properties, Button.pressed Callable declarations, duplicates/unknowns/type-invalid literals rejected |
| Locations | Typed-tree ranges and first-error starts compared to reference; Unicode/astral and CRLF/lone CR/LF tested |
| Limits | Same 256 direct-component and 256 hybrid-island nesting guards; named inner-class markup remains unsupported |
| GDScript semantics | Retained lexically, **not fully parsed/typechecked**; unknown names, invalid expressions, callable signatures and child runtime types require Godot validation after emission in N02 |

This is a tested compatibility corpus, not a claim that every possible GDScript
program is supported. No new grammar or callback semantics are introduced.
The transcript is test data, never runtime UI JSON. The native-only test reads it
without running TypeScript; optional `bun tools/native-frontend-cases.ts` verifies
it against the reference, and `--write` refreshes it intentionally.

## Standalone markup-to-GDScript subset (T04, extended in T07)

```gogo
<VBox gap="16">
    <Rect height="64" fill_width="true" fill="#8566e0" />
    <HBox gap="12" fill_width="true" fill_height="true">
        <Rect width="160" fill_height="true" fill="#30c9b0" />
        <Rect fill_width="true" fill_height="true" fill="#50466f" />
    </HBox>
</VBox>
```

Exactly one component expression is required, optionally surrounded by whitespace
or `<!-- comments -->`. Tags are case-sensitive: `VBox`, `HBox`, `Rect`, `Text`, `Button` resolve
to their `Estragon`-prefixed runtime classes. VBox/HBox accept nested components;
Rect/Text/Button are leaves. Empty stacks and a Rect root are allowed. Tags may
self-close or use matching close tags. **No namespace declarations/prefixes**
are accepted, including `xmlns`. There is no `View` wrapper in this subset.

All properties are optional and use **quoted literal values** (single or double
quotes). Whitespace is required between properties. Supported properties are:

| Components | Property | Accepted literal | Default |
| --- | --- | --- | --- |
| All | `width`, `height` | `auto` or a finite nonnegative decimal number | `auto` |
| All | `fill_width`, `fill_height` | `true` or `false` | `false` |
| VBox/HBox | `gap` | finite nonnegative decimal number | `0` |
| Rect | `fill` | `#RRGGBB` or `#RRGGBBAA` | opaque white |
| Text/Button | `text` | quoted string (literal escaping limits below) | empty |
| Text/Button | `font_size` | positive integral decimal, at most 2147483647 | `20` |
| Text/Button | `color` | `#RRGGBB` or `#RRGGBBAA` (label color) | opaque white |
| Button | `disabled` | `true` or `false` | `false` |

Numbers support fractions, leading `+`, decimal exponents and zero. Negative
values are rejected (negative zero normalizes to zero); use `auto`, not `-1`, for
intrinsic sizing. Values that overflow runtime float32 geometry are rejected.
Colors normalize to lowercase RGBA with opaque alpha added when omitted.
Fixed sizing overrides fill; stack allocation/overflow follows the
[T03 runtime contract](ARCHITECTURE.md#minimal-sizing-and-layout-rules).

Compile and verify with Bun 1.4.4, from the repository root:

```sh
bun run transpile examples/compiled/Layout.gogo --output examples/compiled/generated/Layout.gd
bun run verify:gdscript
bun run check
bun run check:godot
```

Open `examples/compiled/Compiled.tscn` in Godot 4.7 and run that scene. It uses a
single surface host. The generated script extends `EstragonSurface`; `_init()`
constructs typed Estragon objects, assigns validated properties, adds children,
and calls `set_root()`. Layout, rendering and automatic cleanup come from the
runtime. There is no runtime markup/JSON interpreter, generated widget tree or
manual application disposal. The legacy JSON scene stays the configured main
scene; `bun run gogo` still invokes the separate stage-0 compiler.

Generated `.gd` is inspectable but never hand-edited. Emission is deterministic
for a given source/name: stable preorder variables, sorted properties, normalized
literals and a final newline. Godot `.gd.uid` sidecars are stable editor metadata;
regeneration leaves them intact. `verify:gdscript` compares source compilation
against the committed fixture without rewriting either file. Invalid compilation
returns a nonzero CLI exit and leaves previous output untouched. **Compile before
running**: the optional T08 plugin automates compilation and blocks failed builds before Play.

Diagnostics use `file:line:column` and identify invalid syntax, tags, properties,
values or child nesting. Lines/columns are 1-based; columns/offsets count UTF-16
code units, CRLF counts as one newline, and span end offsets are exclusive.
Generated component comments retain source positions for inspection. A full
runtime/source mapping system is not implemented yet.

This is a deliberately small **markup expression island**, not a final XML-only
language. The recursive-descent frontend exposes an offset-based expression
entrypoint; syntax nodes and typed component/literal IR retain spans and are
separate from code emission. T05 can compose it with a GDScript-aware frontend.
It does not yet distinguish markup from comparisons/strings in arbitrary code.

**Unsupported:** GDScript declarations/functions, `{expressions}`, callbacks,
bindings/annotations, IDs/refs, custom component imports, text children, XML
entities/escapes/declarations/DOCTYPE/CDATA, fragments, and arbitrary attributes.
Literal values cannot contain `<`, `&` or backslash escapes. Comments are allowed
between components, not inside tags or values. Maximum component nesting is 256.
Unsupported source is an error, never an ignored property or runtime fallback.

## T05 GDScript-first hybrid subset (implemented)

A `.gogo` file may now be an ordinary GDScript module containing component
expressions. No script block, CDATA or separate code-behind is required:

```gogo
extends EstragonSurface
var spacing: float = 12.0
var tint: Color = Color("8566e0")

func _init() -> void:
    set_root(build_view())

func make_panel(size: float) -> EstragonRect:
    return <Rect width={size} height="32" fill={tint} />

func build_view() -> EstragonVBox:
    var gap: float = spacing / 2.0
    return <VBox gap={gap}>
        {make_panel(120.0)}
        <Rect height={48.0 + spacing} fill_width={true} fill="#30c9b0" />
    </VBox>
```

The first non-whitespace character selects the entrypoint: `<` uses the preserved
T04 standalone grammar; otherwise GDScript-first mode is used. Use GDScript `#`
comments at module level. T04 standalone markup remains quoted-literal-only;
braced expressions belong to GDScript-first modules. The same five component
names and property compatibility rules apply in both modes. Signals require
GDScript-first mode.

### Expressions and authoring contexts

Markup is an expression operand after constructs such as `return`, assignment,
call arguments, collection elements or conditional branches. It is supported in
the script's outer-class methods (including static methods and lambdas) and
member initializers. Authored variables, function parameters/return types,
annotations, indentation and control-flow source are retained. Bare unindented
top-level markup after GDScript declarations is not a statement. Markup within
nested named classes is outside this initial subset; use outer-class helper
methods. This is not a promise of a full TypeScript-side GDScript grammar.

Within markup, `{...}` contains a **GDScript expression**. Dictionaries, arrays,
parentheses, strings, comments, native operators and multiline expressions are
balanced lexically; nested markup within a braced expression is allowed.
Comparisons/shifts after operands remain GDScript. Single/triple/raw strings and
comments do not introduce markup or close expression braces. Delimiter/quote
errors are source-located; other GDScript grammar is checked by Godot.

- Property expressions are passed to generated typed parameters: `float` for
  width/height/gap, `bool` for fill flags, `Color` for fill/color, `String` for text, `int` for font_size and `bool`
  for disabled. Use
  `fill={Color("8566e0")}` for computed color values; quoted hex remains available.
  Runtime auto dimensions can be expressed as `{-1.0}`. Unknown properties are
  still compiler errors regardless of their value expression.
- A `{child_expression}` must evaluate to one live `EstragonDisplayObject`.
  Conditional child expressions and helper-returned components work; arrays,
  null, text, fragments and implicit list expansion do not. Ordinary GDScript
  loops may construct/return a container in a helper method.
- Values are evaluated **once per construction**, in authored property/child
  traversal order, before the surrounding factory constructs its tree. Native
  GDScript conditionals retain lazy branch evaluation. GDScript integer division,
  member/local scope and side effects are not evaluated or translated to JavaScript.
- These expressions are **not reactive bindings**. Changing a member does not
  recompute an existing tree. Rebuild explicitly, e.g. `set_root(build_view())`.
  The surface automatically cleans the previous tree; application code never
  needs disposal. Moves use the existing runtime ownership rules.

### Emission, type checking and source maps

The compiler retains authored source ranges and lowers component AST nodes to
calls to collision-free typed static factories appended to the same script.
Factories construct Estragon objects directly; no interpreter, closure-capture
rewriter or regex source replacement is used. Helpers follow authored indentation.
Their typed return permits ordinary `var box := <VBox/>` inference. Generated
names avoid identifiers in the authored module; full inherited-symbol resolution
is not implemented. Prefer the supported runtime bases for application screens
and `RefCounted` for independent helper/factory modules.

TypeScript validates markup structure and literal types and checks expression
boundaries. **Godot is the authority for GDScript syntax, name resolution and
static/runtime types.** Transpilation alone can succeed on a balanced expression
that Godot later rejects. Typed factory arguments expose static mismatches to
Godot; Variant-dependent mismatches, null/duplicate children and dynamic sizing
constraints may fail only at runtime. Child-adoption errors are reported with
Gogo coordinates instead of being silently ignored. Runtime numeric bounds still
come from the existing component setters.

```sh
bun run transpile examples/mixed/Mixed.gogo --output examples/mixed/generated/Mixed.gd
bun run check
bun run check:godot
```

Run `examples/mixed/Mixed.tscn` in Godot 4.7. Its authored `_init()` explicitly
mounts `build_view()`; there is no magical render-method discovery. Module/factory
scripts can return components for a separately owned surface as well.

Hybrid CLI output includes `<output.gd>.map.json`. The deterministic
`estragon.gogo.source-map` version 1 format stores original source content and
UTF-16 copied/generated ranges. It is compiler metadata, **not runtime UI JSON**
or a standard JavaScript/VLQ map. `originalPosition()` maps generated coordinates;
`traceGodotDiagnostics()` annotates known generated Godot paths in the validation
runner. Copied ranges map exactly; generated assignments/helper signatures map
to their originating Gogo span. When Godot supplies only a line, the mapped point
may be the enclosing expression rather than a precise offending subexpression.
Maps support tracing; they are not editor/debugger breakpoint integration.

`verify:gdscript` checks all three examples and their hybrid map bytes. The Godot runner
recompiles fresh source, then checks positive runtime cases and mapped negative
syntax/type/runtime cases. Compilation failure preserves existing code/map;
recompiling a standalone T04 file removes a stale hybrid map. The optional T08 plugin provides automatic editor compilation and stale-run blocking.

**Still unsupported:** `@Bindable`, reactive bindings, signals beyond Button.pressed,
other widgets, arbitrary component imports, structural reconciliation,
inline named-class markup, spread/array children, full source-language type
inference, highlighting/editor builds or automatic subscriptions. The accepted
larger design below remains a target, not a claim of these features.

## T07 generated signals and interactive Gogo (implemented)

```gogo
extends EstragonSurface
var count: int = 0

func _init() -> void:
    set_root(build_view())

func increment() -> void:
    count += 1
    set_root(build_view())

func build_view() -> EstragonVBox:
    return <VBox gap={12}>
        <Text text={"Count: %d" % count} font_size="24" />
        <Button text="+" pressed={increment} />
    </VBox>
```

Only `Button` exposes a compiled event: `pressed={GDScript Callable expression}`.
There are no `on_` prefixes, quoted method names, implicit method calls or signal
attributes on other components. Unknown/duplicate properties or signals and
children of leaf components are compiler errors with source coordinates. Text
and label color use `color`; Rect's `fill` is not a button background style.
Font resources remain a GDScript runtime API, not a markup property in this slice.

Event attributes are distinct typed IR nodes interleaved with property attributes.
All dynamic attribute/child arguments evaluate once in authored traversal order,
including callback-producing expressions. The callback itself runs on activation,
not construction. An uncalled method reference such as `increment` becomes a
native Callable; `increment()` calls it immediately and is not signal shorthand.
Local Callable variables, computed references, bound methods, static functions
and zero-argument lambdas work with ordinary GDScript scope. The compiler passes
these values as **typed Callable arguments** into its static factories; it does
not try to reference an instance method from static scope or use string dispatch.
Factories emit ordinary inspectable `.pressed.connect(callback)` code, once per
new button, and preserve existing generated-name collision handling and maps.

### Validation boundaries

Godot parses/typechecks generated GDScript. Missing method names and statically
incompatible argument/property types are rejected by Godot with mapped Gogo
positions in the validation runner. The Bun frontend validates the component/
attribute contract and expression boundaries; it does not implement GDScript's
semantic checker. Native conversions and Variant-dependent errors remain native
Godot behavior. Literal font sizes must be positive 32-bit integers; expression
font sizes use a typed `int` argument and the runtime's positive-size check.

Generated guards require `Callable.is_valid()` and **exactly zero remaining
arguments** according to `get_argument_count()`. Godot counts optional arguments
and subtracts bound arguments. Thus a method with optional parameters must be
wrapped in a zero-argument lambda or have those parameters bound explicitly.
Empty/invalid callables, incompatible arity and direct disposed component targets
produce source-located engine errors before connecting; no silent fallback occurs.
Return values are ignored. Godot checks bound argument types when invoked, not
through the arity guard. Arbitrary closure effects/captured object lifetimes are
not statically proven. See the [Godot Callable API](https://docs.godotengine.org/en/4.7/classes/class_callable.html).

### Lifecycle and updates

Connections use native synchronous signals. Rebuilding constructs fresh buttons;
`set_root(build_view())` automatically disposes the old tree and disconnects its
outgoing handlers/closures. Removing a direct component-method target also
removes its incoming connections, even if that disposed object is retained by
application code. Transfers preserve live connections while canceling unfinished
pointer gestures. No application disposal, per-frame polling or reactive binding
is introduced. Ordinary native Object/Node callback targets follow Godot's own
lifetime rules; hidden references inside arbitrary lambdas are application code.

```sh
bun run transpile examples/counter/Counter.gogo --output examples/counter/generated/Counter.gd
bun run check
bun run check:godot
```

Run `examples/counter/Counter.tscn` in Godot 4.7: `+` increments the displayed
count, Reset resets it and is disabled at zero. Both handlers and all layout are
authored in Counter.gogo with **no handwritten connections**. Rebuild is explicit;
T09 owns bindings. The old examples and JSON host remain unchanged. Source/maps
are checked byte-for-byte; the Godot runner generates fresh code before import.
The optional T08 plugin automates editor build/run; see EDITOR.md for setup.

## Target: markup expressions mixed with GDScript

Gogo should look and feel like **TSX with GDScript as its programming language**, while keeping XML-like component syntax. Elements are **unprefixed**, and user components participate in the same type-resolved language as built-in components.

~~~text
# Counter.gogo — proposed; NOT executable today
extends VBox

@Bindable var count: int = 0

func increment() -> void:
    count += 1

func render() -> DisplayObject:
    return (
        <VBox gap={12}>
            <Text value={"Count: %d" % count} />
            <Button label="+" pressed={increment} />
        </VBox>
    )
~~~

No `<gogo:View>`, `<fx:Button>` or `xmlns` declarations in the target syntax. `<VBox>` and `<MyWidget>` resolve through an Estragon component registry/import system; exact import rules remain open. Curly-brace props and child expressions are GDScript expressions, **not TypeScript**, and must be type-checked. The signal/event name, IDs/refs, one-way/two-way binding syntax, conditional/repeated children, lifetime semantics, and the exact structure of a generated class still require language design and a parser prototype.

**Important:** Gogo's source may be XML-*like* but cease to be a valid standalone XML *document* once GDScript and markup interleave. The language needs a coordinated lexer/parser, not regex hacks or the existing XML-only parser applied to the complete mixed file.

Output is **ordinary generated GDScript**, with component construction, signal wiring, binding hooks, deterministic identifiers and source maps. The generated code creates Estragon's independent component objects, never a Godot `Control` tree. Read [the design direction](DESIGN_DIRECTION.md).

## Stage-0 compiler syntax (IMPLEMENTED TODAY; temporary)

The current `tools/gogo.ts` remains a deliberate rendering spike. Its old XML namespace syntax below is **not** the intended final authoring experience:

~~~xml
<?xml version="1.0" encoding="UTF-8"?>
<gogo:View xmlns:gogo="urn:estragon:gogo:1"
           id="main" width="960" height="540">
    <gogo:Rect id="accent" x="48" y="48"
               width="480" height="128" fill="#8566e0" />
</gogo:View>
~~~

- The root is `View` with required finite positive `width`/`height`, optional `id`.
- Only direct leaf `Rect` children are valid. `width`, `height` and `fill` are required; finite `x`/`y` default to zero.
- `fill` accepts `#RRGGBB` or `#RRGGBBAA` and normalizes to lowercase eight-digit RGBA.
- IDs must be nonblank and unique. Unknown attributes/components, mixed text, invalid namespaces and unsupported nesting are errors.
- The **old compiler requires** namespace URI `urn:estragon:gogo:1`, although the XML prefix is arbitrary. This requirement will be removed for the new language.
- The output is deterministic, versioned JSON IR for the current demo, **not** GDScript and **not** a serialized Godot scene.

Run the existing tool from the repository root:

~~~sh
bun run gogo examples/hello/Main.gogo --output examples/hello/generated/Main.gogo.json
bun run check
~~~

This stage-0 compiler and sample stay working until the real transpiler and runtime vertical slice are verified. Do not extend the old JSON format as though it were the target architecture.

## Grammar and evolution

Design and test component imports/resolution, property types, attribute expressions, children and fragments (if any), signal callback conventions, binding expressions, typed component references, error recovery, GDScript-language islands and source maps. Favor Flex 4's class/component model and modern TSX's composition ergonomics without copying HTML, React's runtime semantics, or XML namespace ceremony. Produce compile errors for unknown features instead of silent fallback.

## Automatic editor builds (T08)

Enable Estragon in Godot 4.7 and configure Bun once if it is not discoverable.
The native Script Editor opens `.gogo` with automatic mixed highlighting. Saving
sources and pressing either Play command generates these same ordinary scripts
and maps without manual compiler commands. gogo.config.json explicitly defines
source roots; adjacent generated paths preserve scene references. Failed frontend,
process or native GDScript validation blocks execution and reports authored
locations. The language/evaluation/lifecycle contract is unchanged. See
[EDITOR.md](EDITOR.md) for exact policy, setup and existing-tab/highlighting limits.
