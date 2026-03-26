#!/usr/bin/env node
/**
 * PostToolUse advisory hook — real-time feedback after Edit/Write on .gd/.tscn files.
 * Non-blocking (exit 0 always). Scans changed content for common violations.
 */
const fs = require('fs');

let input = '';
process.stdin.on('data', d => input += d);
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const tool = data.tool_name || '';
    const filePath = data.tool_input?.file_path || '';

    // Only check .gd and .tscn files
    if (!filePath.match(/\.(gd|tscn)$/)) return;
    if (!['Edit', 'Write'].includes(tool)) return;
    if (!fs.existsSync(filePath)) return;

    const content = fs.readFileSync(filePath, 'utf8');
    const warnings = [];

    // LAW 17: dict[key] without guard
    const dictLines = content.split('\n');
    dictLines.forEach((line, i) => {
      // Skip comments
      if (line.trimStart().startsWith('#')) return;
      // Bare dict access pattern: word[word] not preceded by .has or .get
      if (/\w+\[\w+\]/.test(line) && !line.includes('.has(') && !line.includes('.get(')
          && !line.includes('Array') && !line.includes('pool[') && !line.includes('# ok')) {
        // Check if it's likely a dict access (heuristic)
        if (!/\bfor\b/.test(line) && !/\brange\b/.test(line) && !/\bvar\b.*:.*Array/.test(line)) {
          warnings.push(`LAW 17 (dict guard): possible unguarded dict access — line ${i + 1}`);
        }
      }
    });

    // LAW 20: await without is_instance_valid
    const awaitPattern = /await\s/;
    const validPattern = /is_instance_valid/;
    dictLines.forEach((line, i) => {
      if (line.trimStart().startsWith('#')) return;
      if (awaitPattern.test(line)) {
        // Check next 3 lines for validity check
        const nextLines = dictLines.slice(i + 1, i + 4).join(' ');
        if (!validPattern.test(nextLines) && !line.includes('# no-check')) {
          warnings.push(`LAW 20 (await safety): await without is_instance_valid — line ${i + 1}`);
        }
      }
    });

    // QA #1: early return without push_warning
    dictLines.forEach((line, i) => {
      if (line.trimStart().startsWith('#')) return;
      if (/\breturn\b/.test(line) && line.includes('\t') && !line.includes('push_warning')
          && !line.includes('func ') && !line.includes('# ok')
          && !/return\s+\w/.test(line.trim())) {
        // Only flag bare returns inside conditions (indented)
        const indent = line.search(/\S/);
        if (indent >= 2) {
          warnings.push(`QA #1 (silent return): return without push_warning — line ${i + 1}`);
        }
      }
    });

    // A12: hardcoded visible strings
    dictLines.forEach((line, i) => {
      if (line.trimStart().startsWith('#')) return;
      if (/\.text\s*=\s*"[A-Za-z]/.test(line) && !line.includes('tr(') && !line.includes('# ok')) {
        warnings.push(`A12 (i18n): hardcoded string assignment — line ${i + 1}`);
      }
    });

    // LAW 13: division without guard
    dictLines.forEach((line, i) => {
      if (line.trimStart().startsWith('#')) return;
      if (/\/\s*\w+/.test(line) && !line.includes('maxf(') && !line.includes('maxi(')
          && !line.includes('# safe') && !line.includes('2.0') && !line.includes('/2')
          && !/\/\//.test(line) && !line.includes('res://')) {
        // Very rough heuristic — only flag suspicious divisions
        if (/\w+\s*\/\s*[a-z_]\w*/.test(line) && !line.includes('PI') && !line.includes('TAU')) {
          warnings.push(`LAW 13 (numeric safety): possible unguarded division — line ${i + 1}`);
        }
      }
    });

    if (warnings.length > 0) {
      const msg = `ADVISORY (${warnings.length} warnings in ${filePath.split(/[/\\]/).pop()}):\n`
        + warnings.slice(0, 5).map(w => '  * ' + w).join('\n')
        + (warnings.length > 5 ? `\n  ... and ${warnings.length - 5} more` : '');
      process.stderr.write(msg + '\n');
    }
  } catch { /* non-blocking — ignore errors */ }
});
