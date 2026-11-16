import Mathlib

/-- Delete this file (and `mathlib = true` in flake.nix) to go core-only. -/
example (α : Type) (a : α) : a = a := by
  aesop
