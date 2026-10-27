# Gogo language: `*.gogo`

**Status:** T04 implements a small namespace-free markup-to-GDScript slice targeting the independent component runtime. The legacy namespaced XML-to-JSON demo is preserved separately. T05 adds a GDScript-first hybrid subset with component/property/child expressions and range source maps. Full binding/widget/editor features remain future work.

## T04 markup-to-GDScript subset (implemented)

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
or `<!-- comments -->`. Tags are case-sensitive: `VBox`, `HBox`, `Rect` resolve
to `EstragonVBox`, `EstragonHBox`, `EstragonRect`. VBox/HBox accept nested
components; Rect is a leaf. Empty stacks and a Rect root are allowed. Tags may
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
running**: automatic editor compilation and stale-output blocking belong to T08.

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
braced expressions belong to GDScript-first modules. Exactly the same three
component names and property compatibility rules apply in both modes.

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
  width/height/gap, `bool` for fill flags, `Color` for fill. Use
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

`verify:gdscript` checks both examples and the hybrid map bytes. The Godot runner
recompiles fresh source, then checks positive runtime cases and mapped negative
syntax/type/runtime cases. Compilation failure preserves existing code/map;
recompiling a standalone T04 file removes a stale hybrid map. Automatic editor
compilation and stale-run blocking remain T08 work.

**Still unsupported:** `@Bindable`, reactive bindings, event/signal wiring,
Text/Button widgets, arbitrary component imports, structural reconciliation,
inline named-class markup, spread/array children, full source-language type
inference, highlighting/editor builds or automatic subscriptions. The accepted
larger design below remains a target, not a claim of these features.

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
