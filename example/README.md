# Example

Lean 4 + Mathlib, all from nixpkgs `leanPackages`, wired up with
[lean-flakes](https://github.com/yuanwang-wf/lean-flakes). Mathlib is a prebuilt
download and Lake never needs the network.

```sh
direnv allow            # or: nix develop
lake build              # incremental build; deps come from the store
lean Example.lean       # check one file -- this is what the LSP does
nix build               # reproducible build of the package
```

Editing: the Lean VS Code extension needs `lean` and `LEAN_PATH` from this
shell, so start the editor from a direnv'd terminal.

Core Lean only: set `mathlib = false` in `flake.nix`, then delete
`Example/Mathlib.lean`, the `require` line in `lakefile.lean`, and
`lake-manifest.json`.

Adding deps: if `pkgs.leanPackages` has it, add `pkgs.leanPackages.<name>` to
`lean.leanDeps`, plus a `require` line in `lakefile.lean` and a
`lake-manifest.json` entry (run `lake update` once with network to get one).
Otherwise you're back to Lake's git deps and a plain Lake build.

`lake update` is not needed for the deps above (the manifest only has to exist
so plain Lake tooling is happy); the shell sets `MATHLIB_NO_CACHE_ON_UPDATE=1`
so it skips Mathlib's olean cache, which nixpkgs' `leantar` cannot unpack.

`nix flake update nixpkgs` moves Lean and Mathlib together: the flake fails
until `lean-toolchain` matches, and cache.nixos.org only keeps one rev, so
expect a long rebuild unless the new rev is already cached.
