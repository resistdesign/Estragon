# Editing `.gogo` in Godot

**Status: file-extension integration only.**

We want **first-class Gogo editing in Godot 4.7**, including TSX-like GDScript/markup composition and automatic Gogo-to-GDScript transpilation, without turning authored UI components into Godot `Control` nodes. See [design direction](DESIGN_DIRECTION.md).

## What the scaffold plugin does

`addons/estragon/editor/plugin.cfg` registers an optional editor plugin. When enabled it adds `gogo` to the editor's `docks/filesystem/textfile_extensions` setting, so Godot can treat `.gogo` as an editable text format.

**Important:** this setting is **global to your Godot editor**, not scoped to the Estragon project, and the extension remains registered when the plugin is disabled. The plugin does not remove or overwrite your existing extension entries. Depending on the editor state, you may need a filesystem rescan or editor restart to see existing `.gogo` files.

To enable it: open `project.godot`, go to **Project > Project Settings > Plugins**, and enable **Estragon (experimental)**. Or add `gogo` yourself in **Editor > Editor Settings > Docks > FileSystem > Textfile Extensions** without enabling the plugin.

## What the plugin does NOT do yet

It does not highlight mixed Gogo/GDScript syntax, call the Bun/TypeScript compiler, generate GDScript, provide diagnostics/completion, watch files, or display a UI preview. Those are future features. Its current JSON compiler path is temporary scaffolding.

## Intended editor architecture

- Treat `.gogo` as a first-class **mixed GDScript plus XML-like component language**. Prototype reliable file opening, code/markup highlighting and language switching in Godot 4.7; the existing text extension registration alone is insufficient.
- Investigate `EditorSyntaxHighlighter`, `ScriptEditor` hooks, a custom text editor or language-server-style integration for nested markup, GDScript expressions, diagnostics and references; verify that highlighting is actually applied to `.gogo` files.
- Reuse the Gogo hybrid compiler's type/component registry and source maps for diagnostics, completion, navigation and reliable generated GDScript debugging.
- Provide completions for Estragon components, **not** raw Godot `Control` classes; include props/events and data-binding paths.
- Add build-on-save and pre-run transpilation to generated `.gd` files. On compile failure, report original source locations and refuse to run stale generated output.
- Preview the **Estragon renderer output** in an editor viewport; never substitute Godot's stock GUI scene builder for the application preview.
- Consider a dedicated editor workspace for source, component outline, diagnostics, property inspector and live preview. Godot `Control` nodes may of course implement the editor *tooling UI*; the restriction concerns Estragon-rendered application components.

We are intentionally not beginning with `EditorImportPlugin`; treating the editable source file as an imported resource can interfere with ordinary text-file opening. Verify the hybrid-source editor experience with a real Godot 4.7 prototype before promising automatic syntax selection, diagnostics or navigation. `@Bindable` in ordinary `.gd` has a **separate pre-parse integration obstacle**, not solved by Gogo file recognition.

Godot APIs to investigate:
- [EditorPlugin](https://docs.godotengine.org/en/stable/classes/class_editorplugin.html)
- [EditorSyntaxHighlighter](https://docs.godotengine.org/en/stable/classes/class_editorsyntaxhighlighter.html)
- [ScriptEditor](https://docs.godotengine.org/en/stable/classes/class_scripteditor.html)
- [CodeEdit](https://docs.godotengine.org/en/stable/classes/class_codeedit.html)
