#!/usr/bin/env node
/**
 * FULLCYCLE-FLAG — детектор тригер-фрази + генератор токенів.
 * Філософія: memory = advisory = ігнорується. Hooks = law = блокує.
 *
 * UserPromptSubmit hook:
 *   - "полный цикл" → створити .fullcycle-active + контекст
 *   - "postflight done" → згенерувати HMAC токен у .postflight-done
 *   - "laws read" → згенерувати HMAC токен у .fullcycle-laws-read
 *
 * Токени підписані HMAC — Claude не може підробити (не знає секрет у runtime).
 */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = process.cwd();
const FLAG = path.join(ROOT, '.fullcycle-active');
const POSTFLIGHT = path.join(ROOT, '.postflight-done');
const LAWS_READ = path.join(ROOT, '.fullcycle-laws-read');

// Той самий секрет що і в commit-gate.cjs — з env var
const HMAC_SECRET = process.env.CLAUDE_HOOK_SECRET || 'FALLBACK-CHANGE-ME';

// Тригер-фрази (lowercase)
const FULLCYCLE_TRIGGERS = ['полный цикл', 'полній цикл', 'full cycle', 'полный аудит'];
const POSTFLIGHT_TRIGGERS = ['postflight done', 'постфлайт готово', 'чеклист готово'];
const LAWS_READ_TRIGGERS = ['laws read', 'документы прочитаны', 'доки прочитаны'];

function makeToken(payload) {
  const date = new Date().toISOString().slice(0, 10);
  return crypto
    .createHmac('sha256', HMAC_SECRET)
    .update(date + ':' + payload)
    .digest('hex')
    .slice(0, 16);
}

let input = '';
process.stdin.on('data', (d) => (input += d));
process.stdin.on('end', () => {
  try {
    const inp = JSON.parse(input);
    const msg = (
      inp.user_message || inp.message || inp.content || ''
    ).toLowerCase();

    const contexts = [];

    // ─── FULL CYCLE TRIGGER ──────────────────────────────
    if (FULLCYCLE_TRIGGERS.some((t) => msg.includes(t))) {
      fs.writeFileSync(FLAG, new Date().toISOString(), 'utf8');
      contexts.push(
        'FULL CYCLE MODE ACTIVATED.\n'
        + 'You MUST:\n'
        + '1. Read ALL required docs: GAME_DESIGN_LAWS.md, QA_PROTOCOLS.md, ARCHITECTURE.md, GAME_DESIGN_BIBLE.md\n'
        + '2. Execute ALL 9 phases of full_cycle_checklist.md with evidence\n'
        + '3. Run Godot tests and paste output verbatim\n'
        + '4. When done, tell user to say "postflight done" and "laws read" to create tokens\n'
        + '5. Commit will be BLOCKED until both HMAC tokens exist.'
      );
    }

    // ─── POSTFLIGHT TOKEN TRIGGER ────────────────────────
    if (POSTFLIGHT_TRIGGERS.some((t) => msg.includes(t))) {
      const token = makeToken('postflight');
      fs.writeFileSync(POSTFLIGHT, 'checklist done — hmac:' + token, 'utf8');
      contexts.push(
        'POST-FLIGHT TOKEN CREATED. HMAC token written to .postflight-done.\n'
        + 'git commit is now allowed (one-time token, deleted after use).'
      );
    }

    // ─── LAWS READ TOKEN TRIGGER ─────────────────────────
    if (LAWS_READ_TRIGGERS.some((t) => msg.includes(t))) {
      const token = makeToken('fullcycle');
      const content =
        'GAME_DESIGN_LAWS.md\nQA_PROTOCOLS.md\nARCHITECTURE.md\nGAME_DESIGN_BIBLE.md\n'
        + 'hmac:' + token;
      fs.writeFileSync(LAWS_READ, content, 'utf8');
      contexts.push(
        'FULL CYCLE LAWS TOKEN CREATED. All 4 docs marked as read.\n'
        + 'Combined with postflight token, git commit is now allowed.'
      );
    }

    // ─── OUTPUT ──────────────────────────────────────────
    if (contexts.length > 0) {
      console.log(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'UserPromptSubmit',
          additionalContext: contexts.join('\n\n'),
        },
      }));
    }
  } catch { /* невалідний JSON — пропустити */ }
});
