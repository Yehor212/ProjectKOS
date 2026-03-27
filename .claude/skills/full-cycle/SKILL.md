---
name: full-cycle
description: "Execute full development cycle: read all docs, run all guardians, verify all 30 Laws + 12 Axioms"
---

# Full Cycle

Execute the complete verification pipeline for all changed files.

## Process
1. Read ALL mandatory docs: ARCHITECTURE.md, GAME_DESIGN_LAWS.md, GAME_DESIGN_BIBLE.md, QA_PROTOCOLS.md
2. Get changed files: `git diff --name-only HEAD`
3. For each .gd file:
   - Law Enforcer: 30 Laws audit (P0/P1/P2)
   - Axiom check: 12 Axioms per affected game
   - QA Protocols: #1-#10
4. Run tests: `godot --headless --path game/ -s tests/run_all_tests.gd --quit-after 60`
5. Verify compile: check exit code (grep misses parse errors!)
6. I18n: verify all tr() keys exist in translations.csv
7. Performance: check for create_tween() vs _create_game_tween()
8. Output: compliance table with evidence

## Verdict
PASS: 0 P0, tests green, compile clean
FAIL: list all violations with file:line
