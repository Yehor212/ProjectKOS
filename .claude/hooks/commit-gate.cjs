#!/usr/bin/env node
/**
 * COMMIT-GATE v2 — спрощена версія без HMAC.
 *
 * PreToolUse hook (matcher: Bash):
 *   - git commit → заблоковано без .postflight-done (Claude створює після postflight)
 *   - git push → заблоковано без проходження Godot тестів
 *   - Токен одноразовий — видаляється після успішного коміту.
 *
 * Потік:
 *   1. Claude виконує postflight чеклист
 *   2. Claude створює .postflight-done через Write tool
 *   3. git commit проходить
 *   4. .postflight-done автоматично видаляється
 */
const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const POSTFLIGHT = path.join(ROOT, '.postflight-done');

// Godot test runner — cross-platform binary detection
function findGodot() {
  if (process.env.GODOT_PATH) return process.env.GODOT_PATH;
  const { execSync } = require('child_process');
  try {
    const bin = execSync(process.platform === 'win32' ? 'where godot' : 'which godot', {
      encoding: 'utf8', timeout: 3000,
    }).trim().split('\n')[0];
    if (bin && fs.existsSync(bin)) return bin;
  } catch { /* not in PATH */ }
  const candidates = [
    '/c/Godot/Godot_v4.6.1-stable_win64_console.exe',
    'C:/Godot/Godot_v4.6.1-stable_win64_console.exe',
    '/usr/local/bin/godot',
    '/usr/bin/godot',
    '/Applications/Godot.app/Contents/MacOS/Godot',
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  return null;
}
const GODOT_BIN = findGodot();

function block(reason) {
  process.stderr.write(reason);
  process.exit(2);
}

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

    // ─── GIT COMMIT GATE ────────────────────────────────────
    if (isGitCommit(cmd)) {
      // Post-flight файл обов'язковий
      if (!fs.existsSync(POSTFLIGHT)) {
        block(
          'POST-FLIGHT BLOCKED! Run /postflight first.\n'
          + 'Claude must create .postflight-done after completing the checklist.'
        );
      }
      // Видалити одноразовий токен
      try { fs.unlinkSync(POSTFLIGHT); } catch { /* ok */ }
      // Дозволити коміт
      return;
    }

    // ─── GIT PUSH GATE ─────────────────────────────────────
    if (isGitPush(cmd)) {
      if (!GODOT_BIN) {
        process.stderr.write('WARNING: Godot not found, tests skipped on push.\n');
        return;
      }
      const { execSync } = require('child_process');
      try {
        execSync(`"${GODOT_BIN}" --headless --path game/ -s tests/run_all_tests.gd --quit-after 60`, {
          cwd: ROOT, stdio: 'pipe', timeout: 90000,
        });
      } catch (err) {
        const output = (err.stdout || '').toString().slice(-500);
        block('GODOT TESTS FAILED!\n' + output);
      }
    }
    // Не git commit/push → дозволити

  } catch (err) {
    if (input.includes('git commit') || input.includes('git push')) {
      block('GATE ERROR: ' + (err?.message || 'unknown'));
    }
  }
});
