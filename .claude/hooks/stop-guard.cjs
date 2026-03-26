#!/usr/bin/env node
/**
 * Stop hook — blocks stop if .gd/.tscn files were changed without postflight.
 * Checks git diff for code changes and requires .postflight-done token.
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT = process.cwd();
const POSTFLIGHT = path.join(ROOT, '.postflight-done');

try {
  // Check if postflight already done
  if (fs.existsSync(POSTFLIGHT)) {
    process.exit(0);
  }

  // Check for code changes in .gd/.tscn files
  let diff = '';
  try {
    diff = execSync('git diff --name-only HEAD', {
      encoding: 'utf8',
      timeout: 5000,
      cwd: ROOT,
    });
  } catch {
    // Also check unstaged
    try {
      diff = execSync('git diff --name-only', {
        encoding: 'utf8',
        timeout: 5000,
        cwd: ROOT,
      });
    } catch {
      // Git not available or no repo — allow stop
      process.exit(0);
    }
  }

  // Also check staged changes
  try {
    const staged = execSync('git diff --cached --name-only', {
      encoding: 'utf8',
      timeout: 5000,
      cwd: ROOT,
    });
    diff += '\n' + staged;
  } catch { /* ignore */ }

  const codeChanges = diff
    .split('\n')
    .filter(f => /\.(gd|tscn)$/.test(f.trim()));

  if (codeChanges.length > 0) {
    process.stderr.write(
      `STOP BLOCKED: ${codeChanges.length} code file(s) changed without postflight:\n`
      + codeChanges.slice(0, 5).map(f => '  ' + f.trim()).join('\n')
      + (codeChanges.length > 5 ? `\n  ... and ${codeChanges.length - 5} more` : '')
      + '\n\nRun /postflight to verify changes, then say "postflight done" to unlock.'
    );
    process.exit(2);
  }

  // No code changes — allow stop
  process.exit(0);
} catch (err) {
  // Fail open on unexpected errors (don't trap the user)
  process.exit(0);
}
