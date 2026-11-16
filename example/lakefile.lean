import Lake
open Lake DSL

package Example

-- Tag must match nixpkgs' mathlib; lake never fetches it (the store paths are
-- injected), but it must be declared for lake to put it on the search path.
require "leanprover-community" / "mathlib" @ git "v4.35.0"

@[default_target]
lean_lib Example where
  -- Pick up Example/*.lean (e.g. Example/Mathlib.lean), not just Example.lean.
  globs := #[.andSubmodules `Example]
