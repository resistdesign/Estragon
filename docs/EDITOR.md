# Editing and running Gogo in Godot 4.7

Estragon's optional editor plugin uses the bundled **native GDScript compiler**.
Install Godot and the addon, enable the plugin, edit Gogo and press Play.
**No Bun, Node, TypeScript, executable setting, shell or compiler command is
required.** Repository TypeScript tools are optional contributor/reference tools.
Completion, debugger remapping, live preview and bindings remain future work.

## Getting started

1. Copy `addons/estragon` into a Godot 4.7 project, or open this repository's
   `project.godot`. Enable **Estragon (experimental)** in Project Settings > Plugins.
2. Open `.gogo` files from the FileSystem dock. Godot's normal Script Editor
   selects the Gogo mixed-language highlighter automatically. A tab opened before
   the plugin was first enabled may need reopening; known tabs regain highlighting
   after disable/re-enable.
3. For the working example, open `examples/counter/Counter.tscn`, edit
   `Counter.gogo`, and use Run Current Scene (F6). Set that scene as the main scene
   to use Run Project (F5). The repository's legacy main scene is preserved.
   In a new application, attach the generated surface script to a single Node
   host as in Counter.tscn; Estragon components do not become Godot Nodes/Controls.

There is no compiler setup step. Existing projects may keep an explicit
`gogo.config.json`; fresh projects work without one. Plugin enablement is optional
and is never forced in the owner's checkout or global editor settings by tests.
Legacy Estragon executable/timeout settings are cleared in memory on enable;
they are neither read nor registered, and no fallback process exists.

## Sources and generated resources

Without configuration, scan project sources recursively, excluding the root
`addons` directory, hidden entries, and `generated`, `tests`, `vendor` and
`node_modules` directories. This avoids scanning the addon and dependencies.
An explicit `gogo.config.json` remains authoritative:

```json
{"version": 1, "source_roots": ["examples/compiled", "examples/mixed", "examples/counter"]}
```

Explicit roots are nonempty project-relative files/directories; traversal is
sorted and deduplicated. Missing/invalid roots or configuration block the build.
Roots cannot escape the project or name hidden/excluded paths. Symlink sources
and generated paths are rejected. The repository config deliberately excludes
the legacy namespaced XML demo and invalid test fixtures; keep it when using
this repository. A fresh project needs no config file.

`folder/Screen.gogo` generates `folder/generated/Screen.gd`, and hybrid modules
also generate `Screen.gd.map.json` using the existing version-1 map format.
Standalone mode removes an obsolete hybrid map. The adjacent `generated`
directory is compiler-owned; authored scripts belong elsewhere. Existing scene
paths and UID sidecars are preserved. Byte-identical files are not rewritten. A first native build can normalize older
TypeScript output formatting/map serialization; subsequent unchanged builds do
not churn those files.
Outputs from renamed/deleted sources are not deleted automatically; update scene
references and remove obsolete generated artifacts deliberately.

Every build compiles all sources before touching outputs. Changed code/maps are
staged with rename backups, then validated by Godot at their actual output paths.
A syntax, type, path or publication failure blocks Play and restores prior output
bytes/maps/timestamps. No failed build authorizes stale code to run. Errors during
rollback report the retained backup path for recovery. Transactions prevent
partial output after a reported failure; this is not a filesystem crash journal.

Validation/reloads are dependency ordered using the native lexer for static
extends/preload paths and Godot's literal semantics. Each validated dependency is
refreshed in place before checking its dependents, so cached base fields/types
cannot cause stale checks. Failed transactions restore prior cached code too.
This retains resource/class identity and updates already-loaded dependencies.
Filesystem records are refreshed; newly generated directories request a scan.
Running applications are not hot-reloaded: stop/re-run after editing.

## Save, unsaved edits and Play

Enablement builds current saved sources. Saved Gogo resources and filesystem
changes schedule a short coalesced native build; there is no per-frame source
polling. External edits are detected when Godot scans (normally on window focus);
use Scan Sources if necessary. Background builds use saved sources.

Both Play modes use the same `_build()` gate. It saves native Script Editor
buffers, including modified Gogo TextFile tabs, then compiles and semantically
validates all current source. A Gogo buffer that cannot be saved blocks Play
instead of using old disk content. Dirty edits need no manual Save before Play.
Invalid source appears in the **Gogo** diagnostics panel. Repair it and press
Play again; no compiler restart or external tool recovery is needed.

Compilation is synchronous because Godot's `_build()` requires a boolean result.
Large projects can briefly pause the editor. No external process/timeout setting
exists. Incremental/background compilation is future work. Runtime-only errors,
such as invalid dynamic Callables or sizes, remain runtime errors; compilation
does not execute a UI to prove arbitrary application behavior.

## Highlighting, diagnostics and lifecycle

Godot 4.7 selects the registered `EditorSyntaxHighlighter` for `.gogo` TextFiles.
It colors GDScript declarations, tags, attributes, braces, strings/multiline strings
and code/markup comments. Coloring is approximate for partial/malformed source;
all diagnostics come from the native compiler and Godot semantic validator.
The panel shows original file:line:column. Godot's reload API supplies lines,
not exact error columns; generated spans map to their owning authored location.
Engine diagnostics remain visible. No debugger breakpoint/source remapping or
clickable diagnostic navigation is implemented.

The global `docks/filesystem/textfile_extensions` preference is only appended
with `gogo` when absent, preserving all existing values. It persists on disable.
Disabling removes subscriptions/timers/panel and detaches active Gogo highlighters;
re-enabling restores known tabs and one set of hooks. Generated files remain
usable. Restart uses the same native source discovery/build path.

## Evidence and API boundaries

The independent `sh tools/check-editor.sh` harness runs a copied self-contained
Godot editor and fresh application project with an empty executable PATH, no
repository toolchain/config/generated application scripts, and no user preference
changes. It exercises native file opening/highlighting, saved/unsaved/external
edits, actual main/current scene run commands, button/text/resize/cleanup assertions
in the launched application, malformed/semantic errors blocking both modes,
repair, resource/class identity, plugin lifecycle, no-op behavior and full editor
restart. It also runs native transactional build tests. See TESTING for commands
and graphics/physical-keyboard coverage.

Relevant Godot contracts:

- [Native TextFile highlighter selection](https://github.com/godotengine/godot/blob/5b4e0cb0f/editor/script/script_editor_plugin.cpp#L2314).
- [Common main/current run path](https://github.com/godotengine/godot/blob/5b4e0cb0f/editor/run/editor_run_bar.cpp#L255)
  and [EditorPlugin._build](https://docs.godotengine.org/en/4.7/classes/class_editorplugin.html#class-editorplugin-private-method-build).
- [Resource.set_path_cache](https://docs.godotengine.org/en/4.7/classes/class_resource.html#class-resource-method-set-path-cache)
  for isolated semantic validation; explicit Script reloads then synchronize the
  committed editor resources without replacing them.
