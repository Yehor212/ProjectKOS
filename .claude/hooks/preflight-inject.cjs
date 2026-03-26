#!/usr/bin/env node
/**
 * UserPromptSubmit hook — SHORT preflight injection for .gd/.tscn edits.
 * Max 300 tokens. All detail lives in guardians, not here.
 */
const fs = require('fs');
const path = require('path');

let input = '';
process.stdin.on('data', d => input += d);
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const msg = (data.prompt || data.user_message || data.message || data.content || '').toLowerCase();

    // Detect code-editing intent
    const actions = ['add', 'fix', 'remove', 'update', 'create', 'implement', 'refactor',
      'добав', 'исправ', 'удали', 'обнов', 'создай', 'реализ', 'переделай', 'улучш'];
    const hasAction = actions.some(a => msg.includes(a));
    const hasFullCycle = /полн.*цикл|full\s*cycle/i.test(msg);

    // Track requirements
    try {
      fs.writeFileSync(path.join(process.cwd(), '.user-requirements'), JSON.stringify({
        timestamp: new Date().toISOString(),
        has_action: hasAction,
        has_full_cycle: hasFullCycle,
      }, null, 2));
    } catch {}

    // Short protocol — delegates to guardians
    let context = [
      'Before editing .gd/.tscn: read affected files, then write <thinking> block.',
      'Check: which Laws (1-30) apply? Child-safe (ages 2-7)? Top 2 failure modes?',
      'Scope: list files to touch. Verdict: GO / STOP / ASK.',
      'After edits: route to verifier agent. Never verify your own code.',
    ].join('\n');

    if (hasFullCycle) {
      context += '\nFULL CYCLE: read ALL docs, run ALL guardians, execute full_cycle_checklist.md.';
    }

    console.log(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'UserPromptSubmit',
        additionalContext: context,
      },
    }));
  } catch (e) {
    process.stderr.write('HOOK ERROR [preflight]: ' + (e.message || e) + '\n');
  }
});
