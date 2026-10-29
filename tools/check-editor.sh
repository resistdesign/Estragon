#!/bin/sh
# Fresh self-contained editor + app, with no external compiler/tool PATH.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
godot=$(command -v "${GODOT_BIN:-godot}") || { echo 'Set GODOT_BIN to Godot 4.7.' >&2; exit 1; }
case "$godot" in /*) ;; *) godot="$(pwd)/$godot" ;; esac
workspace=$(mktemp -d "${TMPDIR:-/tmp}/estragon-editor native-XXXXXXXX")
trap 'if [ "${ESTRAGON_KEEP_EDITOR_TEST:-0}" = 1 ]; then echo "Retained isolated editor: $workspace"; else rm -rf "$workspace"; fi' EXIT
project="$workspace/project"
mkdir -p "$project/addons" "$project/examples/counter" "$project/tests/editor/driver" "$project/tests/godot" "$workspace/no-tools"
cp "$godot" "$workspace/godot"
if [ "$(uname)" = Darwin ]; then /usr/bin/codesign --force --sign - "$workspace/godot"; fi
: > "$workspace/_sc_"
if [ "${ESTRAGON_EDITOR_NATIVE:-0}" = 1 ]; then
    # This override is read when Godot opens the project, before plugins enter.
    # It affects only this self-contained editor, never user preferences.
    mkdir -p "$workspace/editor_data"
    printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\nrun/window_placement/game_embed_mode = -1\n' > "$workspace/editor_data/editor_settings-4.7.tres"
fi
[ "$("$workspace/godot" --headless --version)" = '4.7.stable.official.5b4e0cb0f' ] || { echo 'Expected pinned Godot 4.7.' >&2; exit 1; }
cp -R "$root/addons/estragon" "$project/addons/"
cp "$root/examples/counter/Counter.gogo" "$root/examples/counter/Counter.tscn" "$project/examples/counter/"
cp "$root/tests/editor/game_proof.txt" "$root/tests/editor/highlighter_tests.gd" "$project/tests/editor/"
cp "$root/tests/godot/native_build.gd" "$project/tests/godot/"
cp "$root/tests/editor/driver.gd" "$project/tests/editor/driver/driver.gd"
printf '[plugin]\nname="Isolated test driver"\ndescription="Test only"\nauthor="Estragon"\nversion="1"\nscript="driver.gd"\n' > "$project/tests/editor/driver/plugin.cfg"
cat > "$project/project.godot" <<'PROJECT'
config_version=5
[application]
config/name="Native Estragon isolated proof"
run/main_scene="res://examples/counter/Counter.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
[display]
window/size/viewport_width=640
window/size/viewport_height=360
[rendering]
renderer/rendering_method="gl_compatibility"
[editor_plugins]
enabled=PackedStringArray("res://addons/estragon/editor/plugin.cfg", "res://tests/editor/driver/plugin.cfg")
PROJECT
if [ "${ESTRAGON_EDITOR_NATIVE:-0}" != 1 ]; then
    printf '\n[editor]\nrun/main_run_args="--headless"\n' >> "$project/project.godot"
fi
# No config, repository tools, package files or generated scripts are installed.
for phase in 1 2; do
    if [ "${ESTRAGON_EDITOR_NATIVE:-0}" = 1 ]; then display_args=''; else display_args='--headless'; fi
    env PATH="$workspace/no-tools" ESTRAGON_EDITOR_TEST=1 ESTRAGON_EDITOR_NATIVE="${ESTRAGON_EDITOR_NATIVE:-0}" \
      "$workspace/godot" $display_args --path "$project" --editor --log-file "$workspace/editor-$phase.log" > "$workspace/output-$phase.log" 2>&1 &
    pid=$!
    seconds=0
    while kill -0 "$pid" 2>/dev/null; do
        if [ "$seconds" -ge 150 ]; then kill -9 "$pid"; cat "$workspace/output-$phase.log"; echo 'Editor test timed out.' >&2; exit 1; fi
        sleep 1
        seconds=$((seconds + 1))
    done
    wait "$pid" || { cat "$workspace/output-$phase.log"; exit 1; }
    cat "$workspace/output-$phase.log"
    grep -qx "ESTRAGON_EDITOR_PHASE_${phase}_OK" "$workspace/output-$phase.log"
    awk '
      /SCRIPT ERROR:/ && !/Parse Error: Identifier "missing_handler" not declared/ { print; bad=1 }
      /^ERROR:/ && !/An EditorPlugin build callback failed/ { print; bad=1 }
      END { exit bad }
    ' "$workspace/output-$phase.log" || { echo 'Unexpected editor/game errors.' >&2; exit 1; }
    if [ "$phase" = 1 ]; then
        env PATH="$workspace/no-tools" "$workspace/godot" --headless --path "$project" --script res://tests/godot/native_build.gd --quit-after 120 > "$workspace/build.log" 2>&1 || { cat "$workspace/build.log"; exit 1; }
        cat "$workspace/build.log"
        grep -qx ESTRAGON_NATIVE_BUILD_OK "$workspace/build.log"
    fi
done
printf 'ESTRAGON_EDITOR_OK\n'
