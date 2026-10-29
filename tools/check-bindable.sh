#!/bin/sh
# R01 isolated research. Expected failures are asserted, never hidden as success.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
godot=$(command -v "${GODOT_BIN:-godot}") || { echo "Set GODOT_BIN to the official Godot 4.7 editor executable." >&2; exit 1; }
case "$godot" in /*) ;; *) godot="$(pwd)/$godot" ;; esac
[ "$("$godot" --headless --version)" = '4.7.stable.official.5b4e0cb0f' ] || { echo 'Expected pinned Godot 4.7.stable.official.5b4e0cb0f.' >&2; exit 1; }
workspace=$(mktemp -d)
trap 'if [ "${ESTRAGON_KEEP_BINDABLE_TEST:-0}" = 1 ]; then echo "Retained R01: $workspace"; else rm -rf "$workspace"; fi' EXIT
mkdir -p "$workspace/no-tools"
for mode in baseline explicit preload inheritance preload-generic inheritance-generic preload-warm inheritance-warm remap-preload remap-inheritance remap-inheritance-warm language; do
    project="$workspace/$mode"
    mkdir -p "$project"
    cp "$root"/tests/research/bindable/*.gd "$project/"
    cp "$root/tests/research/bindable/authored.gd.txt" "$project/model.gd"
    cp "$root/tests/research/bindable/generated.gd.txt" "$project/"
    case "$mode" in remap-*)
        cp "$root/tests/research/bindable/generated.gd.txt" "$project/lowered.gd"
        printf '[remap]\npath="res://lowered.gd"\n' > "$project/model.gd.remap"
    ;; esac
    printf 'config_version=5\n' > "$project/project.godot"
    env PATH="$workspace/no-tools" "$godot" --headless --path "$project" --script res://probe.gd --quit-after 30 -- "$mode" > "$project/result.log" 2>&1 || { cat "$project/result.log"; exit 1; }
    cat "$project/result.log"
    grep -Eq "^R01_RESULT $mode [0-9]+ OK$" "$project/result.log"
done
# Real ScriptEditor with self-contained preferences; never touches owner settings.
cp "$godot" "$workspace/godot"
if [ "$(uname)" = Darwin ]; then /usr/bin/codesign --force --sign - "$workspace/godot"; fi
: > "$workspace/_sc_"
project="$workspace/editor"
mkdir -p "$project/addons/probe"
cp "$root"/tests/research/bindable/*.gd "$project/"
cp "$root/tests/research/bindable/editor.gd" "$root/tests/research/bindable/loader.gd" "$root/tests/research/bindable/importer.gd" "$root/tests/research/bindable/capture.gd" "$project/addons/probe/"
cp "$root/tests/research/bindable/authored.gd.txt" "$project/model.gd"
cp "$root/tests/research/bindable/generated.gd.txt" "$project/"
printf '[plugin]\nname="R01 isolated probe"\ndescription="Research only"\nauthor="Estragon"\nversion="1"\nscript="editor.gd"\n' > "$project/addons/probe/plugin.cfg"
printf 'config_version=5\n[editor_plugins]\nenabled=PackedStringArray("res://addons/probe/plugin.cfg")\n' > "$project/project.godot"
env PATH="$workspace/no-tools" "$workspace/godot" --headless --editor --path "$project" --quit-after 1200 > "$project/result.log" 2>&1 || { cat "$project/result.log"; exit 1; }
cat "$project/result.log"
grep -Eq '^R01_EDITOR_RESULT [0-9]+ OK$' "$project/result.log"
# Expected errors are checked by native Logger assertions as well as this
# whitelist. Any unrelated parse/runtime/cleanup failure rejects the experiment.
for log in "$workspace"/*/result.log; do
    awk '
      /^(SCRIPT ERROR:|ERROR:)/ && !/Unrecognized annotation: "@Bindable"/ && !/Could not (preload resource script|resolve script|resolve super class inheritance from) "res:\/\/model.gd"/ && !/A script language with extension/ && !/Failed to load script "res:\/\/model.gd" with error "Parse error"/ { print; bad=1 }
      /WARNING:.*(leak|aborted)/ { print; bad=1 }
      END { exit bad }
    ' "$log" || exit 1
done
printf 'ESTRAGON_BINDABLE_RESEARCH_OK\n'
