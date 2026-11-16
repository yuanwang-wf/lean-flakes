{
  description = "A flake-parts module and template for Lean 4 projects, with optional prebuilt Mathlib";

  inputs = {
    # flake.lock is the real pin. Mathlib is fetched prebuilt from the caches
    # and only one nixpkgs rev is cached at a time, so before moving this,
    # check that `nix build .#default` still substitutes (see check.sh).
    nixpkgs.url = "github:NixOS/nixpkgs/0bb2eedc20e4739f29e8045034f2828ad7054f8f";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ ./nix/module.nix ];

      systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ];

      # The template doubles as the test: `nix build .#default` and
      # `nix develop` build it with the module in this repo.
      perSystem = { ... }: {
        lean = {
          src = ./example;
          packageName = "Example";
          mathlib = true;
        };
      };

      flake = {
        flakeModule = ./nix/module.nix;
        templates.default = {
          description = "Lean 4 Lake project (flake-parts) with Mathlib from the store";
          path = ./example;
        };
      };
    };
}
