---
name: law-check
description: "Quick 30 Laws compliance check for a specific file"
---

# Law Check

Run a focused 30 Laws compliance check on a single file.

## Usage
`/law-check [filepath]` — e.g. `/law-check game/scripts/minigames/counting_game.gd`

## Process
1. Read the specified file
2. Read GAME_DESIGN_LAWS.md
3. Check all 30 laws with file:line evidence
4. Check QA Protocols #1-#10
5. Output table:

| Law | Status | Evidence |
|-----|--------|----------|
| LAW 1-30 | PASS/FAIL | file:line |
| QA #1-10 | PASS/FAIL | file:line |

## Priority
- P0 = CRITICAL (blocks commit)
- P1 = IMPORTANT (should fix)
- P2 = QUALITY (nice to fix)
