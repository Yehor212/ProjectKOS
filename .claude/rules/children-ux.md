---
description: Children UX rules — applies to game/scenes/**/*.tscn, game/scripts/**/*.gd
---

# Children UX Design (Ages 2-7)

## Touch Targets

- Minimum 44px for ALL interactive elements (Fitts's Law)
- Recommended: 80-120px for primary game buttons
- Snap radius: 80px minimum for drag-drop (DragController.\_SNAP_RADIUS)

## Visual Feedback

- EVERY tap/action produces IMMEDIATE response (< 100ms)
- Success: squish-bounce + confetti + success SFX + star particle
- Error (Toddler): gentle wobble + "click" SFX (NO negative feedback)
- Error (Preschool): head shake + "error" SFX + smoke VFX + vibration

## No Punitive Mechanics (Toddler)

- NEVER show "wrong" or "game over" to ages 2-4
- NEVER play negative sounds (buzzer, fail horn)
- NEVER reduce stars/progress as punishment
- Use "try again" loop: wrong answer -> snap back -> hint escalation

## Hick's Law

- Maximum 3-4 choices per screen (ages 2-4 can't process more)
- Main menu: 3 options max (Play, Collection, Playground)
- In-game: 3-4 answer options per round (LAW 2)

## Animation

- All characters should "breathe" (idle bob/blink) when waiting
- No flashing > 3Hz (photosensitive safety)
- Particle effects: max 100 active particles per scene
- Use `prefers-reduced-motion` equivalent where possible

## Audio

- All SFX: 0.5-2 seconds, distinct pitch per action type
- Background music: 60-80 BPM, looping, no lyrics
- Game must be FULLY playable with sound OFF (visual primary)
- Maximum volume: -6dB relative to background (no sudden loud sounds)

## Text

- Font size minimum 24px for any visible text
- Labels NEVER overlap (LAW 4): guaranteed Y-gap minimum 4px
- Pre-readers (2-4): NO text in gameplay — visual-only matching
- All strings through tr() for i18n (LAW 12 / Axiom A12)
