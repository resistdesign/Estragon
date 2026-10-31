# C01-C callback compatibility and progressive diagnostics

Tracking: [#46](https://github.com/resistdesign/Estragon/issues/46), parent #41.
Base: `005ce53` (C01-B #53 and documentation #56 merged).
The [owner refinement](https://github.com/resistdesign/Estragon/issues/46#issuecomment-6534935109)
approves a narrow progressive-enhancement fallback after the investigation below.
Godot 4.0–4.2 skip unsupported proactive arity introspection; all versions retain
validity, direct-target disposal, connection and automatic lifecycle checks.
Godot 4.3+ retains early zero-argument validation, including optional parameters.
No arbitrary Callable provenance restriction, adapter system or minimum-version
increase is introduced.

## Implementation

Native and optional reference emitters retain typed Callable factory inputs.
Each generated event aliases its already-evaluated argument to a uniquely named
Variant, then short-circuits the native `get_argument_count()` query behind
`Engine.get_version_info()["minor"] >= 3`. Variant dispatch prevents the older
parser from statically resolving the missing Callable API; the version guard
prevents its execution there. Authored expressions still evaluate once in their
original order, and every emitted line maps to the event expression's source span.
The same Variant alias supplies target lookup: typed Callable.get_object()
returns a boolean instead of its object in the measured 4.0.4 path; dynamic
dispatch returns the actual target. This small bridge preserves direct disposed-
target rejection. Connection and lifecycle behavior remain unchanged.

The captured-payload test observes WeakRef through a separate helper frame.
Godot 4.0 retains an inline get_ref() expression temporary until the calling
function returns; the test's own earlier liveness observation otherwise keeps
the payload alive. Both mounted retention and immediate unmount release remain
asserted; no warmup, delay or engine-version exemption is used.

On older engines, an incompatible required/unbound callback connects and reports
the normal signal-invocation error when activated. Old Godot also logs a
method-name lookup error while formatting a failed opaque-lambda invocation;
the tests require this exact two-error sequence rather than suppressing it. An optional-argument callback
runs using its default. Neither is invoked during construction. Newer engines
reject both required and optional arity before connection. This difference is
explicitly approved; lack of introspection does not reject valid opaque Callables.

## Required behavior

Button.pressed accepts a native Callable expression, including local variables,
factory parameters, computed/returned Callables, bound methods and lambdas.
Expressions evaluate once in authored order. Before connection, all versions reject invalid Callables and direct disposed
component targets. On 4.3+, the guard additionally rejects every nonzero remaining
argument count (including optional parameters). Normal activation,
source-mapped errors, single connections and owner cleanup must remain intact.
Validation must not invoke application callbacks merely to discover their arity.

Godot 4.0–4.2 lack `Callable.get_argument_count()`. Replacing it with ordinary
method reflection solves only a subset, not the accepted arbitrary Callable
boundary. The opaque cases below include existing supported authoring forms,
not speculative language extensions.

## Reproducible capability experiment

The existing `tools/check-compatibility.py` collector runs
`tests/compatibility/callback_metadata.gd` in an isolated minimal project, with
external tools absent from Godot PATH. `tools/callback_metadata_evidence.py`
requires all **21** observations, completion and exact expected engine diagnostics.
No application callback runs during inspection. A transient test signal is
connected/disconnected without emission to test the native connection validator.
The effects array must remain empty.

Cases cover required/default/zero-argument methods, bound and unbound methods,
static callbacks, captureless/self/captured/named/returned lambdas, bound/unbound
lambdas, and empty/missing/freed-target Callables. Fixed test-only native arity queries run
on 4.3+; no unsupported query is compiled on older engines. Existing production
signal/lifecycle tests run separately and remain the behavioral authority.

```sh
python3 tools/check-compatibility.py \
  --engine 4.0.4=/absolute/official/godot-4.0.4 \
  --engine 4.7.2=/absolute/official/godot-4.7.2 \
  --output /new/c01-c-evidence --editor --collect-only
```

Repeat `--engine` for each pinned official version in the existing manifest.
`callback_metadata_probe=PASS` means the experiment/evidence assertions
completed. It is **not** successful callback portability. The separate
`callback_arity_api` stage remains **BLOCKED on 4.0–4.2**. Generated Counter parse
and generated-signals results retain their real failures on those versions.
`--collect-only` never promotes them to success. Unexpected errors, missing
observations, changed metadata conclusions or unexpected counts fail the probe.

## Recorded matrix

[Structured results](../tests/compatibility/c01-c-results.json) record exact
versions, binary hashes, 21 observations per engine and individual stages.
The initial investigation snapshot is superseded by implementation verification.
`callback_guard_*` processes independently check empty, missing, freed and disposed
targets, required/optional methods and lambdas, and unbound callbacks. Expected
engine errors are counted exactly and matched to authored source or normal
invocation diagnostics. Generated-signals tests exercise evaluation order, bound
optional/static callbacks, pointer activation, no duplicate connections and cleanup.
Other compatibility failures remain visible, including #48 cold Text-first loading
and #44 filtered highlighting. Headless evidence does not certify graphics.

## Findings

- Named method metadata exposes declared argument arrays; Script metadata also
  exposes defaults. Optional arguments must still count toward arity, matching
  the current contract. Bound method values/counts can be inspected.
- Captured/self and returned lambdas do not appear in Object or Script method
  lists. On 4.0–4.2, querying `get_method()` for those forms emits a native
  `Can't get method on CallableCustom ... (lambda)` error. Some captureless
  forms expose a name on later engines; a name still does not supply a signature.
- A zero-argument lambda and a one-required-argument lambda have identical
  signature-relevant 4.0 observations: validity/custom/null flags, object ID,
  display/name, bound count/values and empty reflected metadata. Optional-argument
  and zero-argument lambdas likewise match. Named lambdas deliberately use the
  same name; returned lambdas cross the same Callable factory boundary. Opaque
  identity/hash values are not documented arity metadata.
- `Signal.connect()` returns OK for every valid case, including nonzero required
  and optional arity. Connection success cannot replace the pre-connection guard.
- On 4.3+, the native count distinguishes the same pairs: zero reports 0,
  required/optional report 1, bound one-argument callbacks report 0 and unbinding
  a zero-argument callback reports 1. Those facts are independently asserted.

This blocks a complete reflection-based replacement. It does **not** establish
that every named/native/custom callable variant has a complete fallback; no
partial strategy is shipped as a universal validator.

## Primary engine/API evidence

The [published 4.0 Callable API](https://docs.godotengine.org/en/4.0/classes/class_callable.html)
has validity, object/method, binding and identity operations but no argument-count
query. [Object method metadata](https://docs.godotengine.org/en/4.0/classes/class_object.html#class-object-method-get-method-list)
and [Script method metadata](https://docs.godotengine.org/en/4.0/classes/class_script.html#class-script-method-get-script-method-list)
describe registered methods, not opaque lambda function/capture internals.

Version-pinned source confirms the observed gap:

- [4.0.4 GDScript lambda implementation](https://github.com/godotengine/godot/blob/4.0.4-stable/modules/gdscript/gdscript_lambda_callable.cpp):
  underlying function and capture data are internal; the lambda implementations
  do not expose the later arity query. A bound object/script ID is not a function
  signature. Inspecting source text cannot identify which of multiple identical
  lambda names an arbitrary incoming Callable represents.
- [4.0.4 Callable implementation](https://github.com/godotengine/godot/blob/4.0.4-stable/core/variant/callable.cpp):
  default `CallableCustom::get_method()` reports an error. Public validity and
  binding metadata do not reveal the hidden lambda function's declared arity.
- [4.0.4 Object connection implementation](https://github.com/godotengine/godot/blob/4.0.4-stable/core/object/object.cpp):
  native connection checks do not provide the required arity guarantee; the
  experiment confirms connect succeeds without running the target.
- [4.3 GDScript lambda implementation](https://github.com/godotengine/godot/blob/4.3-stable/modules/gdscript/gdscript_lambda_callable.cpp):
  the added native arity implementation reads the internal function argument
  count and subtracts captures. That information is unavailable through the
  earlier supported GDScript reflection surface.

The conclusion is limited to preserving the existing arbitrary-Callable boundary
with supported Godot 4.0 addon APIs. It is not a claim that compiler-owned callback
representations are impossible. Those change the representation/source boundary
and need an explicit design decision and separate implementation proof.

## Alternatives assessed

| Approach | Why it does not satisfy the current contract unchanged |
| --- | --- |
| Object/Script method-list lookup plus bound count | Useful for registered methods; opaque lambda signatures are absent |
| Callable method name / display string / hash | No signature; identical names and returned lambdas defeat source association; identity is not arity |
| Native Signal.connect success | Accepts invalid arity too; experimentally disproved as a validator |
| Invoke/callv the candidate during validation | Runs user code early, changes state/evaluation order, may block or fail, and cannot safely distinguish an application exception from a signature error |
| Wrap any incoming Callable in a new zero-argument function | Verifies only the wrapper; the original incompatible Callable is unchecked |
| Reject every custom Callable on old engines | Breaks bound methods and supported lambdas; requires owner-approved feature reduction |
| Accept every custom Callable or remove the count check | Loses the required pre-connection rejection; explicitly disallowed |
| Find a lambda by reading its script text/name | Cannot associate arbitrary parameter/returned/native external Callables reliably; no regex/source rewriting substitute |
| Engine fork/GDExtension or raising the engine minimum | Conflicts with the accepted bundled-GDScript/Godot-4.0 baseline; not proposed as an implementation shortcut |

## Decision and continuity

The initial investigation correctly rejected method reflection, connection
success and unchecked wrappers as universal pre-connection arity proof. The owner
then explicitly approved normal older-engine invocation semantics rather than
an elaborate callback representation or an opaque-Callable restriction.
[AGENTS.md](../AGENTS.md) and [DECISIONS.md](DECISIONS.md) record this as a
repository-wide engineering principle: implement small safe compatibility bridges;
where bridging is disproportionate, preserve valid behavior and reserve optional
early diagnostics for capable engines.

Cold Text-first dependency loading remains #48. C01-D numeric work, reactivity,
Box/padding and the approved but deferred unit helpers (#54/#56) are untouched.
C01-C remains in review until its sole PR is approved and merged; do not start a
successor implementation or claim full-addon certification from this scoped fix.
