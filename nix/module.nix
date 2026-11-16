# flake-parts module: build a Lake project from nixpkgs' `leanPackages`.
#
# Everything non-trivial here mirrors `pkgs.leanPackages.buildLakePackage`, so
# the dev shell and `nix build` resolve dependencies the same way: from the
# store, never from the network.
{ flake-parts-lib, lib, ... }:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption ({ config, pkgs, ... }:
    let
      cfg = config.lean;

      lp = pkgs.leanPackages;

      # One Lean for both the build and the dev shell. The VS Code Lean
      # extension reads `lean-toolchain` and downloads that toolchain with
      # elan, so a silent mismatch makes the LSP disagree with `lake build`:
      # fail early when the pin moves (new nixpkgs rev, or buildArgs.lean4).
      toolchainFile = toString (cfg.src + "/lean-toolchain");
      toolchain =
        assert lib.assertMsg (
          !builtins.pathExists toolchainFile ||
          lib.trim (builtins.readFile toolchainFile) == "leanprover/lean4:v${lp.lean4.version}"
        ) ''
          lean-flakes: ${toolchainFile} must contain exactly
            leanprover/lean4:v${lp.lean4.version}
          to match the Lean this flake builds with (${lp.lean4.name}).
        '';
        lp.lean4;

      pkg = lp.buildLakePackage (cfg.buildArgs // {
        pname = cfg.packageName;
        version = cfg.version;
        src = cfg.src;
        lean4 = toolchain;
        # Ours wins over anything in buildArgs; `leanDeps` is the knob.
        leanDeps = lib.optional cfg.mathlib lp.mathlib ++ cfg.leanDeps;
      });

      # Transitive Lean deps of `leanDeps` (Mathlib pulls in batteries, aesop,
      # Qq, proofwidgets, ...): the same closure buildLakePackage built with.
      deps = pkg.passthru.allLeanDeps;

      # Lake has no env var for package overrides, only `--packages=<json>`, so
      # shadow `lake` in the dev shell with one that always passes the store
      # paths. Keeps `lake build` / `lake serve` (the LSP) flag-free.
      lakeOverrides = pkgs.writeText "lake-overrides.json" (builtins.toJSON {
        schemaVersion = "1.2.0";
        packages = map (dep: {
          type = "path";
          name = dep.passthru.lakePackageName or dep.pname;
          inherited = false;
          dir = dep.outPath;
        }) deps;
      });
      lake = pkgs.writeShellScriptBin "lake" ''
        real="${toolchain}/bin/lake"
        case "''${1-}" in
          build | query | serve | lean | env | exe | check-build)
            if [[ -n "''${LAKE_OVERRIDES-}" && " $* " != *--packages* ]]; then
              exec "$real" "$1" --packages="$LAKE_OVERRIDES" "''${@:2}"
            fi
            ;;
        esac
        exec "$real" "$@"
      '';

    in
    {
      options.lean = {
        src = lib.mkOption {
          type = lib.types.path;
          description = "Project root: the directory holding lakefile.lean and lean-toolchain.";
        };
        packageName = lib.mkOption {
          type = lib.types.str;
          description = "Lake package name, as written by `package X` in the lakefile.";
        };
        version = lib.mkOption {
          type = lib.types.str;
          default = "0.1.0";
        };
        mathlib = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Depend on Mathlib, taken prebuilt from the store.";
        };
        leanDeps = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          example = lib.literalExpression "[ pkgs.leanPackages.aesop ]";
          description = "Extra dependencies from pkgs.leanPackages.";
        };
        buildArgs = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          example = lib.literalExpression "{ isExecutable = true; buildTargets = [ \"Example:exe\" ]; }";
          description = "Extra arguments passed to pkgs.leanPackages.buildLakePackage.";
        };
        devShellPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Extra packages in devShells.default (lean, lake and their deps are already there).";
        };
      };

      config = {
        packages.default = pkg;

        devShells.default = pkgs.mkShell {
          packages = [ lake toolchain ] ++ cfg.devShellPackages;

          # The LSP and a bare `lean file.lean` resolve deps straight from the
          # store; `lake` gets them via $LAKE_OVERRIDES.
          LEAN_PATH = lib.concatStringsSep ":"
            (map (dep: "${dep}/.lake/build/lib/lean") deps);
          LAKE_OVERRIDES = lib.optionalString (deps != [ ]) lakeOverrides;

          # Mathlib's post-update hook would run `lake exe cache get`; its
          # .ltar files fail to unpack with nixpkgs' leantar, and the oleans
          # come from the store anyway.
          MATHLIB_NO_CACHE_ON_UPDATE = "1";
        };
      };
    });
}
