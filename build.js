#!/usr/bin/env node
/**
 * build.js - Build Helmsman from src/flight.lua into both install formats:
 *
 *   dist/Helmsman_vX.Y.txt   Paste-able JSON (right-click seat → Advanced →
 *                                 Paste Lua configuration from clipboard).
 *                                 Link core (+ optional databank / anti-grav)
 *                                 in any slot — the script detects them by class.
 *                                 This is the one to use for DRM'd ships.
 *   dist/Helmsman_vX.Y.conf  DU custom autoconfigure file (links the core
 *                                 and anti-grav for you).
 *
 * Usage: node build.js
 *
 * Source format matches DU Starmap Navigator's handler blocks, using
 * autoconf-style names:
 *   --[[@
 *   slot=system
 *   event=onFlush
 *   ]]
 * EVENTS below maps each one to its JSON equivalent.
 */

const fs   = require('fs');
const path = require('path');

const VERSION = 'v1.0.2';
const NAME    = `Helmsman ${VERSION}`;
const SRC     = path.join('src', 'flight.lua');
const OUT_CONF = path.join('dist', `Helmsman_${VERSION}.conf`);
const OUT_JSON = path.join('dist', `Helmsman_${VERSION}.txt`);

// ── .conf slots ── navdb is select:manual (link your Navigator databank).
const CONF_SLOTS = [
  ['core',     { class: 'CoreUnit' }],
  ['antigrav', { class: 'AntiGravityGeneratorUnit' }],
  ['navdb',    { class: 'databank', select: 'manual' }],
  // Linked only to read ground distance for fast landings (engines are
  // still driven by tags, links don't change that).
  ['vBooster', { class: 'VerticalBooster' }],
  ['hover',    { class: 'Hovercraft' }],
  // A telemeter pointing DOWN sees ~100 m: faster landings when the ground
  // height is unknown (map picks). Only used once a reading proves it's down.
  ['telemeter', { class: 'TelemeterUnit' }],
  // Manual: the pilot links the radar(s); the script finds them by class.
  // (Fuel tanks need no links — every tank is read through the core.)
  ['radar',    { class: 'RadarPVPUnit', select: 'manual' }],
  // Warp drive: auto-linked like the default flight script / Arch.
  ['warpdrive', { class: 'WarpDriveUnit' }],
  // Manual: seat-linked switches for cabin automation (ON while seated).
  ['switch',   { class: 'ManualSwitchUnit', select: 'manual' }],
];

// ── JSON slots ── only system slots are named; link slots 0-9 stay generic
// (slot1..slot10) and are identified by class at startup, like Navigator.
const JSON_SLOTS = {
  '-1': 'unit', '-2': 'construct', '-3': 'player', '-4': 'system', '-5': 'library',
};

// autoconf "slot event" → JSON { slotKey, signature, args }
const EVENTS = {
  'unit onStart':                { slotKey: '-1', signature: 'onStart()' },
  'unit onStop':                 { slotKey: '-1', signature: 'onStop()' },
  'unit tick(timerId)':          { slotKey: '-1', signature: 'onTimer(tag)',           args: ['*'] },
  'system onUpdate':             { slotKey: '-4', signature: 'onUpdate()' },
  'system onFlush':              { slotKey: '-4', signature: 'onFlush()' },
  'system actionStart(action)':  { slotKey: '-4', signature: 'onActionStart(action)',  args: ['*'] },
  'system actionStop(action)':   { slotKey: '-4', signature: 'onActionStop(action)',   args: ['*'] },
  'system actionLoop(action)':   { slotKey: '-4', signature: 'onActionLoop(action)',   args: ['*'] },
  'system inputText(text)':      { slotKey: '-4', signature: 'onInputText(text)',      args: ['*'] },
};

function parseHandlers(lua) {
  const handlers = [];
  const re = /--\[\[@\n([\s\S]*?)\]\]\n([\s\S]*?)(?=--\[\[@|$)/g;
  let m;
  while ((m = re.exec(lua)) !== null) {
    const meta = {};
    for (const line of m[1].split('\n')) {
      const eq = line.indexOf('=');
      if (eq !== -1) meta[line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
    }
    if (!meta.slot || !meta.event) throw new Error(`Handler missing slot/event: ${m[1]}`);
    handlers.push({ slot: meta.slot, event: meta.event, code: m[2].replace(/\s+$/, '') });
  }
  return handlers;
}

// ── Minify ── drop comments (except --export lines: DU builds the
// parameter screen from those), indentation and blank lines. Lua-aware:
// strings ("...", '...', [[...]], [=[...]=]) are copied untouched.
// `node build.js --full` keeps everything (for reading the pasted code).
function stripLua(code) {
  let out = '', i = 0;
  const n = code.length;
  const longOpen = (at) => {             // "[", "=" * k, "[" → k, else -1
    if (code[at] !== '[') return -1;
    let j = at + 1, k = 0;
    while (code[j] === '=') { j++; k++; }
    return code[j] === '[' ? k : -1;
  };
  while (i < n) {
    const c = code[i];
    if (c === '-' && code[i + 1] === '-') {
      const k = longOpen(i + 2);
      if (k >= 0) {                      // --[[ long comment ]]
        const close = ']' + '='.repeat(k) + ']';
        const e = code.indexOf(close, i + 4 + k);
        i = e < 0 ? n : e + close.length;
        continue;
      }
      let e = code.indexOf('\n', i);
      if (e < 0) e = n;
      if (code.startsWith('--export', i)) out += code.slice(i, e);   // keep: parameters
      i = e;
      continue;
    }
    if (c === '"' || c === "'") {        // short string
      let j = i + 1;
      while (j < n && code[j] !== c && code[j] !== '\n') j += code[j] === '\\' ? 2 : 1;
      out += code.slice(i, j + 1);
      i = j + 1;
      continue;
    }
    const k = longOpen(i);
    if (k >= 0) {                        // [[ long string ]]
      const close = ']' + '='.repeat(k) + ']';
      const e = code.indexOf(close, i + 2 + k);
      const end = e < 0 ? n : e + close.length;
      out += code.slice(i, end);
      i = end;
      continue;
    }
    out += c;
    i++;
  }
  // Indentation and blank lines (newlines stay: statement boundaries and
  // readable error line numbers are worth the few bytes).
  return out.split('\n').map(l => l.trim()).filter(l => l !== '').join('\n');
}

function buildConf(handlers) {
  const indent = (code, n) => code.split('\n').map(l => (l.trim() === '' ? '' : ' '.repeat(n) + l)).join('\n');
  const bySlot = new Map();
  for (const h of handlers) {
    if (!bySlot.has(h.slot)) bySlot.set(h.slot, []);
    bySlot.get(h.slot).push(h);
  }
  let out = `name: ${NAME}\nslots:\n`;
  for (const [name, def] of CONF_SLOTS) {
    out += `  ${name}:\n`;
    for (const [k, v] of Object.entries(def)) out += `    ${k}: ${v}\n`;
  }
  out += 'handlers:\n';
  for (const [slot, hs] of bySlot) {
    out += `  ${slot}:\n`;
    for (const h of hs) out += `    ${h.event}:\n      lua: |\n${indent(h.code, 8)}\n`;
  }
  return out;
}

function buildJson(handlers) {
  const slots = {};
  for (const [k, name] of Object.entries(JSON_SLOTS)) slots[k] = { name, type: { events: [], methods: [] } };
  const out = handlers.map((h, i) => {
    const ev = EVENTS[`${h.slot} ${h.event}`];
    if (!ev) throw new Error(`No JSON mapping for "${h.slot} ${h.event}" — add it to EVENTS`);
    const args = (ev.args || []).map(a => (a === '*' ? { variable: '*' } : { value: a }));
    return {
      code: `--${JSON_SLOTS[ev.slotKey]}.${ev.signature}\n${h.code}\n--`,
      filter: { args, signature: ev.signature, slotKey: ev.slotKey },
      key: String(i),
    };
  });
  return JSON.stringify({ slots, handlers: out, methods: [], events: [] });
}

const lua = fs.readFileSync(SRC, 'utf8').replace(/\r\n/g, '\n');
if (lua.includes('\t')) throw new Error('Tabs found in source — YAML block scalars need spaces.');
// Build stamp (local time, MMDD-HHMM): shown on the HUD strip so a tester
// can see at a glance which paste is running.
const d = new Date(), p2 = n => String(n).padStart(2, '0');
const STAMP = p2(d.getMonth() + 1) + p2(d.getDate()) + '-' + p2(d.getHours()) + p2(d.getMinutes());
if (!/BUILD\s*=\s*"dev"/.test(lua)) throw new Error('BUILD = "dev" line missing in source');
const FULL = process.argv.includes('--full');
const handlers = parseHandlers(lua.replace(/BUILD(\s*)=(\s*)"dev"/, `BUILD$1=$2"${STAMP}"`));
if (!FULL) for (const h of handlers) h.code = stripLua(h.code);
console.log(`Build stamp ${STAMP}${FULL ? '  (full, with comments)' : '  (minified: comments stripped, --export kept)'}`);

fs.mkdirSync('dist', { recursive: true });
for (const [file, text] of [[OUT_JSON, buildJson(handlers)], [OUT_CONF, buildConf(handlers)]]) {
  fs.writeFileSync(file, text, 'utf8');
  console.log(`Built ${file}  (${handlers.length} handlers, ${(Buffer.byteLength(text) / 1024).toFixed(1)} KB)`);
}
