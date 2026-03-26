---
name: game-qa
description: "Quick 30 Laws + 12 Axioms compliance check for a specified game file"
---

# Game QA Check

Run a quick compliance check against all 30 Game Design Laws and 12 Axioms.

## Usage
`/game-qa [filename]` — e.g. `/game-qa shadow_match.gd`

## Process
1. Read the specified .gd file
2. Read GAME_DESIGN_LAWS.md and GAME_DESIGN_BIBLE.md
3. Check each of the 30 laws against the code
4. Check each of the 12 axioms
5. Output compliance table:

| Law/Axiom | Status | Evidence |
|-----------|--------|----------|
| LAW 1 | PASS/FAIL/N/A | file:line or reason |
| LAW 2 | PASS/FAIL/N/A | file:line or reason |
| ... | ... | ... |
| A1 | PASS/FAIL/N/A | file:line or reason |
| A12 | PASS/FAIL/N/A | file:line or reason |

## Priority
- P0 violations = CRITICAL (must fix before commit)
- P1 violations = IMPORTANT (should fix)
- P2 violations = QUALITY (nice to fix)

## Summary format
```
GAME QA: [filename]
P0 violations: N
P1 violations: N
P2 violations: N
VERDICT: PASS / FAIL
```
