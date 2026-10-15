import Phaser from 'phaser';
import './style.css';

(() => {
const W = 960, H = 600, C = 40, COLS = 24, ROWS = 15, CHOICE_FROM = 5;
let MAX_WAVE = 20; // set per map in newRun
const MAPS = {
  verdant:  { name: 'Verdant Rift', tier: 'Level 1', waves: 20, shardMul: 1, desc: 'The standard run. No modifiers.',
    path: [[-1,2],[5,2],[5,7],[2,7],[2,12],[11,12],[11,4],[17,4],[17,10],[23,10]] },
  ironhold: { name: 'Ironhold', tier: 'Level 2', waves: 25, shardMul: 1.5, enemyHp: 1.4, gold: 0.7, desc: 'Enemies have 40% more HP and drop 30% less gold.',
    path: [[-1,7],[4,7],[4,2],[10,2],[10,12],[15,12],[15,3],[20,3],[20,8],[23,8]] },
  warped:   { name: 'Warped Spire', tier: 'Level 3', waves: 30, shardMul: 2, drain: true, desc: 'After each wave, the tower that dealt the most damage is drained and deals half damage for the next wave only.',
    path: [[-1,12],[6,12],[6,3],[12,3],[12,9],[18,9],[18,2],[23,2]] },
};
// Maps unlock in order: beat one to open the next.
const MAP_ORDER = ['verdant', 'ironhold', 'warped'];
function mapUnlocked(id) { const i = MAP_ORDER.indexOf(id); return i <= 0 || !!(META.best[MAP_ORDER[i - 1]] && META.best[MAP_ORDER[i - 1]].won); }
let WP, SEG, PATH_LEN, pathCells, BASE;
function setMap(id) {
  WP = MAPS[id].path.map(([c, r]) => ({ x: c * C + C / 2, y: r * C + C / 2 }));
  SEG = []; PATH_LEN = 0;
  for (let i = 0; i < WP.length - 1; i++) {
    const a = WP[i], b = WP[i + 1], len = Math.hypot(b.x - a.x, b.y - a.y);
    SEG.push({ a, b, len, start: PATH_LEN }); PATH_LEN += len;
  }
  pathCells = new Set();
  for (let i = 0; i < WP.length - 1; i++) {
    let c0 = Math.floor(WP[i].x / C), r0 = Math.floor(WP[i].y / C);
    const c1 = Math.floor(WP[i + 1].x / C), r1 = Math.floor(WP[i + 1].y / C);
    while (true) {
      if (c0 >= 0) pathCells.add(c0 + ',' + r0);
      if (c0 === c1 && r0 === r1) break;
      c0 += Math.sign(c1 - c0); r0 += Math.sign(r1 - r0);
    }
  }
  BASE = WP[WP.length - 1];
}
setMap('verdant');
function posAt(d) {
  for (const s of SEG) if (d <= s.start + s.len) {
    const t = (d - s.start) / s.len;
    return { x: s.a.x + (s.b.x - s.a.x) * t, y: s.a.y + (s.b.y - s.a.y) * t };
  }
  return { x: BASE.x, y: BASE.y };
}
const pct = v => Math.round(v * 100) + '%';
const pick = arr => arr[Math.floor(Math.random() * arr.length)];
const shuffle = arr => { for (let i = arr.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [arr[i], arr[j]] = [arr[j], arr[i]]; } return arr; };

// ---------- towers ----------
const TOWERS = {
  arcane: { name: 'Arcane Bolt', key: '1', cost: 50, dmg: 14, rate: 0.5, range: 120, color: 0xb07cff, css: '#b07cff',
    info: 'Fires quick magic bolts at one enemy at a time. Steady, reliable damage that is good against anything.' },
  plasma: { name: 'Plasma Cannon', key: '2', cost: 80, dmg: 24, rate: 1.4, range: 110, splash: 50, color: 0xff8a3d, css: '#ff8a3d',
    info: 'Lobs slow plasma shells that explode on impact and hurt every enemy in the blast. Best against tight groups.' },
  frost:  { name: 'Frost Pylon', key: '3', cost: 60, dmg: 6, rate: 0.9, range: 100, slow: 0.45, color: 0x7fd4ff, css: '#7fd4ff',
    info: 'Hits weakly but slows enemies down, so the rest of your towers get more time to shoot. Pairs with everything.' },
  tesla:  { name: 'Tesla Coil', key: '4', cost: 90, dmg: 12, rate: 1.1, range: 105, chain: 3, color: 0x4fd8e8, css: '#4fd8e8',
    info: 'Fires lightning that jumps from enemy to enemy, losing a bit of power with each jump. Great for long lines of enemies.' },
};
// Each tower has the same 5 upgrade options at every level. Options stack up to their max rank.
// Levels 5 and 10 also unlock the tower's bonus (TOWER_CAPS) automatically.
const TOWER_UPS = {
  arcane: [
    { id: 'runes',  name: 'Sharpened Runes', desc: '+25% damage.', max: 5, apply: t => t.dmg *= 1.25 },
    { id: 'twin',   name: 'Twin Cast',       desc: 'Shoots 1 more enemy at the same time.', max: 2, apply: t => t.multi += 1 },
    { id: 'focus',  name: 'Arcane Focus',    desc: 'Each hit in a row on the same enemy deals +12% more damage, up to 5 stacks.', max: 2, apply: t => t.ramp += 0.12 },
    { id: 'surge',  name: 'Mana Surge',      desc: 'Every 5th shot deals triple damage.', max: 1, apply: t => t.surge = 5 },
    { id: 'quick',  name: 'Quickcast',       desc: 'Fires 15% faster.', max: 4, apply: t => t.rate *= 0.85 },
  ],
  plasma: [
    { id: 'shells', name: 'Bigger Shells',   desc: '+20% blast radius.', max: 3, apply: t => t.splash *= 1.2 },
    { id: 'hot',    name: 'Hot Plasma',      desc: '+25% damage.', max: 5, apply: t => t.dmg *= 1.25 },
    { id: 'burn',   name: 'Burning Ground',  desc: 'Enemies hit burn for 40% of the hit’s damage over 2s.', max: 2, apply: t => t.burn += 0.4 },
    { id: 'auto',   name: 'Autoloader',      desc: 'Fires 15% faster.', max: 4, apply: t => t.rate *= 0.85 },
    { id: 'concuss',name: 'Concussive Shells', desc: 'Blasts slow enemies by 25% for 1s.', max: 1, apply: t => { t.slow = Math.max(t.slow, 0.25); t.slowDur = Math.max(t.slowDur, 1); } },
  ],
  frost: [
    { id: 'deep',   name: 'Deep Freeze',     desc: 'Slows 8% more (up to 85%).', max: 3, apply: t => t.slow = Math.min(0.85, t.slow + 0.08) },
    { id: 'burst',  name: 'Frost Burst',     desc: 'Shots burst and chill every enemy nearby.', max: 3, apply: t => t.splash = t.splash ? t.splash * 1.2 : 35 },
    { id: 'linger', name: 'Lingering Cold',  desc: 'Slows last 0.8s longer.', max: 3, apply: t => t.slowDur += 0.8 },
    { id: 'shards', name: 'Ice Shards',      desc: '+50% damage.', max: 4, apply: t => t.dmg *= 1.5 },
    { id: 'brittle',name: 'Brittle',         desc: 'Slowed enemies take 10% more damage from everything.', max: 3, apply: t => t.brittle += 0.1 },
  ],
  tesla: [
    { id: 'arcs',   name: 'More Arcs',       desc: 'Lightning jumps to 1 more enemy.', max: 4, apply: t => t.chain += 1 },
    { id: 'volt',   name: 'High Voltage',    desc: '+25% damage.', max: 5, apply: t => t.dmg *= 1.25 },
    { id: 'conduct',name: 'Conductive',      desc: 'Jumps lose less damage (+8% per jump).', max: 3, apply: t => t.chainMul = Math.min(0.95, t.chainMul + 0.08) },
    { id: 'bank',   name: 'Capacitor Bank',  desc: 'Fires 15% faster.', max: 4, apply: t => t.rate *= 0.85 },
    { id: 'jump',   name: 'Arc Reach',       desc: 'Lightning can jump 25% farther.', max: 3, apply: t => t.chainReach *= 1.25 },
  ],
};
const TOWER_CAPS = {
  arcane: { 5: { id: 'mark', name: 'Arcane Mark', desc: 'Enemies hit take 20% more damage from everything for 2s.', apply: t => t.mark = 0.2 },
            10: { id: 'archmage', name: 'Archmage', desc: 'Fires 50% faster and shoots 1 more enemy.', apply: t => { t.rate *= 0.67; t.multi += 1; } } },
  plasma: { 5: { id: 'cluster', name: 'Cluster Bomb', desc: 'Each shot throws 2 bomblets at nearby enemies for 50% damage.', apply: t => t.cluster = 2 },
            10: { id: 'orbital', name: 'Orbital Strike', desc: 'Every 4th shot is a huge blast: double radius, triple damage.', apply: t => t.orbital = 4 } },
  frost:  { 5: { id: 'flash', name: 'Flash Freeze', desc: 'Every 6th shot freezes enemies solid for 1.2s.', apply: t => t.freeze = 6 },
            10: { id: 'zero', name: 'Absolute Zero', desc: 'Every enemy in range is constantly slowed by 35%.', apply: t => t.zero = 0.35 } },
  tesla:  { 5: { id: 'overload', name: 'Overload', desc: 'Lightning jumps have a 15% chance to stun for 0.6s.', apply: t => t.stun = 0.15 },
            10: { id: 'storm', name: 'Storm Core', desc: 'Shoots 1 more enemy and lightning jumps 2 more times.', apply: t => { t.multi += 1; t.chain += 2; } } },
};
const RECIPES = {
  'arcane+frost':  { name: 'Rimeshard',    color: 0xc9b8ff, desc: 'Fires rapid ice shards that slow every enemy they hit. Arcane speed with Frost control.' },
  'arcane+plasma': { name: 'Starbolt',     color: 0xff6fd8, desc: 'Fires fast bolts that explode on impact. Arcane speed with Plasma splash, so it shreds groups.' },
  'arcane+tesla':  { name: 'Railgun',      color: 0x8affff, desc: 'Fires heavy bolts that arc to more enemies on hit. Huge single hits that also clear lines.' },
  'frost+plasma':  { name: 'Steam Engine', color: 0xe0e6ff, desc: 'Blasts scalding steam that splashes and slows every enemy caught in the cloud.' },
  'frost+tesla':   { name: 'Cryo Coil',    color: 0x9af0ff, desc: 'Chain lightning that slows every enemy it jumps to. Locks down whole lines.' },
  'plasma+tesla':  { name: 'Ion Storm',    color: 0xffd36e, desc: 'Explosive shells whose blast also throws lightning outward. The best crowd clearer.' },
};
// Hybrids pick from a fixed 5 of their parents' upgrades (ranks start fresh after the merge).
const HYBRID_UPS = {
  'arcane+frost':  ['runes', 'quick', 'twin', 'deep', 'brittle'],
  'arcane+plasma': ['runes', 'quick', 'twin', 'shells', 'burn'],
  'arcane+tesla':  ['runes', 'quick', 'focus', 'arcs', 'conduct'],
  'frost+plasma':  ['hot', 'auto', 'shells', 'deep', 'linger'],
  'frost+tesla':   ['volt', 'bank', 'arcs', 'deep', 'brittle'],
  'plasma+tesla':  ['hot', 'auto', 'shells', 'arcs', 'conduct'],
};
// Super towers: two level 10 hybrids merged together. They share one set of 5 upgrades.
const SUPER_UPS = [
  { id: 'overcharge', name: 'Overcharge',     desc: '+30% damage.', max: 4, apply: t => t.dmg *= 1.3 },
  { id: 'hyper',      name: 'Hyperdrive',     desc: 'Fires 15% faster.', max: 4, apply: t => t.rate *= 0.85 },
  { id: 'resonant',   name: 'Resonant Core',  desc: 'Boosts every special effect: +15% blast radius, +1 lightning jump, +5% slow and +20% burn.', max: 3,
    apply: t => { if (t.splash) t.splash *= 1.15; if (t.chain) t.chain += 1; if (t.slow) t.slow = Math.min(0.85, t.slow + 0.05); if (t.burn) t.burn += 0.2; } },
  { id: 'fork',       name: 'Rift Fork',      desc: 'Shoots 1 more enemy at the same time.', max: 2, apply: t => t.multi += 1 },
  { id: 'lens',       name: 'Rift Lens',      desc: '+12% range.', max: 2, apply: t => t.range *= 1.12 },
];
// Super tower names come from the base towers inside them.
const SUPERS = {
  'arcane+frost+plasma+tesla': { name: 'Rift Singularity', color: 0xffffff, desc: 'Holds the power of all four towers: fast bolts, explosions, deep slows and chain lightning in every shot.' },
  'arcane+frost+plasma':       { name: 'Prism Reactor',    color: 0xffa8f0, desc: 'Rapid exploding ice bolts that shred and slow whole groups.' },
  'arcane+frost+tesla':        { name: 'Aurora Lance',     color: 0xa8e8ff, desc: 'Piercing frozen lightning that slows everything it jumps through.' },
  'arcane+plasma+tesla':       { name: 'Nova Battery',     color: 0xffe08a, desc: 'Heavy bolts that explode and throw lightning across the field.' },
  'frost+plasma+tesla':        { name: 'Tempest Engine',   color: 0xc8f5ff, desc: 'A storm of scalding, freezing, crackling blasts. Nothing in range moves fast.' },
};
const MERGE_COST = 100, SUPER_MERGE_MUL = 3, MAX_LVL = 10, MERGE_LVL = 10, SELL_RATE = 0.8;
// Numeric tower traits; merges keep the stronger value of each.
const TRAITS = ['splash', 'slow', 'slowDur', 'chain', 'chainMul', 'chainReach', 'multi', 'ramp', 'surge', 'burn', 'brittle', 'mark', 'cluster', 'orbital', 'freeze', 'zero', 'stun'];

const ENEMIES = {
  grunt:  { hp: 40,   speed: 52, gold: 5,   lives: 1,  atk: 8,  r: 9,  color: 0xff5d6c },
  runner: { hp: 24,   speed: 96, gold: 4,   lives: 1,  atk: 5,  r: 7,  color: 0xffb35d },
  brute:  { hp: 170,  speed: 34, gold: 12,  lives: 3,  atk: 20, r: 13, color: 0xd14b8f },
  knight: { hp: 1100, speed: 30, gold: 60,  lives: 6,  atk: 30, r: 16, color: 0xff2e4d, boss: true, name: 'Rift Knight' },
  warden: { hp: 3000, speed: 26, gold: 120, lives: 10, atk: 45, r: 18, color: 0xff2e4d, boss: true, name: 'Rift Warden' },
  tyrant: { hp: 9000, speed: 22, gold: 300, lives: 20, atk: 80, r: 23, color: 0xff2e4d, boss: true, name: 'Rift Tyrant' },
};

// ---------- heroes ----------
const HEROES = {
  vanguard: { name: 'Vanguard', role: 'Tank', color: 0x5fe39a, css: '#5fe39a',
    desc: 'A walking fortress. Huge HP, blocks 3 enemies at once and stuns crowds.',
    stats: { hp: 340, dmg: 8, rate: 0.7, range: 80, block: 3, armor: 0.1, regen: 5, speed: 135 },
    ability: { id: 'slam', name: 'Shield Slam', cd: 18, dmg: 30, r: 100, stun: 1.5 } },
  striker:  { name: 'Striker', role: 'Damage', color: 0xff8a7a, css: '#ff8a7a',
    desc: 'Fast and deadly but fragile. Shreds enemies and blasts groups with Rift Nova.',
    stats: { hp: 180, dmg: 12, rate: 0.5, range: 115, block: 1, armor: 0, regen: 2, speed: 165 },
    ability: { id: 'nova', name: 'Rift Nova', cd: 20, dmg: 40, r: 110 } },
  oracle:   { name: 'Oracle', role: 'Support', color: 0xb07cff, css: '#b07cff',
    desc: 'Empowers towers. Nearby towers deal +15% damage, and Overclock Field makes them fire much faster.',
    stats: { hp: 210, dmg: 7, rate: 0.6, range: 100, block: 2, armor: 0, regen: 3, speed: 150, aura: 0.15 },
    ability: { id: 'overclock', name: 'Overclock Field', cd: 24, r: 170, dur: 6, power: 0.6 } },
  sniper:   { name: 'Sniper', role: 'Marksman', color: 0xffd36e, css: '#ffd36e', unlock: 250,
    desc: 'Hits anything on the map, but has to stand still and brace before every shot. Slow, heavy, precise.',
    stats: { hp: 170, dmg: 48, rate: 2.4, range: 9999, block: 1, armor: 0, regen: 2, speed: 140, brace: 1.2, crit: 0.1 },
    ability: { id: 'pierce', name: 'Piercing Shot', cd: 16, mult: 4, w: 18 } },
};
const isUnlocked = id => !HEROES[id].unlock || !!META.unlocked[id];
function abilityText(h) {
  const a = h.ab;
  if (a.id === 'slam') return `Deals ${a.dmg.toFixed(0)} damage and stuns enemies within ${a.r.toFixed(0)} for ${a.stun.toFixed(1)}s.`;
  if (a.id === 'nova') return `Deals ${a.dmg.toFixed(0)} damage to every enemy within ${a.r.toFixed(0)}.`;
  if (a.id === 'pierce') return `Fires a round through every enemy in a line toward the lead enemy for ${a.mult.toFixed(1)}× damage.`;
  return `Towers within ${a.r.toFixed(0)} fire ${pct(a.power)} faster for ${a.dur.toFixed(1)}s.`;
}

// ---------- hero upgrades and rarity ----------
const RARITIES = [
  { id: 'common',    name: 'Common',    mult: 1,   w: 50 },
  { id: 'uncommon',  name: 'Uncommon',  mult: 1.4, w: 25 },
  { id: 'rare',      name: 'Rare',      mult: 1.9, w: 15 },
  { id: 'mythic',    name: 'Mythic',    mult: 2.6, w: 6.5 },
  { id: 'legendary', name: 'Legendary', mult: 3.5, w: 3 },
  { id: 'secret',    name: 'Secret',    mult: 4.5, w: 0.5 },
];
const RAR = Object.fromEntries(RARITIES.map(r => [r.id, r]));
const DEMONIC_CHANCE = 0.01;
function rollRarity() {
  const luck = (1 + 0.1 * rank(META.global, 'luck')) * (1 + 0.3 * rank(META.global, 'fortune'));
  const ws = RARITIES.map(x => x.id === 'common' ? x.w * (1 - 0.15 * rank(META.global, 'fortune')) : x.w * luck), total = ws.reduce((a, b) => a + b, 0);
  let r = Math.random() * total;
  for (let i = 0; i < RARITIES.length; i++) { if ((r -= ws[i]) < 0) return RARITIES[i]; }
  return RARITIES[0];
}

// Scalable upgrades: m is the base strength, multiplied by rarity (and doubled if Demonic).
const PERKS = [
  // generic, any hero
  { id: 'blade',   cls: 'any', name: 'Plasma Blade',  m: 0.2,  desc: m => `+${pct(m)} hero damage.`, apply: (h, m) => h.dmg *= 1 + m },
  { id: 'plate',   cls: 'any', name: 'Rune Plating',  m: 50,   desc: m => `+${Math.round(m)} max HP and a full heal.`, apply: (h, m) => { h.maxHp += Math.round(m); h.hp = h.maxHp; } },
  { id: 'mend',    cls: 'any', name: 'Nanite Mend',   m: 3,    desc: m => `+${m.toFixed(1)} HP regen per second.`, apply: (h, m) => h.regen += m },
  { id: 'reboot',  cls: 'any', name: 'Quick Reboot',  m: 0.15, desc: m => `Respawn ${pct(Math.min(0.7, m))} faster.`, apply: (h, m) => h.respawn = Math.max(2, h.respawn * (1 - Math.min(0.7, m))) },
  { id: 'arch',    cls: 'any', name: 'Architect',     m: 0.07, desc: m => `Towers cost ${pct(Math.min(0.5, m))} less.`, apply: (h, m) => h.costMul *= 1 - Math.min(0.5, m) },
  { id: 'engineer',cls: 'any', name: 'Engineer',      m: 0.08, desc: m => `Tower level-ups cost ${pct(Math.min(0.5, m))} less.`, apply: (h, m) => h.lvlMul *= 1 - Math.min(0.5, m) },
  { id: 'reach',   cls: 'any', name: 'Long Reach',    m: 0.2,  desc: m => `+${pct(m)} build range.`, apply: (h, m) => h.buildRange *= 1 + m },
  { id: 'bounty',  cls: 'any', name: 'Bounty Sigil',  m: 1,    desc: m => `+${Math.max(1, Math.round(m))} gold for every kill.`, apply: (h, m) => h.bounty += Math.max(1, Math.round(m)) },
  { id: 'siphon',  cls: 'any', name: 'Siphon',        m: 3,    desc: m => `Heal ${Math.round(m)} HP for every kill.`, apply: (h, m) => h.siphon += Math.round(m) },
  { id: 'boots',   cls: 'any', name: 'Rift Boots',    m: 0.15, desc: m => `+${pct(m)} move speed.`, apply: (h, m) => h.speed *= 1 + m },
  // Vanguard
  { id: 'bulwark', cls: 'vanguard', name: 'Bulwark',       m: 1,    desc: m => `Block ${Math.max(1, Math.round(m))} more enemy at a time.`, apply: (h, m) => h.block += Math.max(1, Math.round(m)) },
  { id: 'shell',   cls: 'vanguard', name: 'Hardlight Shell', m: 0.08, desc: m => `Take ${pct(m)} less damage (up to 75%).`, apply: (h, m) => h.armor = Math.min(0.75, h.armor + m) },
  { id: 'thorns',  cls: 'vanguard', name: 'Thorn Field',   m: 8,    desc: m => `Enemies you block take ${Math.round(m)} damage per second.`, apply: (h, m) => h.thorns += m },
  { id: 'seismic', cls: 'vanguard', name: 'Seismic Slam',  m: 0.3,  desc: m => `Shield Slam deals +${pct(m)} damage.`, apply: (h, m) => h.ab.dmg *= 1 + m },
  { id: 'after',   cls: 'vanguard', name: 'Aftershock',    m: 0.1,  desc: m => `Shield Slam recharges ${pct(Math.min(0.5, m))} faster.`, apply: (h, m) => h.ab.cd = Math.max(6, h.ab.cd * (1 - Math.min(0.5, m))) },
  { id: 'daze',    cls: 'vanguard', name: 'Concussion',    m: 0.4,  desc: m => `Shield Slam stuns ${m.toFixed(1)}s longer.`, apply: (h, m) => h.ab.stun += m },
  { id: 'fort',    cls: 'vanguard', name: 'Fortify',       m: 0.15, desc: m => `+${pct(m)} max HP.`, apply: (h, m) => { h.maxHp = Math.round(h.maxHp * (1 + m)); h.hp = h.maxHp; } },
  // Striker
  { id: 'crit',    cls: 'striker', also: ['sniper'], name: 'Weak Point', m: 0.08, desc: m => `+${pct(m)} crit chance.`, apply: (h, m) => h.crit = Math.min(0.75, h.crit + m) },
  { id: 'critdmg', cls: 'striker', also: ['sniper'], name: 'Lethal Edge', m: 0.25, desc: m => `+${pct(m)} crit damage.`, apply: (h, m) => h.critDmg += m },
  { id: 'split',   cls: 'striker', name: 'Split Shot',     m: 1,    desc: m => `Attacks hit ${Math.max(1, Math.round(m))} more enemy.`, apply: (h, m) => h.multi = Math.min(6, h.multi + Math.max(1, Math.round(m))) },
  { id: 'scope',   cls: 'striker', name: 'Long Barrel',    m: 0.12, desc: m => `+${pct(m)} attack range.`, apply: (h, m) => h.range *= 1 + m },
  { id: 'clock',   cls: 'striker', name: 'Overclock',      m: 0.15, desc: m => `+${pct(m)} attack speed.`, apply: (h, m) => h.rate /= 1 + m },
  { id: 'core',    cls: 'striker', name: 'Nova Core',      m: 0.3,  desc: m => `Rift Nova deals +${pct(m)} damage.`, apply: (h, m) => h.ab.dmg *= 1 + m },
  { id: 'nfocus',  cls: 'striker', name: 'Rift Focus',     m: 0.1,  desc: m => `Rift Nova recharges ${pct(Math.min(0.5, m))} faster.`, apply: (h, m) => h.ab.cd = Math.max(6, h.ab.cd * (1 - Math.min(0.5, m))) },
  { id: 'wide',    cls: 'striker', name: 'Wide Nova',      m: 0.12, desc: m => `Rift Nova radius +${pct(m)}.`, apply: (h, m) => h.ab.r *= 1 + m },
  // Oracle
  { id: 'aura',    cls: 'oracle', name: 'Commander Aura',  m: 0.08, desc: m => `Towers near you deal +${pct(m)} more damage.`, apply: (h, m) => h.aura += m },
  { id: 'signal',  cls: 'oracle', name: 'Signal Boost',    m: 0.15, desc: m => `Aura reaches ${pct(m)} farther and all towers get +${pct(m / 3)} range.`, apply: (h, m) => { h.auraRange *= 1 + m; h.towerRange += m / 3; } },
  { id: 'surge',   cls: 'oracle', name: 'Power Surge',     m: 0.15, desc: m => `Overclock Field speeds towers up ${pct(m)} more.`, apply: (h, m) => h.ab.power += m },
  { id: 'extend',  cls: 'oracle', name: 'Extended Field',  m: 1.5,  desc: m => `Overclock Field lasts ${m.toFixed(1)}s longer.`, apply: (h, m) => h.ab.dur += m },
  { id: 'chill',   cls: 'oracle', name: 'Chilling Presence', m: 0.08, desc: m => `Towers near you also slow enemies by ${pct(m)}.`, apply: (h, m) => h.auraSlow = Math.min(0.6, h.auraSlow + m) },
  { id: 'interest',cls: 'oracle', name: 'Investments',     m: 0.03, desc: m => `Earn ${pct(m)} interest on your gold after each wave.`, apply: (h, m) => h.interest += m },
  // Sniper
  { id: 'brace',   cls: 'sniper', name: 'Quick Brace',     m: 0.15, desc: m => `Brace ${pct(Math.min(0.6, m))} faster.`, apply: (h, m) => h.brace = Math.max(0.25, h.brace * (1 - Math.min(0.6, m))) },
  { id: 'caliber', cls: 'sniper', name: 'Heavy Caliber',   m: 0.25, desc: m => `+${pct(m)} hero damage.`, apply: (h, m) => h.dmg *= 1 + m },
  { id: 'chamber', cls: 'sniper', name: 'Fast Chamber',    m: 0.12, desc: m => `+${pct(m)} attack speed.`, apply: (h, m) => h.rate /= 1 + m },
  { id: 'penetrate', cls: 'sniper', name: 'Penetrator',    m: 1,    desc: m => `Shots also hit ${Math.max(1, Math.round(m))} enemy near the target for 50% damage.`, apply: (h, m) => h.pierce += Math.max(1, Math.round(m)) },
  { id: 'apround', cls: 'sniper', name: 'Armor-Piercing Rounds', m: 0.3, desc: m => `Piercing Shot deals +${pct(m)} damage.`, apply: (h, m) => h.ab.mult *= 1 + m },
  { id: 'steady',  cls: 'sniper', name: 'Steady Aim',      m: 0.1,  desc: m => `Piercing Shot recharges ${pct(Math.min(0.5, m))} faster.`, apply: (h, m) => h.ab.cd = Math.max(5, h.ab.cd * (1 - Math.min(0.5, m))) },
  { id: 'alchemy', cls: 'oracle', name: 'Alchemist',       m: 0.15, desc: m => `Merging costs ${pct(Math.min(0.8, m))} less.`, apply: (h, m) => h.mergeMul *= 1 - Math.min(0.8, m) },
];
// Unique upgrades that only appear at Legendary (per hero) or Secret (any hero).
const UNIQUES = [
  { id: 'aegis',  cls: 'vanguard', rarity: 'legendary', name: 'Aegis Core',     desc: 'Block 2 more enemies, take 20% less damage and gain 100 max HP.', apply: h => { h.block += 2; h.armor = Math.min(0.75, h.armor + 0.2); h.maxHp += 100; h.hp = h.maxHp; } },
  { id: 'unbreak',cls: 'vanguard', rarity: 'legendary', name: 'Unbreakable',    desc: 'Once per wave, a fatal blow leaves you at full HP instead.', apply: h => h.unbreakable = true },
  { id: 'exec',   cls: 'striker',  rarity: 'legendary', name: 'Executioner',    desc: '+20% damage. Your hits instantly finish non-boss enemies below 15% HP.', apply: h => { h.dmg *= 1.2; h.execute = 0.15; } },
  { id: 'storm',  cls: 'striker',  rarity: 'legendary', name: 'Bullet Storm',   desc: 'Every 3rd attack hits every enemy in range.', apply: h => h.bulletStorm = 3 },
  { id: 'master', cls: 'oracle',   rarity: 'legendary', name: 'Master Architect', desc: 'All towers deal +25% damage and cost 20% less.', apply: h => { S.mod.towerDmg += 0.25; h.costMul *= 0.8; } },
  { id: 'warp',   cls: 'oracle',   rarity: 'legendary', name: 'Time Warp',      desc: 'Overclock Field also slows enemies inside it by 40%.', apply: h => h.timeWarp = 0.4 },
  { id: 'deadeye', cls: 'sniper', rarity: 'legendary', name: 'Deadeye',      desc: 'Every 3rd shot is a guaranteed crit, and crits deal +50% more damage.', apply: h => { h.deadeye = 3; h.critDmg += 0.5; } },
  { id: 'overwatch', cls: 'sniper', rarity: 'legendary', name: 'Overwatch',  desc: 'Your shots stun their target for 0.5s (bosses 0.2s).', apply: h => h.shotStun = 0.5 },
  { id: 'sun',    cls: 'any', rarity: 'secret', name: 'Second Sun',     desc: 'Your ability casts itself whenever it is ready, and recharges 25% faster.', apply: h => { h.autoCast = true; h.ab.cd = Math.max(5, h.ab.cd * 0.75); } },
  { id: 'midas',  cls: 'any', rarity: 'secret', name: 'Midas Protocol', desc: 'Enemies drop double gold.', apply: () => S.mod.gold += 1 },
  { id: 'heart',  cls: 'any', rarity: 'secret', name: 'Rift Heart',     desc: 'All towers deal +30% damage and fire 30% faster.', apply: () => { S.mod.towerDmg += 0.3; S.mod.towerRate *= 0.7; } },
];
// Demonic downsides, scaled by the upgrade's rarity.
const CURSES = [
  { desc: k => `Enemies have ${Math.round(5 * k)}% more HP.`, apply: k => S.mod.enemyHp += 0.05 * k },
  { desc: k => `Lose ${Math.round(2 * k)} base HP.`, apply: k => S.lives = Math.max(1, S.lives - Math.round(2 * k)) },
  { desc: k => `Your hero loses ${Math.round(Math.min(50, 10 * k))}% max HP.`, apply: k => { const h = S.hero; h.maxHp = Math.round(h.maxHp * (1 - Math.min(0.5, 0.1 * k))); h.hp = Math.min(h.hp, h.maxHp); } },
  { desc: k => `New towers cost ${Math.round(8 * k)}% more.`, apply: k => S.hero.costMul *= 1 + 0.08 * k },
  { desc: k => `Lose ${Math.round(60 * k)} gold.`, apply: k => S.gold = Math.max(0, S.gold - Math.round(60 * k)) },
  { desc: k => `Enemies move ${Math.round(4 * k)}% faster.`, apply: k => S.mod.enemySpeed += 0.04 * k },
];

// Boss drops: heroic powers with 3 ranks.
const HEROICS = [
  { id: 'blades', name: 'Orbiting Blades', desc: r => `${r + 1} blades circle your hero, each dealing ${20 * r} damage per second to enemies they touch.` },
  { id: 'drone',  name: 'Turret Drone',    desc: r => `${r} drone${r > 1 ? 's' : ''} fly beside your hero and shoot the nearest enemy for ${10 + 8 * r} damage.` },
  { id: 'timestop', name: 'Time Stop',     desc: r => `Every 25s, every enemy on the map freezes for ${1 + r}s.` },
  { id: 'wither', name: 'Withering Aura',  desc: r => `Enemies within ${90 + 20 * r} of your hero take ${10 * r} damage per second and are slowed 20%.` },
  { id: 'chainstrike', name: 'Chain Strike', desc: r => `Your attacks jump to ${1 + r} more enemies for 60% damage.` },
  { id: 'goldrush', name: 'Gold Rush',     desc: r => `Kills have a ${8 * r}% chance to drop 15 bonus gold.` },
  { id: 'phoenix', name: 'Phoenix Rebirth', desc: r => `When knocked out, explode for ${150 * r} damage and respawn in 2s.` },
];

// ---------- wave rewards ----------
const RELICS = [
  { id: 'overcharger', name: 'Overcharger',    desc: 'All towers deal +15% damage.', apply: () => S.mod.towerDmg += 0.15 },
  { id: 'cryocore',    name: 'Cryo Core',      desc: 'All slows are 15% stronger.', apply: () => S.mod.slow += 0.15 },
  { id: 'treasury',    name: 'Rift Treasury',  desc: '+25% gold from kills.', apply: () => S.mod.gold += 0.25 },
  { id: 'lens',        name: 'Farsight Lens',  desc: 'All towers +12% range.', apply: () => S.hero.towerRange += 0.12 },
  { id: 'warbanner',   name: 'War Banner',     desc: 'Hero deals +25% damage.', apply: () => S.hero.dmg *= 1.25 },
  { id: 'repair',      name: 'Repair Drones',  desc: 'Restore 6 base HP.', repeat: true, apply: () => S.lives += 6 },
  { id: 'capacitor',   name: 'Capacitor',      desc: 'Towers fire 10% faster.', apply: () => S.mod.towerRate *= 0.9 },
];
const LEGENDARY_RELICS = [
  { id: 'starforge', rarity: 'legendary', name: 'Starforge',    desc: 'All towers deal +30% damage and get +10% range.', apply: () => { S.mod.towerDmg += 0.3; S.hero.towerRange += 0.1; } },
  { id: 'chrono',    rarity: 'legendary', name: 'Chrono Engine', desc: 'All towers fire 20% faster.', apply: () => S.mod.towerRate *= 0.8 },
  { id: 'phoenixcore', rarity: 'legendary', name: 'Phoenix Core', desc: 'The first time your base would fall, it survives with 10 HP.', apply: () => S.mod.phoenix = true },
];
const SECRET_RELICS = [
  { id: 'crown', rarity: 'secret', name: 'Rift Crown',    desc: 'Every tower you own gains 2 free levels of damage.', repeat: true, apply: () => { for (const t of S.towers) { t.dmg *= 1.6; } } },
  { id: 'loop',  rarity: 'secret', name: 'Infinity Loop', desc: 'Your ability recharges twice as fast and your hero attacks 30% faster.', apply: () => { S.hero.ab.cd = Math.max(5, S.hero.ab.cd / 2); S.hero.rate *= 0.7; } },
];
const CHALLENGES = [
  { id: 'swarm',  name: 'Swarm',       rule: 'Twice as many enemies, each with 35% less HP.' },
  { id: 'blitz',  name: 'Blitz',       rule: 'Enemies move 40% faster.' },
  { id: 'iron',   name: 'Iron Tide',   rule: 'Every enemy is a brute.' },
  { id: 'lone',   name: 'Lone Hero',   rule: 'Towers deal 40% less damage. Your hero deals double.' },
];

// Merging can awaken a hero upgrade inspired by the hybrid (35% chance, once per recipe per run).
const BOONS = {
  'arcane+frost':  { name: 'Frostbitten Strikes', desc: 'Your hero’s attacks slow enemies by 30%.', apply: h => h.boonSlow = 0.3 },
  'arcane+plasma': { name: 'Starburst Rounds',    desc: 'Your hero’s attacks explode, dealing 40% damage to nearby enemies.', apply: h => h.boonSplash = 0.4 },
  'arcane+tesla':  { name: 'Rail Lance',          desc: 'Every 4th hero attack deals 4× damage.', apply: h => h.boonRail = 4 },
  'frost+plasma':  { name: 'Steam Vent',          desc: 'Enemies within 80 of your hero take 15 damage per second and are slowed 15%.', apply: h => h.boonVent = 15 },
  'frost+tesla':   { name: 'Static Frost',        desc: 'Your hero’s attacks jump to 2 more enemies for 50% damage and slow them.', apply: h => h.boonChain = 2 },
  'plasma+tesla':  { name: 'Ion Discharge',       desc: 'Every 6s, lightning strikes 4 random enemies for 60 damage plus double your hero damage.', apply: h => h.boonIon = 6 },
};

// ---------- meta progression (saved in this browser)
// Each hero has its own permanent upgrades, bought with Rift Shards on the Heroes page.
const HERO_META = {
  vanguard: [
    { id: 'ironhide', name: 'Ironhide',         max: 5, cost: r => 30 + 25 * r, desc: r => `+${10 * r}% max HP`, apply: (h, r) => h.maxHp = Math.round(h.maxHp * (1 + 0.1 * r)) },
    { id: 'bastion',  name: 'Bastion Plating',  max: 4, cost: r => 40 + 30 * r, desc: r => `Take ${4 * r}% less damage`, apply: (h, r) => h.armor = Math.min(0.75, h.armor + 0.04 * r) },
    { id: 'seismic',  name: 'Seismic Training', max: 4, cost: r => 40 + 30 * r, desc: r => `Shield Slam deals +${15 * r}% damage and stuns ${(0.2 * r).toFixed(1)}s longer`, apply: (h, r) => { h.ab.dmg *= 1 + 0.15 * r; h.ab.stun += 0.2 * r; } },
    { id: 'medic',    name: 'Field Medic',      max: 3, cost: r => 50 + 40 * r, desc: r => `+${(1.5 * r).toFixed(1)} HP regen per second`, apply: (h, r) => h.regen += 1.5 * r },
  ],
  striker: [
    { id: 'honed',    name: 'Honed Edge',       max: 5, cost: r => 30 + 25 * r, desc: r => `+${7 * r}% damage`, apply: (h, r) => h.dmg *= 1 + 0.07 * r },
    { id: 'instinct', name: 'Killer Instinct',  max: 4, cost: r => 40 + 30 * r, desc: r => `+${4 * r}% crit chance`, apply: (h, r) => h.crit += 0.04 * r },
    { id: 'novam',    name: 'Nova Mastery',     max: 4, cost: r => 40 + 30 * r, desc: r => `Rift Nova deals +${10 * r}% damage and recharges ${6 * r}% faster`, apply: (h, r) => { h.ab.dmg *= 1 + 0.1 * r; h.ab.cd *= 1 - 0.06 * r; } },
    { id: 'fleet',    name: 'Fleet Foot',       max: 3, cost: r => 50 + 40 * r, desc: r => `+${6 * r}% move and attack speed`, apply: (h, r) => { h.speed *= 1 + 0.06 * r; h.rate /= 1 + 0.06 * r; } },
  ],
  oracle: [
    { id: 'resonance', name: 'Resonance',       max: 5, cost: r => 30 + 25 * r, desc: r => `Tower aura gives +${4 * r}% more damage`, apply: (h, r) => h.aura += 0.04 * r },
    { id: 'longclock', name: 'Long Overclock',  max: 4, cost: r => 40 + 30 * r, desc: r => `Overclock Field lasts ${(0.6 * r).toFixed(1)}s longer`, apply: (h, r) => h.ab.dur += 0.6 * r },
    { id: 'tithe',     name: 'Rift Tithe',      max: 4, cost: r => 40 + 30 * r, desc: r => `Start each run with +${25 * r} gold`, apply: (h, r) => S.gold += 25 * r },
    { id: 'widesig',   name: 'Wide Signal',     max: 3, cost: r => 50 + 40 * r, desc: r => `All towers get +${3 * r}% range`, apply: (h, r) => h.towerRange += 0.03 * r },
  ],
  sniper: [
    { id: 'rounds',   name: 'Heavy Rounds',     max: 5, cost: r => 30 + 25 * r, desc: r => `+${8 * r}% damage`, apply: (h, r) => h.dmg *= 1 + 0.08 * r },
    { id: 'stance',   name: 'Steady Stance',    max: 4, cost: r => 40 + 30 * r, desc: r => `Brace ${12 * r}% faster`, apply: (h, r) => h.brace *= 1 - 0.12 * r },
    { id: 'hollow',   name: 'Hollow Points',    max: 4, cost: r => 40 + 30 * r, desc: r => `+${15 * r}% crit damage`, apply: (h, r) => h.critDmg += 0.15 * r },
    { id: 'drills',   name: 'Piercing Drills',  max: 3, cost: r => 50 + 40 * r, desc: r => `Piercing Shot recharges ${8 * r}% faster`, apply: (h, r) => h.ab.cd *= 1 - 0.08 * r },
  ],
};
const GLOBAL_META = [
  { id: 'gold',    name: 'War Chest',       max: 5, cost: r => 25 + 20 * r, desc: r => `Start with +${20 * r} gold` },
  { id: 'lives',   name: 'Reinforced Core', max: 5, cost: r => 25 + 20 * r, desc: r => `Base starts with +${2 * r} HP` },
  { id: 'reroll',  name: 'Fate Weaver',     max: 3, cost: r => 50 + 40 * r, desc: r => `+${r} upgrade reroll${r > 1 ? 's' : ''} per run` },
  { id: 'luck',    name: 'Lucky Star',      max: 3, cost: r => 60 + 50 * r, desc: r => `Rarer upgrades are ${10 * r}% more likely` },
  { id: 'vet',     name: 'Veteran',         max: 2, cost: r => 120 + 100 * r, desc: r => `Start each run with ${r} free hero upgrade${r > 1 ? 's' : ''}` },
  { id: 'fortune', name: 'Fortune’s Favor', max: 3, cost: r => 300 + 250 * r, desc: r => `Much better upgrade odds: Rare and above ${30 * r}% more likely, Common ${15 * r}% less likely` },
];
let META = { v: 2, shards: 0, heroes: { vanguard: {}, striker: {}, oracle: {}, sniper: {} }, unlocked: {}, global: {}, best: {}, runs: [] };
try { const m = JSON.parse(localStorage.getItem('riftguard-meta') || 'null'); if (m) META = Object.assign(META, m, { v: m.v || 1 }); } catch (e) {}
function saveMeta() { try { localStorage.setItem('riftguard-meta', JSON.stringify(META)); } catch (e) {} }
// Older saves used one shared upgrade list for every hero: refund those shards so they can be spent on the new hero upgrades.
if (META.v < 2) {
  const old = { hp: r => 30 + 25 * r, dmg: r => 30 + 25 * r, cd: r => 40 + 30 * r, vet: r => 90 + 70 * r };
  for (const k of Object.keys(META.heroes)) {
    for (const [id, cost] of Object.entries(old)) for (let r = 0; r < (META.heroes[k][id] || 0); r++) META.shards += cost(r);
    META.heroes[k] = {};
  }
  META.v = 2; META.unlocked = META.unlocked || {}; saveMeta();
}
for (const k of Object.keys(HEROES)) META.heroes[k] = META.heroes[k] || {};
META.unlocked = META.unlocked || {};
const rank = (obj, id) => (obj && obj[id]) || 0;

// ---------- settings (saved in this browser) ----------
let SETTINGS = { volume: 0.6, muted: false, fullscreen: true };
try { Object.assign(SETTINGS, JSON.parse(localStorage.getItem('riftguard-settings') || '{}')); } catch (e) {}
function saveSettings() { try { localStorage.setItem('riftguard-settings', JSON.stringify(SETTINGS)); } catch (e) {} }
const desktop = window.desktop || null; // set by the desktop app's preload script
function setFullscreen(on) {
  SETTINGS.fullscreen = on; saveSettings();
  if (desktop) return desktop.setFullscreen(on);
  try { if (on && !document.fullscreenElement) document.documentElement.requestFullscreen(); else if (!on && document.fullscreenElement) document.exitFullscreen(); } catch (e) {}
}
if (desktop && !SETTINGS.fullscreen) desktop.setFullscreen(false);

// ---------- sound: tiny synthesized effects, no audio files ----------
let actx = null, master = null;
function audio() {
  if (!actx) {
    try { actx = new (window.AudioContext || window.webkitAudioContext)(); master = actx.createGain(); master.connect(actx.destination); } catch (e) { return null; }
  }
  master.gain.value = SETTINGS.muted ? 0 : SETTINGS.volume;
  if (actx.state === 'suspended') actx.resume();
  return actx;
}
const SFX = {
  shot:    { f: 900, f2: 450, d: 0.05, type: 'square', v: 0.035, gap: 0.07 },
  boom:    { noise: true, f: 500, d: 0.25, v: 0.16, gap: 0.09 },
  snipe:   { f: 1600, f2: 120, d: 0.2, type: 'sawtooth', v: 0.12 },
  kill:    { f: 520, f2: 260, d: 0.08, type: 'triangle', v: 0.07, gap: 0.04 },
  leak:    { f: 160, f2: 60, d: 0.3, type: 'sawtooth', v: 0.2, gap: 0.15 },
  wave:    { f: 300, f2: 620, d: 0.35, type: 'sawtooth', v: 0.1 },
  boss:    { f: 110, f2: 55, d: 0.9, type: 'sawtooth', v: 0.18 },
  level:   { f: 600, f2: 1300, d: 0.3, type: 'triangle', v: 0.14 },
  ability: { f: 220, f2: 900, d: 0.3, type: 'sine', v: 0.2 },
  click:   { f: 760, f2: 700, d: 0.04, type: 'sine', v: 0.06, gap: 0.03 },
};
const lastSfx = {};
function sfx(name) {
  if (SETTINGS.muted || SETTINGS.volume <= 0) return;
  const s = SFX[name], ctx = audio(); if (!s || !ctx) return;
  const now = ctx.currentTime;
  if (s.gap && lastSfx[name] && now - lastSfx[name] < s.gap) return;
  lastSfx[name] = now;
  const g = ctx.createGain(); g.gain.setValueAtTime(s.v, now); g.gain.exponentialRampToValueAtTime(0.0001, now + s.d); g.connect(master);
  if (s.noise) {
    const len = Math.floor(ctx.sampleRate * s.d), buf = ctx.createBuffer(1, len, ctx.sampleRate), data = buf.getChannelData(0);
    for (let i = 0; i < len; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / len);
    const src = ctx.createBufferSource(), lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = s.f;
    src.buffer = buf; src.connect(lp); lp.connect(g); src.start(now);
    return;
  }
  const o = ctx.createOscillator(); o.type = s.type;
  o.frequency.setValueAtTime(s.f, now); o.frequency.exponentialRampToValueAtTime(s.f2, now + s.d);
  o.connect(g); o.start(now); o.stop(now + s.d + 0.02);
}
document.addEventListener('click', e => { if (e.target.closest && e.target.closest('button')) sfx('click'); });

let codex = {};
try { codex = JSON.parse(localStorage.getItem('riftguard-codex') || '{}') || {}; } catch (e) { codex = {}; }
function saveCodex() { try { localStorage.setItem('riftguard-codex', JSON.stringify(codex)); } catch (e) {} }

let S = null;
function showScreen(html) { closeModal(); hideTip(); $('screen').innerHTML = `<div class="screen-inner">${html}</div>`; $('screen').hidden = false; $('screen').scrollTop = 0; }
function hideScreen() { $('screen').hidden = true; }
const shardsTag = () => `<span class="shards">◆ ${META.shards} Rift Shards</span>`;
function showMenu() {
  S = null; closeModal();
  showScreen(`<div class="title"><h1>Rift<span>guard</span></h1>
    <p class="lead">Hold the rift. Earn Rift Shards every run to make your heroes stronger.</p>
    <p style="margin-top:10px">${shardsTag()}</p>
    <div class="menu">
      <button class="go" id="mStart">Play</button>
      <button id="mUpgrades">Heroes</button>
      <button id="mSettings">Settings</button>
      <button id="mLog">Stats log</button>
      ${desktop ? '<button id="mQuit">Quit</button>' : ''}
    </div></div>`);
  $('mStart').onclick = showMapSelect; $('mUpgrades').onclick = () => showHeroes(); $('mLog').onclick = showLog; $('mSettings').onclick = showSettings;
  if ($('mQuit')) $('mQuit').onclick = () => desktop.quit();
}
function showMapSelect() {
  showScreen(`<div class="screen-head"><h2>Choose a map</h2>${shardsTag()}<button id="mBack">Back</button></div>
    <p class="lead">Beat a map to unlock the next one. Harder maps have more waves and pay more Rift Shards.</p>
    <div class="cards">${MAP_ORDER.map((k, i) => { const m = MAPS[k], open = mapUnlocked(k), best = META.best[k];
      return `<button class="choice mapcard map-pick ${open ? '' : 'locked'}" data-k="${k}" ${open ? '' : 'disabled'}>
      <small class="path">${m.tier} · ${m.waves} waves · ×${m.shardMul} shards</small><b>${m.name}</b><span>${m.desc}</span>
      ${open ? `<em class="reward">${best ? 'Best: wave ' + best.wave + (best.won ? ' (beaten)' : '') : 'Not played yet'}</em>`
             : `<span class="lock">Locked: beat ${MAPS[MAP_ORDER[i - 1]].name} to unlock</span>`}</button>`; }).join('')}</div>`);
  $('screen').querySelectorAll('.map-pick').forEach(b => b.onclick = () => newRun(b.dataset.k));
  $('mBack').onclick = showMenu;
}
function metaRow(def, obj, key, heroId) {
  const r = rank(obj, def.id), maxed = r >= def.max, cost = def.cost(r);
  return `<div class="meta-row"><div><b>${def.name}</b> <span class="help">${r}/${def.max}</span><br><span class="help">${r ? def.desc(r) : 'Not bought'}${maxed ? '' : ' → ' + def.desc(r + 1)}</span></div>
    <button data-meta="${key}" data-id="${def.id}" ${heroId ? `data-hero="${heroId}"` : ''} ${maxed || META.shards < cost ? 'disabled' : ''}>${maxed ? 'Maxed' : '◆ ' + cost}</button></div>`;
}
// Heroes page: every hero (locked ones too), their permanent upgrades, and the upgrades shared by all heroes.
function showHeroes(sel) {
  sel = sel || 'vanguard';
  const d = HEROES[sel], open = isUnlocked(sel), st = d.stats;
  showScreen(`<div class="screen-head"><h2>Heroes</h2>${shardsTag()}<button id="mBack">Back</button></div>
    <div class="heroes">
      <div class="roster">${Object.entries(HEROES).map(([k, h]) => `<button data-hero-tab="${k}" class="${k === sel ? 'on' : ''} ${isUnlocked(k) ? '' : 'locked'}" style="border-left-color:${h.css}">
        <small>${h.role}</small><b style="color:${h.css}">${h.name}</b>${isUnlocked(k) ? '' : `<span class="lock">Locked · ◆ ${h.unlock}</span>`}</button>`).join('')}</div>
      <div class="card herodetail">
        <h3 style="color:${d.css}">${d.name} · ${d.role}</h3>
        <p>${d.desc}</p>
        <div class="stats">
          <div><span>HP</span>${st.hp}</div><div><span>Damage</span>${st.dmg}</div>
          <div><span>Attacks/s</span>${(1 / st.rate).toFixed(2)}</div><div><span>Range</span>${st.range >= 9999 ? 'Whole map' : st.range}</div>
          <div><span>Blocks</span>${st.block}</div><div><span>Move speed</span>${st.speed}</div>
          ${st.brace ? `<div><span>Brace time</span>${st.brace}s</div>` : ''}${st.crit ? `<div><span>Crit chance</span>${pct(st.crit)}</div>` : ''}
        </div>
        <p class="help"><b style="color:var(--text)">${d.ability.name}</b> (${d.ability.cd}s): ${abilityText({ ab: d.ability })}</p>
        ${open ? `<h3 class="meta-h">${d.name} upgrades</h3>${HERO_META[sel].map(x => metaRow(x, META.heroes[sel], 'hero', sel)).join('')}`
               : `<div class="row"><button class="go" id="unlockHero" ${META.shards < d.unlock ? 'disabled' : ''}>Unlock ${d.name} · ◆ ${d.unlock}</button></div>
                  <p class="help" style="margin-top:8px">Unlock ${d.name} to play them and buy their upgrades.</p>`}
      </div>
    </div>
    <div class="card"><h3>All heroes</h3>${GLOBAL_META.map(x => metaRow(x, META.global, 'global')).join('')}</div>`);
  $('screen').querySelectorAll('[data-hero-tab]').forEach(b => b.onclick = () => showHeroes(b.dataset.heroTab));
  $('screen').querySelectorAll('[data-meta]').forEach(b => b.onclick = () => {
    const isHero = b.dataset.meta === 'hero', defs = isHero ? HERO_META[b.dataset.hero] : GLOBAL_META, def = defs.find(x => x.id === b.dataset.id);
    const obj = isHero ? META.heroes[b.dataset.hero] : META.global;
    const cost = def.cost(rank(obj, def.id));
    if (META.shards < cost || rank(obj, def.id) >= def.max) return;
    META.shards -= cost; obj[def.id] = rank(obj, def.id) + 1; saveMeta(); showHeroes(sel);
  });
  if ($('unlockHero')) $('unlockHero').onclick = () => {
    if (META.shards < d.unlock) return;
    META.shards -= d.unlock; META.unlocked[sel] = true; saveMeta(); sfx('level'); showHeroes(sel);
  };
  $('mBack').onclick = showMenu;
}
function showLog() {
  const runs = META.runs.slice().reverse();
  showScreen(`<div class="screen-head"><h2>Stats log</h2><button id="mCopy">Copy full log</button><button id="mBack">Back</button></div>
    <p class="lead">Your last ${runs.length} runs, newest first. Copy the full log to share it for balancing.</p>
    <div class="card logwrap"><table class="log"><thead><tr><th>Map</th><th>Hero</th><th>Wave</th><th>Result</th><th>Lives lost</th><th>Top damage</th><th>Shards</th></tr></thead><tbody>
    ${runs.map(r => `<tr><td>${MAPS[r.map].name}</td><td>${HEROES[r.hero] ? HEROES[r.hero].name : r.hero}</td><td>${r.wave}</td><td>${r.won ? 'Won' : 'Lost'}</td><td>${r.livesLost}</td><td>${r.top || '-'}</td><td>◆ ${r.shards}</td></tr>`).join('') || '<tr><td colspan="7">No runs yet.</td></tr>'}
    </tbody></table></div>
    <textarea id="logText" readonly hidden></textarea>`);
  $('mBack').onclick = showMenu;
  $('mCopy').onclick = () => {
    const text = JSON.stringify(META.runs, null, 1);
    const ta = $('logText'); ta.value = text;
    navigator.clipboard.writeText(text).then(() => toast('Log copied.'), () => { ta.hidden = false; ta.select(); toast('Select the text below and copy it.'); });
  };
}
// Settings: from the main menu, or mid-run with Esc / the gear button (which pauses the game).
function showSettings() {
  const inRun = !!(S && S.hero && !S.over);
  if (inRun) { if (!$('modal').hidden) return; S.paused = true; }
  openModal(`<h2>${inRun ? 'Paused' : 'Settings'}</h2>
    <div class="settings">
      <label>Volume <input type="range" id="setVol" min="0" max="1" step="0.05" value="${SETTINGS.volume}"></label>
      <label>Mute sound <input type="checkbox" id="setMute" ${SETTINGS.muted ? 'checked' : ''}></label>
      <label>Fullscreen <input type="checkbox" id="setFs" ${SETTINGS.fullscreen ? 'checked' : ''}></label>
      <label>Move the hero with WASD / arrow keys <input type="checkbox" id="setKeys" ${keyMove ? 'checked' : ''}></label>
    </div>
    <div class="row" style="margin-top:14px">
      <button class="go" id="setClose">${inRun ? 'Resume' : 'Done'}</button>
      ${inRun ? '<button id="setRestart">Restart run</button><button id="setMenu">Main menu</button>' : ''}
      ${desktop ? '<button id="setQuit">Quit game</button>' : ''}
    </div>`);
  $('setVol').oninput = e => { SETTINGS.volume = +e.target.value; saveSettings(); audio(); };
  $('setVol').onchange = () => sfx('level');
  $('setMute').onchange = e => { SETTINGS.muted = e.target.checked; saveSettings(); audio(); };
  $('setFs').onchange = e => setFullscreen(e.target.checked);
  $('setKeys').onchange = e => { if (e.target.checked !== keyMove) toggleKeys(); };
  $('setClose').onclick = closeSettings;
  if ($('setRestart')) $('setRestart').onclick = () => { const id = S.map; S.paused = false; endRun(false, true, true); newRun(id); };
  if ($('setMenu')) $('setMenu').onclick = confirmQuit;
  if ($('setQuit')) $('setQuit').onclick = () => desktop.quit();
}
function closeSettings() { closeModal(); if (S && S.hero && !S.over) S.paused = false; }
const settingsOpen = () => !$('modal').hidden && !!$('setClose');
function newRun(mapId) {
  setMap(mapId);
  const map = MAPS[mapId], G = META.global;
  S = {
    map: mapId, gold: 150 + 20 * rank(G, 'gold'), lives: 20 + 2 * rank(G, 'lives'), startLives: 20 + 2 * rank(G, 'lives'), bossKills: 0,
    log: [], ws: null, drained: null, boons: {}, pendingBoon: null, ionT: 6, wave: 0, waveActive: false, spawnQ: [], spawnT: 0, interval: 0.9,
    enemies: [], towers: [], fx: [], sel: null, build: null, mergeFrom: null, pendingBuild: null,
    paused: true, over: false, speed: 1, pendingLevels: 0, pendingHeroic: 0, hover: null, rerolls: 2 + rank(G, 'reroll'), time: 0,
    mode: { kind: 'normal', name: 'Normal' }, relics: [], picks: [], heroics: {}, overclockT: 0, timeStopT: 25,
    mod: { towerDmg: 1, slow: 0, gold: map.gold || 1, towerRate: 1, enemyHp: map.enemyHp || 1, enemySpeed: 1, phoenix: false },
    hero: null,
  };
  MAX_WAVE = map.waves;
  $('sMap').textContent = map.name;
  showHeroSelect();
}
function makeHero(id) {
  const d = HEROES[id], s = d.stats;
  return {
    cls: id, x: BASE.x - 80, y: BASE.y > 120 ? BASE.y - 60 : BASE.y + 60, tx: null, ty: null, hp: s.hp, maxHp: s.hp, dmg: s.dmg, rate: s.rate, cd: 0,
    range: s.range, block: s.block, regen: s.regen, armor: s.armor, speed: s.speed, ko: 0, lvl: 1, xp: 0, next: 30,
    buildRange: 170, respawn: 8, thorns: 0, aura: s.aura || 0, auraRange: 130, auraSlow: 0, siphon: 0,
    costMul: 1, lvlMul: 1, mergeMul: 1, crit: s.crit || 0, critDmg: 2, multi: 0, bounty: 0, towerRange: 0, interest: 0,
    brace: s.brace || 0, braceT: 0, pierce: 0, deadeye: 0, shotStun: 0,
    execute: 0, bulletStorm: 0, attacks: 0, unbreakable: false, unbreakUsed: false, timeWarp: 0, autoCast: false,
    ab: Object.assign({ t: 0 }, d.ability),
    boonSlow: 0, boonSplash: 0, boonRail: 0, boonVent: 0, boonChain: 0, boonIon: 0,
  };
}
function applyHeroMeta(h) {
  const M = META.heroes[h.cls] || {};
  for (const def of HERO_META[h.cls]) if (rank(M, def.id)) def.apply(h, rank(M, def.id));
  h.hp = h.maxHp;
  S.pendingLevels += rank(META.global, 'vet');
}
function showHeroSelect() {
  showScreen(`<div class="screen-head"><h2>Choose your hero</h2><button id="mBack">Back</button></div>
    <p class="lead">${MAPS[S.map].name} · ${MAX_WAVE} waves. Each hero has their own ability and upgrades, plus shared ones.</p>
    <div class="cards">${Object.entries(HEROES).map(([k, d]) => { const open = isUnlocked(k);
      return `<button class="choice mapcard hero-pick ${open ? '' : 'locked'}" data-k="${k}" style="border-color:${d.css}" ${open ? '' : 'disabled'}>
      <small class="path" style="color:${d.css}">${d.role}</small><b style="color:${d.css}">${d.name}</b><span>${d.desc}</span>
      <span>HP ${d.stats.hp} · Damage ${d.stats.dmg} · ${d.stats.range >= 9999 ? 'Whole-map range' : 'Blocks ' + d.stats.block}</span>
      ${open ? `<em class="reward">Ability: ${d.ability.name}</em>` : `<span class="lock">Locked: unlock on the Heroes page for ◆ ${d.unlock}</span>`}</button>`; }).join('')}</div>`);
  $('screen').querySelectorAll('.hero-pick').forEach(b => b.onclick = () => {
    S.hero = makeHero(b.dataset.k); applyHeroMeta(S.hero); S.paused = false; hideScreen();
    renderBuildBar(); renderInspector(); renderCodex(); renderHero();
    toast(HEROES[b.dataset.k].name + ' ready. Build towers, then start the wave.');
  });
  $('mBack').onclick = () => { S = null; showMapSelect(); };
}

const $ = id => document.getElementById(id);
let toastT = 0;
function toast(msg) { $('toast').textContent = msg; $('toast').hidden = false; toastT = 3; }

function countType(type) { return S.towers.filter(t => t.type === type || (t.parents && t.parents.includes(type))).length; }
function towerCost(type) { return Math.round(TOWERS[type].cost * (1 + 0.3 * countType(type)) * S.hero.costMul); }
function levelCost(t) { return Math.round(t.baseCost * 0.5 * t.lvl * S.hero.lvlMul); }
function mergeCost(t) { return Math.round(MERGE_COST * (t && t.hybrid ? SUPER_MERGE_MUL : 1) * S.hero.mergeMul); }
function tRange(t) { return t.range * (1 + S.hero.towerRange); }
function towerName(t) { return t.super ? t.name : t.hybrid ? RECIPES[t.type].name : TOWERS[t.type].name; }
function towerBlurb(t) { return t.super ? t.desc : t.hybrid ? RECIPES[t.type].desc : TOWERS[t.type].info; }
function towerKind(t) { return t.super ? 'Super ' : t.hybrid ? 'Hybrid ' : ''; }
function baseTypes(t) { return t.parents || [t.type]; }
function traits(t) {
  const out = ['Shoots the enemy closest to your base' + (t.multi ? `, plus ${t.multi} more at once.` : '.')];
  if (t.splash) out.push('Explodes on hit, damaging all enemies within ' + t.splash.toFixed(0) + '.');
  if (t.slow) out.push('Slows enemies by ' + Math.round(Math.min(0.85, t.slow + S.mod.slow) * 100) + '% for ' + (t.slowDur || 1.6).toFixed(1) + 's.');
  if (t.chain) out.push('Lightning jumps to ' + t.chain + ' more enemies at ' + pct(t.chainMul || 0.7) + ' damage, less each jump.');
  if (t.burn) out.push('Burns enemies for ' + pct(t.burn) + ' of hit damage over 2s.');
  if (t.ramp) out.push('Gains +' + pct(t.ramp) + ' damage per hit in a row on the same enemy (5 stacks).');
  if (t.surge) out.push('Every ' + t.surge + 'th shot deals triple damage.');
  if (t.brittle) out.push('Slowed enemies take +' + pct(t.brittle) + ' damage from everything.');
  if (t.mark) out.push('Marks enemies to take +' + pct(t.mark) + ' damage for 2s.');
  if (t.cluster) out.push('Throws ' + t.cluster + ' bomblets per shot.');
  if (t.orbital) out.push('Every ' + t.orbital + 'th shot is a huge triple-damage blast.');
  if (t.freeze) out.push('Every ' + t.freeze + 'th shot freezes enemies for 1.2s.');
  if (t.zero) out.push('Constantly slows every enemy in range by ' + pct(t.zero) + '.');
  if (t.stun) out.push('Lightning jumps have a ' + pct(t.stun) + ' chance to stun.');
  return out;
}

// ---------- waves ----------
function waveReward(n, kind) {
  if (kind === 'normal') return null;
  if (kind === 'legendary' || kind === 'secret') {
    const owned = new Set(S.relics.map(r => r.id));
    const pool = (kind === 'secret' ? SECRET_RELICS : LEGENDARY_RELICS).filter(r => r.repeat || !owned.has(r.id));
    const relic = pool.length ? pick(pool) : RELICS[5];
    const gold = (kind === 'secret' ? 250 : 150) + 15 * n;
    return { gold, relic, label: `${RAR[kind].name} relic: ${relic.name} (${relic.desc.replace(/\.$/, '')}) and +${gold} gold` };
  }
  const gold = (kind === 'hard' ? 60 : 90) + 10 * n;
  if (kind === 'hard') return { gold, perk: true, label: `+${gold} gold and a free hero upgrade` };
  const owned = new Set(S.relics.map(r => r.id));
  const relic = pick(RELICS.filter(r => r.repeat || !owned.has(r.id)));
  return { gold, relic, label: `${relic.name} relic (${relic.desc.replace(/\.$/, '')}) and +${gold} gold` };
}
function offerWaveChoice() {
  const n = S.wave + 1, ch = pick(CHALLENGES);
  const opts = [
    { kind: 'normal', name: 'Normal', rule: 'A standard wave.', reward: null },
    { kind: 'hard', name: 'Hard', rule: 'Enemies have 40% more HP and there are 25% more of them.', reward: waveReward(n, 'hard') },
    { kind: 'challenge', name: 'Challenge: ' + ch.name, challenge: ch.id, rule: ch.rule, reward: waveReward(n, 'challenge') },
  ];
  const roll = Math.random();
  if (roll < 0.03) opts[2] = { kind: 'secret', rarity: 'secret', name: 'Secret: Gilded Breach', gilded: true, hpMul: 2,
    rule: 'Golden enemies with double HP. Every kill drops triple gold.', reward: waveReward(n, 'secret') };
  else if (roll < 0.13) opts[2] = { kind: 'legendary', rarity: 'legendary', name: 'Legendary: ' + ch.name, challenge: ch.id, hpMul: 1.3,
    rule: ch.rule + ' Enemies also have 30% more HP.', reward: waveReward(n, 'legendary') };
  S.paused = true;
  const boss = !!bossFor(n);
  openModal(`<h2>Choose wave ${n}</h2><p>${boss ? 'A boss leads this wave. ' : ''}Harder waves pay out when you clear them.</p>
    <div class="choices">${opts.map((o, i) => `<button class="choice mode-${o.kind} ${o.rarity ? 'rarity-' + o.rarity : ''}" data-i="${i}">
      <b>${o.name}</b><span>${o.rule}</span>
      <em class="reward">${o.reward ? 'Reward: ' + o.reward.label : 'Reward: the usual wave bonus'}</em></button>`).join('')}</div>`);
  $('modalBox').querySelectorAll('.choice').forEach(b => b.onclick = () => {
    S.mode = opts[+b.dataset.i]; closeModal(); S.paused = false; renderBuildBar();
    toast(S.mode.name + ' chosen. Build up, then start the wave.');
  });
}
function makeWave(n, mode) {
  let q = [];
  for (let i = 0; i < 6 + n * 3; i++) q.push('grunt');
  if (n >= 2) for (let i = 0; i < n * 2; i++) q.push('runner');
  if (n >= 4) for (let i = 0; i < n - 2; i++) q.push('brute');
  if (mode.kind === 'hard') q = q.concat(q.slice(0, Math.round(q.length * 0.25)));
  if (mode.challenge === 'swarm') q = q.concat(q);
  if (mode.challenge === 'iron') q = q.slice(0, Math.max(4, Math.round(q.length / 3))).map(() => 'brute');
  shuffle(q);
  const boss = bossFor(n);
  if (boss) q.push(boss);
  return q;
}
function bossFor(n) { return n === MAX_WAVE ? 'tyrant' : n % 10 === 0 ? 'warden' : n % 5 === 0 ? 'knight' : null; }
function startWave() {
  if (S.waveActive || S.over || S.paused) return;
  S.wave++; S.spawnQ = makeWave(S.wave, S.mode); S.spawnT = 0.3;
  S.interval = Math.max(0.3, 0.9 - S.wave * 0.04) * (S.mode.challenge === 'swarm' ? 0.6 : 1);
  S.waveActive = true; S.hero.unbreakUsed = false;
  S.ws = { wave: S.wave, mode: S.mode.name, livesLost: 0, kills: 0, gold: 0, heroDmg: 0, heroKOs: 0, start: S.time, enemies: S.spawnQ.length };
  const boss = { knight: 'A Rift Knight leads this wave.', warden: 'The Rift Warden approaches.', tyrant: 'Final wave. The Rift Tyrant is coming.' }[bossFor(S.wave)];
  toast(boss || 'Wave ' + S.wave + ' incoming.'); sfx(boss ? 'boss' : 'wave');
  renderBuildBar();
}
function closeWaveLog(cleared) {
  if (!S.ws) return;
  const towers = S.towers.map(t => ({ name: towerName(t) + ' L' + t.lvl, dmg: Math.round(t.dmgWave || 0) })).sort((a, b) => b.dmg - a.dmg);
  S.log.push(Object.assign(S.ws, { cleared, seconds: Math.round(S.time - S.ws.start), heroDmg: Math.round(S.ws.heroDmg), gold: Math.round(S.ws.gold),
    goldBank: Math.floor(S.gold), heroLvl: S.hero.lvl, towerCount: S.towers.length, towers }));
  S.ws = null;
}
function endWave() {
  S.waveActive = false;
  if (MAPS[S.map].drain && S.towers.length) {
    const top = S.towers.reduce((a, b) => (b.dmgWave || 0) > (a.dmgWave || 0) ? b : a);
    S.drained = top.dmgWave ? top : null;
  }
  closeWaveLog(true);
  for (const t of S.towers) t.dmgWave = 0;
  const bonus = 25 + 5 * S.wave; S.gold += bonus;
  const msgs = ['+' + bonus + ' gold'];
  if (S.hero.interest) { const i = Math.round(S.gold * Math.min(0.3, S.hero.interest)); S.gold += i; msgs.push('+' + i + ' interest'); }
  const r = S.mode.reward;
  if (r) {
    S.gold += r.gold; msgs.push('+' + r.gold + ' reward gold');
    if (r.perk) { S.pendingLevels++; msgs.push('a free hero upgrade'); }
    if (r.relic) { r.relic.apply(); if (!r.relic.repeat) S.relics.push(r.relic); msgs.push(r.relic.name); }
  }
  if (S.wave >= MAX_WAVE) return endRun(true);
  toast('Wave ' + S.wave + ' cleared: ' + msgs.join(', ') + '.' + (S.drained ? ' ' + towerName(S.drained) + ' is drained next wave.' : ''));
  S.mode = { kind: 'normal', name: 'Normal' };
  renderBuildBar(); renderHero();
  if (S.wave >= CHOICE_FROM) S.needChoice = true;
}
function spawn(type) {
  const d = ENEMIES[type], m = S.mode;
  // Harder curve than before; bosses also scale with the wave they lead.
  let scale = d.boss ? 1 + 0.18 * Math.max(0, S.wave - 5) : 1 + 0.45 * (S.wave - 1) + 0.07 * (S.wave - 1) ** 2;
  scale *= S.mod.enemyHp;
  if (m.kind === 'hard') scale *= 1.4;
  if (m.hpMul) scale *= m.hpMul;
  if (m.challenge === 'swarm') scale *= 0.65;
  const speed = d.speed * S.mod.enemySpeed * (m.challenge === 'blitz' ? 1.4 : 1);
  const p = posAt(0);
  S.enemies.push({ type, boss: !!d.boss, hp: d.hp * scale, max: d.hp * scale, speed, d: 0, x: p.x - 30, y: p.y,
    slow: 0, slowT: 0, stunT: 0, burnT: 0, burnDps: 0, markT: 0, mark: 0, brittle: 0,
    gold: d.gold * (m.gilded ? 3 : 1), lives: d.lives, atk: d.atk, r: d.r, color: m.gilded ? 0xf2c14e : d.color, blocked: false, dead: false });
}

// ---------- combat ----------
function damage(e, amt, src) {
  if (e.dead) return;
  amt *= 1 + (e.markT > 0 ? e.mark : 0) + (e.slowT > 0 ? e.brittle : 0);
  const dealt = Math.min(amt, e.hp);
  if (src && typeof src === 'object') { src.dmgWave = (src.dmgWave || 0) + dealt; src.dmgTotal = (src.dmgTotal || 0) + dealt; }
  else if (S.ws) S.ws.heroDmg += dealt;
  e.hp -= amt;
  if (e.hp <= 0) {
    e.dead = true;
    const h = S.hero;
    let g = e.gold * S.mod.gold + h.bounty;
    if (S.heroics.goldrush && Math.random() < 0.08 * S.heroics.goldrush) { g += 15; S.fx.push({ k: 'ring', x: e.x, y: e.y, r: 14, color: 0xf2c14e, t: 0.5, T: 0.5, fill: true }); }
    S.gold += g; h.xp += e.gold;
    if (S.ws) { S.ws.kills++; S.ws.gold += g; }
    if (e.boss) S.bossKills++;
    if (h.siphon && !h.ko) h.hp = Math.min(h.maxHp, h.hp + h.siphon);
    while (h.xp >= h.next) { h.xp -= h.next; h.lvl++; h.next = Math.round(h.next * 1.3); S.pendingLevels++; }
    sfx('kill');
    if (e.boss && e.type !== 'tyrant') { S.pendingHeroic++; toast(ENEMIES[e.type].name + ' defeated! It dropped a heroic power.'); }
    S.fx.push({ k: 'ring', x: e.x, y: e.y, r: e.r + 6, color: e.color, t: 0.3, T: 0.3 });
  }
}
function slowEnemy(e, amt, dur) { e.slow = Math.min(0.85, Math.max(e.slow, amt + S.mod.slow)); e.slowT = Math.max(e.slowT, dur || 1.6); }
function inRange(x, y, r) { return S.enemies.filter(e => !e.dead && Math.hypot(e.x - x, e.y - y) <= r); }
function nearAura(t) { const h = S.hero; return !h.ko && Math.hypot(h.x - t.x, h.y - t.y) <= h.auraRange; }

function applyHit(t, e, dmg, freeze) {
  damage(e, dmg, t.src);
  if (t.slow) slowEnemy(e, t.slow, t.slowDur);
  if (t.brittle) e.brittle = Math.max(e.brittle, t.brittle);
  if (t.mark) { e.mark = Math.max(e.mark, t.mark); e.markT = 2; }
  if (t.burn) { e.burnDps = Math.max(e.burnDps, dmg * t.burn / 2); e.burnT = 2; e.burnSrc = t.src; }
  if (freeze) e.stunT = Math.max(e.stunT, 1.2);
  if (t.auraSlow) slowEnemy(e, t.auraSlow, 1);
}
function fire(t, targets) {
  const h = S.hero;
  t.shots++;
  let dmg = t.dmg * S.mod.towerDmg * (S.mode.challenge === 'lone' ? 0.6 : 1);
  const aura = h.aura && nearAura(t);
  if (aura) dmg *= 1 + h.aura;
  if (t.surge && t.shots % t.surge === 0) dmg *= 3;
  const big = t.orbital && t.shots % t.orbital === 0;
  const freeze = t.freeze && t.shots % t.freeze === 0;
  if (t === S.drained) dmg *= 0.5;
  sfx(t.splash ? 'boom' : 'shot');
  const hitT = Object.assign({}, t, { auraSlow: aura ? h.auraSlow : 0, src: t });
  for (const target of targets) {
    let d = dmg;
    if (t.ramp) { if (t.lastTarget === target) t.stacks = Math.min(5, t.stacks + 1); else { t.stacks = 0; t.lastTarget = target; } d *= 1 + t.ramp * t.stacks; }
    const splash = t.splash * (big ? 2 : 1); if (big) d *= 3;
    S.fx.push({ k: 'line', x1: t.x, y1: t.y, x2: target.x, y2: target.y, color: t.color, t: 0.12, T: 0.12, w: t.hybrid ? 3 : 2 });
    const hits = splash ? inRange(target.x, target.y, splash) : [target];
    if (splash) S.fx.push({ k: 'ring', x: target.x, y: target.y, r: splash, color: t.color, t: 0.25, T: 0.25, fill: big });
    for (const e of hits) applyHit(hitT, e, d, freeze);
    if (t.cluster) {
      const near = shuffle(inRange(target.x, target.y, 90).filter(e => e !== target)).slice(0, t.cluster);
      for (const n of near) {
        S.fx.push({ k: 'ring', x: n.x, y: n.y, r: (t.splash || 30) * 0.6, color: t.color, t: 0.2, T: 0.2 });
        for (const e of inRange(n.x, n.y, (t.splash || 30) * 0.6)) applyHit(hitT, e, d * 0.5, false);
      }
    }
    if (t.chain) {
      const hit = new Set(hits); let from = target, cd = d * t.chainMul;
      for (let i = 0; i < t.chain; i++) {
        let best = null, bd = t.chainReach;
        for (const e of S.enemies) { if (e.dead || hit.has(e)) continue; const dd = Math.hypot(e.x - from.x, e.y - from.y); if (dd < bd) { bd = dd; best = e; } }
        if (!best) break;
        S.fx.push({ k: 'line', x1: from.x, y1: from.y, x2: best.x, y2: best.y, color: t.color, t: 0.15, T: 0.15, w: 1.5 });
        applyHit(hitT, best, cd, false);
        if (t.stun && Math.random() < t.stun) best.stunT = Math.max(best.stunT, 0.6);
        hit.add(best); from = best; cd *= 0.85;
      }
    }
  }
}
function heroDmg() { return S.hero.dmg * (S.mode.challenge === 'lone' ? 2 : 1); }

function useAbility() {
  const h = S.hero, a = h.ab;
  if (!h || h.ko > 0 || a.t > 0 || S.over || S.paused) return;
  if (a.id === 'pierce') {
    // A round through every enemy on the line from the hero toward the lead enemy.
    const lead = S.enemies.filter(e => !e.dead).sort((x, y) => (y.boss - x.boss) || (y.d - x.d))[0];
    if (!lead) return toast('No target for Piercing Shot.');
    const dx = lead.x - h.x, dy = lead.y - h.y, len = Math.hypot(dx, dy) || 1, ux = dx / len, uy = dy / len;
    for (const e of S.enemies.filter(e => !e.dead)) {
      const along = (e.x - h.x) * ux + (e.y - h.y) * uy, off = Math.abs((e.x - h.x) * uy - (e.y - h.y) * ux);
      if (along > 0 && off <= a.w + e.r) damage(e, heroDmg() * a.mult);
    }
    S.fx.push({ k: 'line', x1: h.x, y1: h.y, x2: h.x + ux * 2000, y2: h.y + uy * 2000, color: 0xffd36e, t: 0.35, T: 0.35, w: 4 });
    a.t = a.cd; sfx('snipe'); return;
  }
  a.t = a.cd; sfx('ability');
  if (a.id === 'slam') {
    for (const e of inRange(h.x, h.y, a.r)) { damage(e, a.dmg); e.stunT = Math.max(e.stunT, a.stun); }
    S.fx.push({ k: 'ring', x: h.x, y: h.y, r: a.r, color: 0x5fe39a, t: 0.4, T: 0.4, fill: true });
  } else if (a.id === 'nova') {
    for (const e of inRange(h.x, h.y, a.r)) damage(e, a.dmg);
    S.fx.push({ k: 'ring', x: h.x, y: h.y, r: a.r, color: 0xb07cff, t: 0.4, T: 0.4, fill: true });
  } else {
    S.overclockT = a.dur; S.overclockAt = { x: h.x, y: h.y };
    S.fx.push({ k: 'ring', x: h.x, y: h.y, r: a.r, color: 0xb07cff, t: 0.6, T: 0.6, fill: true });
  }
}
function overclocked(t) { return S.overclockT > 0 && Math.hypot(S.overclockAt.x - t.x, S.overclockAt.y - t.y) <= S.hero.ab.r; }

function knockOut(h) {
  if (h.unbreakable && !h.unbreakUsed) { h.unbreakUsed = true; h.hp = h.maxHp; toast('Unbreakable! Back to full HP.'); return; }
  h.hp = 0; h.ko = h.respawn; h.tx = null; S.pendingBuild = null; if (S.ws) S.ws.heroKOs++;
  if (S.heroics.phoenix) {
    h.ko = 2;
    for (const e of inRange(h.x, h.y, 150)) damage(e, 150 * S.heroics.phoenix);
    S.fx.push({ k: 'ring', x: h.x, y: h.y, r: 150, color: 0xff8a3d, t: 0.6, T: 0.6, fill: true });
  }
  toast('Hero knocked out. Back in ' + Math.ceil(h.ko) + 's.');
}

function update(dt) {
  if (toastT > 0) { toastT -= dt; if (toastT <= 0) $('toast').hidden = true; }
  if (!S || S.paused || S.over || !S.hero) return;
  if (S.pendingBoon) return showBoon();
  if (S.pendingHeroic > 0) return showHeroic();
  if (S.pendingLevels > 0) return showLevelUp();
  if (S.needChoice) { S.needChoice = false; return offerWaveChoice(); }
  dt *= S.speed;
  S.time += dt;
  const h = S.hero, HX = S.heroics;

  if (S.waveActive) {
    S.spawnT -= dt;
    if (S.spawnT <= 0 && S.spawnQ.length) { spawn(S.spawnQ.shift()); S.spawnT = S.interval; }
    if (!S.spawnQ.length && !S.enemies.length) return endWave();
  }
  if (S.overclockT > 0) S.overclockT -= dt;
  if (HX.timestop && S.waveActive) {
    S.timeStopT -= dt;
    if (S.timeStopT <= 0) { S.timeStopT = 25; for (const e of S.enemies) e.stunT = Math.max(e.stunT, 1 + HX.timestop); toast('Time Stop!'); }
  }

  if (h.ko > 0) {
    h.ko -= dt;
    if (h.ko <= 0) { h.ko = 0; h.hp = h.maxHp; h.x = BASE.x - 40; h.y = BASE.y; h.tx = null; toast('Your hero is back.'); }
  } else {
    const kx = (held.has('d') || held.has('arrowright') ? 1 : 0) - (held.has('a') || held.has('arrowleft') ? 1 : 0);
    const ky = (held.has('s') || held.has('arrowdown') ? 1 : 0) - (held.has('w') || held.has('arrowup') ? 1 : 0);
    if (keyMove && (kx || ky)) {
      const n = Math.hypot(kx, ky), step = h.speed * dt;
      h.x = Math.max(10, Math.min(W - 10, h.x + kx / n * step)); h.y = Math.max(10, Math.min(H - 10, h.y + ky / n * step));
      h.tx = null; S.pendingBuild = null;
    } else if (h.tx !== null) {
      const dx = h.tx - h.x, dy = h.ty - h.y, dist = Math.hypot(dx, dy), step = h.speed * dt;
      if (dist <= step) { h.x = h.tx; h.y = h.ty; h.tx = null; } else { h.x += dx / dist * step; h.y += dy / dist * step; }
    }
    const pb = S.pendingBuild;
    if (pb && Math.hypot(pb.c * C + C / 2 - h.x, pb.r * C + C / 2 - h.y) <= h.buildRange) {
      S.pendingBuild = null; h.tx = null;
      const why = buildProblem(pb.c, pb.r, pb.type);
      if (why) toast(why); else placeTower(pb.c, pb.r, pb.type);
    }
    // No healing between waves, so waiting it out isn't free.
    if (S.waveActive) h.hp = Math.min(h.maxHp, h.hp + h.regen * dt);
    h.cd -= dt;
    // Sniper: has to stand still for h.brace seconds before it can shoot.
    if (h.brace) h.braceT = h.x === h.px && h.y === h.py ? Math.min(h.brace, h.braceT + dt) : 0;
    h.px = h.x; h.py = h.y;
    if (h.cd <= 0 && (!h.brace || h.braceT >= h.brace)) {
      const inR = inRange(h.x, h.y, h.range).sort((a, b) => (h.brace ? b.boss - a.boss : 0) || b.d - a.d);
      if (inR.length) {
        h.cd = h.rate; h.attacks++; sfx(h.brace ? 'snipe' : 'shot');
        const ts = h.bulletStorm && h.attacks % h.bulletStorm === 0 ? inR : inR.slice(0, 1 + h.multi);
        for (const t of ts) {
          const crit = Math.random() < h.crit || (h.deadeye && h.attacks % h.deadeye === 0);
          let dmg = heroDmg() * (crit ? h.critDmg : 1);
          if (h.boonRail && h.attacks % h.boonRail === 0) dmg *= 4;
          if (h.execute && !t.boss && (t.hp - dmg) / t.max <= h.execute) dmg = t.hp;
          damage(t, dmg);
          if (h.shotStun) t.stunT = Math.max(t.stunT, t.boss ? 0.2 : h.shotStun);
          if (h.pierce) for (const o of inRange(t.x, t.y, 60).filter(e => e !== t).slice(0, h.pierce)) damage(o, dmg * 0.5);
          if (h.boonSlow) slowEnemy(t, h.boonSlow, 1.2);
          if (h.boonSplash) { for (const o of inRange(t.x, t.y, 45)) if (o !== t) damage(o, dmg * h.boonSplash); S.fx.push({ k: 'ring', x: t.x, y: t.y, r: 45, color: 0xff6fd8, t: 0.2, T: 0.2 }); }
          if (h.boonChain) for (const o of inRange(t.x, t.y, 100).filter(e => e !== t).slice(0, h.boonChain)) { damage(o, dmg * 0.5); slowEnemy(o, 0.3, 1.2); S.fx.push({ k: 'line', x1: t.x, y1: t.y, x2: o.x, y2: o.y, color: 0x9af0ff, t: 0.12, T: 0.12, w: 1 }); }
          S.fx.push({ k: 'line', x1: h.x, y1: h.y, x2: t.x, y2: t.y, color: crit ? 0xffffff : 0xf2c14e, t: 0.1, T: 0.1, w: crit ? 3 : 2 });
          if (HX.chainstrike) {
            const others = inRange(t.x, t.y, 100).filter(e => e !== t).slice(0, 1 + HX.chainstrike);
            for (const o of others) { damage(o, dmg * 0.6); S.fx.push({ k: 'line', x1: t.x, y1: t.y, x2: o.x, y2: o.y, color: 0xf2c14e, t: 0.12, T: 0.12, w: 1 }); }
          }
        }
      }
    }
    if (HX.blades) {
      for (let i = 0; i < HX.blades + 1; i++) {
        const ang = S.time * 3 + i * Math.PI * 2 / (HX.blades + 1), bx = h.x + Math.cos(ang) * 42, by = h.y + Math.sin(ang) * 42;
        for (const e of inRange(bx, by, 14)) damage(e, 20 * HX.blades * dt);
      }
    }
    if (h.boonVent) for (const e of inRange(h.x, h.y, 80)) { damage(e, h.boonVent * dt); slowEnemy(e, 0.15, 0.3); }
    if (h.boonIon && S.enemies.length) {
      S.ionT -= dt;
      if (S.ionT <= 0) { S.ionT = h.boonIon; for (const e of shuffle(S.enemies.slice()).slice(0, 4)) { damage(e, 60 + 2 * heroDmg()); S.fx.push({ k: 'line', x1: e.x, y1: 0, x2: e.x, y2: e.y, color: 0xffd36e, t: 0.2, T: 0.2, w: 3 }); } }
    }
    if (HX.wither) for (const e of inRange(h.x, h.y, 90 + 20 * HX.wither)) { damage(e, 10 * HX.wither * dt); slowEnemy(e, 0.2, 0.3); }
    if (HX.drone) {
      S.droneCd = (S.droneCd || 0) - dt;
      if (S.droneCd <= 0) {
        const ts = inRange(h.x, h.y, 150).sort((a, b) => b.d - a.d).slice(0, HX.drone);
        if (ts.length) {
          S.droneCd = 0.6;
          ts.forEach((t, i) => { const dx = h.x + (i ? -22 : 22), dy = h.y - 22; damage(t, 10 + 8 * HX.drone); S.fx.push({ k: 'line', x1: dx, y1: dy, x2: t.x, y2: t.y, color: 0x5fe39a, t: 0.1, T: 0.1, w: 1.5 }); });
        }
      }
    }
  }
  if (h.ab.t > 0 && S.waveActive) h.ab.t = Math.max(0, h.ab.t - dt);
  else if (h.autoCast && !h.ko && S.enemies.length && (h.ab.id === 'overclock' || inRange(h.x, h.y, h.ab.r).length)) useAbility();

  let blocking = 0;
  const order = S.enemies.slice().sort((a, b) => b.d - a.d);
  for (const e of order) {
    e.blocked = false;
    if (!h.ko && blocking < h.block && Math.hypot(e.x - h.x, e.y - h.y) <= e.r + 14) { e.blocked = true; blocking++; }
  }
  for (const e of S.enemies) {
    if (e.dead) continue;
    if (e.slowT > 0) { e.slowT -= dt; if (e.slowT <= 0) { e.slow = 0; e.brittle = 0; } }
    if (e.markT > 0) e.markT -= dt;
    if (e.burnT > 0) { e.burnT -= dt; damage(e, e.burnDps * dt, e.burnSrc); if (e.dead) continue; }
    if (S.overclockT > 0 && h.timeWarp && Math.hypot(e.x - S.overclockAt.x, e.y - S.overclockAt.y) <= h.ab.r) slowEnemy(e, h.timeWarp, 0.3);
    if (e.stunT > 0) { e.stunT -= dt; }
    else if (e.blocked) {
      h.hp -= e.atk * (1 - h.armor) * dt;
      if (h.thorns) damage(e, h.thorns * dt);
    } else {
      e.d += e.speed * (1 - e.slow) * dt;
      if (e.d >= PATH_LEN) {
        e.dead = true; S.lives -= e.lives; if (S.ws) S.ws.livesLost += e.lives; sfx('leak');
        S.fx.push({ k: 'ring', x: BASE.x, y: BASE.y, r: 30, color: 0xff5d6c, t: 0.4, T: 0.4 });
        if (S.lives <= 0 && S.mod.phoenix) { S.mod.phoenix = false; S.lives = 10; toast('Phoenix Core saved your base!'); }
        if (S.lives <= 0) { S.lives = 0; return endRun(false); }
        continue;
      }
    }
    if (!e.dead) { const p = posAt(e.d); e.x = p.x; e.y = p.y; }
  }
  if (!h.ko && h.hp <= 0) knockOut(h);

  for (const t of S.towers) {
    if (t.zero) for (const e of inRange(t.x, t.y, tRange(t))) slowEnemy(e, t.zero, 0.2);
    t.cd -= dt * (overclocked(t) ? 1 + h.ab.power : 1);
    if (t.cd > 0) continue;
    const targets = inRange(t.x, t.y, tRange(t)).sort((a, b) => b.d - a.d).slice(0, 1 + t.multi);
    if (targets.length) { t.cd = t.rate * S.mod.towerRate; fire(t, targets); }
  }
  S.enemies = S.enemies.filter(e => !e.dead);
  for (const f of S.fx) f.t -= dt;
  S.fx = S.fx.filter(f => f.t > 0);
}

// ---------- hero upgrade offers ----------
function owns(id) { return S.picks.some(p => p.perk.id === id); }
function makeOffer(perk, rarity, demonic) {
  const o = { perk, rarity, demonic: false };
  if (perk.rarity) return o; // uniques have fixed effects and are never Demonic
  o.m = perk.m * rarity.mult * (demonic ? 2 : 1);
  if (demonic) { o.demonic = true; o.curse = pick(CURSES); o.k = rarity.mult; }
  return o;
}
// Two slots from your hero's own pool, one shared slot. Upgrades you already own show up more often.
function rollPerks() {
  const h = S.hero, out = [];
  const weighted = list => { const bag = []; for (const p of list) { bag.push(p); if (owns(p.id)) bag.push(p, p); } return bag; };
  const slots = shuffle([h.cls, h.cls, Math.random() < 0.3 ? h.cls : 'any']);
  for (const cls of slots) {
    const rarity = rollRarity(), demonic = Math.random() < DEMONIC_CHANCE;
    const taken = new Set(out.map(o => o.perk.id));
    let perk = null, rar = rarity;
    if (rarity.id === 'secret') perk = pick(UNIQUES.filter(u => u.rarity === 'secret' && !owns(u.id) && !taken.has(u.id))) || null;
    if (!perk && (rarity.id === 'legendary' || rarity.id === 'secret') && Math.random() < 0.5) {
      perk = pick(UNIQUES.filter(u => u.rarity === 'legendary' && u.cls === h.cls && !owns(u.id) && !taken.has(u.id))) || null;
      if (perk) rar = RAR.legendary;
    }
    if (!perk) perk = pick(weighted(PERKS.filter(p => (p.cls === cls || (p.also && p.also.includes(cls))) && !taken.has(p.id))));
    out.push(makeOffer(perk, rar, demonic));
  }
  return out;
}
function offerHtml(o, i) {
  const p = o.perk, r = o.rarity;
  const desc = p.rarity ? p.desc : p.desc(o.m);
  const label = (o.demonic ? 'Demonic ' : '') + r.name + ' · ' + (p.cls === 'any' ? 'Shared' : HEROES[S.hero.cls].name);
  return `<button class="choice rarity-${r.id} ${o.demonic ? 'is-demonic' : ''}" data-i="${i}"><small class="path rar-${r.id}">${label}</small>
    <b>${p.name}</b><span>${desc}</span>${o.demonic ? `<em class="cost">Curse: ${o.curse.desc(o.k)}</em>` : ''}
    ${owns(p.id) ? `<em class="reward">Owned ×${S.picks.filter(x => x.perk.id === p.id).length}</em>` : ''}</button>`;
}
function showLevelUp(offers) {
  S.paused = true; if (!offers) sfx('level');
  offers = offers || rollPerks();
  const h = S.hero;
  openModal(`<h2>Hero upgrade</h2><p>Level ${h.lvl}. Choose one. Rarer upgrades are stronger. Demonic ones are twice as strong but carry a curse.</p>
    <div class="choices">${offers.map(offerHtml).join('')}</div>
    <div class="row" style="margin-top:12px"><button id="reroll" ${S.rerolls ? '' : 'disabled'}>Reroll offers (${S.rerolls} left)</button></div>`);
  $('modalBox').querySelectorAll('.choice').forEach(b => b.onclick = () => {
    const o = offers[+b.dataset.i];
    if (o.perk.rarity) o.perk.apply(h); else o.perk.apply(h, o.m);
    if (o.demonic) o.curse.apply(o.k);
    S.picks.push(o);
    if (o.rarity.id !== 'common' || o.demonic) toast((o.demonic ? 'Demonic ' : '') + o.rarity.name + ' upgrade: ' + o.perk.name + '!');
    S.pendingLevels--; closeModal(); S.paused = false; renderBuildBar(); renderHero();
  });
  $('reroll').onclick = () => { if (S.rerolls > 0) { S.rerolls--; showLevelUp(); } };
}
function showBoon() {
  S.paused = true;
  const key = S.pendingBoon, b = BOONS[key];
  openModal(`<h2>Resonance</h2><p>Your new ${RECIPES[key].name} resonates with your hero and awakens a power.</p>
    <div class="choices"><button class="choice rarity-heroic" id="takeBoon"><small class="path rar-heroic">Inspired by ${RECIPES[key].name}</small><b>${b.name}</b><span>${b.desc}</span></button></div>`);
  $('takeBoon').onclick = () => { b.apply(S.hero); S.boons[key] = true; S.pendingBoon = null; closeModal(); S.paused = false; renderHero(); toast('Awakened: ' + b.name + '.'); };
}
function showHeroic() {
  S.paused = true;
  const fresh = shuffle(HEROICS.filter(x => !S.heroics[x.id])).slice(0, 3);
  const owned = HEROICS.filter(x => S.heroics[x.id] && S.heroics[x.id] < 3);
  openModal(`<h2>Heroic power</h2><p>The boss dropped a heroic power. Take a new one, or empower one you already have (up to rank 3).</p>
    <div class="choices">${fresh.map((x, i) => `<button class="choice rarity-heroic" data-new="${i}"><small class="path rar-heroic">Heroic · New</small><b>${x.name}</b><span>${x.desc(1)}</span></button>`).join('')}</div>
    ${owned.length ? `<p style="margin-top:14px">Or empower:</p><div class="choices">${owned.map((x, i) => `<button class="choice rarity-heroic" data-up="${i}"><small class="path rar-heroic">Rank ${S.heroics[x.id]} → ${S.heroics[x.id] + 1}</small><b>${x.name}</b><span>${x.desc(S.heroics[x.id] + 1)}</span></button>`).join('')}</div>` : ''}`);
  const done = (x) => { S.pendingHeroic--; closeModal(); S.paused = false; renderHero(); toast('Heroic power: ' + x.name + ' rank ' + S.heroics[x.id] + '.'); };
  $('modalBox').querySelectorAll('[data-new]').forEach(b => b.onclick = () => { const x = fresh[+b.dataset.new]; S.heroics[x.id] = 1; done(x); });
  $('modalBox').querySelectorAll('[data-up]').forEach(b => b.onclick = () => { const x = owned[+b.dataset.up]; S.heroics[x.id]++; done(x); });
}
function endRun(won, quit) {
  S.over = true;
  closeWaveLog(won);
  const map = MAPS[S.map], cleared = won ? MAX_WAVE : (S.waveActive ? S.wave - 1 : S.wave);
  const shards = Math.round((cleared * 4 + S.bossKills * 15 + (won ? 60 : 0)) * map.shardMul);
  META.shards += shards;
  const best = META.best[S.map];
  if (!best || cleared > best.wave) META.best[S.map] = { wave: cleared, won };
  const top = S.towers.slice().sort((a, b) => (b.dmgTotal || 0) - (a.dmgTotal || 0))[0];
  META.runs.push({ date: new Date().toISOString(), map: S.map, hero: S.hero.cls, wave: S.wave, won, shards,
    livesLost: S.startLives - S.lives, heroLvl: S.hero.lvl, top: top ? towerName(top) + ' L' + top.lvl : '',
    upgrades: S.picks.map(o => (o.demonic ? 'Demonic ' : '') + o.rarity.name + ' ' + o.perk.name), heroics: S.heroics, relics: S.relics.map(r => r.name),
    boons: Object.keys(S.boons).map(k => BOONS[k].name), waves: S.log });
  META.runs = META.runs.slice(-25); saveMeta();
  const rows = S.log.slice(-6).map(w => `<tr><td>${w.wave}</td><td>${w.mode}</td><td>${w.livesLost}</td><td>${w.heroDmg}</td><td>${w.towers[0] ? w.towers[0].name + ' (' + w.towers[0].dmg + ')' : '-'}</td></tr>`).join('');
  openModal(`<h2>${won ? 'The rift is sealed' : quit ? 'Run ended' : 'The base has fallen'}</h2>
    <p>${won ? 'You held all ' + MAX_WAVE + ' waves' : 'You reached wave ' + S.wave} on ${map.name} as a level ${S.hero.lvl} ${HEROES[S.hero.cls].name}.</p>
    <p class="shards">+◆ ${shards} Rift Shards (${META.shards} total)</p>
    <div class="logwrap"><table class="log"><thead><tr><th>Wave</th><th>Mode</th><th>Lives lost</th><th>Hero dmg</th><th>Top tower</th></tr></thead><tbody>${rows}</tbody></table></div>
    <div class="row" style="margin-top:12px"><button class="go" id="again">Play again</button><button id="toMenu">Main menu</button></div>`);
  const mapId = S.map;
  $('again').onclick = () => newRun(mapId);
  $('toMenu').onclick = showMenu;
}
function openModal(html) { $('modalBox').innerHTML = html; $('modal').hidden = false; hideTip(); }
function closeModal() { $('modal').hidden = true; }

// ---------- building ----------
function cellAt(x, y) { return { c: Math.floor(x / C), r: Math.floor(y / C) }; }
function towerAt(c, r) { return S.towers.find(t => t.c === c && t.r === r); }
function inBuildRange(c, r) { const h = S.hero; return Math.hypot(c * C + C / 2 - h.x, r * C + C / 2 - h.y) <= h.buildRange; }
function buildProblem(c, r, type) {
  if (c < 0 || r < 0 || c >= COLS || r >= ROWS) return 'Out of bounds.';
  if (pathCells.has(c + ',' + r)) return 'You can’t build on the path.';
  if (towerAt(c, r)) return 'That tile is taken.';
  if (S.hero.ko) return 'Your hero is knocked out.';
  if (S.gold < towerCost(type)) return 'Not enough gold.';
  return null;
}
function newTower(type, c, r) {
  const d = TOWERS[type];
  return { type, c, r, x: c * C + C / 2, y: r * C + C / 2, lvl: 1, dmg: d.dmg, rate: d.rate, range: d.range,
    splash: d.splash || 0, slow: d.slow || 0, slowDur: 1.6, chain: d.chain || 0, chainMul: 0.7, chainReach: 95,
    multi: 0, ramp: 0, surge: 0, burn: 0, brittle: 0, mark: 0, cluster: 0, orbital: 0, freeze: 0, zero: 0, stun: 0,
    color: d.color, cd: 0, shots: 0, stacks: 0, spent: 0, baseCost: d.cost, ups: {} };
}
function placeTower(c, r, type) {
  const cost = towerCost(type), t = newTower(type, c, r);
  S.gold -= cost; t.spent = cost; S.towers.push(t);
  if (S.build && S.gold < towerCost(S.build)) S.build = null;
  renderBuildBar(); renderInspector();
}
// The same 5 options every level. Picking one never removes the others; each stacks up to its max rank.
const ALL_TOWER_UPS = Object.values(TOWER_UPS).flat();
function towerOptions(t) {
  if (t.super) return SUPER_UPS;
  if (t.hybrid) return HYBRID_UPS[t.type].map(id => ALL_TOWER_UPS.find(u => u.id === id));
  return TOWER_UPS[t.type];
}
function levelBonus(t, lvl) { return !t.hybrid && TOWER_CAPS[t.type][lvl]; }
function levelTower(t, up) {
  const lc = levelCost(t);
  if (S.gold < lc || t.lvl >= MAX_LVL || (t.ups[up.id] || 0) >= up.max) return;
  S.gold -= lc; t.spent += lc; t.lvl++; t.dmg *= 1.05;
  up.apply(t); t.ups[up.id] = (t.ups[up.id] || 0) + 1;
  const bonus = levelBonus(t, t.lvl);
  if (bonus) { bonus.apply(t); t.ups[bonus.id] = 1; }
  toast(towerName(t) + ' reached level ' + t.lvl + ': ' + up.name + (bonus ? ', and unlocked ' + bonus.name : '') + '.');
  renderInspector(); renderBuildBar();
}

function cancelPlacing() {
  if (!S.build && !S.mergeFrom && !S.pendingBuild) return false;
  S.build = null; S.mergeFrom = null; S.pendingBuild = null;
  toast('Cancelled.'); renderBuildBar(); renderInspector();
  return true;
}
function moveHero(x, y) {
  if (S.hero.ko) return;
  S.pendingBuild = null;
  S.hero.tx = Math.max(10, Math.min(W - 10, x)); S.hero.ty = Math.max(10, Math.min(H - 10, y));
}
function handleRight(x, y) {
  if (S.paused || S.over) return;
  if (cancelPlacing()) return;
  moveHero(x, y);
}
function handleClick(x, y, touch) {
  if (S.paused || S.over) return;
  const { c, r } = cellAt(x, y), t = towerAt(c, r);
  if (S.mergeFrom) {
    if (t && t !== S.mergeFrom) tryMerge(S.mergeFrom, t);
    else { S.mergeFrom = null; toast('Merge cancelled.'); renderInspector(); }
    return;
  }
  if (t) { S.sel = t; S.build = null; S.pendingBuild = null; renderBuildBar(); renderInspector(); return; }
  if (S.build) {
    const why = buildProblem(c, r, S.build);
    if (why) return toast(why);
    if (inBuildRange(c, r)) return placeTower(c, r, S.build);
    const h = S.hero, cx = c * C + C / 2, cy = r * C + C / 2, d = Math.hypot(h.x - cx, h.y - cy), stop = h.buildRange * 0.8;
    h.tx = cx + (h.x - cx) / d * stop; h.ty = cy + (h.y - cy) / d * stop;
    S.pendingBuild = { c, r, type: S.build };
    return;
  }
  if (S.sel) { S.sel = null; renderInspector(); }
  if (touch) moveHero(x, y);
}

// Returns why two towers can't merge, or '' if they can.
function mergeProblem(a, b) {
  if (a.super || b.super) return 'Super towers are already fully merged.';
  if (a.lvl < MERGE_LVL || b.lvl < MERGE_LVL) return 'Both towers need to be level ' + MERGE_LVL + '.';
  if (a.hybrid !== b.hybrid) return 'Merge two basic towers into a hybrid, or two hybrids into a super tower.';
  if (!a.hybrid && a.type === b.type) return 'Merge two different tower types.';
  return '';
}
function tryMerge(a, b) {
  S.mergeFrom = null;
  const why = mergeProblem(a, b), cost = mergeCost(a);
  if (why) { toast(why); return renderInspector(); }
  if (S.gold < cost) { toast('Merging costs ' + cost + ' gold.'); return renderInspector(); }
  S.gold -= cost;
  const base = { lvl: 1, spent: a.spent + b.spent + cost, cd: 0, shots: 0, stacks: 0, ups: {}, baseCost: a.baseCost + b.baseCost,
    range: Math.max(a.range, b.range) * 1.1 };
  let merged, label, color, key = '';
  if (a.hybrid) {
    const parents = [...new Set(a.parents.concat(b.parents))].sort(), info = SUPERS[parents.join('+')];
    const recipe = RECIPES[a.type];
    label = info ? info.name : 'Prime ' + recipe.name; color = info ? info.color : recipe.color;
    merged = Object.assign(base, { type: a.type, hybrid: true, super: true, parents, name: label, color,
      desc: info ? info.desc : 'Two ' + recipe.name + 's fused into one. ' + recipe.desc,
      dmg: Math.max(a.dmg, b.dmg) * 1.6, rate: Math.min(a.rate, b.rate) * 0.9 });
  } else {
    key = [a.type, b.type].sort().join('+');
    const rec = RECIPES[key];
    label = rec.name; color = rec.color;
    merged = Object.assign(base, { type: key, hybrid: true, parents: [a.type, b.type], color,
      dmg: Math.max(a.dmg, b.dmg) * 1.5, rate: Math.min(a.rate, b.rate) });
  }
  for (const k of TRAITS) merged[k] = Math.max(a[k], b[k]);
  if (merged.chain) merged.chain += 1;
  if (merged.super) merged.multi += 1;
  Object.assign(b, merged);
  S.towers = S.towers.filter(t => t !== a);
  S.fx.push({ k: 'ring', x: b.x, y: b.y, r: merged.super ? 60 : 40, color, t: 0.6, T: 0.6, fill: true });
  if (key) {
    const isNew = !codex[key]; codex[key] = true; saveCodex();
    toast((isNew ? 'New recipe: ' : 'Merged into ') + label + '!');
    if (!S.boons[key] && Math.random() < 0.35) S.pendingBoon = key;
  } else toast('Super merge: ' + label + '!');
  S.sel = b; renderInspector(); renderCodex(); renderBuildBar();
}

// ---------- UI ----------
function renderBuildBar() {
  if (!S.hero) return;
  const bar = $('buildBar');
  const modeTag = S.mode.kind !== 'normal' ? ' · ' + S.mode.name : '';
  bar.innerHTML = Object.entries(TOWERS).map(([k, d]) =>
    `<button class="tbtn ${S.build === k ? 'on' : ''}" data-k="${k}" ${S.gold < towerCost(k) ? 'disabled' : ''}>
      <span class="sw" style="background:${d.css}"></span>${d.name}<span class="c">${towerCost(k)}</span><kbd>${d.key}</kbd></button>`).join('') +
    `<button id="abilityBtn" class="ability">${S.hero.ab.name} <kbd>Q</kbd></button><span class="spacer"></span>
     <button id="speedBtn">${S.speed}×</button>
     <button class="go" id="waveBtn" ${S.waveActive || S.over ? 'disabled' : ''}>${S.waveActive ? 'Wave ' + S.wave + modeTag : 'Start wave ' + (S.wave + 1) + modeTag + ' <kbd>Space</kbd>'}</button>`;
  bar.querySelectorAll('.tbtn').forEach(b => {
    b.onclick = () => selectBuild(b.dataset.k);
    b.onmouseenter = () => showTip(buildTipHtml(b.dataset.k), b.getBoundingClientRect(), 'above');
    b.onmouseleave = hideTip;
  });
  $('abilityBtn').onclick = useAbility;
  abilityMeter();
  $('speedBtn').onclick = () => { S.speed = S.speed === 3 ? 1 : S.speed + 1; renderBuildBar(); };
  $('waveBtn').onclick = startWave;
  lastBarGold = S.gold;
}
function confirmQuit() {
  if (S.over) return showMenu();
  S.paused = true;
  openModal(`<h2>Leave this run?</h2><p>You'll still earn Rift Shards for the waves you cleared.</p>
    <div class="row"><button class="go" id="qStay">Keep playing</button><button id="qLeave">End run</button></div>`);
  $('qStay').onclick = () => { closeModal(); S.paused = false; };
  // (End run returns to the main menu from the summary screen.)
  $('qLeave').onclick = () => { S.paused = false; endRun(false, true); };
}
function selectBuild(k) {
  if (S.over || S.paused) return;
  if (S.build === k) S.build = null;
  else if (S.gold >= towerCost(k)) { S.build = k; S.sel = null; S.mergeFrom = null; }
  renderBuildBar(); renderInspector();
}
function previewTower(k) { return newTower(k, 0, 0); }
function buildTipHtml(k) {
  const d = TOWERS[k], t = previewTower(k);
  return `<b>${d.name}</b> <span class="tip-c">${towerCost(k)} gold</span><p>${d.info}</p>
    <div class="tip-s">Damage ${d.dmg} · ${(1 / d.rate).toFixed(2)} shots/s · Range ${d.range}</div>
    <ul>${traits(t).slice(1).map(x => `<li>${x}</li>`).join('')}</ul>
    <div class="tip-s">Upgrades: ${TOWER_UPS[k].map(u => u.name).join(', ')}. Level 5 unlocks ${TOWER_CAPS[k][5].name}, level 10 unlocks ${TOWER_CAPS[k][10].name}.</div>`;
}
function towerTipHtml(t) {
  const ups = Object.entries(t.ups).map(([id, n]) => { const u = ALL_TOWER_UPS.concat(SUPER_UPS, Object.values(TOWER_CAPS).flatMap(c => Object.values(c))).find(x => x.id === id); return u ? u.name + (n > 1 ? ' ×' + n : '') : ''; }).filter(Boolean);
  return `<b>${towerName(t)}</b> <span class="tip-c">Lv ${t.lvl}/${MAX_LVL}${t.super ? ' · Super' : t.hybrid ? ' · Hybrid' : ''}</span>${t === S.drained ? '<p style="color:var(--danger)">Drained: half damage this wave.</p>' : ''}<p>${towerBlurb(t)}</p>
    <div class="tip-s">Damage dealt: ${Math.round(t.dmgTotal || 0)} total, ${Math.round(t.dmgWave || 0)} this wave</div>
    <div class="tip-s">Damage ${(t.dmg * S.mod.towerDmg).toFixed(0)} · ${(1 / (t.rate * S.mod.towerRate)).toFixed(2)} shots/s · Range ${tRange(t).toFixed(0)}</div>
    <ul>${traits(t).map(x => `<li>${x}</li>`).join('')}</ul>${ups.length ? `<div class="tip-s">Upgrades: ${ups.join(', ')}</div>` : ''}`;
}

function renderInspector() {
  if (!S.hero) return;
  const el = $('inspector'), t = S.sel;
  if (!t || !S.towers.includes(t)) {
    S.sel = null;
    if (S.build) {
      el.innerHTML = `<h3>Placing</h3>${buildTipHtml(S.build)}<p class="help">Left-click a tile to build. Right-click or press R to cancel.</p>`;
      return;
    }
    el.innerHTML = `<h3>Tower</h3><p>Hover a tower to see what it does. Pick one, then left-click a free tile. If it's out of reach, your hero walks over and builds it.</p><p>Towers level up to ${MAX_LVL}. Each level you pick one of the tower's 5 upgrades, and levels 5 and 10 unlock a bonus. Two different level ${MERGE_LVL} towers merge into a hybrid, and two level ${MERGE_LVL} hybrids merge into a super tower.</p>`;
    return;
  }
  const lc = levelCost(t), sell = Math.round(t.spent * SELL_RATE);
  const gc = v => `<span style="color:var(--gold)">${v}</span>`;
  const opts = towerOptions(t), bonus = levelBonus(t, t.lvl + 1), canMerge = t.lvl >= MERGE_LVL && !t.super;
  el.innerHTML = `<h3>${towerName(t)} · ${towerKind(t)}Lv ${t.lvl}/${MAX_LVL}</h3>
    <p>${towerBlurb(t)}${t.hybrid ? ' Contains ' + t.parents.map(p => TOWERS[p].name).join(' + ') + '.' : ''}</p>
    <div class="stats">
      <div><span>Damage</span>${(t.dmg * S.mod.towerDmg).toFixed(0)}</div><div><span>Shots/s</span>${(1 / (t.rate * S.mod.towerRate)).toFixed(2)}</div>
      <div><span>Range</span>${tRange(t).toFixed(0)}</div><div><span>Spent</span>${t.spent}</div>
    </div>
    <ul class="traits">${traits(t).map(x => `<li>${x}</li>`).join('')}</ul>
    ${S.mergeFrom === t ? `<p>Tap another level ${MERGE_LVL} ${t.hybrid ? 'hybrid' : 'tower of a different type'} to merge with. Tap anywhere else to cancel.</p>` : ''}
    ${t.lvl < MAX_LVL ? `<p class="help" style="margin-top:8px">Level up to ${t.lvl + 1} for ${gc(lc)} gold. Every level also adds +5% damage.${bonus ? ` Level ${t.lvl + 1} also unlocks <b>★ ${bonus.name}</b>: ${bonus.desc}` : ''} Pick one:</p>
      <div class="ups">${opts.map((u, i) => { const n = t.ups[u.id] || 0, full = n >= u.max;
        return `<button class="up" data-u="${i}" ${S.gold < lc || full ? 'disabled' : ''}><b>${u.name} <small>${n}/${u.max}</small></b><span>${full ? 'Maxed.' : u.desc}</span></button>`; }).join('')}</div>`
      : `<p class="help">Max level.${canMerge ? ` Merge it with another level ${MERGE_LVL} ${t.hybrid ? 'hybrid to make a super tower' : 'tower of a different type to make a hybrid'}.` : ''}</p>`}
    <div class="row">
      ${canMerge ? `<button id="mergeBtn" ${S.gold < mergeCost(t) ? 'disabled' : ''}>${t.hybrid ? 'Super merge' : 'Merge'} · ${gc(mergeCost(t))}</button>` : ''}
      <button id="sellBtn">Sell · ${gc('+' + sell)} <kbd>R</kbd></button>
    </div>`;
  el.querySelectorAll('.up').forEach(b => b.onclick = () => levelTower(t, opts[+b.dataset.u]));
  if ($('mergeBtn')) $('mergeBtn').onclick = () => { S.mergeFrom = t; renderInspector(); toast(t.hybrid ? 'Pick another level ' + MERGE_LVL + ' hybrid.' : 'Pick a level ' + MERGE_LVL + ' tower of another type.'); };
  $('sellBtn').onclick = sellSelected;
  lastInspGold = S.gold;
}
function sellSelected() {
  const t = S.sel; if (!t) return;
  const sell = Math.round(t.spent * SELL_RATE);
  S.gold += sell; S.towers = S.towers.filter(x => x !== t); S.sel = null;
  toast('Sold for ' + sell + ' gold.'); renderInspector(); renderBuildBar();
}
function renderCodex() {
  $('codex').innerHTML = Object.entries(RECIPES).map(([k, r]) => {
    const [a, b] = k.split('+');
    return codex[k] ? `<li class="found" title="${r.desc}"><b>${r.name}</b><span>${TOWERS[a].name} + ${TOWERS[b].name}</span></li>`
                    : `<li><b>???</b><span>Undiscovered</span></li>`;
  }).join('');
}
function renderHero() {
  const h = S.hero; if (!h) return;
  const f = v => v.toFixed(0), d = HEROES[h.cls];
  const picks = S.picks.map(o => `<span class="tag rar-${o.rarity.id} ${o.demonic ? 'is-demonic' : ''}" title="${o.perk.rarity ? o.perk.desc : o.perk.desc(o.m)}${o.demonic ? ' Curse: ' + o.curse.desc(o.k) : ''}">${o.demonic ? '☠ ' : ''}${o.perk.name}</span>`).join('');
  const heroics = HEROICS.filter(x => S.heroics[x.id]).map(x => `<span class="tag rar-heroic" title="${x.desc(S.heroics[x.id])}">${x.name} ${'I'.repeat(S.heroics[x.id])}</span>`).join('');
  const relics = S.relics.map(r => `<span class="tag relic ${r.rarity ? 'rar-' + r.rarity : ''}" title="${r.desc}">${r.name}</span>`).join('');
  $('heroCard').innerHTML = `<h3 style="color:${d.css}">${d.name} · ${d.role} · Lv ${h.lvl}${h.ko ? ' · Knocked out' : ''}</h3>
    <p class="help"><b style="color:var(--text)">${h.ab.name}</b> (${h.ab.cd.toFixed(0)}s): ${abilityText(h)}</p>
    <div class="stats">
      <div><span>HP</span>${f(h.hp)}/${f(h.maxHp)}</div><div><span>Damage</span>${f(heroDmg())}</div>
      <div><span>Attacks/s</span>${(1 / h.rate).toFixed(2)}</div><div><span>Range</span>${h.range >= 9999 ? 'Whole map' : f(h.range)}</div>
      <div><span>Targets</span>${1 + h.multi}</div><div><span>Crit chance</span>${pct(h.crit)}</div>
      <div><span>Crit damage</span>${pct(h.critDmg)}</div>${h.brace ? `<div><span>Brace</span>${h.brace.toFixed(2)}s</div>` : ''}
      <div><span>Armor</span>${pct(h.armor)}</div><div><span>Blocks</span>${h.block}</div>
      <div><span>Regen/s</span>${h.regen.toFixed(1)}</div><div><span>Respawn</span>${h.respawn.toFixed(1)}s</div>
      <div><span>Build range</span>${f(h.buildRange)}</div><div><span>Move speed</span>${f(h.speed)}</div>
      ${h.aura ? `<div><span>Tower aura</span>+${pct(h.aura)}</div>` : ''}
      ${h.bounty ? `<div><span>Bounty</span>+${h.bounty}g</div>` : ''}
      ${h.interest ? `<div><span>Interest</span>${pct(h.interest)}</div>` : ''}
    </div>
    ${heroics ? `<div class="tags">${heroics}</div>` : ''}
    ${Object.keys(S.boons).length ? `<div class="tags">${Object.keys(S.boons).map(k => `<span class="tag rar-heroic" title="${BOONS[k].desc}">✦ ${BOONS[k].name}</span>`).join('')}</div>` : ''}
    <div class="tags">${picks || '<span class="help">No upgrades yet. Kill enemies to level up.</span>'}${relics}</div>`;
}

// Tooltip
function showTip(html, rect, where) {
  const tip = $('tip'); tip.innerHTML = html; tip.hidden = false;
  const tw = tip.offsetWidth, th = tip.offsetHeight;
  let x = rect.left + rect.width / 2 - tw / 2, y = where === 'above' ? rect.top - th - 8 : rect.bottom + 12;
  if (y < 8) y = rect.bottom + 12;
  x = Math.max(8, Math.min(window.innerWidth - tw - 8, x));
  y = Math.max(8, Math.min(window.innerHeight - th - 8, y));
  tip.style.left = x + 'px'; tip.style.top = y + 'px';
}
function hideTip() { $('tip').hidden = true; }

let lastBarGold = -1, lastInspGold = -1, heroT = 0, tipTower = null;
// The ability button empties when used and refills as the cooldown runs down.
function abilityMeter() {
  const b = $('abilityBtn'), a = S.hero && S.hero.ab; if (!b || !a) return;
  const fill = a.t > 0 ? (1 - a.t / a.cd) * 100 : 100;
  b.style.setProperty('--fill', fill.toFixed(1) + '%');
  b.classList.toggle('ready', !(a.t > 0));
}
function updateHud() {
  const h = S && S.hero; if (!h) return;
  $('sWave').textContent = S.wave + '/' + MAX_WAVE;
  $('sLives').textContent = S.lives;
  $('sGold').textContent = Math.floor(S.gold);
  $('sLvl').textContent = h.ko ? 'KO ' + Math.ceil(h.ko) + 's' : 'Lv ' + h.lvl;
  $('mHp').style.width = (h.hp / h.maxHp * 100) + '%';
  $('mXp').style.width = (h.xp / h.next * 100) + '%';
  abilityMeter();
  if (Math.floor(S.gold) !== Math.floor(lastBarGold)) renderBuildBar();
  if (S.sel && Math.floor(S.gold) !== Math.floor(lastInspGold) && !S.mergeFrom) renderInspector();
  if (--heroT <= 0) { heroT = 3; renderHero(); }
}

function draw(g) {
  g.clear();
  g.lineStyle(1, 0x141a2e, 1);
  for (let c = 0; c <= COLS; c++) g.lineBetween(c * C, 0, c * C, H);
  for (let r = 0; r <= ROWS; r++) g.lineBetween(0, r * C, W, r * C);
  for (const k of pathCells) { const [c, r] = k.split(',').map(Number); g.fillStyle(0x1a2140, 1).fillRect(c * C, r * C, C, C); }
  g.lineStyle(2, 0x2a3459, 1);
  g.beginPath(); g.moveTo(WP[0].x, WP[0].y); for (const p of WP) g.lineTo(p.x, p.y); g.strokePath();
  g.fillStyle(0x4fd8e8, 0.15).fillCircle(BASE.x, BASE.y, 26);
  g.lineStyle(2, 0x4fd8e8, 1).strokeCircle(BASE.x, BASE.y, 18);
  g.fillStyle(0x4fd8e8, 1).fillCircle(BASE.x, BASE.y, 7);
  const h = S && S.hero; if (!h) return;
  const hc = HEROES[h.cls].color;

  if (S.overclockT > 0) { g.fillStyle(0xb07cff, 0.06).fillCircle(S.overclockAt.x, S.overclockAt.y, h.ab.r); g.lineStyle(1, 0xb07cff, 0.5).strokeCircle(S.overclockAt.x, S.overclockAt.y, h.ab.r); }
  if (h.aura && !h.ko) g.lineStyle(1, 0xb07cff, 0.12).strokeCircle(h.x, h.y, h.auraRange);
  if (S.build && !h.ko) {
    g.fillStyle(0x4fd8e8, 0.05).fillCircle(h.x, h.y, h.buildRange);
    g.lineStyle(1, 0x4fd8e8, 0.35).strokeCircle(h.x, h.y, h.buildRange);
    if (S.hover) {
      const ok = !buildProblem(S.hover.c, S.hover.r, S.build), near = ok && inBuildRange(S.hover.c, S.hover.r);
      g.fillStyle(!ok ? 0xff5d6c : near ? 0x5fe39a : 0xf2c14e, 0.25).fillRect(S.hover.c * C, S.hover.r * C, C, C);
      if (ok) g.lineStyle(1, TOWERS[S.build].color, 0.4).strokeCircle(S.hover.c * C + C / 2, S.hover.r * C + C / 2, TOWERS[S.build].range * (1 + h.towerRange));
    }
  }
  if (S.pendingBuild) { const pb = S.pendingBuild; g.lineStyle(2, TOWERS[pb.type].color, 0.8).strokeRect(pb.c * C + 4, pb.r * C + 4, C - 8, C - 8); }
  const showR = S.sel || tipTower;
  if (showR) g.lineStyle(1, showR.color, 0.5).strokeCircle(showR.x, showR.y, tRange(showR));
  if (S.mergeFrom) for (const t of S.towers) if (t !== S.mergeFrom && !mergeProblem(S.mergeFrom, t))
    g.lineStyle(2, 0xf2c14e, 0.8).strokeRect(t.x - 18, t.y - 18, 36, 36);

  for (const t of S.towers) {
    g.fillStyle(0x141a2e, 1).fillRoundedRect(t.x - 16, t.y - 16, 32, 32, 5);
    g.lineStyle(2, t.color, t === S.sel ? 1 : 0.6).strokeRoundedRect(t.x - 16, t.y - 16, 32, 32, 5);
    if (t === S.drained) { g.lineStyle(2, 0xff5d6c, 0.9).lineBetween(t.x - 14, t.y - 14, t.x + 14, t.y + 14); }
    if (overclocked(t)) g.lineStyle(1, 0xb07cff, 0.9).strokeRoundedRect(t.x - 19, t.y - 19, 38, 38, 6);
    if (t.super) {
      g.fillStyle(t.color, 1).fillCircle(t.x, t.y - 3, 8);
      g.lineStyle(2, t.color, 0.8).strokeCircle(t.x, t.y - 3, 11);
      g.lineStyle(1, 0xf2c14e, 0.9).strokeCircle(t.x, t.y - 3, 14);
    } else if (t.hybrid) {
      g.fillStyle(t.color, 1).fillCircle(t.x, t.y - 3, 7);
      g.lineStyle(2, t.color, 0.7).strokeCircle(t.x, t.y - 3, 11);
    } else {
      g.fillStyle(t.color, 1);
      if (t.type === 'arcane') g.fillTriangle(t.x, t.y - 12, t.x - 8, t.y + 4, t.x + 8, t.y + 4);
      else if (t.type === 'plasma') g.fillCircle(t.x, t.y - 3, 8);
      else if (t.type === 'frost') g.fillPoints([{ x: t.x, y: t.y - 13 }, { x: t.x + 7, y: t.y - 3 }, { x: t.x, y: t.y + 7 }, { x: t.x - 7, y: t.y - 3 }], true);
      else g.fillRect(t.x - 4, t.y - 12, 8, 16);
    }
    // level pips: 10 small dots in two rows of 5
    for (let i = 0; i < t.lvl; i++) g.fillStyle(i >= 5 ? 0xff6fd8 : 0xf2c14e, 1).fillCircle(t.x - 10 + (i % 5) * 5, t.y + 10 + (i >= 5 ? 0 : 3), 1.6);
  }

  for (const e of S.enemies) {
    g.fillStyle(e.color, 1).fillCircle(e.x, e.y, e.r);
    if (e.stunT > 0) g.lineStyle(2, 0xffffff, 0.9).strokeCircle(e.x, e.y, e.r + 2);
    else if (e.slow) g.lineStyle(2, 0x7fd4ff, 0.9).strokeCircle(e.x, e.y, e.r + 2);
    if (e.burnT > 0) g.fillStyle(0xff8a3d, 0.8).fillCircle(e.x, e.y - e.r, 2.5);
    if (e.boss) g.lineStyle(2, 0xf2c14e, 1).strokeCircle(e.x, e.y, e.r + 4);
    const w = e.r * 2 + 4;
    g.fillStyle(0x000000, 0.6).fillRect(e.x - w / 2, e.y - e.r - 7, w, 3);
    g.fillStyle(0x5fe39a, 1).fillRect(e.x - w / 2, e.y - e.r - 7, w * Math.max(0, e.hp / e.max), 3);
  }

  if (h.tx !== null && !h.ko) g.lineStyle(1, hc, 0.5).strokeCircle(h.tx, h.ty, 6);
  if (h.ko) {
    g.fillStyle(0x8d95b8, 0.3).fillCircle(h.x, h.y, 13);
    g.lineStyle(3, hc, 0.8).beginPath();
    g.arc(h.x, h.y, 17, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (1 - h.ko / h.respawn)); g.strokePath();
  } else {
    const HX = S.heroics;
    if (HX.wither) g.fillStyle(0x7a2e5a, 0.12).fillCircle(h.x, h.y, 90 + 20 * HX.wither);
    if (h.range < 9999) g.lineStyle(1, hc, 0.15).strokeCircle(h.x, h.y, h.range);
    if (h.brace) { const ready = h.braceT >= h.brace; g.lineStyle(ready ? 3 : 2, ready ? 0xffd36e : 0x8d95b8, ready ? 0.95 : 0.6).beginPath(); g.arc(h.x, h.y, 26, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (h.braceT / h.brace)); g.strokePath(); }
    g.fillStyle(hc, 0.2).fillCircle(h.x, h.y, 18);
    g.fillStyle(hc, 1).fillCircle(h.x, h.y, 12);
    g.fillStyle(0x0b0f1c, 1).fillCircle(h.x, h.y, 5);
    g.fillStyle(0x000000, 0.6).fillRect(h.x - 16, h.y - 24, 32, 4);
    g.fillStyle(0x5fe39a, 1).fillRect(h.x - 16, h.y - 24, 32 * h.hp / h.maxHp, 4);
    if (h.ab.t > 0) { g.lineStyle(2, 0xb07cff, 0.7).beginPath(); g.arc(h.x, h.y, 21, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (1 - h.ab.t / h.ab.cd)); g.strokePath(); }
    else g.lineStyle(2, 0xb07cff, 0.9).strokeCircle(h.x, h.y, 21);
    if (HX.blades) for (let i = 0; i < HX.blades + 1; i++) {
      const ang = S.time * 3 + i * Math.PI * 2 / (HX.blades + 1);
      g.fillStyle(0xe6e9f5, 1).fillCircle(h.x + Math.cos(ang) * 42, h.y + Math.sin(ang) * 42, 5);
    }
    if (HX.drone) for (let i = 0; i < HX.drone; i++) g.fillStyle(0x5fe39a, 1).fillRect(h.x + (i ? -26 : 18), h.y - 26, 8, 8);
  }

  for (const f of S.fx) {
    const a = f.t / f.T;
    if (f.k === 'line') g.lineStyle(f.w, f.color, a).lineBetween(f.x1, f.y1, f.x2, f.y2);
    else {
      const r = f.r * (1.2 - a * 0.4);
      if (f.fill) g.fillStyle(f.color, a * 0.2).fillCircle(f.x, f.y, r);
      g.lineStyle(2, f.color, a).strokeCircle(f.x, f.y, r);
    }
  }
}

let hudT = 0;
class Main extends Phaser.Scene {
  create() {
    this.g = this.add.graphics();
    this.input.mouse.disableContextMenu();
    this.input.on('pointerdown', p => { hideTip(); if (!S || !S.hero) return; p.rightButtonDown() ? handleRight(p.worldX, p.worldY) : handleClick(p.worldX, p.worldY, p.wasTouch); });
    this.input.on('pointermove', p => {
      if (!S || !S.hero) return;
      S.hover = cellAt(p.worldX, p.worldY);
      const t = !S.paused && towerAt(S.hover.c, S.hover.r);
      if (t && !p.wasTouch) {
        tipTower = t;
        const ev = p.event, rect = { left: ev.clientX, top: ev.clientY, width: 0, bottom: ev.clientY };
        showTip(towerTipHtml(t), rect, 'below');
      } else if (tipTower) { tipTower = null; hideTip(); }
    });
    this.input.on('gameout', () => { if (S) S.hover = null; tipTower = null; hideTip(); });
    showMenu();
    $('settingsBtn').onclick = () => (S && S.hero && !S.over ? showSettings() : null);
  }
  update(time, delta) {
    const dt = Math.min(delta / 1000, 0.05);
    update(dt); draw(this.g);
    hudT -= dt; if (hudT <= 0) { hudT = 0.1; updateHud(); }
  }
}

const held = new Set();
let keyMove = true;
try { keyMove = localStorage.getItem('riftguard-keys') !== 'off'; } catch (e) {}
const MOVE_KEYS = ['w', 'a', 's', 'd', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright'];
function toggleKeys() {
  keyMove = !keyMove; held.clear();
  try { localStorage.setItem('riftguard-keys', keyMove ? 'on' : 'off'); } catch (e) {}
  if (S && S.hero) renderBuildBar(); toast('WASD / arrow movement ' + (keyMove ? 'on' : 'off') + '.');
}
window.addEventListener('keyup', e => held.delete(e.key.toLowerCase()));
window.addEventListener('blur', () => held.clear());
window.addEventListener('keydown', e => {
  if (e.key === 'Escape' && settingsOpen()) { e.preventDefault(); return closeSettings(); }
  if (!S || !S.hero || e.target.tagName === 'INPUT') return;
  const lk = e.key.toLowerCase();
  if (keyMove && MOVE_KEYS.includes(lk)) { e.preventDefault(); held.add(lk); return; }
  const k = Object.keys(TOWERS).find(t => TOWERS[t].key === e.key);
  if (k) selectBuild(k);
  else if (lk === 'r') { if (!S.paused && !S.over && !cancelPlacing()) sellSelected(); }
  else if (lk === 'q') useAbility();
  else if (e.key === ' ' || e.code === 'Space') { e.preventDefault(); if (document.activeElement && document.activeElement.blur) document.activeElement.blur(); if (!e.repeat) startWave(); }
  else if (e.key === 'Escape') {
    if (S.build || S.mergeFrom || S.sel || S.pendingBuild) { S.build = null; S.mergeFrom = null; S.sel = null; S.pendingBuild = null; renderBuildBar(); renderInspector(); }
    else if (!S.over) showSettings();
  }
});

window.riftguard = { get state() { return S; } };
new Phaser.Game({
  type: Phaser.AUTO, parent: 'board', width: W, height: H, backgroundColor: '#080b15',
  scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
  scene: Main, banner: false,
});
})();
