#!/usr/bin/env node
/**
 * UserPromptSubmit hook — PRE-FLIGHT self-reflection protocol for game dev.
 *
 * Adapted from ZenFlow enforcement system for Godot/GDScript game project.
 * Injects 11-check protocol with trimodal reasoning (deduction/abduction/induction).
 */
const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const PREFLIGHT_TOKEN = path.join(ROOT, '.preflight-token');

const PROTOCOL = [
  'MANDATORY PRE-FLIGHT CHECK (Game Dev Self-Reflection)',
  '',
  'Before modifying ANY .gd/.tscn file, generate a <thinking> block.',
  'STRICTLY FORBIDDEN to write code until this block is complete.',
  '',
  '=== CHECK 1: GAME DESIGN LAWS ===',
  'REASONING: DEDUCTION — from 30 laws, derive what applies to THIS task.',
  'Which of the 30 GAME_DESIGN_LAWS.md laws apply? List by number.',
  'Which of the 12 axioms (GAME_DESIGN_BIBLE.md) are affected?',
  '',
  '=== CHECK 2: CHILD SAFETY ===',
  'Is this change safe for ages 2-7? No punitive mechanics for toddlers?',
  'COPPA compliance? No data collection? Parental gate intact (LAW 27)?',
  '',
  '=== CHECK 3: FAILURE MODES ===',
  'REASONING: ABDUCTION — given symptoms, what could go wrong?',
  'Top 2 ways this change could crash/hang the game. Reference file:line.',
  'Check: division by zero? Array bounds? Dictionary guard? Await safety?',
  '',
  '=== CHECK 4: GAMEPLAY LOGIC ===',
  'REASONING: INDUCTION — from patterns in existing games, what should this do?',
  'What SKILL does this game develop? Is the gameplay loop teaching that skill?',
  'Is difficulty progressive (LAW 6)? Is star formula correct (LAW 16)?',
  '',
  '=== CHECK 5: SCOPE ===',
  'Files I WILL touch: [list]. Will NOT: [list].',
  'Am I solving what the user ASKED or drifting?',
  '',
  'VERDICT: GO / STOP / ASK',
  '',
  'EMPIRICISM: NEVER say "it works" without running Godot tests.',
  '"Полный цикл" = read ALL 30 laws + 12 axioms + full POST-FLIGHT.',
].join('\n');

let input = '';
process.stdin.on('data', d => input += d);
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const msg = (data.prompt || data.user_message || data.message || data.content || '').toLowerCase();

    // Clean stale preflight token (>1 hour)
    if (fs.existsSync(PREFLIGHT_TOKEN)) {
      try {
        const stat = fs.statSync(PREFLIGHT_TOKEN);
        if (Date.now() - stat.mtimeMs > 3600000) fs.unlinkSync(PREFLIGHT_TOKEN);
      } catch {}
    }

    // Requirement extraction (bilingual RU/UK/EN)
    const CYR = '[а-яёіїєґА-ЯЁІЇЄҐ]*';
    const actions_ru = ['добав', 'исправ', 'удали', 'обнов', 'создай', 'реализ',
      'расшир', 'улучш', 'провер', 'перепровер', 'внедр', 'рефактор', 'переделай'].filter(v => msg.includes(v));
    const actions_en = ['add', 'fix', 'remove', 'update', 'create', 'implement',
      'redesign', 'improve', 'refactor'].filter(v => new RegExp('\\b' + v + '\\b', 'i').test(msg));

    const has_full_cycle = new RegExp('полн' + CYR + '\\s+цикл', 'i').test(msg) || /full\s*cycle/i.test(msg);
    const has_no_simplification = has_full_cycle || /без\s*упрощен/i.test(msg);

    try {
      fs.writeFileSync(path.join(ROOT, '.user-requirements'), JSON.stringify({
        timestamp: new Date().toISOString(),
        actions_ru, actions_en,
        has_no_simplification,
        has_full_cycle,
        total_actions: actions_ru.length + actions_en.length,
      }, null, 2));
    } catch {}

    let context = PROTOCOL;
    if (has_full_cycle) {
      context += '\n\nFULL CYCLE: Read ALL 30 law specs + 12 axioms. POST-FLIGHT with per-law evidence.';
    }

    console.log(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'UserPromptSubmit',
        additionalContext: context,
      },
    }));
  } catch (e) {
    process.stderr.write('HOOK ERROR [preflight-inject]: ' + (e.message || e) + '\n');
  }
});
