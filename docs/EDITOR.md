# Editing `.gogo` in Godot

**Status: file-extension integration only.**

We want Gogo to feel native in the Godot editor without turning Gogo components into Godot `Control` nodes.

## What the scaffold plugin does

`addons/estragon/editor/plugin.cfg` registers an optional editor plugin. When enabled it adds `gogo` to the editor's `docks/filesystem/textfile_extensions` setting, so Godot can treat `.gogo` as an editable text format.

**Important:** this setting is **global to your Godot editor**, not scoped to the Estragon project, and the extension remains registered when the plugin is disabled. The plugin does not remove or overwrite your existing extension entries. Depending on the editor state, you may need a filesystem rescan or editor restart to see existing `.gogo` files.

To enable it: open `project.godot`, go to **Project > Project Settings > Plugins**, and enable **Estragon (experimental)**. Or add `gogo` yourself in **Editor > Editor Settings > Docks > FileSystem > Textfile Extensions** without enabling the plugin.

## What the plugin does NOT do yet

It does not highlight Gogo syntax, call the Python compiler, show inline errors, regenerate IR automatically, watch files, provide completion or display a UI preview. Those are next-stage features.

## Intended editor architecture

- Register `.gogo` as a text format; use the existing script/text editing surface initially.
- Register an `EditorSyntaxHighlighter` for Gogo markup, attribute values and binding expressions; make selection/association reliable for `.gogo` files.
- Use the Gogo compiler as a language service (parser, type/component registry, diagnostics, symbol index and source maps).
- Provide completions for Estragon components, **not** raw Godot `Control` classes; include props/events and data-binding paths.
- Add build-on-save and a pre-run compilation check, with error location mapping.
- Preview the **Estragon renderer output** in an editor viewport; never use Godot's stock GUI scene builder as the preview renderer.
- Consider a dedicated editor workspace for source, component outline, diagnostics, property inspector and live preview. Godot `Control` nodes may of course implement the editor *tooling UI*; the restriction concerns Estragon-rendered application components.

We are intentionally not beginning with `EditorImportPlugin`; treating the editable source file as an imported resource can interfere with ordinary text-file opening. The best editor/LSP integration path should be verified with a working prototype before promising automatic syntax selection or rich navigation.

Godot APIs to investigate:
- [EditorPlugin](https://docs.godotengine.org/en/stable/classes/class_editorplugin.html)
- [EditorSyntaxHighlighter](https://docs.godotengine.org/en/stable/classes/class_editorsyntaxhighlighter.html)
- [ScriptEditor](https://docs.godotengine.org/en/stable/classes/class_scripteditor.html)
- [CodeEdit](https://docs.godotengine.org/en/stable/classes/class_codeedit.html)
