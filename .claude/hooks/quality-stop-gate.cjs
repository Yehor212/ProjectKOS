#!/usr/bin/env node
/**
 * Stop hook — warns if uncommitted .gd changes exist without verification.
 * Non-blocking advisory (exit 0). Reminds to run verifier before ending.
 */
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

try {
  const status = execSync('git diff --name-only', { encoding: 'utf8', timeout: 5000 });
  const staged = execSync('git diff --cached --name-only', { encoding: 'utf8', timeout: 5000 });
  const combined = status + '\n' + staged;

  const gdChanges = combined.split('\n').filter(f => f.match(/\.(gd|tscn)$/));

  if (gdChanges.length > 0) {
    const hasVerification = fs.existsSync(path.join(process.cwd(), '.postflight-done'));
    if (!hasVerification) {
      process.stderr.write(
        `REMINDER: ${gdChanges.length} uncommitted .gd/.tscn file(s) changed.\n`
        + 'Run verifier agent before committing. User says "postflight done" to unlock commit.\n'
      );
    }
  }
} catch { /* non-blocking */ }
