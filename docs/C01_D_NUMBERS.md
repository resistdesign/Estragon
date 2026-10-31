# C01-D: numeric emission without a lossy formatting round trip

Tracking: [#47](https://github.com/resistdesign/Estragon/issues/47), parent #41.
Base `68f1ec4` includes merged C01-C #57. **Scope is native Godot numeric
semantics, not a correctly-rounded decimal parser or full-addon certification.**
The owner explicitly selected this scope on 2026-10-31 after reviewing the
source-parser limitations below. No additional numerical-contract decision is pending.

## Root cause and trace

The previous pipeline was quoted decimal → `String.to_float()` → typed float →
`JSON.stringify(..., full_precision=true)` → generated GDScript → native tokenizer
→ float → component property. Two independent losses were measured:

1. Godot 4.0–4.5 JSON formatting expands `1e-20` to
   `0.00000000000000000001`. Their native parser counts leading zeros against
   an 18-digit mantissa budget and reads that token as zero. The original
   scientific input and typed float were correct; emission introduced the loss.
   Fixed-decimal formatting also truncates significant digits for more precise
   tiny values and emits zero for `1e-40`/`1e-300`. Newer JSON formatting avoids
   those particular output spellings, so the initial probe passed on 4.6/4.7.
2. An authored quoted `0.00000000000000000001` already becomes zero in
   `String.to_float()` on **every tested engine**, including 4.7.2. Fixing only
   the emitter would preserve the wrong typed value. `String.num_scientific()`
   is not a substitute: older implementations lose significant digits, emitting
   `1` for `1.0000000000000002` and `3.14159` for pi.

[Before-fix traces](../tests/compatibility/c01-d-before.json) record independent
expected bytes, source conversion, typed values, JSON/scientific spellings and
actual reloaded-token results for all nine official binaries. Negative-zero
raw IEEE sign is retained in those traces; Gogo's established normalization is
positive zero and is checked separately by the corrected probes.

Primary, version-pinned engine sources:

- [4.5.2 JSON formatting](https://github.com/godotengine/godot/blob/4.5.2-stable/core/io/json.cpp):
  full-precision float output uses `String::num` with magnitude-based decimals.
- [4.5.2 String conversion/formatting](https://github.com/godotengine/godot/blob/4.5.2-stable/core/string/ustring.cpp):
  fixed-decimal formatting has a decimal-place bound; `built_in_strtod` counts
  mantissa characters, keeps at most 18 digits and applies a decimal exponent.
- [4.0.4 tokenizer](https://github.com/godotengine/godot/blob/4.0.4-stable/modules/gdscript/gdscript_tokenizer.cpp):
  floating tokens are converted through `String.to_float()`.
- [4.6.3 JSON formatting](https://github.com/godotengine/godot/blob/4.6.3-stable/core/io/json.cpp):
  full-precision output uses scientific-capable formatting. This does not fix
  all source-side native conversion limitations.

## Common correction

`compiler/numeric_literal.gd` canonicalizes **validated decimal text**, using
only core string/integer operations. It removes redundant signs/zeros, normalizes
exponents, keeps ordinary fixed spellings readable, and uses scientific spelling
when leading zeros would consume the mantissa budget. It preserves all authored
significant digits. Extremely long exponents are bounded only beyond the range
that any Godot String's length could offset; no exponent-sized output allocation
or arbitrary-precision subsystem is introduced.

Validation converts the canonical token, retains the numeric value for type and
finite/float32-geometry checks, and carries the token in the internal typed IR.
Emission writes that token directly. Thus the model and generated code consume
the same canonical spelling; no binary float is serialized back through JSON.
`auto` remains `-1.0`, signed zero becomes `0.0`, and ordinary canonical output
such as `1e2`/`100` → `100.0` remains stable. Integer font sizes stay typed integers.
The optional reference frontend/emitter applies the same lexical rule.

This is literal normalization, not mixed-language rewriting. Authored GDScript
members and braced expressions remain copied exactly, including their native
numeric parsing behavior. Codegen remains independent of editor/runtime state,
Bun/Node and external processes. Existing generated examples/maps and both
reference transcripts remain byte-for-byte valid; the fixture checks verify this.

## Actual values and explicit native limits

Bytes below are little-endian binary64, not formatted decimal display strings.

| Source | Before | Corrected model and executed token |
| --- | --- | --- |
| `1e-20` | Correct model `2342920ca19cc73b`; emitted decimal executes as zero on 4.0–4.5 | `1e-20`, `2342920ca19cc73b` |
| `0.00000000000000000001` | Source/model already zero on all tested versions | `1e-20`, `2342920ca19cc73b` |
| `1.2345678901234567e-20` | Old JSON loses digits; expanded token executes as zero | Significant digits retained; `f9ff2a478126cd3b` |
| `1e-300` | Old JSON emits zero | `1e-300`, `59f3f8c21f6ea501` |
| `1.0000000000000002` | Precision-sensitive control | `010000000000f03f` |
| `-0`, `-0.0`, `-0e-20` | Established normalization | `0.0`, `0000000000000000` |

The owner chose native Godot parsing semantics instead of a new decimal parser.
Three inherent conversion discrepancies remain **visible against independent IEEE
oracles**, while emission must preserve the actual native value exactly:

| Decimal source | IEEE expected bytes | Native parse/model/runtime bytes |
| --- | --- | --- |
| `3.4028234663852886e38` | `000000e0ffffef47` | `010000e0ffffef47` (one binary64 ULP above) |
| `2.2250738585072014e-308` | `0000000000001000` | `0000000000000000` |
| `4.9406564584124654e-324` | `0100000000000000` | `0000000000000000` |

The storage controls reconstruct the independent expected bytes with public
`PackedByteArray.decode_double()`: storage can retain them, while native decimal
conversion does not produce them. No tolerance or universal IEEE guarantee is
claimed. A full correctly-rounded decimal converter and alternate lowering are
outside the owner-approved scope. The TypeScript reference's `Number` can differ
from Godot at these native-conversion limits; equivalence is not claimed there.

## Reproduction and acceptance

`tests/compatibility/numeric_cases.json` contains 26 ordinary independent byte
oracles and the three separate limitation controls. `numeric_literals.gd` checks
native typed model and actual reloaded GDScript values, binary storage, repeatable
code/maps and original literal spans. Limits additionally require source parsing,
model and generated runtime to agree under the approved native semantics.
`numeric_evidence.py` rejects missing/duplicate observations, poisoned oracles,
map/storage mismatches, false PASS claims and additional emission loss.

- `numeric_literals=PASS`: all 26 ordinary cases match independent bytes, plus
  all three native-limit values survive emission without additional loss.
- `numeric_native_preservation=PASS`: native-limit preservation is verified.
- `numeric_native_conversion=BLOCKED`: the native IEEE conversion discrepancies
  above remain; this is not silently promoted to conversion success.

The full semantic suite also executes all 29 cases through real component
properties where its existing validation dependencies are available. Older
missing Logger/path APIs still fail that suite under #48; the isolated probe
has no such dependency. C01-B runtime and C01-C callback gates remain required.

```sh
python3 -m unittest discover -s tests/compatibility -p 'test_*.py'
python3 tools/check-compatibility.py \
  --engine 4.0.4=/absolute/verified/godot-4.0.4 \
  --engine 4.7.2=/absolute/verified/godot-4.7.2 \
  --output /new/c01-d-results --editor --collect-only
```

Repeat `--engine` for every pinned minor plus 4.7.0. Official provenance is in
[engines.json](../tests/compatibility/engines.json); all engine processes use
isolated projects/settings and empty executable PATH. Successful audit collection
is not compatibility certification: inspect individual stages and known limits.
Full current evidence/CI and handoff are linked in #47/its sole PR. C01-E,
editor fixes, reactive/Box/padding and `to_pixels()` are untouched. No successor
implementation begins until this PR merges or closes; never auto-merge.
