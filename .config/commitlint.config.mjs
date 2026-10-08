// templates/base: copy to .config/commitlint.config.mjs. Policy first - edit
// it; the body-bullets rule below is the one config-conventional lacks.
//
// Every rule is an error or off: the hook runs --strict, which fails a
// warning too.
import { execFileSync } from 'node:child_process';
import { existsSync, readdirSync } from 'node:fs';

// Basenames of the directories under root, relative to the repo root: a
// scope per package. A missing root is no scopes, not an error.
export const dirs = (root) => {
  try {
    return readdirSync(root, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => d.name);
  } catch {
    return [];
  }
};

const types = ['feat', 'fix', 'refactor', 'chore', 'style', 'docs', 'build', 'perf', 'test'];
// Cross-cutting names, then one scope per role and per docs topic.
const scopes = [
  'repo',
  'docs',
  'deps',
  'release',
  'build',
  'tests',
  'hooks',
  'make',
  'galaxy',
  'readme',
  'context',
  'changelog',
  'golden',
  'sanity',
  'playbooks',
  ...dirs('roles'),
  ...dirs('docs'),
];

const scissors = '# ------------------------ >8 ------------------------';
const reTrailer = /^[A-Za-z][A-Za-z0-9-]*: \S/;

// The body is `- ` bullets, back to back, one line each, at most `max`. A
// trailer block may close the message, one blank line before it allowed -
// what git itself writes.
export const bodyBullets = ({ raw }, _when, max = 2) => {
  const lines = [];
  for (const line of (raw ?? '').split('\n')) {
    if (line === scissors) break;
    if (!line.startsWith('#')) lines.push(line.trimEnd());
  }
  while (lines.at(-1) === '') lines.pop();

  let end = lines.length;
  while (end > 1 && reTrailer.test(lines[end - 1])) end--;
  if (end < lines.length && end > 2 && lines[end - 1] === '') end--;
  // No blank under the header is body-leading-blank's to report.
  const start = lines[1] === '' ? 2 : 1;

  const errs = [];
  let bullets = 0;
  let run = null; // wrapped lines are one mistake, not one per line
  const flush = () => {
    if (run?.prose) {
      errs.push(
        `body is prose, not bullets (lines ${run.from}-${run.to})\n  write: - ${run.text}`,
      );
    } else if (run && run.to > run.from) {
      errs.push(
        `bullet wraps across lines ${run.from}-${run.to}\n  write: one bullet per line - cut it, or split it into two`,
      );
    }
    run = null;
  };

  lines.slice(start, end).forEach((line, i) => {
    const at = start + i + 1;
    if (/^- \S/.test(line)) {
      flush();
      bullets++;
      run = { from: at, to: at };
    } else if (line === '') {
      flush();
      errs.push(`line ${at} is blank inside the body\n  write: the bullets back to back`);
    } else if (run && /^\s/.test(line)) {
      run.to = at;
      run.text += ` ${line.trim()}`;
    } else if (run?.prose) {
      run.to = at;
      run.text += ` ${line.trim()}`;
    } else if (reTrailer.test(line)) {
      flush();
      errs.push(
        `line ${at} is a trailer inside the body\n  write: every trailer in one block at the end, no blank between`,
      );
    } else {
      flush();
      run = { from: at, to: at, prose: true, text: line.replace(/^-\s*/, '') };
    }
  });
  flush();

  if (bullets > max) {
    errs.push(`${bullets} bullets, at most ${max}\n  write: the ${max} that matter`);
  }
  return [errs.length === 0, errs.join('\n    ')];
};

// A rebase replays messages it did not author: failing them would make this
// hook the reason you cannot rebase.
const rebasing = () =>
  ['rebase-merge', 'rebase-apply'].some((p) =>
    existsSync(execFileSync('git', ['rev-parse', '--git-path', p], { encoding: 'utf8' }).trim()),
  );

export default {
  extends: ['@commitlint/config-conventional'],
  helpUrl: 'https://github.com/fabbrito/repokit#message-rules',
  ignores: [rebasing],
  plugins: [{ rules: { 'body-bullets': bodyBullets } }],
  rules: {
    'type-enum': [2, 'always', types],
    'scope-enum': [2, 'always', scopes],
    'header-max-length': [2, 'always', 72],
    'body-max-line-length': [2, 'always', 80],
    'body-bullets': [2, 'always', 2],
    'body-leading-blank': [2, 'always'],
    // A trailer may follow the last bullet directly.
    'footer-leading-blank': [0],
  },
};
