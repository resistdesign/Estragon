# Editing and running Gogo in Godot 4.7

**Implemented in T08:** native text-file editing, automatic mixed-language
highlighting, build on saved/source changes, authored diagnostics and compilation
before both Run Project and Run Current Scene. Completion, language-server
navigation, debugger source maps, live preview and bindings remain future work.

## Native compiler migration (accepted; not yet implemented)

**ADR-0012:** T08 uses Bun only as a **temporary editor build bridge**. The owner manually verified changing Counter.gogo font size and pressing Play on 2026-10-28. The next work is N01 native parser, N02 native GDScript emission and maps, and N03 a fully Godot-native editor build with **no Bun executable or external process**. This comes before bindings and legacy retirement.

Until N03 merges, the Bun setup instructions below remain accurate for **the current T08 plugin**. After N03, users must be able to install Estragon and compile Gogo with Godot alone. Preserve source mapping, highlighter, F5/F6 fail-closed behavior, saved and unsaved edits, and diagnostics, without silently falling back to Bun. See [execution plan](EXECUTION_PLAN.md).

## One-time setup

1. Install Bun 1.4.4. Open the root `project.godot` in the pinned Godot 4.7 editor.
2. Enable **Estragon (experimental)** in Project > Project Settings > Plugins.
   The plugin remains optional and is never force-enabled by the repository.
3. If a GUI-launched editor cannot find Bun, set **Estragon > Editor > Bun
   Executable** in Project Settings to the absolute executable path. Turn on
   Advanced Settings if needed. Paths with spaces are supported. No shell is
   launched: shell startup files, aliases and version-manager initialization are
   not used. Automatic lookup checks the editor's inherited PATH, `~/.bun/bin`
   and common Homebrew locations. An explicitly configured invalid path is an
   error, not a fallback to a different executable.
4. Double-click `examples/counter/Counter.gogo` in the FileSystem dock. It opens
   in Godot's normal Script Editor with the **Gogo** highlighter automatically.
   Files already open before first enable may need closing/reopening; Godot's
   highlighter registration does not retroactively select them. Known tabs
   regain Gogo highlighting after plugin disable/re-enable.
5. Open `examples/counter/Counter.tscn` and use Run Current Scene (F6; Command-R
   on macOS). To demonstrate Run Project (F5), set this scene as the main scene
   in your local project settings first. The repository's legacy main scene is
   preserved. **No manual compiler command is needed during normal development.**

The text-extension setting `docks/filesystem/textfile_extensions` is global to
Godot and persists on disable, as in the earlier plugin. Estragon only appends
`gogo` if absent and preserves existing entries verbatim. It does not enable
external editors or overwrite editor preferences. Disabling stops compilation,
removes hooks/panel and replaces active Gogo coloring with a native plain
highlighter; generated files remain usable. Re-enable restores hooks once.

## Source discovery and output policy

`gogo.config.json` at the project root has the strict shape:

```json
{
  "version": 1,
  "source_roots": ["examples/compiled", "examples/mixed", "examples/counter"]
}
```

Only these project-relative roots are compiled, recursively and in sorted order.
Overlapping roots deduplicate. Add your application directory (for example `ui`)
when introducing sources. Hidden directories, `generated`, `tests`, `vendor` and
`node_modules` are skipped. A root cannot escape the project or name an excluded
path; symlink sources/outputs are rejected. This avoids invalid test fixtures,
dependencies and the legacy namespaced XML/JSON demo. Do not configure the legacy
demo as a new-compiler source. Missing/malformed config or roots block Play.

`folder/Screen.gogo` produces `folder/generated/Screen.gd` and, for hybrid source,
`Screen.gd.map.json`. The adjacent `generated` directory is compiler-owned;
authored scripts belong elsewhere. Existing examples/scenes keep their paths.
Source names are stable project-relative paths, so checked-in code/maps match
manual CLI output. Source is never rewritten. UID sidecars are left intact.
Unchanged outputs are not rewritten. All sources pass the Gogo frontend before
any output is touched; a frontend failure preserves the previous outputs.

Outputs from deleted/renamed sources are not automatically deleted: update scene
references and remove obsolete generated artifacts deliberately. This plugin
builds configured sources, not an import/export or source migration system.

## Save and Play behavior

Saved Gogo resources and Godot filesystem changes schedule a short coalesced
build. This uses native editor notifications, not per-frame source polling.
External changes are detected when Godot scans them (normally on window focus);
use Scan Sources if necessary. Invalid saved source appears in the **Gogo**
bottom panel; it does not make stale generated output eligible for Play.

Before either Play action, `_build()` saves native Script Editor buffers and
runs the authoritative build regardless of the background build state. The same
hook gates F5/F6. Bun runs the existing TypeScript pipeline, then the standard
Godot executable checks every configured generated script in a separate headless
process. Native GDScript parse/type errors are mapped back to original Gogo
coordinates while retaining engine diagnostics. The hook returns false on any
failure, so Godot does not start the game. Fix the source and press Play again.

A successful build updates Godot's filesystem records for changed `.gd` paths.
The newly launched game reads the fresh files. Running games are not hot-reloaded;
stop/re-run after edits. These are ordinary generated scripts, not an interpreter.
GDScript semantic errors can leave a newly generated but invalid `.gd` on disk;
the build still fails and execution is blocked. Runtime-only errors (for example
an invalid dynamic Callable or out-of-range computed size) remain runtime errors;
this is not a promise to execute user code safely during compilation.

The editor build is synchronous to honor Godot's boolean `_build` gate. The UI
can pause briefly during a build. **Build Timeout Seconds** defaults to 30 and is
bounded to 1–120; each native script check also has a 10-second limit. A missing
Bun/compiler, launch failure, crash, malformed/missing report or timeout is a
visible failure. No shell quoting or shell-specific configuration is required.
Large projects and incremental/background compilation are future optimization.

## Highlighting and diagnostics

The registered `EditorSyntaxHighlighter` advertises the `gogo` extension. Godot
4.7 selects it for TextFile resources; Estragon does not register Gogo as a
GDScript language or import it as a scene. The normal Script Editor retains its
search, save and other text-editing facilities. Lexical coloring distinguishes
GDScript declarations, component tags, attributes, expression braces, strings
(including multiline strings), and code/markup comments. It is presentation-only,
not the compiler parser; ambiguous/malformed partial code may be colored
approximately. Compiler diagnostics always come from the TypeScript pipeline
and native Godot checks, not the highlighter.

The **Gogo** bottom panel shows original file:line:column diagnostics and native
mapped traces; select/copy them to locate the authored source. There is no custom
completion service, clickable diagnostic navigation or debugger breakpoint
remapping yet. Generated `.gd` remains inspectable; edit the `.gogo` source.

## Verified APIs and limits

Godot 4.7's pinned source establishes two relevant contracts, also exercised by
our isolated editor tests:

- [ScriptEditor extension selection](https://github.com/godotengine/godot/blob/5b4e0cb0f/editor/script/script_editor_plugin.cpp#L2314)
  selects registered highlighters by extension for text files. Registration alone
  does not update already-open files; unregistering alone leaves their active
  highlighter in place, so Estragon explicitly detaches its active instances.
- [EditorRunBar run path](https://github.com/godotengine/godot/blob/5b4e0cb0f/editor/run/editor_run_bar.cpp#L255)
  handles both main/current scene modes, autosaves, then calls the editor build
  gate. See also [`EditorPlugin._build`](https://docs.godotengine.org/en/4.7/classes/class_editorplugin.html#class-editorplugin-private-method-build).

`bun run test:editor` uses a copied, self-contained Godot executable and isolated
project/settings to test actual native file opening, automatic highlighter
assignment, saving and both run commands. Test drivers never enable the plugin
in the user's project or modify global editor settings. On macOS the copied
binary is ad-hoc signed for local test execution only. See TESTING for precise
coverage and the separate manual keyboard/visual procedure.
