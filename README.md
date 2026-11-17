# lean-flakes

A flake template and a flake-parts module for Lean 4 projects, built from
nixpkgs' [`leanPackages`](https://github.com/NixOS/nixpkgs/tree/master/pkgs/development/lean-modules):
`lean`, `lake`, and Mathlib as a prebuilt download. No network during the
build, no `lake exe cache get`, no hours compiling Mathlib.

Why not [lean4-nix](https://github.com/lenianiva/lean4-nix)? Its Lake support
is good, but Mathlib is out of its scope
([issue 115](https://github.com/lenianiva/lean4-nix/issues/115)): ProofWidgets
pulls in npm, and Mathlib's olean cache cannot be unpacked in the sandbox.
nixpkgs now ships the whole Mathlib dependency tree (batteries, aesop, Qq,
proofwidgets, plausible, LeanSearchClient, Cli, importGraph, mathlib), so a
Lean flake can take them straight from the store.

## Start a project

```sh
nix flake init -t github:yuanwang-wf/lean-flakes
direnv allow          # or: nix develop
lake build
```

Then edit `Example.lean`. The template is the `example/` directory of this
repo, so `nix build .#default` at the repo root builds it too.

`lean-toolchain` is what the VS Code Lean extension reads; everything else
comes from nixpkgs. Start the editor from a direnv'd terminal, because the
extension needs `lean` and `LEAN_PATH` from that shell.

## Use it in your own flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    lean-flakes.url = "github:yuanwang-wf/lean-flakes";
  };

  outputs = inputs @ { self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ];
      imports = [ inputs.lean-flakes.flakeModule ];

      perSystem = { ... }: {
        lean = {
          src = ./.;                # the dir with lakefile.lean and lean-toolchain
          packageName = "Example";  # the `package X` in the lakefile
          mathlib = true;
        };
      };
    };
}
```

Your lakefile still has to declare its dependencies, and `lake-manifest.json`
has to exist next to it, or Lake asks Reservoir for them and dies in the
sandbox:

```lean
require "leanprover-community" / "mathlib" @ git "v4.35.0"
```

Copy both from `example/` and edit. The revisions in the manifest do not
matter to nix (the store paths override them), so `lake update` is only worth
running when you add a dependency.

## Options

`perSystem.lean`, used in `example/flake.nix`:

| option | default | what it does |
| --- | --- | --- |
| `src` | required | project root, holds `lakefile.lean` and `lean-toolchain` |
| `packageName` | required | Lake package name, the `package X` in the lakefile |
| `version` | `"0.1.0"` | derivation version |
| `mathlib` | `false` | depend on Mathlib and its transitive deps, from the store |
| `leanDeps` | `[]` | more dependencies from `pkgs.leanPackages` (aesop, batteries, Cli, ...) |
| `buildArgs` | `{}` | extra arguments for `buildLakePackage`: `isExecutable`, `buildTargets`, `lakeHash`, ... |
| `devShellPackages` | `[]` | extra tools in `devShells.default` |

## What you get

- `packages.default`: `buildLakePackage` over `src`.
- `devShells.default`: `lean`, plus a `lake` that always passes
  `--packages=<store paths>`, so `lake build` and `lake serve` (the LSP) need
  no flags, `LEAN_PATH` so a bare `lean file.lean` works, and
  `MATHLIB_NO_CACHE_ON_UPDATE=1` so Mathlib's update hook stays quiet.

Adding a dependency that nixpkgs packages: put `pkgs.leanPackages.<name>` in
`leanDeps` and add a `require` line to the lakefile. One it does not package:
`buildArgs.lakeHash` turns Lake's git dependencies into a fixed-output
derivation (that path is not covered by `check.sh`), or skip the flake and use
plain Lake.

## Caches

Mathlib's compiled output substitutes from cache.nixos.org. Its unpacked form
(the `.ltar` oleans expanded) is not built by Hydra, because `mathlib` sets
`hydraPlatforms = []`, so [lean4math.cachix.org](https://app.cachix.org/cache/lean4math)
carries that one path. The template's `nixConfig` points there; nix asks once
before trusting a new substituter, and `accept-flake-config = true` in
`nix.conf` skips the prompt.

`nix flake update nixpkgs` moves Lean and Mathlib together, and only one rev is
cached at a time. The flake refuses to evaluate until `lean-toolchain` matches
the new Lean, and if the caches do not have the new Mathlib yet, expect a
multi-hour build. After bumping the pin, `./push-cache.sh` publishes it.

## Hacking

```sh
./check.sh    # builds example/ with and without Mathlib, and checks nix flake init
```

Extracted from [yuanw/learn-lean](https://github.com/yuanw/learn-lean).
