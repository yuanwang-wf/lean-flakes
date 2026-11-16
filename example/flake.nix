{
  description = "Lean 4 project built by nixpkgs leanPackages (Mathlib prebuilt)";

  inputs = {
    # flake.lock is the real pin. Mathlib comes prebuilt from the caches below
    # and only one nixpkgs rev is cached at a time, so before running
    # `nix flake update nixpkgs`, check that `nix build` still substitutes.
    nixpkgs.url = "github:NixOS/nixpkgs/0bb2eedc20e4739f29e8045034f2828ad7054f8f";
    flake-parts.url = "github:hercules-ci/flake-parts";
    lean-flakes.url = "github:yuanw/lean-flakes";
  };

  outputs = inputs @ { self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ];
      imports = [ inputs.lean-flakes.flakeModule ];

      perSystem = { ... }: {
        lean = {
          src = ./.;
          packageName = "Example";
          # Set to false for core Lean, and drop the `import Mathlib` file.
          mathlib = true;
        };
      };
    };

  # --- Flake Local Nix Configuration -------------------------------
  # Substitute the Mathlib closure instead of rebuilding it. Nix asks once
  # before trusting a new substituter; `accept-flake-config = true` in
  # nix.conf skips the prompt.
  nixConfig = {
    extra-substituters = [ "https://lean4math.cachix.org" ];
    extra-trusted-public-keys = [ "lean4math.cachix.org-1:lo4ur+c1M7f5i9VqM0YzEdZ1KpzXdlVqmFfrqfxmY5g=" ];
  };
}
