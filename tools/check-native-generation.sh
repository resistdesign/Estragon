#!/bin/sh
# Full native generation/runtime proof; no optional development tools required.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
godot=$(command -v "${GODOT_BIN:-godot}") || { echo 'Set GODOT_BIN to official Godot 4.7.' >&2; exit 1; }
case "$godot" in /*) ;; *) godot="$(pwd)/$godot" ;; esac
PATH=/usr/bin:/bin
export PATH
[ "$("$godot" --version)" = '4.7.stable.official.5b4e0cb0f' ] || { echo 'Expected pinned Godot 4.7.' >&2; exit 1; }
project=$(mktemp -d)
trap 'if [ "${ESTRAGON_KEEP_NATIVE_TEST:-0}" = 1 ]; then echo "Retained native project: $project"; else rm -rf "$project"; fi' EXIT
mkdir -p "$project/no-tools" "$project/addons/estragon" "$project/tests/godot" "$project/tests/fixtures" "$project/examples"
cp -R "$root/addons/estragon/compiler" "$root/addons/estragon/runtime" "$project/addons/estragon/"
cp "$root/tests/fixtures/"*.gogo "$root/tests/fixtures/native-frontend.json" "$root/tests/fixtures/native-generation.json" "$project/tests/fixtures/"
cp "$root/tests/godot/native_counter.gd" "$root/tests/godot/native_semantics.gd" "$root/tests/godot/native_generation.gd" "$root/tests/godot/generated_gogo.gd" "$root/tests/godot/hybrid_gogo.gd" "$root/tests/godot/generated_signals.gd" "$project/tests/godot/"
cp "$root/tests/compatibility/numeric_literals.gd" "$project/tests/godot/numeric_literals.gd"
cp "$root/tests/compatibility/numeric_cases.json" "$project/numeric_cases.json"
printf 'config_version=5\n' > "$project/project.godot"
run() {
    marker=$1
    shift
    env PATH="$project/no-tools" "$godot" --headless --path "$project" "$@" > "$project/result.log" 2>&1 || { cat "$project/result.log"; exit 1; }
    if grep -E 'SCRIPT ERROR:|ERROR:|Parse Error:|Assertion failed:' "$project/result.log"; then cat "$project/result.log"; exit 1; fi
    if [ -n "$marker" ]; then grep -qx "$marker" "$project/result.log" || { cat "$project/result.log"; exit 1; }; fi
    cat "$project/result.log"
}
run '' --editor --recovery-mode --import
# No checked-in TypeScript-generated application code participates in this proof.
for example in compiled mixed counter; do
    cp -R "$root/examples/$example" "$project/examples/"
    rm -rf "$project/examples/$example/generated"
done
run ESTRAGON_NATIVE_GENERATION_OK --script res://tests/godot/native_generation.gd --quit-after 120 -- --require-no-bun
run '' --editor --recovery-mode --import
run ESTRAGON_GENERATED_GOGO_OK --script res://tests/godot/generated_gogo.gd --quit-after 120
run ESTRAGON_HYBRID_GOGO_OK --script res://tests/godot/hybrid_gogo.gd --quit-after 120
run ESTRAGON_NATIVE_COUNTER_OK --script res://tests/godot/native_counter.gd --quit-after 120
run ESTRAGON_SIGNALS_OK --script res://tests/godot/generated_signals.gd --quit-after 120
# Expected negative diagnostics are asserted and counted inside this script;
# unlike positive steps, engine error text is required here, not globally ignored.
env PATH="$project/no-tools" "$godot" --headless --path "$project" --script res://tests/godot/native_semantics.gd --quit-after 120 > "$project/negative.log" 2>&1 || { cat "$project/negative.log"; exit 1; }
cat "$project/negative.log"
grep -qx 'ESTRAGON_NATIVE_SEMANTICS_OK' "$project/negative.log"
[ "$(grep -c '^EXPECTED_NATIVE_DIAGNOSTIC ' "$project/negative.log")" = 9 ]
[ "$(grep -c '^EXPECTED_NATIVE_CALLBACK_REJECTION ' "$project/negative.log")" = 4 ]
printf 'ESTRAGON_NATIVE_RUNTIME_OK\n'
run C01_NUMERIC_OK --script res://tests/godot/numeric_literals.gd --quit-after 120
