#!/bin/sh
# E01-only real editor proof on a supplied official 4.x binary. No compiler port.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
godot=$(command -v "${GODOT_BIN:-godot}")
case "$godot" in /*) ;; *) godot="$(pwd)/$godot" ;; esac
workspace=$(mktemp -d)
trap 'if [ "${ESTRAGON_KEEP_COMPAT_TEST:-0}" = 1 ]; then echo "E01_RETAINED $workspace"; else rm -rf "$workspace"; fi' EXIT
cp "$godot" "$workspace/godot"
if [ "$(uname)" = Darwin ]; then /usr/bin/codesign --force --sign - "$workspace/godot"; fi
: > "$workspace/_sc_"
mkdir -p "$workspace/no-tools"
project="$workspace/project"
mkdir -p "$project/addons/estragon/editor" "$project/addons/probe" "$project/examples/counter"
cp "$root/addons/estragon/editor/highlighter.gd" "$root/addons/estragon/editor/highlighter_association.gd" "$project/addons/estragon/editor/"
cp "$root/tests/editor/compatibility/driver.gd" "$project/addons/probe/driver.gd"
cp "$root/tests/editor/seed_plain.gd" "$project/seed.gd"
for name in Counter.gogo Background.gogo New.gogo Counter.gogo.txt; do cp "$root/examples/counter/Counter.gogo" "$project/examples/counter/$name"; done
printf '[plugin]\nname="E01 isolated compatibility"\ndescription="Test only"\nauthor="Estragon"\nversion="1"\nscript="driver.gd"\n' > "$project/addons/probe/plugin.cfg"
printf 'config_version=5\n[editor_plugins]\nenabled=PackedStringArray("res://addons/probe/plugin.cfg")\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n' > "$project/project.godot"
run_editor() {
    env PATH="$workspace/no-tools" E01_FULL_ADDON="${2:-0}" "$workspace/godot" --headless --editor --path "$project" > "$workspace/$1.log" 2>&1 &
    pid=$!
    seconds=0
    while kill -0 "$pid" 2>/dev/null; do
        if [ "$seconds" -ge 90 ]; then kill -9 "$pid"; cat "$workspace/$1.log"; echo 'E01 editor timeout' >&2; exit 1; fi
        sleep 1
        seconds=$((seconds + 1))
    done
    wait "$pid" || { cat "$workspace/$1.log"; exit 1; }
    cat "$workspace/$1.log"
}
for phase in 1 2; do
    run_editor "phase-$phase"
    grep -Eq '^E01_COMPAT_RESULT [0-9]+ OK$' "$workspace/phase-$phase.log"
    if grep -E 'SCRIPT ERROR:|^ERROR:' "$workspace/phase-$phase.log"; then exit 1; fi
    if [ "$phase" = 1 ]; then
        env PATH="$workspace/no-tools" ESTRAGON_EDITOR_TEST=1 "$workspace/godot" --headless --path "$project" --script res://seed.gd > "$workspace/seed.log" 2>&1 || { cat "$workspace/seed.log"; exit 1; }
        cat "$workspace/seed.log"
        grep -qx ESTRAGON_SEEDED_PLAIN_RESTORE "$workspace/seed.log"
    fi
done
printf 'E01_ISOLATED_HIGHLIGHTING_OK\n'
# Separate startup probe: copy complete unmodified addon, retain exact errors.
# BLOCKED here is an explicit failed compatibility result, never certification.
cp -R "$root/addons/estragon/." "$project/addons/estragon/"
printf '\n[editor_plugins]\nenabled=PackedStringArray("res://addons/estragon/editor/plugin.cfg", "res://addons/probe/plugin.cfg")\n' >> "$project/project.godot"
run_editor full-addon 1
grep -q '^E01_FULL_ADDON_REPORT_VALID ' "$workspace/full-addon.log"
if grep -Eq 'SCRIPT ERROR:|ERROR:' "$workspace/full-addon.log" || ! grep -qx 'E01_FULL_ADDON_REPORT_VALID true' "$workspace/full-addon.log"; then
    printf 'E01_FULL_ADDON_BLOCKED\n'
else
    printf 'E01_FULL_ADDON_STARTUP_OK\n'
fi
