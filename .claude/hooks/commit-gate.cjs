#!/usr/bin/env node
/**
 * COMMIT-GATE — механічне примушення через Claude Code hooks.
 * Філософія: memory = advisory = ігнорується. Hooks = law = блокує.
 *
 * PreToolUse hook (matcher: Bash):
 *   - git commit → заблоковано без .postflight-done
 *   - git commit + fullcycle → додатково потрібен .fullcycle-laws-read
 *   - git push → заблоковано без проходження Godot тестів
 *   - Усі токени одноразові — видаляються після успішної перевірки.
 *
 * SECURITY:
 *   - --amend також перевіряється (дира P0 закрита)
 *   - Catch-all блокує за замовчуванням (дира P1 закрита)
 *   - Токени вимагають HMAC-підпис (дира P0: Claude не може підробити)
 */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = process.cwd();
const POSTFLIGHT = path.join(ROOT, '.postflight-done');
const FULLCYCLE_ACTIVE = path.join(ROOT, '.fullcycle-active');
const FULLCYCLE_LAWS = path.join(ROOT, '.fullcycle-laws-read');

// HMAC secret — з env var (Claude не має доступу до process.env)
// Встанови: export CLAUDE_HOOK_SECRET="your-unique-secret-here"
const HMAC_SECRET = process.env.CLAUDE_HOOK_SECRET || 'FALLBACK-CHANGE-ME';

// Обов'язкові документи для повного циклу (ProjectKOS)
const REQUIRED_LAW_FILES = [
  'GAME_DESIGN_LAWS.md',
  'QA_PROTOCOLS.md',
  'ARCHITECTURE.md',
  'GAME_DESIGN_BIBLE.md',
];

// Godot test runner
const GODOT_BIN = process.env.GODOT_PATH
  || 'C:/Godot/Godot_v4.6.1-stable_win64_console.exe';
const GODOT_TEST_CMD = `"${GODOT_BIN}" --headless --path game/ -s tests/run_all_tests.gd --quit-after 60`;

function block(reason) {
  process.stderr.write(reason);
  process.exit(2);
}

/** Генерує HMAC токен для поточної дати (дійсний 24 години). */
function makeToken(payload) {
  const date = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  return crypto
    .createHmac('sha256', HMAC_SECRET)
    .update(date + ':' + payload)
    .digest('hex')
    .slice(0, 16);
}

/** Перевіряє що файл містить валідний HMAC токен. */
function verifyToken(filePath, payload) {
  if (!fs.existsSync(filePath)) return false;
  const content = fs.readFileSync(filePath, 'utf8').trim();
  const expected = makeToken(payload);
  return content.includes(expected);
}

/** Перевіряє чи команда містить git commit/push (з урахуванням варіацій). */
function isGitCommit(cmd) {
  return /git\s+(commit|ci)\b/.test(cmd);
}

function isGitPush(cmd) {
  return /git\s+push\b/.test(cmd);
}

let input = '';
process.stdin.on('data', (d) => (input += d));
process.stdin.on('end', () => {
  try {
    const inp = JSON.parse(input);
    const cmd = inp.tool_input?.command || '';

    // ─── ANTI-FORGERY: блокувати створення токен-файлів через Bash ──
    if (
      cmd.includes('.postflight-done')
      || cmd.includes('.fullcycle-laws-read')
      || cmd.includes('.fullcycle-active')
    ) {
      // Дозволити тільки якщо це rm/cleanup, не створення
      if (
        !cmd.startsWith('rm ')
        && !cmd.startsWith('cat ')
        && !cmd.startsWith('head ')
      ) {
        block(
          'TOKEN FORGERY BLOCKED! Токен-файли створюються тільки через hook систему.\n'
          + 'Для post-flight: виконай чеклист, потім user каже "postflight done".'
        );
      }
    }

    // ─── GIT COMMIT GATE (включаючи --amend) ────────────────
    if (isGitCommit(cmd)) {
      const isFullCycle = fs.existsSync(FULLCYCLE_ACTIVE);

      // 1. Post-flight HMAC token обов'язковий
      if (!verifyToken(POSTFLIGHT, 'postflight')) {
        block(
          'POST-FLIGHT BLOCKED! Виконай post-flight чеклист.\n'
          + 'Коли готово — user повинен сказати "postflight done" щоб hook створив токен.'
        );
      }

      // 2. Full cycle: додаткова перевірка
      if (isFullCycle) {
        if (!fs.existsSync(FULLCYCLE_LAWS)) {
          block(
            'FULL CYCLE BLOCKED! Прочитай усі обов\'язкові документи '
            + 'і запиши їх імена у .fullcycle-laws-read (з HMAC токеном).'
          );
        }
        const lawsContent = fs.readFileSync(FULLCYCLE_LAWS, 'utf8');
        const missing = REQUIRED_LAW_FILES.filter(
          (f) => !lawsContent.includes(f)
        );
        if (missing.length > 0) {
          block(
            'FULL CYCLE INCOMPLETE! Не прочитані документи:\n  '
            + missing.join('\n  ')
          );
        }
        // Перевірити HMAC підпис
        if (!verifyToken(FULLCYCLE_LAWS, 'fullcycle')) {
          block('FULL CYCLE TOKEN INVALID! HMAC підпис невірний.');
        }
      }

      // 3. Успіх — видалити одноразові токени
      try { fs.unlinkSync(POSTFLIGHT); } catch { /* ок */ }
      if (isFullCycle) {
        try { fs.unlinkSync(FULLCYCLE_LAWS); } catch { /* ок */ }
        try { fs.unlinkSync(FULLCYCLE_ACTIVE); } catch { /* ок */ }
      }
      // Дозволити коміт (exit 0)
      return;
    }

    // ─── GIT PUSH GATE ─────────────────────────────────────
    if (isGitPush(cmd)) {
      // Перевірити чи Godot доступний
      if (!fs.existsSync(GODOT_BIN) && !process.env.GODOT_PATH) {
        block(
          'GODOT NOT FOUND at ' + GODOT_BIN + '.\n'
          + 'Set GODOT_PATH env var or install Godot.\n'
          + 'Push blocked until tests can run.'
        );
      }

      const { execSync } = require('child_process');
      try {
        execSync(GODOT_TEST_CMD, {
          cwd: ROOT,
          stdio: 'pipe',
          timeout: 90000,
        });
        // Тести пройшли — дозволити push
      } catch (err) {
        const output = (err.stdout || '').toString().slice(-500);
        block(
          'GODOT TESTS FAILED! Виправ тести перед push.\n'
          + 'Last output:\n' + output
        );
      }
    }

    // Не git commit/push → дозволити (exit 0)

  } catch (err) {
    // SECURITY: помилка парсингу = блокувати за замовчуванням
    // (закрита дира P1: silent catch = allow all)
    const errMsg = err?.message || 'unknown error';
    // Але тільки для git команд — інші Bash команди пропускаємо
    if (input.includes('git commit') || input.includes('git push')) {
      block('GATE ERROR (fail-closed): ' + errMsg);
    }
    // Не git — дозволити
  }
});
