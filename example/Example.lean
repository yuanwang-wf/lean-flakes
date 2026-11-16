def cirno : String := "Cirno's Perfect Arithmetics Class has begun!"

/-- Core Lean only: `Nat` because `ℕ` notation needs Mathlib. -/
theorem nng_tutorial_1 (x q : Nat) : 37 * x + q = 37 * x + q := by
  rfl
