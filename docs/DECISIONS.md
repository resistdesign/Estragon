# Architecture decisions and open questions

This file is a lightweight decision log. Decisions marked **provisional** are not settled by the code scaffold.

## ADR-0001 — Own the UI stack

**Status: accepted. 2026-10-25.**

Estragon is **not** a declarative generator for Godot `Control` nodes. Estragon manages its own components, layout, styling, input handling, observable state and graphics rendering. Godot provides hosting, platform/window/input facilities and graphics APIs. A small host node is acceptable. Per-component node adapters, if they are ever introduced, must be **optional**.

## ADR-0002 — Naming

**Status: accepted. 2026-10-25.**

Estragon names the framework. Gogo names the language and its compiler; markup files end in `.gogo`. Inspiration comes from Adobe Flex's MXML and bindability, but the actual markup is a new language, not MXML compatibility mode.

## ADR-0003 — Graphics API and backends

**Status: provisional. 2026-10-25.**

The initial proof uses `RenderingServer` canvas primitives to render pixels without `Control` nodes. This is not a selection of the final engine backend. Investigate `RenderingDevice`, custom shaders, batching and native/GDExtension implementation when we have representative UI workloads. Keep IR, component tree, layout and binding independent of the graphics interface.

## ADR-0004 — Bindable syntax strategy

**Status: provisional. 2026-10-25.**

The desired experience is `@Bindable` in ordinary user-authored `.gd`, transformed into typed getters/setters and notifications. **Stock GDScript does not accept arbitrary addon-defined annotations**, and a simple `EditorPlugin` cannot register them. Explore real pre-parse source transformation/editor integration before considering a separate source extension (`.bgd`) or engine/parser modification. None of these mechanisms is confirmed; do not silently replace the requested `.gd` experience with `.bgd`.

**R01 evidence, 2026-10-29 (not an alternate architecture decision):** [Feasibility report](BINDABLE_FEASIBILITY.md) records native runtime, loader/cache/remap/import/language and real ScriptEditor experiments. Fixed generated setters work, but native authored-buffer validation rejects `@Bindable` independently of those loading hooks. No complete supported stock 4.7 integration was found. Retain the requested ordinary `.gd` experience as unmet; obtain an explicit owner decision before adopting a different source boundary or engine dependency.

## ADR-0005 — Edit the original Gogo source

**Status: provisional. 2026-10-25.**

Favor Godot's editable text-file workflow plus editor plugin first; do not convert Gogo source to a `.tscn` tree. Later, add semantic editing, build integration and a preview backed by the actual Estragon renderer.

## ADR-0006 — Project license

**Status: accepted. 2026-10-25.**

Estragon is distributed under the [MIT License](../LICENSE).

## ADR-0007 — Gogo generates GDScript with TSX-like authoring

**Status: accepted direction. 2026-10-26.**

Gogo (`.gogo`) should support **XML-like component expressions directly mixed with GDScript**, borrowing TSX's compositional authoring model and Flex 4's runtime/component principles. Component tags are **unprefixed** (`<VBox>`, `<Button>`); mandatory XML namespace prefixes and `xmlns` declarations are rejected as the product direction. The transpiler generates valid GDScript for typed Estragon components, automatic event/signal wiring, and later bindings. The first prototype's JSON output and namespaced XML are **temporary scaffolding**, not the final language contract.

The *experience* is accepted; precise grammar, imports, binding semantics, parser architecture, editor integration, GDScript class organization, and handling `@Bindable` in ordinary `.gd` files are still open engineering decisions. See [design direction](DESIGN_DIRECTION.md).


## ADR-0008 — Framework-owned automatic component lifecycle

**Status: accepted user requirement, 2026-10-26; T03 implementation reviewed in its PR.**

Application developers must not call `dispose()` during normal Estragon usage.
A surface owns its root and renderer; unmounting/replacing a root or leaving the
scene tree automatically cleans components, subscriptions and rendering resources.
Container removal/replacement likewise unmounts and cleans; direct adoption into
a new parent transfers ownership without disposal. Live surface roots cannot
have another owner. Internal cleanup remains idempotent and terminal.

This explicitly supersedes T02's manual-dispose/remove-to-detach convention.
The user requested this correction for T03; it is not a compiler or binding change.
Keep root/child transfer checks separate from cleanup so moving a subtree does
not destroy it. Deterministic cleanup executes in live owners, not RefCounted
final-deletion callbacks (calling instance cleanup there failed in Godot 4.7).
Raw unmounted values remain reference-counted data; normal application UI is
mounted in a surface. No Node or graphics resource per component is introduced.

T03 uses deliberately narrow fixed/auto/fill sizing and stack gaps, documented
in ARCHITECTURE. These are the first tested rules, not automatic Flex/CSS semantics;
broader sizing/alignment remains an open future design.

## ADR-0009 — Minimal GDScript-first hybrid composition

**Status: T05 implementation contract, reviewed with its implementation PR.**

T05 composes lexically retained GDScript with parsed component expressions and
balanced braced GDScript property/child expressions. No XML document wrapper,
script block or mandatory code-behind is introduced. T04 standalone markup
continues unchanged. The full future language is not fixed by this initial slice.

Lower markup AST nodes to typed static factories within the authored module.
Arguments are evaluated once in authored scope/source traversal order before
construction; nested native conditionals remain lazy. This preserves local/member
references without rewriting variable names or depending on Callable Variant
return inference. Helper names avoid module identifiers and indentation follows
authored GDScript. Application surfaces mount explicitly with set_root; existing
automatic lifecycle remains intact. No reactive expression reevaluation is implied.

Godot supplies GDScript syntax/type authority; the TypeScript frontend supplies
markup/type compatibility, expression boundaries and range maps. Dynamic types
and runtime constraints are not falsely advertised as statically proven.
Range-map sidecars and mapped Godot checks provide traceability without claiming
editor/debugger integration. Named inner-class markup, collection expansion,
bindings, widget/signal features and full semantic analysis remain outside T05.

## ADR-0010 — Minimal generated Button signal connections

**Status: T07 implementation contract, reviewed with its implementation PR.**

Gogo resolves Text/Button to the existing independent runtime classes. In hybrid
modules only, `Button pressed={expression}` accepts a native GDScript Callable.
Ordered typed signal/property attributes retain construction-time evaluation
order. A typed Callable factory argument preserves authored scope; ordinary
synchronous signal connection code is generated exactly once per new component.
No string-handler dispatch, runtime markup interpretation or new event framework
is introduced. Godot owns GDScript syntax/types; generated validity/arity guards
require zero remaining arguments (including optional parameters in metadata).
Bound argument types and arbitrary closure effects remain native runtime concerns.

T06's automatic teardown disconnects outgoing connections. T07 also disconnects
incoming direct method connections on terminal components so live sources cannot
invoke retained disposed targets. Transfers preserve connections/identity. Counter
uses explicit root rebuilding with framework-owned cleanup; reactive bindings and
editor integration remain T09/T08. See GOGO_LANGUAGE for supported props, callback
limits, mapped diagnostics and the runnable no-handwritten-connection example.

## ADR-0011 — Native editor authoring and synchronous compile-before-Play

**Status: T08 foundation; its external compiler contract below is superseded by N03/ADR-0012. TextFile/highlighter contracts remain implemented.**

Use Godot 4.7's native TextFile/ScriptEditor and registered EditorSyntaxHighlighter
with `gogo` extension association. Pinned engine source and isolated real-editor
tests demonstrate automatic selection for new tabs; no replacement IDE or source
importer is needed. **E01 correction:** registration alone misses existing tabs,
and native cached Plain Text state can override extension selection on restore.
An event-driven deferred association pass repairs open/restored `.gogo` tabs;
non-Gogo highlighters and preferences are preserved. The resource-path adapter's
version-sensitive native-list fallback and test coverage are documented in EDITOR.
Disable detaches active Gogo highlighters and owned hooks; re-enable repairs tabs.

The project declares strict source roots in gogo.config.json. Output is adjacent
`generated/<name>.gd` plus hybrid maps, preserving existing scenes and UID files.
Exclude tests/dependencies/legacy explicitly; never rewrite authored Gogo. Reuse
the existing TypeScript pipeline, compiling every source before writing outputs.
Unchanged files are not rewritten. No automatic source deletion migration occurs.

Saved-resource/filesystem notifications coalesce a build. Both native Play modes
share EditorPlugin._build; save buffers and synchronously gate execution on the
bounded direct Bun subprocess and native Godot script validation. No shell is
used; configure an absolute Bun executable when GUI PATH discovery is insufficient.
Any frontend/process/semantic error aborts Play and appears with authored source
locations. Successful output paths update the resource filesystem; fresh game
processes execute current code. Running games are not hot-reloaded.

This intentionally accepts a brief editor pause for the boolean build gate.
Incremental/background compilation, completion/navigation, debugger integration
and live preview remain future work. Tests use a copied self-contained editor
with isolated project/settings, never the user's persistent editor configuration.
See EDITOR/TESTING for setup, API evidence, guarantees and manual procedures.

## ADR-0012 — Gogo compilation must run natively inside Godot

**Status: accepted owner decision, 2026-10-28; N01–N03 native compiler/editor implemented.**

**Decision:** Users installing and working with Estragon in Godot require **only Godot and the addon**. The Gogo compiler must be bundled and authored in **GDScript**, supporting native lexical/semantic markup processing, GDScript generation, source maps and editor build/Play diagnostics **without Bun/Node/TypeScript installed, configured or spawned**. No new external compiler process, runtime markup/JSON interpreter, engine fork, GDExtension binary or per-component Godot Node/Control is an acceptable substitute without another explicit decision.

**Why:** T04–T07 prove Gogo with a Bun/TypeScript compiler. T08 PR #29 proves the Godot editor can automatically build on save and before F5/F6 through a bounded Bun subprocess; the user personally verified a font-size Gogo edit and Play on 2026-10-28. They explicitly reject Bun as a required developer tool. Therefore **T08/ADR-0011's Bun subprocess and executable configuration are transitional**, not the chosen final architecture.

**Execution:** N01 native GDScript lexer/parser/typed frontend → N02 native emitter/maps, T04–T07 parity and interactive Counter → N03 no-Bun native editor cutover with real F5/F6 failure/recovery tests in a fresh Godot-only project. These tasks move **ahead of T09/T10**. Preserve existing working T08 behavior until N03 passes; do not silently fall back to Bun once cut over. TypeScript/Bun may remain **optional developer/CI reference tests**, never user-facing editor dependencies.

**N01/N02 implementation:** The addon now includes a scene-independent native lexer, hybrid parser, typed built-in validation and source-located diagnostics. Godot-only tests consume checked reference transcripts with Bun unavailable. N02 adds deterministic native GDScript emission, version-1 range maps and explicit native semantic validation. Godot-only Counter/fixture tests prove input, evaluation and lifecycle parity with external tools unavailable. Validation uses a scoped Logger/reload window and Resource.set_path_cache() with the actual output path (including class_name identity), never taking over cached application scripts; Godot reports lines rather than exact columns. N03 directly integrates the compiler/validator into the editor, with no Bun fallback or executable setting. See GOGO_LANGUAGE for API and parity boundaries.

**N03 editor contract:** All compiler modules are tool-callable. Explicit configured roots remain authoritative; absent config scans project sources with addon/dependency/generated/hidden/test exclusions, enabling a setup-free fresh addon. Stage all changed code/maps with rename backups; reject/restore on failure before authorizing Play. Order validation/state-preserving reloads from lexer-proven static resource paths, decoded with native Godot string semantics; refresh dependencies before dependents and roll cached code back on failure; filesystem updates alone do not guarantee fresh GDScript bytecode. Preserve no-op bytes/UIDs and native TextFile highlighting/save behavior. Fresh isolated editor/game tests run with an empty executable PATH, no repository toolchain or generated fixtures, and cover both Play modes, failures/repairs, input/layout, cached identity and restart. Physical keyboard/window-manager checks remain distinct from automated run-command evidence.

**Cost/constraints:** Temporary compiler duplication is acceptable to establish semantic parity. Keep codegen independent of EditorInterface, renderer and application scene tree. Preserve accepted Gogo syntax, deterministic output, authored source maps, event/callback semantics, lifecycle and fail-closed builds. GDScript type semantics remain Godot's responsibility. This does not solve arbitrary `@Bindable` annotations in ordinary authored `.gd`; R01/T09 remain separate.

## Unresolved, intentionally not invented

- **Final rendering implementation:** RenderingServer vs RenderingDevice/native backend, multi-platform strategy.
- **Bindable source integration:** preserve the desired `@Bindable` annotation in ordinary authored `.gd`; prove a workable pre-parse/tooling mechanism or evaluate explicit fallbacks.
- **Gogo language:** TSX-like GDScript/markup grammar, component import/resolution, typed expression/event/binding semantics and optional markup-only shorthand.
- **Node integration:** which components, if any, deserve optional Godot node wrappers.
- **Layout/style semantics:** borrow selected Flex ideas, establish a new model, or align with modern UI layouts.
- **Text and accessibility:** text shaper/platform integration, IME, screen readers and testable semantics.
- **Editor architecture:** ScriptEditor plugin vs standalone Gogo authoring surface vs language server.
- **Mixed-authoring implementation:** reliable source mapping, parsing GDScript expressions alongside markup, and optional code-behind.

When any of these is decided, record the rationale and tradeoffs here before implementation.
