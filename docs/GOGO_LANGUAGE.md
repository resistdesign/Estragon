# Gogo language: `*.gogo`

**Status:** T04 implements a small namespace-free markup-to-GDScript slice targeting the independent component runtime. The legacy namespaced XML-to-JSON demo is preserved separately. The **accepted target** remains TSX-like GDScript-plus-markup; mixed source is T05, not supported yet.

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
