# Gogo language: `*.gogo`

**Status:** the prototype accepts a tiny strict XML subset; the **accepted target** is TSX-like GDScript-plus-markup transpiled to GDScript. Neither the new syntax nor runtime is implemented.

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
