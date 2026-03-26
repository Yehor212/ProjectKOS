# Testing Rules (47 Baseline)

1. Always maintain test count >= 47 (quality ratchet)
2. Always run tests headless: `godot --headless --path game/ -s tests/run_all_tests.gd`
3. Always check exit code after test run (grep misses parse errors)
4. Always verify new minigames are covered by test_law_compliance.gd
5. Always test both Toddler and Preschool paths for age-split games
6. Always validate star formula: Toddler=5, Preschool=clampi(5-errors/2,1,5)
7. Always check compile before commit (LAW 12)
8. Always run verifier agent before committing code changes
