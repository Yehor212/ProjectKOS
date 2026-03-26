#!/usr/bin/env node
/**
 * PostToolUse hook — validates .gd files after Edit/Write.
 * Advisory mode (exit 0 always). Outputs warnings via hookSpecificOutput.
 */
const fs = require('fs');

let input = '';
process.stdin.on('data', d => input += d);
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const tool = data.tool_name || '';
    const filePath = data.tool_input?.file_path || '';

    // Only check .gd files on Edit/Write
    if (!filePath.endsWith('.gd')) return;
    if (!['Edit', 'Write'].includes(tool)) return;
    if (!fs.existsSync(filePath)) return;

    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');
    const warnings = [];

    // QA #1: return without push_warning on previous line
    lines.forEach((line, i) => {
      if (line.trimStart().startsWith('#')) return;
      const trimmed = line.trim();
      if (/^\breturn\b$/.test(trimmed) || /^return$/.test(trimmed)) {
        // Bare return (no value) inside indented block
        const indent = line.search(/\S/);
        if (indent >= 1) {
          // Check previous non-empty line for push_warning
          let found = false;
          for (let j = i - 1; j >= Math.max(0, i - 3); j--) {
            const prev = lines[j].trim();
            if (prev === '' || prev.startsWith('#')) continue;
            if (prev.includes('push_warning')) { found = true; break; }
            break;
          }
          if (!found) {
            warnings.push(`QA #1: return without push_warning — line ${i + 1}`);
          }
        }
      }
    });

    // LAW 20: await without is_instance_valid on following lines
    lines.forEach((line, i) => {
      if (line.trimStart().startsWith('#')) return;
      if (/\bawait\b/.test(line)) {
        const nextLines = lines.slice(i + 1, i + 4).join(' ');
        if (!nextLines.includes('is_instance_valid') && !line.includes('# no-check')) {
          warnings.push(`LAW 20: await without is_instance_valid check — line ${i + 1}`);
        }
      }
    });

    // QA #9: TODO or FIXME
    lines.forEach((line, i) => {
      if (/\bTODO\b|\bFIXME\b/.test(line)) {
        warnings.push(`QA #9: TODO/FIXME found — line ${i + 1}`);
      }
    });

    // LAW 13 advisory: array[0], array[1] etc without size check
    lines.forEach((line, i) => {
      if (line.trimStart().startsWith('#')) return;
      if (/\w+\[\d+\]/.test(line)) {
        // Check if preceding lines have .size() check
        const context = lines.slice(Math.max(0, i - 5), i).join(' ');
        if (!context.includes('.size()') && !context.includes('.is_empty()') && !line.includes('# ok')) {
          warnings.push(`LAW 13 (advisory): possible unguarded array index access — line ${i + 1}`);
        }
      }
    });

    if (warnings.length > 0) {
      const fileName = filePath.split(/[/\\]/).pop();
      const output = JSON.stringify({
        hookSpecificOutput: {
          additionalContext: `ADVISORY (${warnings.length} warnings in ${fileName}):\n`
            + warnings.slice(0, 8).map(w => '  * ' + w).join('\n')
            + (warnings.length > 8 ? `\n  ... and ${warnings.length - 8} more` : '')
        }
      });
      process.stdout.write(output);
    }
  } catch { /* non-blocking */ }
});
