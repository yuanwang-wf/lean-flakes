#!/usr/bin/env bash
# Build the template project two ways (Mathlib and core-only) and check that
# `nix flake init` copies it. Run from anywhere: `./check.sh`.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Copy the template somewhere writable, with its lean-flakes input pointed at
# this checkout so the check runs before the flake is published.
new_project() {
    local dir=$tmp/$1
    mkdir -p "$dir"
    cp -R "$repo"/example/. "$dir/"
    perl -pi -e "s|lean-flakes\\.url = \"github:yuanw/lean-flakes\"|lean-flakes.url = \"path:$repo\"|" "$dir/flake.nix"
    echo "$dir"
}

echo "== flake: the template is visible =="
nix eval "$repo#templates.default.description" >/dev/null

echo "== template: nix flake init copies every file =="
mkdir -p "$tmp/init"
cd "$tmp/init"
nix flake init -t "$repo" >/dev/null
for f in flake.nix lakefile.lean lake-manifest.json lean-toolchain Example.lean Example/Mathlib.lean .envrc .gitignore; do
    test -f "$f" || { echo "missing $f after nix flake init" >&2; exit 1; }
done

echo "== project with Mathlib: nix build, lake build, lean =="
cd "$(new_project mathlib)"
nix build --no-link .#default
nix develop -c lake build
nix develop -c lean Example/Mathlib.lean

echo "== core-only project (mathlib = false, no manifest, no require) =="
cd "$(new_project core)"
perl -pi -e 's/mathlib = true/mathlib = false/' flake.nix
perl -ni -e 'print unless /^require |^-- Tag must match/' lakefile.lean
rm Example/Mathlib.lean lake-manifest.json
nix build --no-link .#default
nix develop -c lake build
nix develop -c lean Example.lean

echo "OK"
