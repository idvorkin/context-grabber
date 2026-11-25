// Story 1503 (spec docs/superpowers/specs/2026-11-22-board-rules-on-the-web-design.md): the board's rules as
// WebAssembly, run under node's WASI as the Cockpit would run them. The Cockpit's recorded board sessions (vendored
// scrubbed by scripts/native/board-sessions.py) replay through the module as BoardSessionReplayTests replays them
// natively; the loaded board answers a cut the same whether it arrived whole or as new ink; failures say why.
//   node scripts/native/test-board-wasm.mjs <BoardWasm.wasm>      (just wasm-test builds it first)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { isDeepStrictEqual } from 'node:util';
import { WASI } from 'node:wasi';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const fixtures = path.join(root, 'native/ContextCore/Tests/ContextCoreTests/Fixtures/board-sessions');
const wasmPath = process.argv[2] ?? path.join(root, 'native/Build/wasm/BoardWasm.wasm');

// As BoardSessionReplayTests.changedSince: where today's board answers otherwise than the build that was recorded.
const changedSince = { 'ops-move': ['batch 49946d13484f'] };
// The one natural 32-bit midpoint flip the spike found (spec, Precision): on title-build's last board, y = 100 is the
// exact middle of the row from 38.425 to 161.575. In 32 bits the way up is shorter, so the cut lands on the row's top;
// the iPad's 64-bit rules land on its bottom. A change here means the rules or the toolchain changed.
const pinned = { session: 'title-build', y: 100, cut: Math.fround(38.425) };

const wasi = new WASI({ version: 'preview1', args: [], env: {}, returnOnExit: true });
const module = await WebAssembly.compile(fs.readFileSync(wasmPath));
const instance = await WebAssembly.instantiate(module, wasi.getImportObject());
wasi.initialize(instance);
const x = instance.exports;
const encoder = new TextEncoder();
const decoder = new TextDecoder();

/** A reply: four bytes of length, little-endian, then UTF-8. Freed once read. */
function read(pointer) {
  if (!pointer) return null;
  const length = new DataView(x.memory.buffer).getUint32(pointer, true);
  const text = decoder.decode(new Uint8Array(x.memory.buffer, pointer + 4, length));
  x.bw_free(pointer);
  return text;
}
/** Calls an export taking (pointer, length) with the text written into the module's memory, then frees it. */
function call(name, text) {
  const bytes = encoder.encode(typeof text === 'string' ? text : JSON.stringify(text));
  const pointer = x.bw_alloc(bytes.length);
  new Uint8Array(x.memory.buffer, pointer, bytes.length).set(bytes);
  const result = x[name](pointer, bytes.length);
  x.bw_free(pointer);
  return result;
}
const error = () => read(x.bw_error());

let passed = 0;
const failures = [];
function check(ok, what) {
  if (ok) passed++;
  else failures.push(what);
}

// The interface's version and sizes.
const info = JSON.parse(read(x.bw_info()));
check(info.abi === 23, `bw_info abi is 23: ${JSON.stringify(info)}`);
check(info.contract === 1 && info.line === 40 && info.near === 80, `bw_info contract, line, near: ${JSON.stringify(info)}`);
check(info.cgfloat_bits === 32, `bw_info says the rules' arithmetic is 32-bit: ${info.cgfloat_bits}`);

// Nothing loaded: NaN, and why.
check(Number.isNaN(x.bw_cut_y(100)), 'a cut with nothing loaded is NaN');
check(error() === 'no board is loaded', 'and bw_error says no board is loaded');
check(call('bw_add_strokes', { strokes: [] }) === -1 && error() === 'no board is loaded', 'no new ink without a board');

const names = Object.keys(JSON.parse(fs.readFileSync(path.join(fixtures, 'SOURCE.json'), 'utf8')).sessions).sort();
check(names.length === 4, `four recorded sessions: ${names}`);
const lastBoards = {};

for (const name of names) {
  const jsonl = fs.readFileSync(path.join(fixtures, `${name}.jsonl`), 'utf8');
  const golden = JSON.parse(fs.readFileSync(path.join(fixtures, `${name}.golden.json`), 'utf8')).contexts;
  const report = JSON.parse(read(call('bw_replay', jsonl)));
  if (report.error) {
    failures.push(`${name}: ${report.error}`);
    continue;
  }
  // testEverySessionIsContractOneAndReplaysAsRecordedButForWhatChangedSince
  const known = changedSince[name] ?? [];
  check(report.contract === 1 && report.name === name, `${name}: contract 1, named ${report.name}`);
  check(report.turns.length > 0, `${name}: has turns`);
  const unexpected = report.mismatches.filter((m) => !known.some((k) => m.startsWith(k)));
  check(unexpected.length === 0 && report.mismatches.length === known.length, `${name}: mismatches ${JSON.stringify(report.mismatches)}`);
  // testEachTurnCarriesWhatTheCockpitsRecordedHintToldLarry
  const ids = report.turns.map((t) => t.id).sort();
  check(JSON.stringify(ids) === JSON.stringify(Object.keys(golden).sort()), `${name}: the same turns as the golden`);
  for (const turn of report.turns) {
    if (turn.onBoard) check((golden[turn.id] ?? '').endsWith(' ' + turn.hint), `${name} ${turn.id}: hint is the end of the recorded one`);
    else check(!(golden[turn.id] ?? '').includes('· board '), `${name} ${turn.id}: words alone`);
  }
  if (name === 'ops-move') {
    // testABatchAfterIgorDrewOnceMoreNowAppliesWhereTheRecordedBuildRefusedIt
    const [first, last] = [report.batches[0], report.batches.at(-1)];
    check(report.batches.length === 2, 'ops-move: two batches');
    check(first.arrivedAt === 257 && first.recordedOk === false && first.replayedOk === true && !first.matches,
      `ops-move: the stale batch now applies ${JSON.stringify(first)}`);
    check(last.recordedOk === null && last.replayedOk === true, `ops-move: the resend applies ${JSON.stringify(last)}`);
  }
  if (name === 'question-card') {
    // testADeleteWhileIgorKeptWritingAppliesRebasedFromHisLook
    const first = report.batches[0];
    check(first.replayedOk === true && first.matches === true, `question-card: the delete applies as recorded ${JSON.stringify(first)}`);
  }
  for (const line of jsonl.split('\n')) {
    if (!line.trim()) continue;
    const step = JSON.parse(line);
    if (step.step === 'post' && step.route === '/whiteboard/strokes') lastBoards[name] = step.body;
  }
}

// The board stays loaded: whole, or half and then the rest as new ink, it answers every cut the same.
for (const name of names) {
  const board = lastBoards[name];
  if (!board) {
    failures.push(`${name}: no board posted`);
    continue;
  }
  const maxY = Math.max(...board.strokes.flatMap((s) => (s.points ?? [[0, s.y + (s.h ?? 0)]]).map((p) => p[1]))) + 100;
  const ys = [];
  for (let y = -20; y <= maxY; y += 1.5) ys.push(y);
  const whole = call('bw_load', board);
  check(whole > 0, `${name}: loads (${whole} boxes) ${error() ?? ''}`);
  const cuts = ys.map((y) => x.bw_cut_y(y));
  check(cuts.every((c, i) => Number.isFinite(c) && c >= ys[i] - info.near), `${name}: every cut is the height, below it, or at most near above it`);
  const half = Math.floor(board.strokes.length / 2);
  const first = call('bw_load', { ...board, strokes: board.strokes.slice(0, half) });
  const added = call('bw_add_strokes', { strokes: board.strokes.slice(half) });
  check(first >= 0 && added === whole, `${name}: in two halves, ${first} then ${added} boxes (whole: ${whole})`);
  const again = ys.map((y) => x.bw_cut_y(y));
  const differ = ys.filter((y, i) => !Object.is(cuts[i], again[i]));
  check(differ.length === 0, `${name}: ${ys.length} cuts the same whole and in halves (differ at ${differ.slice(0, 5)})`);
  // A stroke it can't read leaves the board as it was.
  check(call('bw_add_strokes', { strokes: [{ points: [[0, 0]] }] }) === -1 && /no id/.test(error() ?? ''), `${name}: a stroke with no id is refused, saying why`);
  check(Object.is(x.bw_cut_y(ys[ys.length >> 1]), again[ys.length >> 1]), `${name}: and the board is as it was`);
  check(call('bw_add_strokes', { strokes: {} }) === -1 && /no strokes list/.test(error() ?? ''), `${name}: strokes that are not a list are refused, saying why`);
  check(Object.is(x.bw_cut_y(ys[ys.length >> 1]), again[ys.length >> 1]), `${name}: and the board is still as it was`);
  if (name === pinned.session) {
    const cut = x.bw_cut_y(pinned.y);
    check(cut === pinned.cut, `${name}: the 32-bit midpoint case, cut at ${pinned.y} lands on ${cut} (pinned ${pinned.cut})`);
  }
}

// A board built by hand, so each kind of box is there: a line of ink, a hidden stroke (left out), a kept text, and two
// strokes Larry grouped (one box across the gap between them).
const line = (id, y, extra = {}) => ({ id, points: [[0, y], [200, y]], width: 4, ...extra });
const hand = {
  board: 'hand',
  strokes: [
    line('ink', 100),
    line('hidden', 300, { hidden: true }),
    { id: 'text', kind: 'text', x: 0, y: 200, w: 100, h: 40, t: 1000 },
    line('g1', 400, { width: 2, meta: { group: 'g' } }),
    line('g2', 480, { width: 2, meta: { group: 'g' } }),
  ],
};
check(call('bw_load', hand) === 3, `by hand: three boxes (ink, text, the group) ${error() ?? ''}`);
const handCuts = { 99: 98, 210: 200, 230: 240, 300: 300, 350: 350, 430: 399, 470: 481 };
for (const [y, cut] of Object.entries(handCuts)) {
  check(x.bw_cut_y(Number(y)) === cut, `by hand: a cut at ${y} lands on ${cut}, not ${x.bw_cut_y(Number(y))}`);
}
// A kept text is told from another by its time, as on the iPad: two with their own t are two boxes; two without are
// taken for one text's glyphs (spec, a kept text carries its t).
const text = (id, y, t) => ({ id, kind: 'text', x: 0, y, w: 100, h: 40, ...(t ? { t } : {}) });
check(call('bw_load', { board: 'texts', strokes: [text('a', 0, 1000), text('b', 100, 2000)] }) === 2, 'two kept texts with their own t: two boxes');
check(call('bw_load', { board: 'texts', strokes: [text('a', 0), text('b', 100)] }) === 1, 'two kept texts with no t: one box');

// A board it can't read: -1, why, and nothing loaded after.
check(call('bw_load', 'not json') === -1 && /could not be read/.test(error() ?? ''), 'an unreadable board is refused, saying why');
check(Number.isNaN(x.bw_cut_y(0)), 'and nothing is loaded after it');

// Interface 2, story 1508 (spec, rows and folds): the outline, held apart from the board, answers the row a tap is on and what a
// header folds. Built by hand so every number is worked out: a header at 100, two indented lines under it, a line back
// at the header's indent at 300 (which ends its section) and a kept text at 400.
const reply = (pointer) => JSON.parse(read(pointer));
const ask = (name, body) => reply(call(name, body));
check(reply(x.bw_row_at(100)).error === 'no outline is loaded', 'a row with no outline says none is loaded');
check(ask('bw_fold', { id: 'H' }).error === 'no outline is loaded', 'a fold with no outline says none is loaded');
check(call('bw_outline_add', { strokes: [] }) === -1 && error() === 'no outline is loaded', 'no new outline ink without an outline');
const outline = {
  strokes: [line('h1', 100), { ...line('b1', 140), points: [[60, 140], [200, 140]] },
    { ...line('b2', 180), points: [[60, 180], [200, 180]] }, line('n', 300)],
  boxes: [{ id: 't', box: [0, 400, 100, 440] }],
  groups: { t: 't' },
  headers: [{ id: 'H', ids: ['h1'] }],
};
check(call('bw_outline_load', outline) === 5, `the outline: four strokes and a box ${error() ?? ''}`);
const rowAt = (y) => reply(x.bw_row_at(y)).row;
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
check(same(rowAt(100), { bottom: 102, header: 'H', top: 98 }), `the header's row at 100: ${JSON.stringify(rowAt(100))}`);
check(same(rowAt(119), { bottom: 102, header: 'H', top: 98 }), 'within half a line below it, still the header');
check(same(rowAt(140), { bottom: 142, names: ['b1'], top: 138 }), `a line of ink at 140: ${JSON.stringify(rowAt(140))}`);
check(rowAt(250) === null, `blank paper at 250: ${JSON.stringify(rowAt(250))}`);
check(same(rowAt(420), { bottom: 440, names: [], top: 400 }), `a kept text is no one's ink: ${JSON.stringify(rowAt(420))}`);
// The fold: b1 and b2 tuck under H; the rest slides up to a line under the header in whole lines (300 - 102 = 198, four
// lines down less one = 120); two lines hidden; the section ended 80 under the header row.
const folded = { fold: { bottom: 80, ids: ['b1', 'b2'], lines: 2, own: ['b1', 'b2'], shift: 120 } };
check(same(ask('bw_fold', { id: 'H' }), folded), `folding H: ${JSON.stringify(ask('bw_fold', { id: 'H' }))}`);
check(same(ask('bw_fold', { id: 'H' }), folded) && same(rowAt(140), { bottom: 142, names: ['b1'], top: 138 }), 'asking leaves the outline as it was');
check(same(ask('bw_fold', { id: 'nobody' }), { fold: null }), 'no such header: nothing to fold');
check(ask('bw_fold', {}).error === 'no header id', 'a fold with no id says so');
// New ink at the end, and ink it can't read.
check(call('bw_outline_add', { strokes: [line('n2', 340)] }) === 6, `new ink at 340 ${error() ?? ''}`);
check(same(rowAt(340), { bottom: 342, names: ['n2'], top: 338 }), `and its row: ${JSON.stringify(rowAt(340))}`);
check(call('bw_outline_add', { strokes: [{ points: [[0, 0]] }] }) === -1 && /no id/.test(error() ?? ''), 'outline ink with no id is refused, saying why');
check(call('bw_outline_add', { strokes: [{ id: 'z', points: [] }] }) === -1 && /no points/.test(error() ?? ''), 'outline ink with no points is refused, saying why');
check(same(rowAt(340), { bottom: 342, names: ['n2'], top: 338 }) && call('bw_outline_add', { strokes: [] }) === 6, 'and the outline is as it was');
check(call('bw_outline_load', { boxes: [{ id: 't', box: [0, 400, 100, 440] }] }) === 1 && same(rowAt(420), { bottom: 440, names: [], top: 400 }), `a box with no group is still no one's ink: ${JSON.stringify(rowAt(420))}`);
// Story 1280 (interface 18): a group is Larry's, no one's writing, unless the outline names it as Igor's.
{
  const g = (mine) => ({ strokes: [['a', 100], ['b', 124], ['c', 148]].map(([id, x0]) => ({ id, points: [[x0, 524], [x0 + 10, 500], [x0 + 20, 524]] })), groups: { a: 'g', b: 'g', c: 'g' }, ...(mine ? { mine } : {}) });
  check(call('bw_outline_load', g()) === 3 && same(rowAt(512).names, []), `a group of Larry's is none of his writing: ${JSON.stringify(rowAt(512))}`);
  check(call('bw_outline_load', g(['g'])) === 3 && same(rowAt(512).names, ['a', 'b', 'c']), `a group named mine is his writing: ${JSON.stringify(rowAt(512))}`);
}
check(call('bw_outline_load', { boxes: [{ id: 'b', box: [0, 0] }] }) === -1 && /\[left, top, right, bottom\]/.test(error() ?? ''), 'a box with no four sides is refused, saying why');
check(call('bw_outline_load', { headers: 'nope' }) === -1 && /headers could not be read/.test(error() ?? ''), 'headers that are not a list are refused, saying why');
check(reply(x.bw_row_at(100)).error === 'no outline is loaded', 'and nothing is loaded after it');
// The outline is apart from the board: bw_load's board still answers cuts.
check(call('bw_load', hand) === 3 && x.bw_cut_y(99) === 98, 'the board and the outline are held apart');

// Interface 3, story 1513 (spec, paste and drop): where a paste lands and the room a drop opens, over the hand board
// above (its boxes: the line at 98..102 across -2..202, the text at 200..240 across 0..100, the group at 399..481).
// Worked by hand from the spec's rules: a clear patch with half a line of air round it nearest the view's middle, on a
// 20-point grid from the margin's air (84); else room at the clear line nearest the view's middle.
check(same(reply(x.bw_place(100, 40, 0, 0, 820, 1000)), { push: null, x: 364, y: 480 }),
  `a paste in a clear view lands nearest its middle: ${read(x.bw_place(100, 40, 0, 0, 820, 1000))}`);
// A view with no room for it, 90..130: the middle (110) is clear, the blank band runs from the line (102) to the text
// (200), 98 points, and it lands a half line under the line, at the margin's air.
check(same(reply(x.bw_place(100, 40, 0, 90, 820, 130)), { push: null, x: 84, y: 122 }),
  `no clear patch, but blank paper enough: ${read(x.bw_place(100, 40, 0, 90, 820, 130))}`);
// 100 tall needs 140 with its air, 42 more than the band holds: room opens in whole lines, ceil(42 / 40) = 2, 80 points.
check(same(reply(x.bw_place(100, 100, 0, 90, 820, 130)), { push: { cut: 110, dy: 80 }, x: 84, y: 122 }),
  `no blank paper enough: room opens at the view's middle: ${read(x.bw_place(100, 100, 0, 90, 820, 130))}`);
// A drop on the line from far below: room from the clear line at its top (90) down until the line is a half line under
// it (110 + 20 - 98 = 32, one whole line).
check(same(reply(x.bw_drop(50, 90, 150, 110, 50, 600, 150, 620)), { push: { cut: 90, dy: 40 } }),
  `a drop on the line pushes it down a line: ${read(x.bw_drop(50, 90, 150, 110, 50, 600, 150, 620))}`);
check(same(reply(x.bw_drop(300, 300, 400, 320, 300, 600, 400, 620)), { push: null }), 'a drop on clear paper opens nothing');
check(same(reply(x.bw_drop(50, 95, 150, 105, 50, 95, 150, 105)), { push: null }), 'a drop back on the line it was lifted from opens nothing');
check(call('bw_load', 'not json') === -1 && reply(x.bw_place(10, 10, 0, 0, 820, 1000)).error === 'no board is loaded' &&
  reply(x.bw_drop(0, 0, 1, 1, 0, 0, 1, 1)).error === 'no board is loaded', 'with nothing loaded, a paste and a drop say so');

// Interface 4 (spec, headers in ink, Fold all and Collapse): over the outline, each on a copy.
// A line of two zigzag words (98..202 across, 88..112 down, its middle at 100) and a flat stroke under it (95..205,
// 119..121): an underline under most of the line and not far past it, so the line becomes header H, the underline its
// mark and one of its strokes.
const zig = (id, x0) => ({ id, width: 4, points: [0, 1, 2, 3, 4].map((i) => [x0 + 10 * i, i % 2 ? 110 : 90]) });
const inked = { strokes: [zig('a', 100), zig('b', 160), { id: 'u', width: 2, points: [[96, 120], [204, 120]] }], boxes: [], groups: {}, headers: [] };
check(call('bw_outline_load', inked) === 3, `the inked outline ${error() ?? ''}`);
check(same(ask('bw_ink_header', { name: 'u', id: 'H' }),
  { after: { id: 'H', ids: ['a', 'b', 'u'], mark: ['u'] }, ink: { header: 'H', kind: 'underline', mark: ['u'], y: 100 } }),
  `an underline makes its line a header: ${JSON.stringify(ask('bw_ink_header', { name: 'u', id: 'H' }))}`);
check(same(ask('bw_ink_header', { name: 'a', id: 'H' }), { ink: null }), 'a word of writing makes no header');
check(same(ask('bw_ink_header', { name: 'nobody', id: 'H' }), { ink: null }), 'no such stroke: nothing');
check(ask('bw_ink_header', { name: 'u' }).error === 'no stroke name and header id', 'no header id says so');
check(rowAt(100).header === undefined && same(rowAt(100).names, ['a', 'b']), `asking leaves the outline as it was (the line is no header yet): ${JSON.stringify(rowAt(100))}`);
// Fold all: the rows-and-folds outline above with the line at 300 made header N over an indented line at 340. From
// the lowest up: N tucks the line at 340 (338..342, 40 under its row's 302; nothing below, so nothing slides), then H
// tucks its two lines and the rest slides up 120 as before (N's row, its fold under it, still starts at 298).
const two = { ...outline, strokes: [...outline.strokes, { ...line('n2', 340), points: [[60, 340], [200, 340]] }], boxes: [],
  groups: {}, headers: [{ id: 'H', ids: ['h1'] }, { id: 'N', ids: ['n'] }] };
check(call('bw_outline_load', two) === 5, `two headers ${error() ?? ''}`);
const allFolds = [
  { bottom: 40, id: 'N', ids: ['n2'], lines: 1, own: ['n2'], shift: 0 },
  { bottom: 80, id: 'H', ids: ['b1', 'b2'], lines: 2, own: ['b1', 'b2'], shift: 120 },
];
check(same(ask('bw_fold_plan', {}), { folds: allFolds, levels: { H: 1, N: 1 }, open: false }), `Fold all: ${JSON.stringify(ask('bw_fold_plan', {}))}`);
check(same(ask('bw_fold_plan', { to: 1 }), { folds: allFolds, levels: { H: 1, N: 1 }, open: true }), `Collapse to 1, both at level 1: ${JSON.stringify(ask('bw_fold_plan', { to: 1 }))}`);
check(same(ask('bw_fold_plan', { to: 2 }), { folds: allFolds, levels: { H: 1, N: 1 }, open: true }), 'Collapse to 2: shallower headers with nothing under them fold too');
check(same(ask('bw_fold', { id: 'H' }).fold.shift, 120), 'and the outline is as it was: H still folds on its own');
// A header inside another's section: H at 100, N indented to 60 at 140 (in H's section, so level 2), a line indented
// further to 120 at 180 (N's), and a line back at the margin at 300 that ends both. Collapse to 1 folds only H (its
// section the two lines under it, the rest sliding up 120 as before); Collapse to 2 folds only N and leaves H open, a
// header with a header under it (N tucks the line at 180, 40 under its row's 142; 300 - 142 = 158, three whole lines
// less one = 80). Fold all folds N as Collapse to 2 does, then H: its section is N's row alone now (the margin line
// slid to 218), one line, 40 under its row, the rest sliding up 218 - 102 = 116, two lines less one = 40.
const nested = { strokes: [line('h1', 100), { ...line('n', 140), points: [[60, 140], [200, 140]] },
  { ...line('c', 180), points: [[120, 180], [200, 180]] }, line('e', 300)], boxes: [], groups: {},
  headers: [{ id: 'H', ids: ['h1'] }, { id: 'N', ids: ['n'] }] };
check(call('bw_outline_load', nested) === 4, `nested headers ${error() ?? ''}`);
const foldN = { bottom: 40, id: 'N', ids: ['c'], lines: 1, own: ['c'], shift: 80 };
check(same(ask('bw_fold_plan', { to: 1 }), { folds: [{ bottom: 80, id: 'H', ids: ['n', 'c'], lines: 2, own: ['n', 'c'], shift: 120 }],
  levels: { H: 1, N: 2 }, open: true }), `Collapse to 1 folds the outer header only: ${JSON.stringify(ask('bw_fold_plan', { to: 1 }))}`);
check(same(ask('bw_fold_plan', { to: 2 }), { folds: [foldN], levels: { H: 1, N: 2 }, open: true }),
  `Collapse to 2 folds the inner header and leaves its parent open: ${JSON.stringify(ask('bw_fold_plan', { to: 2 }))}`);
check(same(ask('bw_fold_plan', {}), { folds: [foldN, { bottom: 40, id: 'H', ids: ['n', 'c'], lines: 1, own: ['n'], shift: 40 }],
  levels: { H: 1, N: 2 }, open: false }), `Fold all folds the inner header, then the outer: ${JSON.stringify(ask('bw_fold_plan', {}))}`);
check(ask('bw_fold_plan', { to: '2' }).error && ask('bw_fold_plan', { to: 1.5 }).error && ask('bw_fold_plan', 'not json').error,
  'a level that is no whole number, or no request, says so rather than folding all');
// A fold left on a header whose lines show again (an Undo opened it) is no fold made: a header with nothing under it
// does not fold, so Fold all lists nothing.
check(call('bw_outline_load', { strokes: [line('x', 100)], boxes: [], groups: {},
  headers: [{ id: 'X', ids: ['x'], fold: { ids: ['x'], own: ['x'], shift: 0, lines: 1, bottom: 40 } }] }) === 1, `an undone fold ${error() ?? ''}`);
check(same(ask('bw_fold_plan', {}).folds, []), `an undone fold that does not fold again is not listed: ${JSON.stringify(ask('bw_fold_plan', {}))}`);
check(call('bw_load', 'not json') === -1 && call('bw_outline_load', 'not json') === -1 && ask('bw_fold_plan', {}).error === 'no outline is loaded' &&
  ask('bw_ink_header', { name: 'u', id: 'H' }).error === 'no outline is loaded', 'with no outline, both say so');

// Interface 5 (spec, what a hold is on): a header H at 100 (100..150), a line at 200 of two strokes 10 apart (100..130,
// 140..170; under a word gap of 16, one word) and one far off (300..330), a group of Larry's at 300, a kept text at
// 400..440.
const seg = (id, x0, x1, y) => ({ id, width: 4, points: [[x0, y], [x1, y]] });
const held = {
  strokes: [seg('h1', 100, 150, 100), seg('a', 100, 130, 200), seg('b', 140, 170, 200), seg('c', 300, 330, 200), seg('g1', 100, 150, 300)],
  boxes: [{ id: 't', box: [100, 400, 200, 440] }], groups: { t: 't', g1: 'g' }, headers: [{ id: 'H', ids: ['h1'] }],
};
check(call('bw_outline_load', held) === 6, `the held outline ${error() ?? ''}`);
const wordAt = (px, py, slop = 10) => reply(x.bw_word_at(px, py, slop)).names;
check(same(wordAt(105, 202), ['a', 'b']), `a Pencil on a picks up the word a b: ${JSON.stringify(wordAt(105, 202))}`);
check(same(wordAt(310, 200), ['c']), 'on c, c alone: the gap to b is past a word gap');
check(wordAt(500, 200) === null, 'off ink: nothing');
check(same(wordAt(150, 420), ['t']), `on the kept text: the text: ${JSON.stringify(wordAt(150, 420))}`);
check(same(wordAt(120, 100), ['h1']), "on the header: its row");
const holdAt = (px, py, margin = false) => reply(x.bw_hold_menu(px, py, margin ? 1 : 0, 22));
check(same(holdAt(105, 200), { choices: ['select', 'to-text', 'delete', 'make-room', 'paste', 'make-header'], names: ['a', 'b'], on: 'ink' }),
  `a finger on a word: Select, To text, Delete, then the line's rows: ${JSON.stringify(holdAt(105, 200))}`);
check(same(holdAt(120, 100), { choices: ['select', 'to-text', 'make-room', 'paste', 'not-header'], header: 'H', names: ['h1'], on: 'header' }),
  `on a header: no Delete, and Not a header: ${JSON.stringify(holdAt(120, 100))}`);
check(same(holdAt(120, 300), { choices: ['select', 'to-text', 'delete', 'make-room', 'paste'], names: ['g1'], on: 'group' }),
  `on a group of Larry's: the group, and no Make header (it is no one's writing): ${JSON.stringify(holdAt(120, 300))}`);
check(same(holdAt(500, 250), { choices: ['make-room', 'paste'], names: [], on: 'paper' }), `on blank paper: ${JSON.stringify(holdAt(500, 250))}`);
check(same(holdAt(30, 100, true), { choices: ['fold-all', 'level-1', 'level-2', 'level-3', 'unfold-all'], names: [], on: 'header-mark' }),
  `in the margin beside a header: the outline: ${JSON.stringify(holdAt(30, 100, true))}`);
check(same(holdAt(30, 200, true), { choices: ['make-room', 'paste', 'make-header'], names: [], on: 'paper' }), 'in the margin beside a line: its rows');
// Interface 21 (story 1310): held on the selection, the menu takes all of it, To text and Delete, no Select; held
// off it, the thing under the finger as before.
const holdOn = (px, py, selected) => ask('bw_hold_menu_on', { x: px, y: py, in_margin: false, slop: 22, selected });
check(same(holdOn(105, 200, ['a', 'b', 'c']), { choices: ['to-text', 'delete', 'make-room', 'paste', 'make-header'], names: ['a', 'b', 'c'], on: 'selection' }),
  `on the selection, all of it: ${JSON.stringify(holdOn(105, 200, ['a', 'b', 'c']))}`);
check(same(holdOn(105, 200, ['c']), holdAt(105, 200)), `off the selection, the word as before: ${JSON.stringify(holdOn(105, 200, ['c']))}`);
check(same(holdOn(105, 200, []), holdAt(105, 200)), 'nothing selected: as bw_hold_menu');
check(holdOn(500, 250, ['a']).on === 'paper', 'blank paper with a selection elsewhere: the paper');
check(same(ask('bw_hold_menu_on', { x: 30, y: 100, in_margin: 1, slop: 22, selected: [] }), holdAt(30, 100, true)) &&
  same(ask('bw_hold_menu_on', { x: 30, y: 100, in_margin: true, slop: 22, selected: [] }), holdAt(30, 100, true)),
  'in_margin as a number or a bool: the margin either way');
check(ask('bw_hold_menu_on', { y: 1 }).error === 'no x and y', 'no x: says so');
check(call('bw_outline_load', 'not json') === -1 && reply(x.bw_word_at(0, 0, 10)).error === 'no outline is loaded' &&
  reply(x.bw_hold_menu(0, 0, 0, 22)).error === 'no outline is loaded', 'with no outline, both say so');

// Interface 6 (spec, a connector's route): straight from a's right to b's left when nothing is in the way; with a box
// across the straight line, one elbow, across then down: a's right (100, 20) along to above b (350, 20), then down to
// b's top (350, 200), clear of the box and of both ends.
const route = (body) => ask('bw_route_connector', body);
check(same(route({ from: [0, 0, 100, 40], to: [300, 0, 400, 40], fromSide: 'right', toSide: 'left', obstacles: [] }), { points: [[100, 20], [300, 20]] }),
  `nothing in the way: straight: ${JSON.stringify(route({ from: [0, 0, 100, 40], to: [300, 0, 400, 40], fromSide: 'right', toSide: 'left' }))}`);
const around = { from: [0, 0, 100, 40], to: [300, 200, 400, 240], fromSide: 'right', toSide: 'left', obstacles: [[180, 100, 220, 140]] };
check(same(route(around), { points: [[100, 20], [350, 20], [350, 200]] }), `a box in the way: one elbow round it: ${JSON.stringify(route(around))}`);
check(route({ from: [0, 0, 1] }).error === 'no from and to boxes', 'no boxes: says so');

// Interface 7 (spec, Larry's ops): the batch read as the iPad reads it, and planned on a board sent with it. A make-room
// at 200 of 50 opens whole lines (80) at the clear line under a (98.5..101.5), so b and the box move 80; a stroke of a
// group moves its group; a name the board lacks is missing; his text on clear paper stays where he put it.
const opsBoard = {
  strokes: [{ id: 'a', points: [[100, 100], [200, 100]], width: 3 }, { id: 'b', points: [[100, 300], [200, 300]], width: 3 },
    { id: 'c', points: [[100, 340], [200, 340]], width: 3 }],
  boxes: [{ id: 'x', box: [0, 500, 50, 540] }], metas: { b: { group: 'g' }, c: { group: 'g' } }, ghosts: [],
  measured: { 1: [60, 40] },
};
const ops = (list, board) => ask('bw_ops_plan', { batch: { board: 'ink', base_rev: 3, label: 'l', list }, board });
const refused = ops([{ op: 'translate', ids: ['b'], dy: 10 }, { op: 'nope' }]);
check(same(refused, { batch: { base_rev: 3, board: 'ink', label: 'l', names_used: [], ops: 0, refusal: 'unknown_op' } }), `a bad op refuses the batch: ${JSON.stringify(refused)}`);
const used = ops([{ op: 'delete', ids: ['a'] }, { op: 'select', ids: ['g'] }]).batch.names_used;
check(same(used, ['a', 'g']), `the names a batch uses: ${JSON.stringify(used)}`);
const room = ops([{ op: 'translate', below_y: 200, dy: 50 }], opsBoard).plan;
check(same(room.moves, { b: [0, 80], c: [0, 80], x: [0, 80] }) && room.rooms[0].dy === 80, `a make-room of whole lines: ${JSON.stringify(room)}`);
const moved = ops([{ op: 'translate', ids: ['b', 'gone'], dx: 5, dy: 10 }, { op: 'add_text', id: 't1', x: 300, y: 700, text: 'hi' }], opsBoard).plan;
check(same(moved.moves, { b: [5, 10], c: [5, 10] }) && same(moved.missing_ids, ['gone']) && moved.texts.length === 1 &&
  moved.texts[0].y === 700, `a group moves whole, a missing name, his text on clear paper: ${JSON.stringify(moved)}`);

const connectorBoxes = [{ id: 'start', box: [0, 0, 100, 40] }, { id: 'end', box: [300, 200, 400, 240] }];
const obstacle = { id: 'obstacle', box: [200, 100, 240, 150] };
const connectorBoard = { boxes: [...connectorBoxes, obstacle], metas: { end: { group: 'target' } } };
const drawn = ops([
  { op: 'connector', id: 'forward', from: [50, 20], to: 'target' },
  { op: 'connector', id: 'reverse', from: [350, 220], to: [50, 20] },
], connectorBoard).plan;
check(same(drawn.connected, ['forward', 'reverse']) && drawn.metas.forward.connector.from === 'start' &&
  drawn.metas.forward.connector.to === 'target' && drawn.metas.reverse.connector.to === 'start' &&
  same(drawn.metas.forward.connector.route, [[100, 20], [350, 20], [350, 200]]),
  `points attach to boxes by name and route around a third box: ${JSON.stringify(drawn)}`);

const straight = [[100, 20], [300, 220]];
const followed = ops([{ op: 'translate', ids: ['obstacle'], dy: -150 }], {
  strokes: [{ id: 'arrow', points: straight }],
  boxes: [...connectorBoxes, { id: 'obstacle', box: [200, 250, 240, 300] }],
  metas: { arrow: { connector: { from: 'start', to: 'end', from_side: 'right', to_side: 'left', route: straight } } },
}).plan;
check(same(followed.moves, { obstacle: [0, -150] }) && same(followed.rerouted, ['arrow']) &&
  same(followed.metas.arrow.connector.route, [[100, 20], [350, 20], [350, 200]]),
  `moving a box into an existing connector's route reroutes it: ${JSON.stringify(followed)}`);
const namedBoxes = ops([
  { op: 'select', ids: ['start'] }, { op: 'set_hidden', ids: ['start'], hidden: true },
  { op: 'set_meta', ids: ['start'], meta: { note: 'kept' } }, { op: 'delete', ids: ['end'] },
], connectorBoard).plan;
check(same(namedBoxes.select, ['start']) && same(namedBoxes.hidden, { start: true }) &&
  same(namedBoxes.metas, { start: { note: 'kept' } }) && same(namedBoxes.erase, ['end']),
  `box changes use the public name once: ${JSON.stringify(namedBoxes)}`);

const button = { op: 'overlay', id: 'control', kind: 'button', rect: { x: 10, y: 20, w: 90, h: 40 }, label: 'Keep',
  style: { fill: '#123456' }, tap_event: { action: 'keep' } };
const controls = [button, { op: 'remove_overlay', id: 'control' }, { ...button, label: 'Again' }];
check(isDeepStrictEqual(ops(controls, {}).plan.overlays, controls), 'the web plan preserves ordered overlay changes and their payloads');

const short = { op: 'add_text', id: 't1', x: 20, y: 90, text: 'a' };
const wide = { ...short, y: 290, text: 'W W W' };
const textBoard = { strokes: opsBoard.strokes.slice(0, 2) };
const replacedText = ops([short, { op: 'select', ids: ['a'] }, wide], {
  ...textBoard, measured: { 0: [30, 20], 2: [100, 20] },
}).plan;
check(same(replacedText.moves, { b: [0, 40] }) && replacedText.texts.length === 1 && replacedText.texts[0].text === wide.text,
  `the short text clears the top ink and only the wider replacement opens room: ${JSON.stringify(replacedText)}`);
const showing = ops([
  { op: 'set_meta', ids: ['t1'], meta: { note: 'keep it' } }, { op: 'translate', below_y: 590, dy: 40 }, wide,
], {
  ...textBoard, measured: { 2: [100, 20] },
  ghosts: [{ id: 't1', x: 20, y: 500, text: 'Old', color: '#A0b124', measured: [30, 120] }],
}).plan;
check(showing.rooms[0].below_y === 620 && showing.inked[0].y === 500 && showing.inked[0].color === '#a0b124' &&
  same(showing.moves, { b: [0, 40] }),
  `the existing ghost uses its own measured height and the new text uses its own width: ${JSON.stringify(showing)}`);
check(ask('bw_ops_plan', 'not json').error !== undefined, 'unreadable: says so');

// Interface 8 (spec, a late reply's room): a line written at 2000 at y 100 (its box 98..102) and one at 500 at y 200.
// A mark over the first, its picture taken at 1000, sits on ink newer than the picture: from that ink's top (98, the
// top of its own line) everything goes down whole lines until it is 20 under the mark's bottom (130): 52 short, two
// lines, 80. Taken at 3000, nothing is newer; a mark on clear paper covers nothing.
const lateInk = { strokes: [{ ...seg('w', 100, 300, 100), t: 2000 }, { ...seg('o', 100, 300, 200), t: 500 }], boxes: [], groups: {}, headers: [] };
check(call('bw_outline_load', lateInk) === 2, `the late outline ${error() ?? ''}`);
const late = (marks, seen) => ask('bw_late', { marks, seen });
check(same(late([[100, 90, 300, 130]], 1000), { covered: 1, push: { cut: 98, dy: 80 } }), `a mark over newer ink: room under it: ${JSON.stringify(late([[100, 90, 300, 130]], 1000))}`);
check(same(late([[100, 90, 300, 130]], 3000), { covered: 0, push: null }), 'nothing newer than the picture: no room');
check(same(late([[400, 400, 500, 440]], 1000), { covered: 0, push: null }), 'a mark on clear paper: no room');
check(ask('bw_late', { marks: [] }).error === 'no marks and seen', 'no seen says so');

// bw_text_room (interface 8): a text of Larry's at a box. Over the line at y 200 (198..202), 30 tall from 190: it sits on
// it; its top is already on a clear line (190), so it lands where it is and the line
// and all below go down whole lines until 20 under it (190 + 30 + 20 - 198 = 42: two lines, 80). On clear paper it lands
// where it is, sitting on nothing.
check(call('bw_outline_load', lateInk) === 2, `the late outline again ${error() ?? ''}`);
const textRoom = (box) => ask('bw_text_room', { box });
check(same(textRoom([120, 190, 200, 220]), { cut: 190, dy: 80, sits: true, y: 190 }), `a text on ink: room under it: ${JSON.stringify(textRoom([120, 190, 200, 220]))}`);
check(same(textRoom([120, 400, 200, 430]), { cut: 400, dy: 0, sits: false, y: 400 }), `a text on clear paper: none: ${JSON.stringify(textRoom([120, 400, 200, 430]))}`);
check(textRoom(null).error === 'no box', 'no box says so');

// Interface 9, story 1267 (spec, lines that look like headers): four usual lines of three letters 24 tall (each line's
// box 27 tall, pen 3), a line of three letters 60 tall at 300 (box 98.5..229.5 by 298.5..361.5: half again his usual
// line, letters 1.6 times his, wider than twice its height), a line at 420 with a flat stroke under it (box 98.5..169.5
// by 418.5..445.5) and a big line at 520 that is a header already. The big line is offered at its middle, 330, the
// underlined one at 432; the header is not.
const letter = (id, x, y, w = 20, h = 24) => ({ id, width: 3, points: [[x, y + h], [x + w / 2, y], [x + w, y + h]] });
const lettersAt = (p, y, w, h) => [0, 1, 2].map((i) => letter(`${p}${i}`, 100 + i * (w + 4), y, w, h));
const candidateInk = {
  strokes: [
    ...[100, 140, 180, 220].flatMap((y, i) => lettersAt(`l${i}`, y, 20, 24)),
    ...lettersAt('b', 300, 40, 60),
    ...lettersAt('u', 420, 20, 24),
    { id: 'under', width: 3, points: [[98, 450], [168, 450]] },
    ...lettersAt('h', 520, 40, 60),
  ],
  boxes: [], groups: {}, headers: [{ id: 'H', ids: ['h0', 'h1', 'h2'] }],
};
check(call('bw_outline_load', candidateInk) === 22, `the candidates outline ${error() ?? ''}`);
const big = { bottom: 361.5, left: 98.5, right: 229.5, top: 298.5, why: 'big', y: 330 };
const underlined = { bottom: 445.5, left: 98.5, right: 169.5, top: 418.5, why: 'underline', y: 432 };
const candidates = (body) => ask('bw_candidates', body);
check(isDeepStrictEqual(candidates({}), { candidates: [big, underlined] }), `the big line and the underlined one: ${JSON.stringify(candidates({}))}`);
check(isDeepStrictEqual(candidates({ declined: ['b1'] }), { candidates: [underlined] }), `the big line declined: ${JSON.stringify(candidates({ declined: ['b1'] }))}`);
check(isDeepStrictEqual(candidates({}), { candidates: [big, underlined] }), 'asking leaves the outline as it was');
check(candidates('[1]').error === 'the request is not a JSON object', 'a request that is no object says so');
check(call('bw_outline_load', 'not json') === -1 && candidates({}).error === 'no outline is loaded', 'with no outline it says so');

// Interface 10, story 1263 (spec, what moves whole and its rows): a header H at 100 folded over a hidden line at 140, a
// line at 300, two strokes Larry grouped at 400 and 420 and a kept text at 500. Four units in board order: H's row with
// what it hides (its box its own row, -2..202 by 98..102, pen 4), the line, the group whole (one box across both) and
// the text; four rows.
const rowsInk = {
  strokes: [line('h1', 100), { ...line('b1', 140), points: [[60, 140], [200, 140]], hidden: true }, line('n', 300),
    seg('g1', 0, 100, 400), seg('g2', 150, 200, 420)],
  boxes: [{ id: 't', box: [0, 500, 100, 540] }],
  groups: { g1: 'g', g2: 'g', t: 't' },
  headers: [{ id: 'H', ids: ['h1'], fold: { ids: ['b1'], own: ['b1'], shift: 0, lines: 1, bottom: 40 } }],
};
check(call('bw_outline_load', rowsInk) === 6, `the rows outline ${error() ?? ''}`);
const wantRows = {
  rows: [{ bottom: 102, top: 98 }, { bottom: 302, top: 298 }, { bottom: 422, top: 398 }, { bottom: 540, top: 500 }],
  units: [
    { box: [-2, 98, 202, 102], header: 'H', key: 'h:H', names: ['h1', 'b1'], object: null, objectIds: [], strokeIds: ['h1', 'b1'], tag: 'h:H' },
    { box: [-2, 298, 202, 302], header: null, key: 's:n', names: ['n'], object: null, objectIds: [], strokeIds: ['n'], tag: null },
    { box: [-2, 398, 202, 422], header: null, key: 'o:g', names: ['g1', 'g2'], object: 'g', objectIds: ['g'], strokeIds: ['g1', 'g2'], tag: 'g' },
    { box: [0, 500, 100, 540], header: null, key: 'o:t', names: ['t'], object: 't', objectIds: ['t'], strokeIds: [], tag: 't' },
  ],
};
const rowsNow = () => reply(x.bw_rows());
check(isDeepStrictEqual(rowsNow(), wantRows), `the units and rows: ${JSON.stringify(rowsNow())}`);
check(isDeepStrictEqual(rowsNow(), wantRows), 'asking leaves the outline as it was');
// Version 13 (story 1263): the edges are the page's to the last bit, though the rules' geometry here is 32-bit. A
// stroke's are its points' extremes widened by half its pen, as the page works them out; a box's are its own numbers;
// new ink's too.
const pageBox = (pts, w) => {
  const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1]), r = w / 2;
  return [Math.min(...xs) - r, Math.min(...ys) - r, Math.max(...xs) + r, Math.max(...ys) + r];
};
const oddA = [[0.1, 100.1], [200.3, 100.7]], oddB = [[10.01, 140.123456789], [12.7, 141.9]], oddC = [[5.55, 700.07], [9.9, 700.3]];
check(call('bw_outline_load', {
  strokes: [{ id: 'a', points: oddA, width: 3.3 }, { id: 'b', points: oddB, width: 4 }],
  boxes: [{ id: 't', box: [0.3, 300.17, 99.9, 340.71] }], groups: { t: 't' }, headers: [],
}) === 3, `the odd outline ${error() ?? ''}`);
check(call('bw_outline_add', { strokes: [{ id: 'c', points: oddC, width: 2.2 }] }) === 4, `and new ink ${error() ?? ''}`);
const odd = rowsNow();
const oddWant = [pageBox(oddA, 3.3), pageBox(oddB, 4), pageBox(oddC, 2.2), [0.3, 300.17, 99.9, 340.71]];
check(isDeepStrictEqual(odd.units.map((u) => u.box), [oddWant[0], oddWant[1], oddWant[3], oddWant[2]]),
  `the edges are the page's exactly: ${JSON.stringify(odd.units.map((u) => u.box))}`);
check(odd.units.some((u) => u.box[1] !== Math.fround(u.box[1])), 'and some of them are no 32-bit number');
check(isDeepStrictEqual(odd.rows, [
  { bottom: oddWant[0][3], top: oddWant[0][1] }, { bottom: oddWant[1][3], top: oddWant[1][1] },
  { bottom: 340.71, top: 300.17 }, { bottom: oddWant[2][3], top: oddWant[2][1] },
]), `and so are the rows: ${JSON.stringify(odd.rows)}`);
check(call('bw_outline_load', 'not json') === -1 && rowsNow().error === 'no outline is loaded', 'rows with no outline say so');

// Interface 11, story 1264 (spec, opening a fold): the outline of interface 2 with H folded (b1 hidden, the line at 300
// slid up 120 to 180) and a line w written under the folded header at 130, indented. Opening H from its row's bottom
// (102): w and the line below slide back the fold's 120 (w's 128 + 120 clears the opened b1's 142, so no more), b1
// shows, and w, which the opened section would now take, ends it.
const openInk = {
  strokes: [line('h1', 100), { ...line('b1', 140), points: [[60, 140], [200, 140]], hidden: true },
    { ...line('w', 130), points: [[60, 130], [200, 130]] }, line('n', 180)],
  boxes: [], groups: {},
  headers: [{ id: 'H', ids: ['h1'], fold: { ids: ['b1'], own: ['b1'], shift: 120, lines: 1, bottom: 40 } }],
};
check(call('bw_outline_load', openInk) === 4, `the folded outline ${error() ?? ''}`);
const opening = (body) => ask('bw_opening', body);
const opened = { opening: { ends: ['w'], moves: { n: 120, w: 120 }, shown: ['b1'], slide: 120, top: 102 } };
check(isDeepStrictEqual(opening({ id: 'H' }), opened), `opening H: ${JSON.stringify(opening({ id: 'H' }))}`);
check(isDeepStrictEqual(opening({ id: 'H' }), opened), 'asking leaves the outline as it was');
check(isDeepStrictEqual(opening({ id: 'X' }), { opening: null }), 'a header that is not there opens nothing');
check(opening({}).error === 'no header id', 'no id says so');
check(call('bw_outline_load', 'not json') === -1 && opening({ id: 'H' }).error === 'no outline is loaded', 'opening with no outline says so');

// Interface 12, story 1265 (spec, erasing a fold whole): H at 100 folded over b1, the line below slid up to 180. H's
// "▸ 1 line folded" (15 letters) sits 212..335.5 by 88..108. A path across it takes the fold: h1 and b1 go, H goes, and
// the line at 178 closes up to H's top (98) in whole lines, 80. Across H's words it takes the fold only with onHeader;
// clear paper takes nothing; by its name, the same as by its marker.
const eraseInk = {
  strokes: [line('h1', 100), { ...line('b1', 140), points: [[60, 140], [200, 140]], hidden: true }, line('n', 180)],
  boxes: [], groups: {},
  headers: [{ id: 'H', ids: ['h1'], fold: { ids: ['b1'], own: ['b1'], shift: 120, lines: 1, bottom: 40 } }],
};
check(call('bw_outline_load', eraseInk) === 3, `the fold to erase ${error() ?? ''}`);
const foldErase = (body) => ask('bw_fold_erase', body);
const hitH = (byMarker) => ({ byMarker, header: 'H', headers: ['H'], names: ['b1', 'h1'], top: 98 });
const erasedH = { headers: ['H'], moves: { n: -80 }, names: ['h1', 'b1'] };
const byMark = foldErase({ path: [[250, 95], [260, 95]] });
check(isDeepStrictEqual(byMark, { erased: erasedH, hits: [hitH(true)] }), `across the marker: ${JSON.stringify(byMark)}`);
check(isDeepStrictEqual(foldErase({ path: [[250, 95], [260, 95]] }), byMark), 'asking leaves the outline as it was');
check(isDeepStrictEqual(foldErase({ headers: ['H'] }), byMark), `by name: ${JSON.stringify(foldErase({ headers: ['H'] }))}`);
const words = foldErase({ path: [[50, 100], [60, 100]], onHeader: true });
check(isDeepStrictEqual(words, { erased: erasedH, hits: [hitH(false)] }), `across its words with onHeader: ${JSON.stringify(words)}`);
check(isDeepStrictEqual(foldErase({ path: [[50, 100], [60, 100]] }), { erased: null, hits: [] }), 'across its words without onHeader: nothing');
check(isDeepStrictEqual(foldErase({ path: [[50, 600], [60, 600]] }), { erased: null, hits: [] }), 'on clear paper: nothing');
check(foldErase({}).error === 'no path or headers', 'neither a path nor headers says so');
check(call('bw_outline_load', 'not json') === -1 && foldErase({ headers: ['H'] }).error === 'no outline is loaded', 'erasing with no outline says so');

// Interface 14 (spec, keeping Larry's marks and Tidy overlaps), over the late outline: w at y 100 (98..102) written at
// 2000, o at y 200 (198..202) at 500. Two marks of reply r over w, its picture taken at 1000: one group, and from w's
// top (98) everything goes down whole lines until it is 20 under the lower mark (180): 102 short, three lines, 120. With
// w among theirs (a millisecond either way) nothing makes room. His text landing on o makes room from o's top: 220 + 20
// - 198 = 42, two lines, 80, and covers nothing newer.
check(call('bw_outline_load', lateInk) === 2, `the late outline for keeping ${error() ?? ''}`);
const keepAll = (body) => ask('bw_keep_all', body);
const pair = [{ id: 'r#0', box: [100, 90, 300, 130], seen: 1000 }, { id: 'r#1', box: [100, 140, 150, 180], seen: 1000 }];
check(same(keepAll({ marks: [...pair, { id: 's#0', box: [400, 0, 420, 10] }] }), { covered: 1, groups: { 'r#0': 'reply-r', 'r#1': 'reply-r' }, push: { cut: 98, dy: 120 } }),
  `Keep all: one group for the reply, a lone mark none, one room: ${JSON.stringify(keepAll({ marks: pair }))}`);
check(same(keepAll({ marks: pair, theirs: [2001] }), { covered: 0, groups: { 'r#0': 'reply-r', 'r#1': 'reply-r' }, push: null }), 'ink of theirs never makes room');
check(same(keepAll({ marks: [], landing: [[120, 190, 200, 220]] }), { covered: 0, groups: {}, push: { cut: 198, dy: 80 } }),
  `his text landing on ink makes room: ${JSON.stringify(keepAll({ marks: [], landing: [[120, 190, 200, 220]] }))}`);
check(keepAll({ marks: [{ id: 'x' }] }).error === 'no marks', 'a mark with no box says so');
// Tidy: label l (a zigzag 120..160 across, 90..110 down) sits on a's line at 100 and moves under it, 20 below: 30. m
// sits clear. n sits in the kept text k (500..560) and moves to 20 under its bottom: 70. g is in a group, so it is ink.
const tidyOutline = { strokes: [seg('a', 100, 300, 100), { id: 'l', points: [[120, 90], [140, 110], [160, 90]] },
  { id: 'm', points: [[120, 400], [140, 420], [160, 400]] }, { id: 'n', points: [[50, 510], [70, 530], [90, 510]] },
  { id: 'g', points: [[200, 95], [220, 105]] }], boxes: [{ id: 'k', box: [0, 500, 300, 560] }], groups: { g: 'G' }, headers: [] };
check(call('bw_outline_load', tidyOutline) === 6, `the tidy outline ${error() ?? ''}`);
check(same(ask('bw_tidy', { labels: ['l', 'm', 'n', 'g'] }), { moves: { l: 30, n: 70 } }), `Tidy: ${JSON.stringify(ask('bw_tidy', { labels: ['l', 'm', 'n', 'g'] }))}`);
check(ask('bw_tidy', {}).error === 'no labels', 'no labels says so');
check(call('bw_outline_load', 'not json') === -1 && keepAll({ marks: [] }).error === 'no outline is loaded' &&
  ask('bw_tidy', { labels: [] }).error === 'no outline is loaded', 'with no outline, both say so');

// Interface 15 (spec board-interaction-review, story 1261): every recorded session under Fixtures/board-reviews reviews
// through bw_review to the report BoardReviewTests holds the iPad's rules to, verdict for verdict and word for word.
const reviews = path.join(root, 'native/ContextCore/Tests/ContextCoreTests/Fixtures/board-reviews');
const reviewNames = fs.readdirSync(reviews).filter((f) => f.endsWith('.jsonl')).map((f) => f.slice(0, -6)).sort();
for (const name of reviewNames) {
  const got = ask('bw_review', fs.readFileSync(path.join(reviews, `${name}.jsonl`), 'utf8'));
  const golden = JSON.parse(fs.readFileSync(path.join(reviews, `${name}.golden.json`), 'utf8'));
  check(isDeepStrictEqual(got, golden), `bw_review ${name} matches its golden: ${JSON.stringify(got).slice(0, 400)}`);
}
check(reviewNames.length >= 37, `the review fixtures are all there: ${reviewNames.length}`);
check(ask('bw_review', '').error === 'the record could not be read: a record starts with its header', 'an empty record says why');
check(ask('bw_review', '{"record":2,"board":"b","session":"s","surface":"web","ink":[]}').error ===
  'the record could not be read: record version 2, this review reads 1', 'a newer record says why');

// Interface 16 (spec, the board's applier): the app's BoardOpApplier kept in the module, stepped. A board at rev 3 lets
// a batch on its own look through; the board's change bumps it to 4 and its report records it applied, touching all; a
// batch from look 3 is then stale; one seen before is ignored; two held for the Pencil, the second supersedes the
// first and applies on the lift; Igor moving a, then a batch from that older look naming a, conflicts on a.
const applier = (body) => ask('bw_applier', body);
const larry = (base, ids = ['a'], label = 'l') => ({ board: 'B', base_rev: base, label, list: [{ op: 'translate', ids, dx: 0, dy: 10 }] });
check(applier({ step: 'load', rev: 3 }).state.rev === 3, 'a board at rev 3');
check(same(applier({ step: 'receive', key: 'm1', batch: larry(3), board: 'B', ready: true }).decision, 'apply'), 'a batch on its look applies');
applier({ step: 'changed', ids: [] });
const reported = applier({ step: 'report', key: 'm1', outcome: 'applied', changes_board: true });
check(same(reported.report, 'applied') && same(reported.result, { label: 'l', ok: true, rev: 4 }) &&
  same(reported.state.touches, [{ all: true, ids: [], rev: 4 }]), `its report: applied at 4, touching all: ${JSON.stringify(reported)}`);
check(same(applier({ step: 'receive', key: 'm2', batch: larry(3), board: 'B' }).result, { label: 'l', ok: false, reason: 'stale', rev: 4 }),
  'a batch from before his own change is stale');
check(same(applier({ step: 'receive', key: 'm1', batch: larry(4), board: 'B' }), { decision: 'ignored', state: applier({ step: 'closed' }).state, why: 'handled' }), 'one seen before is ignored');
check(same(applier({ step: 'receive', key: 'm3', batch: larry(4, ['b'], 'l3'), board: 'B', ready: false }).replaced, null), 'held for the Pencil');
const second = applier({ step: 'receive', key: 'm4', batch: larry(4, ['b'], 'l4'), board: 'B', ready: false });
check(second.replaced === 'l3' && second.state.held === 'l4' && second.state.last_result.reason === 'superseded', `the second supersedes the first: ${JSON.stringify(second)}`);
check(same(applier({ step: 'release', ready: false }).decision, null), 'no lift: nothing');
const lifted = applier({ step: 'release', ready: true });
check(lifted.decision === 'apply' && lifted.key === 'm4' && lifted.state.applying === 'm4', `the lift lets it through: ${JSON.stringify(lifted)}`);
check(applier({ step: 'report', key: 'stray', outcome: 'unavailable' }).report === 'late', 'a report for another batch is late');
check(same(applier({ step: 'report', key: 'm4', outcome: 'failed', reason: 'edit' }), { canvas: 'failed:edit', report: 'refused',
  result: { label: 'l4', ok: false, reason: 'not_applied', rev: 4 }, state: applier({ step: 'closed' }).state }), 'a failed canvas: not applied');
applier({ step: 'changed', ids: ['a'] });
const conflict = applier({ step: 'receive', key: 'm5', batch: larry(4, ['a', 'c']), board: 'B' });
check(same(conflict.result, { conflict_ids: ['a'], label: 'l', ok: false, reason: 'stale', rev: 5 }), `a change since names a: ${JSON.stringify(conflict)}`);
check(applier({ step: 'receive', key: 'm6', batch: larry(5, ['a', 'c']), board: 'B' }).decision === 'apply', 'on the new look it applies');
check(applier({ step: 'nope' }).error && applier('not json').error && applier({ step: 'report', outcome: 'maybe' }).error, 'a step it can\'t read says so');

// Interface 17 (spec, scratch-out and hold-to-shape). A fast zigzag of five sweeps across w (100..300 at y 100), as the
// app's UI tests draw one: four turns, w goes. Over clear paper it finds nothing; slow, it is writing; under eight
// points it is too short to be one.
const zigzag = ([l, t, r, b]) => Array.from({ length: 60 }, (_, i) => {
  const u = (i / 59) * 5, sweep = Math.floor(u), f = u - sweep, a = (sweep % 2 === 0 ? f : 1 - f) - 0.5;
  return [(l + r) / 2 + a * (r - l), (t + b) / 2 + (u / 5 - 0.5) * 16];
});
check(call('bw_outline_load', { strokes: [seg('w', 100, 300, 100), seg('o', 100, 300, 300)], boxes: [], groups: {}, headers: [] }) === 2,
  `the scratch outline ${error() ?? ''}`);
const scratch = (points, ms) => ask('bw_scratch_out', { points, ms });
const over = scratch(zigzag([100, 90, 300, 110]), 100);
check(over.ok === true && same(over.gone, ['w']) && over.reversals === 4 && over.why === null && over.finds_nothing === false && over.zigzag === true,
  `a zigzag over w takes it: ${JSON.stringify(over)}`);
const clear = scratch(zigzag([100, 490, 300, 510]), 100);
check(clear.ok === false && clear.why === 'no ink' && clear.finds_nothing === true && clear.zigzag === true && same(clear.gone, []), `over clear paper it finds nothing: ${JSON.stringify(clear)}`);
check(scratch(zigzag([100, 90, 300, 110]), 10000).why === 'slow' && scratch(zigzag([100, 90, 300, 110]), 10000).zigzag === false, 'slow, it is writing');
check(scratch([[0, 0], [10, 0], [0, 0]], 10).why === 'short', 'three points are too short');
check(ask('bw_scratch_out', {}).error === 'no points', 'no points says so');
// Hold-to-shape: a stroke near a straight line 200 long snaps to a line; still from 0.08 s, lifted at 0.7 it was held
// (half a second or more), at 0.3 it was not.
const rough = [[0, 0], [50, 1], [100, 0], [150, 1], [200, 0]];
const snapped = ask('bw_shape_snap', { points: rough, times: [0, 0.02, 0.04, 0.06, 0.08], lifted: 0.7 });
check(snapped.held === true && snapped.shape.kind === 'line' && snapped.shape.name === 'line' && same(snapped.shape.points[0], [0, 0]) &&
  same(snapped.shape.points.at(-1), [200, 0]), `a rough line held still snaps: ${JSON.stringify({ ...snapped, shape: { ...snapped.shape, points: snapped.shape.points.length } })}`);
check(ask('bw_shape_snap', { points: rough, times: [0, 0.02, 0.04, 0.06, 0.08], lifted: 0.3 }).held === false, 'lifted too soon: not held');
check(same(ask('bw_shape_snap', { points: [[0, 0], [10, 10], [0, 20], [10, 30]] }), { held: null, shape: null }), 'a small scribble snaps to nothing');
check(ask('bw_shape_snap', { points: 'x' }).error === 'no points', 'no points says so');
check(call('bw_outline_load', 'not json') === -1 && scratch([[0, 0]], 1).error === 'no outline is loaded', 'a scratch-out with no outline says so');

// Interface 19 (spec, Larry's marks hold to the ink they answer). A label of Larry's lands over line a (100..300 at y
// 100, pen 4): it holds to a, where a's box began. a moves down 40: the label moves with it. a is erased: the label
// hides and the next post drops it. Igor writes across it: it fades, and the next post drops it as written over.
const marksOn = (...strokes) => call('bw_outline_load', { strokes, boxes: [], groups: {}, headers: [] });
check(marksOn(seg('a', 100, 300, 100), seg('b', 100, 300, 300)) === 2, `the marks outline ${error() ?? ''}`);
const label = { id: 'm', lines: [[[120, 90], [200, 110]]], pen: 2, label: true };
const anchored = ask('bw_mark_anchor', { mark: label }).anchor;
check(same(anchored, { gap: 0, strokes: [{ name: 'a', x: 98, y: 98 }], written_by: [] }), `the label holds to a: ${JSON.stringify(anchored)}`);
const placeOf = (anchor) => ask('bw_mark_place', { marks: [{ id: 'm', anchor }] }).places.m;
marksOn(seg('a', 100, 300, 140), seg('b', 100, 300, 300));
check(same(placeOf(anchored), { drops: null, dx: 0, dy: 40, faded: false, hidden: null }), `a moved down 40, the label with it: ${JSON.stringify(placeOf(anchored))}`);
marksOn(seg('b', 100, 300, 300));
check(same(placeOf(anchored), { drops: 'ink_erased', dx: 0, dy: 0, faded: false, hidden: 'erased' }), `a erased, the label hides: ${JSON.stringify(placeOf(anchored))}`);
check(same(ask('bw_mark_drops', { marks: [{ id: 'm', anchor: anchored }] }), { drops: [{ id: 'm', why: 'ink_erased' }] }), 'and the next post drops it');
marksOn(seg('a', 100, 300, 100), seg('b', 100, 300, 300));
const across = { id: 'igor', points: [[120, 100], [200, 100]], width: 3 };
const wrote = ask('bw_mark_wrote', { stroke: across, marks: [{ mark: label, anchor: anchored }] });
check(same(wrote.wrote, [{ id: 'm', share: 1 }]) && same(wrote.anchors.m.written_by, ['igor']), `Igor's stroke writes over it: ${JSON.stringify(wrote)}`);
marksOn(seg('a', 100, 300, 100), seg('b', 100, 300, 300), across);
check(same(placeOf(wrote.anchors.m), { drops: 'written_over', dx: 0, dy: 0, faded: true, hidden: null }), `with his stroke on the board it fades: ${JSON.stringify(placeOf(wrote.anchors.m))}`);
check(ask('bw_mark_anchor', {}).error === 'no mark' && ask('bw_mark_wrote', { marks: [] }).error === 'no stroke' &&
  ask('bw_mark_place', { marks: [{ id: 'm', anchor: 'x' }] }).error === 'no marks', 'what it can\'t read says so');
check(call('bw_outline_load', 'not json') === -1 && ask('bw_mark_anchor', { mark: label }).error === 'no outline is loaded', 'a mark with no outline says so');

// Interface 20 (spec, room by hand and Larry's picture of a folded board). Two lines, a (y 98..102) and b (298..302):
// a drag of 50 at 200 opens one line there; of 10, nothing; up 300, it closes only the four whole lines of blank paper
// between them (the rigid push). Started inside a, it snaps to a's bottom.
check(call('bw_load', { board: 'by-hand', strokes: [line('a', 100), line('b', 300)] }) === 2, `the by-hand board ${error() ?? ''}`);
const byHand = (y, dy) => reply(x.bw_room_by_hand(y, dy));
check(same(byHand(200, 50), { closable: 160, cut: 200, push: { cut: 200, dy: 40 } }), `down 50 opens a line: ${JSON.stringify(byHand(200, 50))}`);
check(same(byHand(200, 10), { closable: 160, cut: 200, push: null }), `under half a line moves nothing: ${JSON.stringify(byHand(200, 10))}`);
check(same(byHand(200, -300), { closable: 160, cut: 200, push: { cut: 200, dy: -160 } }), `up 300 closes only the blank paper: ${JSON.stringify(byHand(200, -300))}`);
check(same(byHand(101, 80), { closable: 160, cut: 102, push: { cut: 102, dy: 80 } }), `inside a it snaps to a's bottom: ${JSON.stringify(byHand(101, 80))}`);
// The picture of the outline above with H folded: b1 and b2 tucked under it, n and the box slid up 120. Opened, b1 and
// b2 show, n and the box slide back down, and the map says one fold opened under H.
const foldedOutline = {
  ...outline,
  strokes: [line('h1', 100), { ...line('b1', 140), points: [[60, 140], [200, 140]], hidden: true },
    { ...line('b2', 180), points: [[60, 180], [200, 180]], hidden: true }, line('n', 180)],
  boxes: [{ id: 't', box: [0, 280, 100, 320] }],
  headers: [{ id: 'H', ids: ['h1'], fold: folded.fold }],
};
check(call('bw_outline_load', foldedOutline) === 5, `the folded outline ${error() ?? ''}`);
const picture = reply(x.bw_fold_picture()).picture;
check(picture && same(picture.shown, ['b1', 'b2']) && same(picture.offsets.n, [0, 120]) && same(picture.offsets.t, [0, 120]) &&
  picture.map.length === 1 && picture.map[0].header === 'H' && picture.map[0].h === 120 && picture.bands[0].header === 'H' &&
  same(picture.folded_marks.map((m) => m.header), ['H']), `the picture opens H: ${JSON.stringify(picture)}`);
check(call('bw_outline_load', outline) === 5 && same(reply(x.bw_fold_picture()), { picture: null }), 'with nothing folded, no picture of its own');
check(call('bw_outline_load', 'not json') === -1 && reply(x.bw_fold_picture()).error === 'no outline is loaded', 'a picture with no outline says so');

// Interface 22: the shared-board store's clash rule (stories 1293, 1322, 1323).
const clash = ask('bw_store_clash', {
  board: { rev: 94, things: { 's-a': { rev: 94, device: 'web', by: 'igor', at: 't1' }, 's-b': { rev: 80, device: 'web', by: 'igor', at: 't0' } } },
  base_rev: 92, device: 'ipad', by: 'igor', at: 't2',
  ops: [{ op: 'move', ids: ['s-a'], dx: 4 }, { op: 'erase', ids: ['s-b'] }, { op: 'add_strokes', strokes: [{ id: 's-a' }, { id: 's-c' }] }],
});
check(clash.rev === 95 && same(clash.applied, [1, 2]) && clash.refused.length === 2 &&
  clash.refused[0].id === 's-a' && clash.refused[0].reason === 'changed' && clash.refused[0].device === 'web' &&
  clash.refused[1].reason === 'exists' && clash.board.things['s-b'].erased === true && clash.board.things['s-c'].rev === 95,
  `bw_store_clash lands, refuses by name and once per id: ${JSON.stringify(clash)}`);
const gone = ask('bw_store_clash', { board: { rev: 3, deleted: { rev: 3, device: 'web', by: 'igor', at: 't' } }, base_rev: 3, device: 'ipad', by: 'igor', at: 't', ops: [{ op: 'rename', name: 'x' }] });
check(same(gone.applied, []) && gone.refused[0].reason === 'deleted' && gone.refused[0].id === '@board', `bw_store_clash refuses on a deleted board: ${JSON.stringify(gone)}`);
check(ask('bw_store_clash', { board: { rev: 1 } }).error === 'no base_rev', 'bw_store_clash without base_rev says so');
const restored = ask('bw_store_clash', { board: { rev: 6, things: { 's-a': { rev: 5, device: 'ipad', by: 'igor', at: 't', erased: true } } }, base_rev: 5, device: 'ipad', by: 'igor', at: 't2', ops: [{ op: 'restore', ids: ['s-a'] }, { op: 'translate', below_y: 300, dy: 40 }, { op: 'select', ids: ['s-a'] }] });
check(same(restored.applied, [0]) && restored.board.things['s-a'].erased === undefined && restored.refused.length === 1 && restored.refused[0].reason === 'unknown' && same(restored.missing_ids, []),
  `bw_store_clash restores erased ink, refuses an op naming nothing, skips select: ${JSON.stringify(restored)}`);
const ahead = ask('bw_store_clash', { board: { rev: 4 }, base_rev: 9, device: 'ipad', by: 'igor', at: 't', ops: [{ op: 'add_strokes', strokes: [{ id: 's-1' }] }] });
check(same(ahead.applied, []) && ahead.refused[0].reason === 'ahead' && ahead.rev === 4, `bw_store_clash refuses a base ahead of the board: ${JSON.stringify(ahead)}`);

// The shared board-store goldens (cockpit-8kh, stories 1293–1329, 1299, 1300, 1342): every one through the wasm gives the
// answer the host gives (StoreClashGoldenTests), as the Cockpit's vendored copy runs them.
const goldens = path.join(root, 'native/ContextCore/Tests/ContextCoreTests/Fixtures/board-store');
for (const [folder, exp] of [['clash', 'bw_store_clash'], ['encode', 'bw_store_encode']]) {
  for (const name of fs.readdirSync(path.join(goldens, folder)).filter((n) => n.endsWith('.json')).sort()) {
    const golden = JSON.parse(fs.readFileSync(path.join(goldens, folder, name), 'utf8'));
    const got = ask(exp, golden.input);
    check(isDeepStrictEqual(got, golden.expect), `${exp} golden ${folder}/${name}: ${JSON.stringify(got)}`);
  }
}

for (const f of failures) console.log(`FAIL ${f}`);
console.log(`${failures.length ? 'FAIL' : 'ok  '} board wasm: ${passed} checks passed, ${failures.length} failed (${names.length} recorded sessions, ${(fs.statSync(wasmPath).size / 1e6).toFixed(1)} MB module)`);
process.exitCode = failures.length ? 1 : 0;
