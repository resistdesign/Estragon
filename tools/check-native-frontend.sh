#!/bin/sh
# Godot-only frontend proof. No dependency install, project import or Bun runner.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
godot=$(command -v "${GODOT_BIN:-godot}") || {
    echo 'Set GODOT_BIN to the official Godot 4.7 editor executable.' >&2
    exit 1
}
case "$godot" in /*) ;; *) godot="$(pwd)/$godot" ;; esac
# Exclude Bun/Node/custom tools from the launched Godot process.
PATH=/usr/bin:/bin
export PATH
version=$("$godot" --version)
[ "$version" = '4.7.stable.official.5b4e0cb0f' ] || {
    echo "Expected pinned Godot 4.7; found $version" >&2
    exit 1
}
project=$(mktemp -d)
trap 'rm -rf "$project"' EXIT HUP INT TERM
mkdir -p "$project/addons/estragon" "$project/tests/godot" "$project/tests/fixtures"
cp -R "$root/addons/estragon/compiler" "$project/addons/estragon/"
cp "$root/tests/godot/native_frontend.gd" "$project/tests/godot/"
cp "$root/tests/fixtures/native-frontend.json" "$project/tests/fixtures/"
printf 'config_version=5\n' > "$project/project.godot"
"$godot" --headless --path "$project" --script res://tests/godot/native_frontend.gd --quit-after 120 -- --require-no-bun > "$project/result.log" 2>&1 || {
    cat "$project/result.log"
    exit 1
}
cat "$project/result.log"
if grep -E 'SCRIPT ERROR:|ERROR:|Parse Error:|Assertion failed:' "$project/result.log"; then exit 1; fi
grep -qx 'NATIVE_FRONTEND_NO_BUN' "$project/result.log"
grep -qx 'ESTRAGON_NATIVE_FRONTEND_OK' "$project/result.log"
