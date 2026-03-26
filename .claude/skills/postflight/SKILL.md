---
name: postflight
description: "Automated POST-FLIGHT checklist with evidence for all changed files"
---

# Post-Flight Checklist

Run the full POST-FLIGHT verification for all files changed in the current session.

## Process
1. Get list of changed files: `git diff --name-only HEAD`
2. For each changed .gd file, verify:
   - V1 COMPILE: All parent class methods called actually exist (LAW 12)
   - V2 LAWS: Check all 30 laws with file:line evidence
   - V3 AXIOMS: Check 12 axioms for affected games
   - V4 DUAL-SOURCE: grep changed identifiers in both .gd AND .tscn (LAW 22)
   - V5 REGRESSION: No visual quality regression (LAW 29)
3. Output evidence table for each verification gate
4. Final verdict: PASS / FAIL with list of violations

## Evidence Format
```
V1 COMPILE: method _scale_by_round_i(int,int,int,int) exists in base_minigame.gd:45
V2 LAW 17: _origins.get(item, Vector2.ZERO) dict guard at line 128
V3 A4: FAIL — difficulty NOT progressive -> REQUIRES FIX
```

## Verdict
When all checks pass, tell the user to say "postflight done" to create the HMAC token.

When checks fail:
1. List all failures with file:line
2. Suggest specific fixes
3. Do NOT create postflight token
