# Gogo language: `*.gogo`

**Status:** stage-0 implemented subset plus clearly labeled proposals.

Gogo is Estragon's markup language. It is XML-shaped for familiar Flex-style authoring, but it describes **Estragon's own UI components**, never Godot `Control` node types.

## Stage-0 supported syntax

```xml
<?xml version="1.0" encoding="UTF-8"?>
<gogo:View xmlns:gogo="urn:estragon:gogo:1"
           id="main" width="960" height="540">
    <gogo:Rect id="accent" x="48" y="48"
               width="480" height="128" fill="#8566e0" />
</gogo:View>
```

Rules:

- `View` is the **document root**. `width` and `height` are mandatory positive finite numbers; `id` is optional.
- `Rect` is a **leaf** under `View`. `width`, `height` and `fill` are required. `x` and `y` are optional finite numbers, defaulting to zero; `id` is optional.
- `fill` is a hexadecimal `#RRGGBB` or `#RRGGBBAA` color. The compiler canonicalizes it to lowercase `#rrggbbaa`.
- IDs must be unique and nonblank. Unknown attributes, components, mixed text content, missing values and malformed XML are errors.
- There is no implicit layout or text rendering. Units are stage-0 viewport canvas coordinates.
- Components must use namespace `urn:estragon:gogo:1`. A different XML prefix is valid if it resolves to the same namespace.

Compile:

```sh
bun run gogo examples/hello/Main.gogo --output examples/hello/generated/Main.gogo.json
```

The output is versioned, deterministic JSON UI IR, **not a Godot scene**.

## Proposed later syntax (DOES NOT COMPILE YET)

```xml
<gogo:View xmlns:gogo="urn:estragon:gogo:1"
           xmlns:on="urn:estragon:events:1">
    <gogo:Column gap="12" padding="24">
        <gogo:Text value="Hello, {model.name}!" />
        <gogo:TextInput value="@{model.name}" />
        <gogo:Button label="Increment" on:click="increment" />
    </gogo:Column>
</gogo:View>
```

This example is a **design sketch**, not a promise that the exact component names, event syntax, interpolation or property names are final. Candidate capabilities are reusable custom components, declared namespaces, nested layouts, one-way expressions (`{...}`), two-way bindings (`@{...}`), events, styling and diagnostics tied to source locations.

## Versioning and future evolution

Version the compiled IR separately from the source language. The compiler must reject unknown required features rather than silently interpreting them as Godot nodes. Validate property types and component schemas at build time; generate source maps and stable IDs when the semantic compiler exists.
