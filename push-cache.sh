#!/usr/bin/env bash
# Publish the current nixpkgs pin's Mathlib closure and dev shell to
# lean4math.cachix.org, so a fresh `nix build` substitutes instead of
# rebuilding Mathlib. Needs CACHIX_AUTH_TOKEN in the env, or a prior
# `cachix authtoken ...`.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

nix build --no-link --print-out-paths .#default | cachix push lean4math
mkdir -p .direnv
nix develop --profile .direnv/push-profile -c true
cachix push lean4math .direnv/push-profile
