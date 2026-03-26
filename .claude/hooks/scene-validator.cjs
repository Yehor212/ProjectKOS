#!/usr/bin/env node
/**
 * PostToolUse hook — validates .tscn files after Edit/Write.
 * BLOCKING (exit 2) if GPUParticles2D found (LAW 18).
 */
const fs = require('fs');

let input = '';
process.stdin.on('data', d => input += d);
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const tool = data.tool_name || '';
    const filePath = data.tool_input?.file_path || '';

    // Only check .tscn files on Edit/Write
    if (!filePath.endsWith('.tscn')) return;
    if (!['Edit', 'Write'].includes(tool)) return;
    if (!fs.existsSync(filePath)) return;

    const content = fs.readFileSync(filePath, 'utf8');

    // LAW 18: No GPUParticles2D — only CPUParticles2D allowed
    if (/GPUParticles2D/.test(content)) {
      process.stderr.write(
        'LAW 18 VIOLATION: GPUParticles2D found in ' + filePath.split(/[/\\]/).pop() + '.\n'
        + 'Use CPUParticles2D instead (gl_compatibility renderer, Android target).\n'
        + 'Replace all GPUParticles2D nodes with CPUParticles2D.'
      );
      process.exit(2);
    }
  } catch { /* non-blocking on parse errors */ }
});
