import Phaser from 'phaser';
import './style.css';
import riftwalkerUrl from './music/riftwalker.mp3';

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
  maelstrom: { name: 'Rift Maelstrom', tier: 'Level 4', waves: 35, shardMul: 2.5, enemyHp: 1.8, armorBonus: 0.1, early: 2, tyrantCores: 8,
    desc: 'A long spiral into a base in the middle. Rift Storm: enemies have 80% more HP, armored enemies get +10% armor, and special enemies show up 2 waves early. The final Tyrant drops 8 Boss Cores.',
    path: [[-1,1],[22,1],[22,13],[1,13],[1,4],[19,4],[19,10],[4,10],[4,7],[15,7]] },
};
// Maps unlock in order: beat one to open the next.
const MAP_ORDER = ['verdant', 'ironhold', 'warped', 'maelstrom'];
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
  arcane: { name: 'Arcane Bolt', key: '1', cost: 50, dmg: 14, rate: 0.5, range: 120, color: 0xff4fc0, css: '#ff4fc0',
    info: 'Fires quick magic bolts at one enemy at a time. Steady, reliable damage that is good against anything.' },
  plasma: { name: 'Plasma Cannon', key: '2', cost: 80, dmg: 24, rate: 1.4, range: 110, splash: 50, color: 0x2fd6b0, css: '#2fd6b0',
    info: 'Lobs slow plasma shells that explode on impact and hurt every enemy in the blast. Best against tight groups.' },
  frost:  { name: 'Frost Pylon', key: '3', cost: 60, dmg: 6, rate: 0.9, range: 100, slow: 0.45, lvl: 'rate', color: 0x9cf4dd, css: '#9cf4dd',
    info: 'Hits weakly but slows enemies down, so the rest of your towers get more time to shoot. Pairs with everything.' },
  tesla:  { name: 'Tesla Coil', key: '4', cost: 90, dmg: 12, rate: 1.1, range: 105, chain: 3, color: 0x4fd8ff, css: '#4fd8ff',
    info: 'Fires lightning that jumps from enemy to enemy, losing a bit of power with each jump. Great for long lines of enemies.' },
  beacon: { name: 'Rift Beacon', key: '5', cost: 100, dmg: 0, rate: 1, range: 130, support: true, lvl: 'range', unlock: 200, color: 0xffa0e0, css: '#ffa0e0',
    info: 'Never attacks. Every tower in its range deals +15% damage. Beacons don’t stack on the same tower (the strongest wins), so spread them out.' },
  anvil:  { name: 'Grave Anvil', key: '6', cost: 90, dmg: 40, rate: 1.6, range: 70, unlock: 200, color: 0xf6a14a, css: '#f6a14a',
    info: 'Slams the ground, crushing enemies that are not moving: blocked by your hero, stunned or frozen. The longer they stay still, the harder it hits. Moving enemies only take 30%.' },
  laser:  { name: 'Prism Laser', key: '7', cost: 110, dmg: 5, rate: 0.2, range: 115, beam: true, unlock: 250, color: 0xff5f6f, css: '#ff5f6f',
    info: 'Holds a steady beam on one enemy. Every tick on the same target heats the beam up for more damage (up to +160%). Switching targets cools it down. Melts bosses and tanks.' },
  mortar: { name: 'Siege Mortar', key: '8', cost: 130, dmg: 110, rate: 4.5, range: 320, splash: 60, lob: true, unlock: 250, color: 0xf9e6a2, css: '#f9e6a2',
    info: 'Very long range. Lobs a slow, heavy shell that lands a few moments later and wrecks everything in the blast. Fires rarely, so pair it with towers that cover the gaps.' },
};
// What each level-up adds on top of the path point. Damage towers hit harder; utility and support towers
// get a bonus that fits their job instead (Frost fires faster so its slows and freezes land more often,
// the Beacon reaches more towers). Level 13 adds a bigger version of the same bonus.
const LEVEL_BONUS = {
  dmg:   { text: '+5% damage', asc: '+30% damage and fires 15% faster', apply: t => t.dmg *= 1.05, ascend: t => { t.dmg *= 1.3; t.rate *= 0.87; } },
  rate:  { text: '+4% attack speed', asc: 'fires 20% faster and slows 10% harder', apply: t => t.rate *= 0.96, ascend: t => { t.rate *= 0.8; t.slow = Math.min(0.85, t.slow + 0.1); } },
  range: { text: '+3 range', asc: '+10% range and +5% to its damage buff', apply: t => t.range += 3, ascend: t => { t.range *= 1.1; t.bDmg += 0.05; } },
};
const levelBonus = t => LEVEL_BONUS[(!t.hybrid && TOWERS[t.type] && TOWERS[t.type].lvl) || 'dmg'];
const towerUnlocked = k => !TOWERS[k].unlock || !!(META.towerUnlocked && META.towerUnlocked[k]);
// Tower paths. Every tower shows the same 5 paths. Each level-up puts a point into one path. A tower uses
// 3 paths of 4 points; with the Oracle it uses 4 paths of 3 bigger points (ranks 2/3/4), so a maxed path is
// the same either way. A path's last point unlocks its mastery. At level 13 the tower ascends into a form named
// after the paths you chose.
const P = (id, name, tag, words, desc, rank, mastery) => ({ id, name, tag, adj: words[0], noun: words[1], title: words[2], desc, rank, mastery });
const TOWER_PATHS = {
  arcane: [
    P('runes', 'Sharpened Runes', 'power', ['Runic', 'Glyph', 'Runes'], '+20% damage per point.', t => t.dmg *= 1.2,
      { name: 'Arcane Mark', desc: 'Hits mark enemies to take +20% damage from everything for 2s.', apply: t => t.mark += 0.2 }),
    P('hex', 'Hex Brand', 'arcane', ['Hexed', 'Brand', 'Hexes'], 'Hits brand enemies. Every second a branded enemy pulses 2% more per point of all the damage it has taken so far, to itself and enemies within 60. Ignores armor.', t => t.hex += 0.02,
      { name: 'Hex Nova', desc: 'Branded enemies explode when they die for 25% of all the damage they took, hitting enemies within 80.', apply: t => t.hexNova = Math.max(t.hexNova, 0.25) }),
    P('focus', 'Arcane Focus', 'precision', ['Focused', 'Lens', 'Focus'], 'Each hit in a row on the same enemy deals +10% more damage per point (5 stacks).', t => t.ramp += 0.1,
      { name: 'Executioner', desc: 'Hits finish off non-boss enemies below 12% HP.', apply: t => t.execute += 0.12 }),
    P('surge', 'Mana Surge', 'arcane', ['Surging', 'Nova', 'Mana'], 'Every 5th shot deals triple damage; each point makes it come 1 shot sooner.', (t, r) => t.surge = 6 - r,
      { name: 'Mana Nova', desc: 'Every 6th shot also blasts every enemy in range for 50% damage.', apply: t => t.nova += 0.5 }),
    P('quick', 'Quickcast', 'speed', ['Swift', 'Repeater', 'Haste'], 'Fires 14% faster per point.', t => t.rate *= 0.86,
      { name: 'Echo', desc: 'Every shot repeats a moment later for 40% damage.', apply: t => t.echo += 0.4 }),
  ],
  plasma: [
    P('shells', 'Bigger Shells', 'burst', ['Shrapnel', 'Mortar', 'Shrapnel'], '+20% blast radius per point.', t => t.splash *= 1.2,
      { name: 'Cluster Bomb', desc: 'Each shot also throws 2 bomblets at nearby enemies for 50% damage.', apply: t => t.cluster = 2 }),
    P('hot', 'Hot Plasma', 'power', ['Molten', 'Cannon', 'Fire'], '+20% damage per point.', t => t.dmg *= 1.2,
      { name: 'Orbital Strike', desc: 'Every 4th shot is a huge blast: double radius, triple damage.', apply: t => t.orbital = 4 }),
    P('burn', 'Burning Ground', 'burn', ['Blazing', 'Pyre', 'Embers'], 'Hits burn for +30% of their damage over 2s per point.', t => t.burn += 0.3,
      { name: 'Chain Reaction', desc: 'Enemies this tower kills explode for 20% of their max HP.', apply: t => t.deathBlast += 0.2 }),
    P('auto', 'Autoloader', 'speed', ['Rapid', 'Autocannon', 'Haste'], 'Fires 14% faster per point.', t => t.rate *= 0.86,
      { name: 'Double Tap', desc: 'Every shot fires again a moment later for 50% damage.', apply: t => t.echo += 0.5 }),
    P('concuss', 'Concussive Shells', 'slow', ['Quaking', 'Hammer', 'Thunder'], 'Blasts slow enemies by 10% per point for 1s.', (t, r) => { t.slow = Math.max(t.slow, 0.1 * r); t.slowDur = Math.max(t.slowDur, 1); },
      { name: 'Gravity Well', desc: 'Every 5th shot drags enemies near the blast 40 steps back along the path.', apply: t => t.gravity += 40 }),
  ],
  frost: [
    P('deep', 'Deep Freeze', 'slow', ['Glacial', 'Spire', 'Winter'], 'Slows 7% more per point (up to 85%).', t => t.slow = Math.min(0.85, t.slow + 0.07),
      { name: 'Absolute Zero', desc: 'Every enemy in range is constantly slowed by 30%.', apply: t => t.zero = Math.max(t.zero, 0.3) }),
    P('burst', 'Frost Burst', 'burst', ['Shattering', 'Burst', 'Ice'], 'Shots burst and chill every enemy nearby; +20% burst size per point.', t => t.splash = t.splash ? t.splash * 1.2 : 35,
      { name: 'Flash Freeze', desc: 'Every 6th shot freezes enemies solid for 1.2s.', apply: t => t.freeze = 6 }),
    P('linger', 'Lingering Cold', 'slow', ['Lingering', 'Veil', 'Stillness'], 'Slows last 0.8s longer per point.', t => t.slowDur += 0.8,
      { name: 'Time Lock', desc: 'Every 8th shot stuns every enemy in range for 0.6s.', apply: t => t.timeLock += 0.6 }),
    P('hypo', 'Hypothermia', 'arcane', ['Frigid', 'Rime', 'Hypothermia'], 'Each hit adds a chill stack. At 9 stacks the enemy freezes solid for 0.8s (bosses 0.3s); each point needs 1 stack fewer.', (t, r) => t.hypo = 9 - r,
      { name: 'Cold Snap', desc: 'When Hypothermia freezes an enemy, the cold bursts out and freezes every enemy within 70 for 0.5s (bosses 0.2s).', apply: t => t.coldSnap = true }),
    P('brittle', 'Brittle', 'precision', ['Brittle', 'Fang', 'Frailty'], 'Slowed enemies take +8% damage from everything per point.', t => t.brittle += 0.08,
      { name: 'Frostbite', desc: 'Hits on slowed enemies also burn them for 50% of the hit over 2s.', apply: t => t.frostfire += 0.5 }),
  ],
  tesla: [
    P('arcs', 'More Arcs', 'chain', ['Forked', 'Arc', 'Storms'], 'Lightning jumps to 1 more enemy per point.', t => t.chain += 1,
      { name: 'Storm Call', desc: 'Every 4th shot calls lightning down on 3 random enemies in range.', apply: t => t.storm += 3 }),
    P('volt', 'High Voltage', 'power', ['Charged', 'Coil', 'Voltage'], '+20% damage per point.', t => t.dmg *= 1.2,
      { name: 'Overload', desc: 'Lightning jumps have a 15% chance to stun for 0.6s.', apply: t => t.stun = Math.max(t.stun, 0.15) }),
    P('conduct', 'Conductive', 'chain', ['Conductive', 'Conduit', 'Currents'], 'Jumps lose 7% less damage per point.', t => t.chainMul = Math.min(0.95, t.chainMul + 0.07),
      { name: 'Ion Burst', desc: 'Every lightning jump explodes for 30% damage around it.', apply: t => t.chainBlast += 0.3 }),
    P('bank', 'Capacitor Bank', 'speed', ['Overclocked', 'Dynamo', 'Haste'], 'Fires 14% faster per point.', t => t.rate *= 0.86,
      { name: 'Overcharge', desc: 'Every 10th shot deals +150% damage and stuns for 0.5s.', apply: t => t.overload += 1.5 }),
    P('jump', 'Arc Reach', 'chain', ['Leaping', 'Relay', 'Reach'], 'Lightning jumps 20% farther per point.', t => t.chainReach *= 1.2,
      { name: 'Arc Storm', desc: 'Shoots 1 more enemy and lightning jumps 2 more times.', apply: t => { t.multi += 1; t.chain += 2; } }),
  ],
  beacon: [
    P('empower', 'Empower', 'power', ['Radiant', 'Beacon', 'Light'], 'Buffed towers deal +8% more damage per point.', t => t.bDmg += 0.08,
      { name: 'Overdrive', desc: 'Buffed towers crit 10% of the time for triple damage.', apply: t => t.bOverdrive = true }),
    P('haste', 'Haste', 'speed', ['Hastening', 'Pulse', 'Haste'], 'Buffed towers fire 6% faster per point.', t => t.bRate += 0.06,
      { name: 'Tempo Link', desc: 'Every 10s, buffed towers fire at double speed for 3s.', apply: t => t.bTempo = true }),
    P('reach', 'Reach', 'precision', ['Far', 'Lantern', 'Reach'], 'Buffed towers and the Beacon get +8% range per point.', t => { t.bRange += 0.08; t.range *= 1.08; },
      { name: 'Lighthouse', desc: 'Buffed towers can hit enemies within twice their range.', apply: t => t.bLight = true }),
    P('sunder', 'Sunder', 'precision', ['Sundering', 'Spike', 'Sundering'], 'Buffed towers ignore 8% armor per point.', t => t.bSunder += 0.08,
      { name: 'Armor Break', desc: 'Enemies hit by buffed towers lose 15% armor for 3s, stacking to 45%.', apply: t => t.bBreak = true }),
    P('btithe', 'Tithe', 'arcane', ['Gilded', 'Shrine', 'Fortune'], 'Kills by buffed towers give +10% gold per point.', t => t.bGold += 0.1,
      { name: 'Gold Rush', desc: 'Each kill by a buffed tower has an 8% chance to drop a 25 gold coin. Walk your hero over it (coins left at the end of a wave are collected for you).', apply: t => t.bRush = true }),
  ],
  anvil: [
    P('crush', 'Crush', 'power', ['Crushing', 'Anvil', 'Ruin'], '+15% damage per point.', t => t.dmg *= 1.15,
      { name: 'Executioner’s Weight', desc: 'Stopped enemies below 15% HP are crushed instantly (not bosses).', apply: t => t.crushExec = 0.15 }),
    P('pin', 'Pin', 'slow', ['Pinning', 'Spike', 'Chains'], 'Slams hold stopped enemies in place 0.3s longer per point (bosses half).', t => t.pin += 0.3,
      { name: 'Shackle', desc: 'Every 4th slam roots every enemy in the area for 1s, moving or not (bosses 0.5s).', apply: t => t.shackle = true }),
    P('quake', 'Quake', 'burst', ['Quaking', 'Hammer', 'Tremors'], '+10 slam radius per point.', t => t.range += 10,
      { name: 'Aftershock', desc: 'Each slam sends a second shockwave 0.5s later for 50% damage.', apply: t => t.after = true }),
    P('pressure', 'Pressure', 'precision', ['Grinding', 'Press', 'Pressure'], '+10% more damage per second stopped per point, and the cap rises by 25%.', t => { t.press += 0.1; t.pressCap += 0.25; },
      { name: 'Crushing Tide', desc: 'Pressure no longer resets when an enemy starts moving again; it fades over 3s instead.', apply: t => t.tide = true }),
    P('guardian', 'Guardian', 'slow', ['Guarding', 'Bastion', 'Wardens'], 'Your hero takes 6% less damage per point from enemies it blocks within range.', t => t.guard += 0.06,
      { name: 'Bulwark Pact', desc: 'While your hero blocks an enemy in range, the Anvil slams twice as fast.', apply: t => t.pact = true }),
  ],
  laser: [
    P('chainl', 'Chain Laser', 'chain', ['Branching', 'Prism', 'Chains'], 'The beam jumps to 1 more enemy per point at 60% of its damage (heat included).', t => { t.chain += 1; t.chainMul = Math.max(t.chainMul, 0.6); },
      { name: 'Prism Web', desc: 'Chained beams deal full damage and don’t weaken with each jump.', apply: t => { t.chainMul = 1; t.chainKeep = true; } }),
    P('focusl', 'Focusing Lens', 'precision', ['Focused', 'Lens', 'Focus'], 'Each tick on the same target adds +3% more heat damage per point.', t => t.ramp += 0.03,
      { name: 'Meltdown', desc: 'At full heat the beam deals double damage.', apply: t => t.melt = true }),
    P('sink', 'Heat Sink', 'burn', ['Smoldering', 'Core', 'Embers'], 'Holds 5 more heat stacks per point.', t => t.rampMax += 5,
      { name: 'Residual Heat', desc: 'Switching targets only halves the heat instead of resetting it.', apply: t => t.retain = true }),
    P('amp', 'Amplifier', 'power', ['Blazing', 'Emitter', 'Power'], '+20% damage per point.', t => t.dmg *= 1.2,
      { name: 'Sear', desc: 'Hits burn for 40% of their damage over 2s.', apply: t => t.burn += 0.4 }),
    P('lensr', 'Long Lens', 'precision', ['Farseeing', 'Beam', 'Reach'], '+10% range per point.', t => t.range *= 1.1,
      { name: 'Piercing Beam', desc: 'The beam also burns through 3 enemies behind its target for 60% damage.', apply: t => t.pierce += 3 }),
  ],
  mortar: [
    P('payload', 'Heavy Payload', 'power', ['Thundering', 'Mortar', 'Ruin'], '+20% damage per point.', t => t.dmg *= 1.2,
      { name: 'Bunker Buster', desc: 'Every 3rd shell deals triple damage in a double-size blast.', apply: t => t.orbital = 3 }),
    P('blast', 'Wide Blast', 'burst', ['Sprawling', 'Crater', 'Craters'], '+15% blast radius per point.', t => t.splash *= 1.15,
      { name: 'Cluster Shells', desc: 'Each shell scatters 3 bomblets at nearby enemies for 50% damage.', apply: t => t.cluster = 3 }),
    P('napalm', 'Napalm', 'burn', ['Burning', 'Brazier', 'Napalm'], 'Blasts burn for 30% of their damage over 2s per point.', t => t.burn += 0.3,
      { name: 'Firestorm', desc: 'Shells leave burning ground for 3s.', apply: t => t.firestorm = true }),
    P('reload', 'Quick Reload', 'speed', ['Rapid', 'Battery', 'Salvos'], 'Fires 12% faster per point.', t => t.rate *= 0.88,
      { name: 'Double Salvo', desc: 'Every shell is followed by a second one for 60% damage.', apply: t => t.salvo = 0.6 }),
    P('shock', 'Shockwave', 'slow', ['Shaking', 'Quake', 'Tremors'], 'Blasts slow enemies by 12% per point for 1.6s.', (t, r) => t.slow = Math.max(t.slow, 0.12 * r),
      { name: 'Earthquake', desc: 'Every 4th shell stuns everything in the blast for 0.8s (bosses 0.3s).', apply: t => t.quakeStun = true }),
  ],
};
const ELEMENT_TAG = { arcane: 'arcane', plasma: 'burn', frost: 'slow', tesla: 'chain', beacon: 'power', anvil: 'burst', laser: 'precision', mortar: 'burst' };
// Only the four elemental towers have merge recipes.
const MERGEABLE = { arcane: true, plasma: true, frost: true, tesla: true };
// Merged towers never get plain stat upgrades: their 5 paths come from this pool of effects, picked to match
// the paths their parents used. Every point also adds +8% damage on top of the effect.
const F = (id, name, tags, desc, apply) => ({ id, name, tags, desc, apply });
const FUSIONS = [
  F('chainreact', 'Chain Reaction', ['burst', 'burn'], (r, m) => `Enemies this tower kills explode for ${Math.round(8 * r * m)}% of their max HP.`, (t, m) => t.deathBlast += 0.08 * m),
  F('frostfire', 'Frostfire', ['slow', 'burn'], (r, m) => `Hits on slowed enemies burn them for ${Math.round(30 * r * m)}% of the hit, and burning enemies are slowed.`, (t, m) => t.frostfire += 0.3 * m),
  F('echo', 'Echo Shot', ['speed', 'power'], (r, m) => `Every shot repeats a moment later for ${Math.round(15 * r * m)}% damage.`, (t, m) => t.echo += 0.15 * m),
  F('shatter', 'Shatter', ['slow', 'precision'], (r, m) => `Stunned or frozen enemies take +${Math.round(25 * r * m)}% damage from this tower.`, (t, m) => t.shatter += 0.25 * m),
  F('gravity', 'Gravity Well', ['burst', 'slow'], (r, m) => `Every 5th shot drags enemies near the target ${Math.round(15 * r * m)} steps back along the path.`, (t, m) => t.gravity += 15 * m),
  F('execute', 'Executioner', ['precision', 'power'], (r, m) => `Hits finish off non-boss enemies below ${Math.round(4 * r * m)}% HP.`, (t, m) => t.execute = Math.min(0.35, t.execute + 0.04 * m)),
  F('prism', 'Prism Split', ['multi', 'arcane'], (r, m) => `Each hit splits to ${Math.round(r * m)} nearby enemies for 40% damage.`, (t, m) => t.prism += m),
  F('storm', 'Storm Call', ['chain', 'power'], (r, m) => `Every 4th shot calls lightning on ${Math.round(r * m)} random enemies in range.`, (t, m) => t.storm += m),
  F('ionburst', 'Ion Burst', ['chain', 'burst'], (r, m) => `Lightning jumps explode for ${Math.round(10 * r * m)}% damage around them.`, (t, m) => { t.chainBlast += 0.1 * m; if (!t.chain) t.chain = 2; }),
  F('timelock', 'Time Lock', ['slow', 'arcane'], (r, m) => `Every 8th shot stuns every enemy in range for ${(0.15 * r * m).toFixed(2)}s.`, (t, m) => t.timeLock += 0.15 * m),
  F('corrode', 'Corrosion', ['burn', 'precision'], (r, m) => `Hits melt armor: enemies take +${Math.round(5 * r * m)}% damage from everything for 2s.`, (t, m) => t.mark += 0.05 * m),
  F('phase', 'Phase Rounds', ['precision', 'multi'], (r, m) => `Shots pass through and hit ${Math.round(r * m)} enemies behind the target for 60% damage.`, (t, m) => t.pierce += m),
  F('gilded', 'Gilded Rounds', ['power', 'arcane'], (r, m) => `Kills by this tower drop +${Math.round(2 * r * m)} gold.`, (t, m) => t.loot += 2 * m),
  F('siphon', 'Soul Siphon', ['arcane', 'burn'], (r, m) => `Kills by this tower heal your hero ${Math.round(4 * r * m)} HP and give extra XP.`, (t, m) => t.leech += 4 * m),
  F('overload', 'Overload', ['chain', 'speed'], (r, m) => `Every 10th shot deals +${Math.round(60 * r * m)}% damage and stuns for 0.5s.`, (t, m) => t.overload += 0.6 * m),
  F('nova', 'Rift Nova', ['burst', 'arcane'], (r, m) => `Every 6th shot blasts every enemy in range for ${Math.round(20 * r * m)}% damage.`, (t, m) => t.nova += 0.2 * m),
  F('tempo', 'Tempo Field', ['speed', 'multi'], (r, m) => `Each shot makes the next one ${Math.round(4 * r * m)}% faster, up to 5 stacks (resets on a miss).`, (t, m) => t.tempo += 0.04 * m),
  F('static', 'Static Web', ['chain', 'slow'], (r, m) => `Lightning and hits slow enemies by ${Math.round(6 * r * m)}% for 1.5s.`, (t, m) => { t.slow = Math.min(0.85, Math.max(t.slow, 0.06 * m * ((t.ups.static || 0) + 1))); t.slowDur = Math.max(t.slowDur, 1.5); }),
];
// Deterministic pick: the 5 fusions that best match a set of tags; ties broken by a hash of the recipe so
// different path combos land on different sets.
function hashStr(str) { let h = 2166136261; for (let i = 0; i < str.length; i++) h = Math.imul(h ^ str.charCodeAt(i), 16777619); return h >>> 0; }
function pickFusions(tags, seed, exclude) {
  const count = k => tags.filter(x => x === k).length;
  return FUSIONS.filter(f => !exclude.includes(f.id))
    .map(f => ({ f, score: f.tags.reduce((a, k) => a + count(k), 0) * 1000 + hashStr(seed + f.id) % 1000 }))
    .sort((a, b) => b.score - a.score).slice(0, 5).map(x => x.f);
}
const RECIPES = {
  'arcane+frost':  { name: 'Rimeshard',    color: 0xc9b8ff, desc: 'Fires rapid ice shards that slow every enemy they hit. Arcane speed with Frost control.' },
  'arcane+plasma': { name: 'Starbolt',     color: 0xff6fd8, desc: 'Fires fast bolts that explode on impact. Arcane speed with Plasma splash, so it shreds groups.' },
  'arcane+tesla':  { name: 'Railgun',      color: 0x8affff, desc: 'Fires heavy bolts that arc to more enemies on hit. Huge single hits that also clear lines.' },
  'frost+plasma':  { name: 'Steam Engine', color: 0xe0e6ff, desc: 'Blasts scalding steam that splashes and slows every enemy caught in the cloud.' },
  'frost+tesla':   { name: 'Cryo Coil',    color: 0x9af0ff, desc: 'Chain lightning that slows every enemy it jumps to. Locks down whole lines.' },
  'plasma+tesla':  { name: 'Ion Storm',    color: 0xffd36e, desc: 'Explosive shells whose blast also throws lightning outward. The best crowd clearer.' },
};
// Hybrids pick from a fixed 5 of their parents' upgrades (ranks start fresh after the merge).
// Super towers: two level 13 hybrids merged together. Named after the base towers inside them.
const SUPERS = {
  'arcane+frost+plasma+tesla': { name: 'Rift Singularity', color: 0xffffff, desc: 'Holds the power of all four towers: fast bolts, explosions, deep slows and chain lightning in every shot.' },
  'arcane+frost+plasma':       { name: 'Prism Reactor',    color: 0xffa8f0, desc: 'Rapid exploding ice bolts that shred and slow whole groups.' },
  'arcane+frost+tesla':        { name: 'Aurora Lance',     color: 0xa8e8ff, desc: 'Piercing frozen lightning that slows everything it jumps through.' },
  'arcane+plasma+tesla':       { name: 'Nova Battery',     color: 0xffe08a, desc: 'Heavy bolts that explode and throw lightning across the field.' },
  'frost+plasma+tesla':        { name: 'Tempest Engine',   color: 0xc8f5ff, desc: 'A storm of scalding, freezing, crackling blasts. Nothing in range moves fast.' },
};
const MERGE_COST = 1000, MAX_LVL = 13, MERGE_LVL = 13, PATH_MAX = 4, SELL_RATE = 0.8;
// Oracle points: cumulative ranks reached after 1, 2 and 3 points.
const ORACLE_RANKS = [0, 2, 3, 4];
// Numeric tower traits; merges keep the stronger value of each.
const TRAITS = ['splash', 'slow', 'slowDur', 'chain', 'chainMul', 'chainReach', 'multi', 'ramp', 'surge', 'burn', 'brittle', 'mark', 'cluster', 'orbital', 'freeze', 'zero', 'stun',
  'prism', 'execute', 'nova', 'echo', 'deathBlast', 'gravity', 'timeLock', 'shatter', 'frostfire', 'storm', 'chainBlast', 'overload', 'pierce', 'loot', 'leech', 'tempo', 'hex', 'hexNova', 'hypo', 'coldSnap'];

// Enemies. armor = % damage taken off (capped at 60%). unslow = immune to slows (stuns still work).
// phase = only Defensive heroes can block it. first = the wave it starts showing up; per = how many each time.
const ARMOR_CAP = 0.6;
const ENEMIES = {
  grunt:  { name: 'Grunt',  hp: 55,   speed: 52,  gold: 5,   lives: 1,  atk: 8,  r: 9,  color: 0xff5d6c },
  runner: { name: 'Runner', hp: 35,   speed: 100, gold: 4,   lives: 1,  atk: 5,  r: 7,  color: 0xffb35d },
  brute:  { name: 'Brute',  hp: 220,  speed: 34,  gold: 12,  lives: 3,  atk: 20, r: 13, color: 0xd14b8f, armor: 0.15 },
  wraith: { name: 'Wraith', hp: 45,   speed: 120, gold: 5,   lives: 1,  atk: 6,  r: 8,  color: 0x9ad8ff, unslow: true, first: 6, per: 2 },
  phantom:{ name: 'Phantom', hp: 70,  speed: 70,  gold: 7,   lives: 2,  atk: 10, r: 9,  color: 0xc8b8ff, phase: true, first: 7, per: 2 },
  splitter:{ name: 'Splitter', hp: 150, speed: 45, gold: 8,  lives: 2,  atk: 14, r: 12, color: 0x7fe07f, split: 2, first: 8, per: 1 },
  juggernaut:{ name: 'Juggernaut', hp: 600, speed: 26, gold: 25, lives: 4, atk: 35, r: 16, color: 0x9a7a66, armor: 0.3, unslow: true, first: 9, per: 1 },
  shieldbearer:{ name: 'Shieldbearer', hp: 260, speed: 38, gold: 15, lives: 3, atk: 18, r: 13, color: 0xd8b84a, armor: 0.2, shieldAura: 0.15, first: 11, per: 1 },
  mender: { name: 'Mender', hp: 120,  speed: 48,  gold: 12,  lives: 2,  atk: 8,  r: 10, color: 0x7dffb0, heal: 0.03, first: 12, per: 1 },
  knight: { hp: 1100, speed: 30, gold: 60,  lives: 5,  atk: 30, r: 16, color: 0xff2e4d, boss: true, name: 'Rift Knight', armor: 0.25 },
  warden: { hp: 3000, speed: 26, gold: 120, lives: 10, atk: 45, r: 18, color: 0xff2e4d, boss: true, name: 'Rift Warden', armor: 0.3 },
  tyrant: { hp: 9000, speed: 22, gold: 300, lives: 20, atk: 80, r: 23, color: 0xff2e4d, boss: true, name: 'Rift Tyrant', armor: 0.35, unslow: true },
};
const SPECIAL_ENEMIES = ['wraith', 'phantom', 'splitter', 'juggernaut', 'shieldbearer', 'mender'];
// Codex text: what each enemy does and how to beat it.
const ENEMY_INFO = {
  grunt: ['No special trait.', 'Anything works.'],
  runner: ['Fast.', 'Slows and chain lightning.'],
  brute: ['15% armor.', 'Big hits, burns and Hex Brand ignore or shrug off armor.'],
  wraith: ['Very fast and can’t be slowed.', 'Stuns still work. Chain lightning and long range.'],
  phantom: ['Only Defensive heroes can block it.', 'The Vanguard stops it. Everyone else has to shoot it down.'],
  splitter: ['Splits into 2 Runners when it dies.', 'Splash and chain damage clean up the pieces.'],
  juggernaut: ['30% armor, huge HP and can’t be slowed.', 'Burns, Hex Brand, Brittle, Sunder and the Grave Anvil.'],
  shieldbearer: ['20% armor and gives enemies within 70 +15% armor.', 'Kill it first; Sunder and Armor Break cut through.'],
  mender: ['Heals enemies within 70 for 3% of their max HP every second.', 'Focus it first. Sniper Spotter and Headhunter help.'],
  knight: ['25% armor. Shield Bash: every 8s stuns the nearest tower for 2s.', 'Spread your towers out.'],
  warden: ['30% armor. Rift Lock: every 10s stuns 2 random towers for 3s. Summons Grunts at 75%, 50% and 25% HP.', 'Grounded makes stuns shorter.'],
  tyrant: ['35% armor, can’t be slowed. Roar: every 12s stuns 3 towers and knocks your hero back. Enrages at 50% HP and summons 2 Juggernauts.', 'Stuns still work. Save your ability for the enrage.'],
};

// ---------- heroes ----------
// The Vanguard has no block limit: it holds every enemy that walks into it.
const ALL_BLOCK = 999;
const blockText = n => n >= ALL_BLOCK ? 'All' : String(n);
const HEROES = {
  vanguard: { name: 'Vanguard', role: 'Defensive', cat: 'defensive', color: 0x5fe39a, css: '#5fe39a',
    desc: 'A walking fortress. Huge HP, blocks every enemy that reaches it and stuns crowds.',
    stats: { hp: 340, dmg: 8, rate: 0.7, range: 80, block: ALL_BLOCK, armor: 0.1, regen: 5, speed: 135 },
    ability: { id: 'slam', name: 'Shield Slam', cd: 18, dmg: 30, r: 100, stun: 1.5 },
    alt: { id: 'bulwark', name: 'Bulwark Shield', cd: 18, dmg: 30, r: 110, dur: 5 } },
  striker:  { name: 'Striker', role: 'Offensive', cat: 'offensive', color: 0xff8a7a, css: '#ff8a7a',
    desc: 'Fast and deadly but fragile. Shreds enemies and blasts groups with Rift Nova.',
    stats: { hp: 180, dmg: 12, rate: 0.5, range: 115, block: 1, armor: 0, regen: 2, speed: 165 },
    ability: { id: 'nova', name: 'Rift Nova', cd: 20, dmg: 40, r: 110 },
    alt: { id: 'overdrive', name: 'Overdrive', cd: 20, dur: 5, power: 1 } },
  oracle:   { name: 'Oracle', role: 'Support', cat: 'support', color: 0xb07cff, css: '#b07cff',
    desc: 'Empowers towers. Nearby towers deal +15% damage, Overclock Field makes them fire much faster, and towers use 4 upgrade paths of 3 bigger points instead of 3 paths of 4.',
    stats: { hp: 210, dmg: 7, rate: 0.6, range: 100, block: 2, armor: 0, regen: 3, speed: 150, aura: 0.15 },
    ability: { id: 'overclock', name: 'Overclock Field', cd: 24, r: 170, dur: 6, power: 0.6 },
    alt: { id: 'stasis', name: 'Stasis Field', cd: 24, r: 170, dur: 6, power: 0.6 } },
  sniper:   { name: 'Sniper', role: 'Offensive', cat: 'offensive', color: 0xffd36e, css: '#ffd36e', unlock: 250,
    desc: 'Hits anything on the map, but has to stand still and brace before every shot. Slow, heavy, precise.',
    stats: { hp: 170, dmg: 48, rate: 2.4, range: 9999, block: 1, armor: 0, regen: 2, speed: 140, brace: 1.2, crit: 0.1 },
    ability: { id: 'pierce', name: 'Piercing Shot', cd: 16, mult: 4, w: 18 },
    alt: { id: 'strike', name: 'Orbital Strike', cd: 16, mult: 5, r: 90 } },
};
// Each hero has two abilities to choose from on the Heroes page; the choice is saved in META.abilities.
const heroAbility = k => (META.abilities && META.abilities[k] === 'alt' && HEROES[k].alt) || HEROES[k].ability;
const abName = () => S && S.hero ? S.hero.ab.name : 'Your ability';
const isUnlocked = id => !HEROES[id].unlock || !!META.unlocked[id];
const CATEGORIES = [['offensive', 'Offensive'], ['defensive', 'Defensive'], ['support', 'Support'], ['special', 'Special']];
const heroesIn = cat => Object.entries(HEROES).filter(([, h]) => h.cat === cat);
// Hover box for a hero's ability: exact numbers, what each upgrade adds, and the controls.
function abilityTipHtml(h) {
  const a = h.ab, rows = [];
  if (a.id === 'slam') rows.push(['Damage', a.dmg.toFixed(0)], ['Radius', (a.r * (a.magnet ? 1.5 : 1)).toFixed(0)], ['Stun', a.stun.toFixed(1) + 's']);
  if (a.id === 'nova') rows.push(['Damage', a.dmg.toFixed(0)], ['Radius', a.r.toFixed(0)]);
  if (a.id === 'overclock') rows.push(['Radius', a.r.toFixed(0)], ['Towers fire faster', pct(a.power)], ['Lasts', a.dur.toFixed(1) + 's']);
  if (a.id === 'bulwark') rows.push(['Shield', (a.dmg * 5 * (a.overflow ? 1.5 : 1)).toFixed(0)], ['Burst', a.dmg.toFixed(0) + ' + 60% soaked'], ['Lasts', a.dur.toFixed(1) + 's']);
  if (a.id === 'overdrive') rows.push(['Attack speed', '+' + pct(a.power)], ['Lasts', a.dur.toFixed(1) + 's']);
  if (a.id === 'strike') rows.push(['Damage', h.dmg ? (h.dmg * a.mult).toFixed(0) + ' (' + a.mult.toFixed(1) + '× hero damage)' : a.mult.toFixed(1) + '× hero damage'], ['Radius', a.r.toFixed(0)]);
  if (a.id === 'stasis') rows.push(['Radius', a.r.toFixed(0)], ['Slow', pct(Math.min(0.85, a.power * 0.75))], ['Lasts', a.dur.toFixed(1) + 's']);
  if (a.id === 'pierce') rows.push(['Damage per enemy', h.dmg ? (h.dmg * a.mult).toFixed(0) + ' (' + a.mult.toFixed(1) + '× hero damage)' : a.mult.toFixed(1) + '× hero damage'], ['Width', (a.w * (a.rail ? 3 : 1)).toFixed(0)]);
  rows.push(['Cooldown', a.cd.toFixed(1) + 's']);
  const mods = ABILITY_MODS.filter(m => a[m.id]);
  const extra = { slam: h.taunt ? `After the slam, enemies within 120 attack you for ${h.taunt.toFixed(1)}s (bosses half).` : '',
    pierce: 'Press F to set an aim point and it always fires that way. Press F on the point to clear it.',
    strike: 'Press F to set an aim point and the strike always lands there.',
    overclock: '', nova: '' }[a.id];
  return `<b>${a.name}</b> <span class="tip-c">Q</span><p>${abilityText(h)}</p>
    <div class="tip-s">${rows.map(([k, v]) => `${k}: <b>${v}</b>`).join(' · ')}</div>
    ${mods.length ? `<ul>${mods.map(m => `<li><b class="rar-mythic">${m.name}:</b> ${m.desc}</li>`).join('')}</ul>` : ''}
    ${extra ? `<div class="tip-s">${extra}</div>` : ''}`;
}
function tipFor(key) {
  if (key === 'ability' && S && S.hero) return abilityTipHtml(S.hero);
  if (key.startsWith('ability:')) { const parts = key.split(':'), d = HEROES[parts[1]], ab = parts[2] === 'alt' ? d.alt : parts[2] === 'base' ? d.ability : heroAbility(parts[1]); return abilityTipHtml({ ab: Object.assign({}, ab), dmg: d.stats.dmg, taunt: 0 }); }
  if (key.startsWith('mod:')) { const m = ABILITY_MODS.find(x => x.id === key.slice(4)); return m ? `<b>${m.name}</b><p>${m.desc}</p>` : ''; }
  if (key === 'hold') return `<b>Hold position</b> <span class="tip-c">H</span><p>Locks your hero in place so right-clicks, movement keys and taps don’t move it. Press H again to move.</p>`;
  if (key === 'aim') return `<b>Aim point</b> <span class="tip-c">F</span><p>Point at the board and press F: Piercing Shot always fires from your Sniper toward that spot, wherever it stands. Press F on the point (or click this button) to clear it.</p>`;
  return '';
}
document.addEventListener('mouseover', e => {
  const el = e.target.closest && e.target.closest('[data-tip]');
  if (!el) return;
  const html = tipFor(el.dataset.tip); if (!html) return;
  showTip(html, el.getBoundingClientRect(), el.closest('#buildBar') ? 'above' : 'below');
  el.addEventListener('mouseleave', hideTip, { once: true });
});
function abilityText(h) {
  const a = h.ab;
  if (a.id === 'slam') return `Deals ${a.dmg.toFixed(0)} damage and stuns enemies within ${a.r.toFixed(0)} for ${a.stun.toFixed(1)}s.`;
  if (a.id === 'nova') return `Deals ${a.dmg.toFixed(0)} damage to every enemy within ${a.r.toFixed(0)}.`;
  if (a.id === 'pierce') return `Fires a round through every enemy in a line toward your aim point (or the lead enemy) for ${a.mult.toFixed(1)}× damage.`;
  if (a.id === 'bulwark') return `Raises a shield that soaks ${(a.dmg * 5 * (a.overflow ? 1.5 : 1)).toFixed(0)} damage for ${a.dur.toFixed(1)}s. When it breaks or ends it bursts, hitting enemies within ${a.r.toFixed(0)} for ${a.dmg.toFixed(0)} plus 60% of what it soaked.`;
  if (a.id === 'overdrive') return `For ${a.dur.toFixed(1)}s you attack ${pct(a.power)} faster.`;
  if (a.id === 'strike') return `Calls a strike on your aim point (or the toughest enemy). After 0.8s it hits everything within ${a.r.toFixed(0)} for ${a.mult.toFixed(1)}× damage.`;
  if (a.id === 'stasis') return `Enemies within ${a.r.toFixed(0)} of where you cast it are slowed ${pct(Math.min(0.85, a.power * 0.75))} for ${a.dur.toFixed(1)}s.`;
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
  // Shared pools: 'any' is every hero; 'offensive' / 'defensive' / 'support' are heroes of that category.
  { id: 'blade',   cls: 'offensive', name: 'Plasma Blade',  m: 0.2,  desc: m => `+${pct(m)} hero damage.`, apply: (h, m) => h.dmg *= 1 + m },
  { id: 'plate',   cls: 'defensive', name: 'Rune Plating',  m: 50,   desc: m => `+${Math.round(m)} max HP and a full heal.`, apply: (h, m) => { h.maxHp += Math.round(m); h.hp = h.maxHp; } },
  { id: 'mend',    cls: 'defensive', name: 'Nanite Mend',   m: 3,    desc: m => `+${m.toFixed(1)} HP regen per second.`, apply: (h, m) => h.regen += m },
  { id: 'reboot',  cls: 'any', name: 'Quick Reboot',  m: 0.15, desc: m => `Respawn ${pct(Math.min(0.7, m))} faster and +${pct(m)} max HP.`, apply: (h, m) => { h.respawn = Math.max(2, h.respawn * (1 - Math.min(0.7, m))); h.maxHp = Math.round(h.maxHp * (1 + m)); h.hp = Math.min(h.maxHp, h.hp + h.maxHp * m); } },
  { id: 'arch',    cls: 'support', name: 'Architect',     m: 0.07, desc: m => `New towers cost ${pct(Math.min(0.5, m))} less to build.`, apply: (h, m) => h.costMul *= 1 - Math.min(0.5, m) },
  { id: 'engineer',cls: 'support', name: 'Engineer',      m: 0.08, desc: m => `Tower upgrades (level-ups) cost ${pct(Math.min(0.5, m))} less.`, apply: (h, m) => h.lvlMul *= 1 - Math.min(0.5, m) },
  { id: 'reach',   cls: 'support', name: 'Long Reach',    m: 0.2,  desc: m => `+${pct(m)} build range and all towers get +${pct(m / 4)} range.`, apply: (h, m) => { h.buildRange *= 1 + m; h.towerRange += m / 4; } },
  { id: 'bounty',  cls: 'offensive', name: 'Bounty Sigil', m: 2, desc: m => `Enemies your hero kills drop +${Math.max(1, Math.round(m))} gold.`, apply: (h, m) => h.bounty += Math.max(1, Math.round(m)) },
  { id: 'tithe',   cls: 'defensive', also: ['support'], name: 'War Tithe', m: 0.6, desc: m => `Every enemy killed by your towers or your hero drops +${Math.max(1, Math.round(m))} gold.`, apply: (h, m) => h.tithe += Math.max(1, Math.round(m)) },
  { id: 'siphon',  cls: 'defensive', name: 'Siphon',        m: 3,    desc: m => `Heal ${Math.round(m)} HP for every kill.`, apply: (h, m) => h.siphon += Math.round(m) },
  { id: 'grounded', cls: 'any', name: 'Grounded', m: 0.5, desc: m => `Boss stuns on your towers last ${pct(Math.min(0.8, m))} less (up to 80%).`, apply: (h, m) => h.grounded = 1 - (1 - h.grounded) * (1 - Math.min(0.8, m)) },
  { id: 'boots',   cls: 'any', name: 'Rift Boots',    m: 0.15, desc: m => `+${pct(m)} move speed and +${pct(m / 2)} attack speed.`, apply: (h, m) => { h.speed *= 1 + m; h.rate /= 1 + m / 2; } },
  // Vanguard
  { id: 'taunt',   cls: 'vanguard', name: 'Taunt',         m: 2,    desc: m => `After Shield Slam, enemies within 120 stop and attack you for ${m.toFixed(1)}s.`, apply: (h, m) => h.taunt += m },
  { id: 'shell',   cls: 'vanguard', name: 'Hardlight Shell', m: 0.08, desc: m => `Take ${pct(m)} less damage (up to 75%).`, apply: (h, m) => h.armor = Math.min(0.75, h.armor + m) },
  { id: 'thorns',  cls: 'vanguard', name: 'Thorn Field',   m: 8,    desc: m => `Enemies you block take ${Math.round(m)} damage per second.`, apply: (h, m) => h.thorns += m },
  { id: 'seismic', cls: 'vanguard', name: 'Seismic Power',  m: 0.3,  desc: m => `${abName()} is +${pct(m)} stronger (damage${S && S.hero && S.hero.ab.id === 'bulwark' ? ', shield size' : ''}).`, apply: (h, m) => h.ab.dmg *= 1 + m },
  { id: 'after',   cls: 'vanguard', name: 'Aftershock',    m: 0.1,  desc: m => `${abName()} recharges ${pct(Math.min(0.5, m))} faster.`, apply: (h, m) => h.ab.cd = Math.max(6, h.ab.cd * (1 - Math.min(0.5, m))) },
  { id: 'daze',    cls: 'vanguard', ab: 'slam', name: 'Concussion',    m: 0.4,  desc: m => `Shield Slam stuns ${m.toFixed(1)}s longer.`, apply: (h, m) => h.ab.stun += m },
  { id: 'fort',    cls: 'defensive', name: 'Fortify',       m: 0.15, desc: m => `+${pct(m)} max HP.`, apply: (h, m) => { h.maxHp = Math.round(h.maxHp * (1 + m)); h.hp = h.maxHp; } },
  // Striker
  { id: 'crit',    cls: 'offensive', name: 'Weak Point', m: 0.08, desc: m => `+${pct(m)} crit chance.`, apply: (h, m) => h.crit = Math.min(0.75, h.crit + m) },
  { id: 'critdmg', cls: 'offensive', name: 'Lethal Edge', m: 0.25, desc: m => `+${pct(m)} crit damage.`, apply: (h, m) => h.critDmg += m },
  { id: 'split',   cls: 'striker', name: 'Split Shot',     m: 1,    desc: m => `Attacks hit ${Math.max(1, Math.round(m))} more enemy.`, apply: (h, m) => h.multi = Math.min(6, h.multi + Math.max(1, Math.round(m))) },
  { id: 'scope',   cls: 'striker', name: 'Long Barrel',    m: 0.12, desc: m => `+${pct(m)} attack range.`, apply: (h, m) => h.range *= 1 + m },
  { id: 'clock',   cls: 'striker', name: 'Overclock',      m: 0.15, desc: m => `+${pct(m)} attack speed.`, apply: (h, m) => h.rate /= 1 + m },
  { id: 'core',    cls: 'striker', ab: 'nova', name: 'Nova Core',      m: 0.3,  desc: m => `Rift Nova deals +${pct(m)} damage.`, apply: (h, m) => h.ab.dmg *= 1 + m },
  { id: 'nfocus',  cls: 'striker', name: 'Rift Focus',     m: 0.1,  desc: m => `${abName()} recharges ${pct(Math.min(0.5, m))} faster.`, apply: (h, m) => h.ab.cd = Math.max(6, h.ab.cd * (1 - Math.min(0.5, m))) },
  { id: 'wide',    cls: 'striker', ab: 'nova', name: 'Wide Nova',      m: 0.12, desc: m => `Rift Nova radius +${pct(m)}.`, apply: (h, m) => h.ab.r *= 1 + m },
  { id: 'momentum',cls: 'striker', name: 'Momentum',      m: 0.03, desc: m => `Each kill by your hero gives +${pct(m)} attack speed for 4s, stacking up to 10 times.`, apply: (h, m) => h.momentum += m },
  // Oracle
  { id: 'rapid',   cls: 'oracle', name: 'Rapid Construction', m: 0.6, desc: m => `Towers you build within your aura get their first ${Math.max(1, Math.round(m))} level-up${Math.round(m) > 1 ? 's' : ''} free.`, apply: (h, m) => h.rapid += Math.max(1, Math.round(m)) },
  { id: 'aura',    cls: 'oracle', name: 'Commander Aura',  m: 0.08, desc: m => `Towers near you deal +${pct(m)} more damage.`, apply: (h, m) => h.aura += m },
  { id: 'signal',  cls: 'oracle', name: 'Signal Boost',    m: 0.15, desc: m => `Aura reaches ${pct(m)} farther and all towers get +${pct(m / 3)} range.`, apply: (h, m) => { h.auraRange *= 1 + m; h.towerRange += m / 3; } },
  { id: 'surge',   cls: 'oracle', name: 'Power Surge',     m: 0.15, desc: m => S && S.hero && S.hero.ab.id === 'stasis' ? `Stasis Field slows ${pct(m * 0.75)} more.` : `Overclock Field speeds towers up ${pct(m)} more.`, apply: (h, m) => h.ab.power += m },
  { id: 'extend',  cls: 'oracle', name: 'Extended Field',  m: 1.5,  desc: m => `${abName()} lasts ${m.toFixed(1)}s longer.`, apply: (h, m) => h.ab.dur += m },
  { id: 'chill',   cls: 'oracle', name: 'Chilling Presence', m: 0.08, desc: m => `Towers near you also slow enemies by ${pct(m)}.`, apply: (h, m) => h.auraSlow = Math.min(0.6, h.auraSlow + m) },
  { id: 'interest',cls: 'oracle', name: 'Investments',     m: 0.03, desc: m => `Earn ${pct(m)} interest on your gold after each wave.`, apply: (h, m) => h.interest += m },
  // Sniper
  { id: 'brace',   cls: 'sniper', name: 'Quick Brace',     m: 0.15, desc: m => `Brace ${pct(Math.min(0.6, m))} faster.`, apply: (h, m) => h.brace = Math.max(0.25, h.brace * (1 - Math.min(0.6, m))) },
  { id: 'caliber', cls: 'sniper', name: 'Heavy Caliber',   m: 0.25, desc: m => `+${pct(m)} hero damage.`, apply: (h, m) => h.dmg *= 1 + m },
  { id: 'chamber', cls: 'sniper', name: 'Fast Chamber',    m: 0.12, desc: m => `+${pct(m)} attack speed.`, apply: (h, m) => h.rate /= 1 + m },
  { id: 'penetrate', cls: 'sniper', name: 'Penetrator',    m: 1,    desc: m => `Shots also hit ${Math.max(1, Math.round(m))} enemy near the target for 50% damage.`, apply: (h, m) => h.pierce += Math.max(1, Math.round(m)) },
  { id: 'apround', cls: 'sniper', name: 'Armor-Piercing Rounds', m: 0.3, desc: m => `${abName()} deals +${pct(m)} damage.`, apply: (h, m) => h.ab.mult *= 1 + m },
  { id: 'spotter', cls: 'sniper', name: 'Spotter',         m: 0.1,  desc: m => `Your target takes +${pct(m)} damage from towers for 3s.`, apply: (h, m) => h.spotter += m },
  { id: 'headhunter', cls: 'sniper', name: 'Headhunter',  m: 0.25, desc: m => `+${pct(m)} hero damage to bosses.`, apply: (h, m) => h.headhunter += m },
  { id: 'steady',  cls: 'sniper', name: 'Steady Aim',      m: 0.1,  desc: m => `${abName()} recharges ${pct(Math.min(0.5, m))} faster.`, apply: (h, m) => h.ab.cd = Math.max(5, h.ab.cd * (1 - Math.min(0.5, m))) },
  { id: 'barrier', cls: 'vanguard', ab: 'bulwark', name: 'Hardened Barrier', m: 1, desc: m => `Bulwark Shield lasts ${m.toFixed(1)}s longer.`, apply: (h, m) => h.ab.dur += m },
  { id: 'adren',   cls: 'striker', ab: 'overdrive', name: 'Adrenaline', m: 1, desc: m => `Overdrive lasts ${m.toFixed(1)}s longer.`, apply: (h, m) => h.ab.dur += m },
  { id: 'redline', cls: 'striker', ab: 'overdrive', name: 'Redline', m: 0.25, desc: m => `Overdrive gives +${pct(m)} more attack speed.`, apply: (h, m) => h.ab.power += m },
  { id: 'payload', cls: 'sniper', ab: 'strike', name: 'Bigger Payload', m: 0.15, desc: m => `Orbital Strike blast is ${pct(m)} wider.`, apply: (h, m) => h.ab.r *= 1 + m },
  { id: 'alchemy', cls: 'support', name: 'Alchemist',       m: 0.15, desc: m => `Tower merges cost ${pct(Math.min(0.8, m))} less.`, apply: (h, m) => h.mergeMul *= 1 - Math.min(0.8, m) },
];
// Every hero level also grows the hero's core stats, by role. Damage heroes hit harder, reach farther and
// attack faster; tanks get HP, damage reduction and a little regen; support heroes get range and XP gain.
const ROLE_LEVEL = {
  offensive: { text: '+2% damage, +1% range, +1.5% attack speed', apply: h => { h.dmg *= 1.02; if (h.range < 9999) h.range *= 1.01; h.rate /= 1.015; } },
  defensive: { text: '+3% max HP, +0.5% damage reduction, +0.2% of max HP as regen per second',
    apply: h => { const add = Math.round(HEROES[h.cls].stats.hp * 0.03); h.maxHp += add; h.hp = Math.min(h.maxHp, h.hp + add); h.armor = Math.min(0.75, h.armor + 0.005); h.regen += h.maxHp * 0.002; } },
  support:   { text: '+1% range and aura reach, +1% XP gain', apply: h => { if (h.range < 9999) h.range *= 1.01; h.auraRange *= 1.01; h.xpGain += 0.01; } },
};
function levelHero(h) {
  h.xp -= h.next; h.lvl++; h.next = Math.round(h.next * 1.3); S.pendingLevels++;
  const r = ROLE_LEVEL[HEROES[h.cls].cat]; if (r) r.apply(h);
}
// Ability upgrades: they change what the hero's ability does. Offered at Rare or better, never Demonic.
const BASE_AB = { vanguard: 'slam', striker: 'nova', oracle: 'overclock', sniper: 'pierce' };
const AM = (cls, id, name, desc, ab) => ({ id, cls, ab: ab || BASE_AB[cls], name, desc, fixed: true, mod: true, apply: h => { h.ab[id] = true; } });
const ABILITY_MODS = [
  AM('vanguard', 'rings',   'Shockwave Rings', 'Shield Slam sends out 3 expanding rings that each hit for 40% damage and push enemies back.'),
  AM('vanguard', 'magnet',  'Magnetic Slam',   'Shield Slam reaches 50% farther and drags every enemy it hits back along the path.'),
  AM('vanguard', 'molten',  'Molten Crater',   'Shield Slam leaves a glowing crater for 4s that burns and slows enemies inside.'),
  AM('vanguard', 'echo',    'Echo Slam',       'A second slam hits 1s later for 50% damage.'),
  AM('striker',  'twin',    'Twin Nova',       'A second nova bursts on the toughest enemy on the map.'),
  AM('striker',  'hole',    'Black Hole',      'Rift Nova first holds enemies in a vortex for 1.5s, then explodes for 150% damage.'),
  AM('striker',  'chainN',  'Chain Nova',      'Every enemy Rift Nova kills sets off a smaller nova of its own.'),
  AM('striker',  'dash',    'Nova Dash',       'You dash toward the cursor before the nova, leaving a burning trail.'),
  AM('oracle',   'mobile',  'Mobile Field',    'Overclock Field follows you around.'),
  AM('oracle',   'chrono',  'Chrono Field',    'Enemies inside Overclock Field are slowed 30%, and tower shots inside it jump to 1 more enemy.'),
  AM('oracle',   'burst',   'Overcharge Burst', 'When Overclock Field ends, every tower inside fires one 3× damage shot.'),
  AM('oracle',   'prismF',  'Prism Field',     'Towers inside Overclock Field fire a bonus beam at a second enemy.'),
  AM('sniper',   'rail',    'Railgun',         'Piercing Shot is 3× wider and leaves a burning line for 3s.'),
  AM('sniper',   'bounce',  'Ricochet Round',  'Piercing Shot bounces through 5 more enemies after its line.'),
  AM('sniper',   'cluster', 'Cluster Round',   'Every enemy Piercing Shot hits explodes for 40% damage around it.'),
  AM('vanguard', 'spiked',  'Spiked Barrier',  'While Bulwark Shield is up, enemies you block take 40 damage per second.', 'bulwark'),
  AM('vanguard', 'overflow','Overflowing Shield', 'Bulwark Shield is 50% bigger, and whatever is left of it when it ends heals you.', 'bulwark'),
  AM('striker',  'bloodrush','Blood Rush',     'Each kill during Overdrive extends it by 0.4s (up to 4s more).', 'overdrive'),
  AM('striker',  'afterimg','Afterimage',      'During Overdrive your attacks hit 2 more enemies.', 'overdrive'),
  AM('oracle',   'shatterS','Shattering Stasis', 'Enemies inside Stasis Field take +25% damage from everything.', 'stasis'),
  AM('oracle',   'anchor',  'Rift Anchor',     'Casting Stasis Field freezes every enemy inside it solid for 1.5s (bosses 0.5s).', 'stasis'),
  AM('sniper',   'carpet',  'Carpet Strike',   'Orbital Strike drops 3 more blasts around the target for 50% damage.', 'strike'),
  AM('sniper',   'scorch',  'Scorched Earth',  'Orbital Strike leaves burning ground for 4s.', 'strike'),
  AM('sniper',   'execR',   'Execution Round', 'Piercing Shot kills non-boss enemies below 30% HP, and each kill refunds 10% of its cooldown (up to 40% per shot).'),
];
// Unique upgrades that only appear at Legendary (per hero) or Secret (any hero).
const UNIQUES = [
  { id: 'aegis',  cls: 'vanguard', rarity: 'legendary', name: 'Aegis Core',     desc: 'Take 20% less damage and gain 150 max HP.', apply: h => { h.maxHp += 50; h.armor = Math.min(0.75, h.armor + 0.2); h.maxHp += 100; h.hp = h.maxHp; } },
  { id: 'unbreak',cls: 'vanguard', rarity: 'legendary', name: 'Unbreakable',    desc: 'Once per wave, a fatal blow leaves you at full HP instead.', apply: h => h.unbreakable = true },
  { id: 'exec',   cls: 'striker',  rarity: 'legendary', name: 'Executioner',    desc: '+20% damage. Your hits instantly finish non-boss enemies below 15% HP.', apply: h => { h.dmg *= 1.2; h.execute = 0.15; } },
  { id: 'stasisL', cls: 'oracle', ab: 'stasis', rarity: 'legendary', name: 'Frozen Moment', desc: 'Stasis Field is 30% wider and every tower inside it fires 30% faster.', apply: h => { h.ab.r *= 1.3; h.ab.haste = 0.3; } },
  { id: 'storm',  cls: 'striker',  rarity: 'legendary', name: 'Bullet Storm',   desc: 'Every 3rd attack hits every enemy in range.', apply: h => h.bulletStorm = 3 },
  { id: 'master', cls: 'oracle',   rarity: 'legendary', name: 'Master Architect', desc: 'All towers deal +25% damage, and new towers cost 20% less to build.', apply: h => { S.mod.towerDmg += 0.25; h.costMul *= 0.8; } },
  { id: 'warp',   cls: 'oracle', ab: 'overclock', rarity: 'legendary', name: 'Time Warp',      desc: 'Overclock Field also slows enemies inside it by 40%.', apply: h => h.timeWarp = 0.4 },
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
  { desc: k => `New towers cost ${Math.round(8 * k)}% more to build.`, apply: k => S.hero.costMul *= 1 + 0.08 * k },
  { desc: k => `Lose ${Math.round(60 * k)} gold.`, apply: k => S.gold = Math.max(0, S.gold - Math.round(60 * k)) },
  { desc: k => `Enemies move ${Math.round(4 * k)}% faster.`, apply: k => S.mod.enemySpeed += 0.04 * k },
];

// Boss drops: heroic powers with 3 ranks.
const HEROICS = [
  // Saved for a future melee hero: not offered to anyone right now.
  { id: 'blades', for: [], name: 'Orbiting Blades', desc: r => `${r + 1} blades circle your hero, each dealing ${20 * r} damage per second to enemies they touch.` },
  { id: 'retribution', for: ['vanguard'], name: 'Retribution', desc: r => `Every 4s, a shockwave hits enemies within 110 of your hero for ${20 * r} damage plus ${30 * r}% of the damage you took since the last one.` },
  { id: 'barrage', for: ['striker'], name: 'Rift Barrage', desc: r => `Every 5s, fire ${2 + 2 * r} homing rift missiles at enemies near your hero, each dealing 150% hero damage + ${10 * r}.` },
  { id: 'drone',  for: ['striker', 'oracle'], name: 'Turret Drone',    desc: r => `${r} drone${r > 1 ? 's' : ''} fly beside your hero and shoot the nearest enemy for ${10 + 8 * r} damage.` },
  { id: 'timestop', for: ['oracle', 'sniper'], name: 'Time Stop',     desc: r => `Every 25s, every enemy on the map freezes for ${1 + r}s.` },
  { id: 'wither', for: ['vanguard'], name: 'Withering Aura',  desc: r => `Enemies within ${90 + 20 * r} of your hero take ${10 * r} damage per second and are slowed 20%.` },
  { id: 'chainstrike', for: ['striker'], name: 'Chain Strike', desc: r => `Your attacks jump to ${1 + r} more enemies for 60% damage.` },
  { id: 'goldrush', for: ['oracle'], name: 'Gold Rush',     desc: r => `Kills have a ${8 * r}% chance to drop 15 bonus gold.` },
  { id: 'phoenix', for: ['vanguard'], name: 'Phoenix Rebirth', desc: r => `When knocked out, explode for ${150 * r} damage and respawn in 2s.` },
  { id: 'ricochet', for: ['sniper'], name: 'Ricochet', desc: r => `Your shots bounce to ${r} more enem${r > 1 ? 'ies' : 'y'} for 50% damage.` },
  { id: 'marked', for: ['sniper'], name: 'Marked for Death', desc: r => `Every 5th shot marks its target for 4s: marked enemies take +${20 * r}% damage from everything.` },
];

// ---------- wave rewards ----------
const RELICS = [
  { id: 'overcharger', name: 'Overcharger',    desc: 'All towers deal +15% damage.', apply: () => S.mod.towerDmg += 0.15 },
  { id: 'cryocore',    name: 'Cryo Core',      desc: 'All slows are 15% stronger.', apply: () => S.mod.slow += 0.15 },
  { id: 'treasury',    name: 'Rift Treasury',  desc: '+25% gold from kills.', apply: () => S.mod.gold += 0.25 },
  { id: 'lens',        name: 'Farsight Lens',  desc: 'All towers +12% range.', apply: () => S.hero.towerRange += 0.12 },
  { id: 'warbanner',   offensive: true, name: 'War Banner',     desc: 'Hero deals +25% damage.', apply: () => S.hero.dmg *= 1.25 },
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

// Boss shop: opens after every 10th wave. Items are only sold here. 1% of shops are demonic: half the items
// are demonic versions (double strength, with a curse).
const SHOP_ITEMS = [
  { id: 'conduit',  kind: 'Tower', name: 'Rift Conduit',     cost: 300, m: 0.2,  desc: m => `All towers deal +${pct(m)} damage.`, apply: m => S.mod.towerDmg += m },
  { id: 'hyper',    kind: 'Tower', name: 'Hyperclock Array', cost: 320, m: 0.12, desc: m => `All towers fire ${pct(m)} faster.`, apply: m => S.mod.towerRate *= 1 - Math.min(0.5, m) },
  { id: 'matrix',   kind: 'Tower', name: 'Farsight Matrix',  cost: 220, m: 0.12, desc: m => `All towers get +${pct(m)} range.`, apply: m => S.hero.towerRange += m },
  { id: 'codex',    kind: 'Tower', name: 'Mastery Codex',    cost: 450, m: 1,    desc: m => `Every tower can use ${m} more upgrade path${m > 1 ? 's' : ''}.`, apply: m => S.pathBonus += m },
  { id: 'primer',   kind: 'Tower', name: 'Path Primer',      cost: 260, m: 3,    desc: m => `Your next ${m} tower upgrades are free.`, apply: m => S.freeLevels += m },
  { id: 'catalyst', kind: 'Tower', name: 'Merge Catalyst',   cost: 500, m: 1,    desc: m => `Your next ${m} tower merge${m > 1 ? 's cost' : ' costs'} no gold.`, apply: m => S.freeMerges += m },
  { id: 'lattice',  kind: 'Tower', name: 'Cryo Lattice',     cost: 280, m: 0.1,  desc: m => `Every tower hit also slows enemies by ${pct(m)}.`, apply: m => S.mod.allSlow += m },
  { id: 'ember',    kind: 'Tower', name: 'Ember Coating',    cost: 280, m: 0.25, desc: m => `Every tower hit also burns for ${pct(m)} of its damage over 2s.`, apply: m => S.mod.allBurn += m },
  { id: 'titan',    kind: 'Hero',  name: 'Titan Frame',      cost: 260, m: 0.4,  desc: m => `Hero +${pct(m)} max HP and takes ${pct(m / 2)} less damage.`, apply: m => { const h = S.hero; h.maxHp = Math.round(h.maxHp * (1 + m)); h.hp = h.maxHp; h.armor = Math.min(0.8, h.armor + m / 2); } },
  { id: 'riftblade',kind: 'Hero',  name: 'Rift Blade',       cost: 280, m: 0.4,  desc: m => `Hero +${pct(m)} damage and +${pct(m / 4)} crit chance.`, apply: m => { S.hero.dmg *= 1 + m; S.hero.crit = Math.min(0.9, S.hero.crit + m / 4); } },
  { id: 'chrono',   kind: 'Hero',  name: 'Chrono Battery',   cost: 240, m: 0.25, desc: m => `Your ability recharges ${pct(Math.min(0.6, m))} faster.`, apply: m => S.hero.ab.cd = Math.max(4, S.hero.ab.cd * (1 - Math.min(0.6, m))) },
  { id: 'soul',     kind: 'Hero',  name: 'Soul Engine',      cost: 300, m: 2,    desc: m => `Pick ${m} hero upgrades right now.`, apply: m => S.pendingLevels += m },
  { id: 'contract', kind: 'Hero',  name: 'Bounty Contract',  cost: 220, m: 3,    desc: m => `+${m} gold for every kill.`, apply: m => S.hero.bounty += m },
  { id: 'bulwark',  kind: 'Hero',  name: 'Rift Bulwark',     cost: 200, m: 8,    desc: m => `Your base gains ${m} HP.`, apply: m => S.lives += m },
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
    { id: 'tithe',     name: 'Rift Tithe',      max: 4, cost: r => 40 + 30 * r, desc: r => `Start each run with +${25 * r} gold`, stat: ['Starting gold bonus', r => 25 * r], apply: (h, r) => S.gold += 25 * r },
    { id: 'widesig',   name: 'Wide Signal',     max: 3, cost: r => 50 + 40 * r, desc: r => `All towers get +${3 * r}% range`, apply: (h, r) => h.towerRange += 0.03 * r },
  ],
  sniper: [
    { id: 'rounds',   name: 'Heavy Rounds',     max: 5, cost: r => 30 + 25 * r, desc: r => `+${8 * r}% damage`, apply: (h, r) => h.dmg *= 1 + 0.08 * r },
    { id: 'stance',   name: 'Steady Stance',    max: 4, cost: r => 40 + 30 * r, desc: r => `Brace ${12 * r}% faster`, apply: (h, r) => h.brace *= 1 - 0.12 * r },
    { id: 'hollow',   name: 'Hollow Points',    max: 4, cost: r => 40 + 30 * r, desc: r => `+${15 * r}% crit damage`, apply: (h, r) => h.critDmg += 0.15 * r },
    { id: 'drills',   name: 'Piercing Drills',  max: 3, cost: r => 50 + 40 * r, desc: r => `Piercing Shot recharges ${8 * r}% faster`, apply: (h, r) => h.ab.cd *= 1 - 0.08 * r },
  ],
};
// Special upgrades: bought once with Boss Cores. Mythic tier and up.
const SPECIALS = [
  { id: 'sovereign', rarity: 'mythic',    cost: 25, name: 'Rift Sovereign',    desc: 'Start every run with a random Legendary upgrade for your hero.' },
  { id: 'second',    rarity: 'mythic',    cost: 30, name: 'Second Chance',     desc: 'Once per run, when your base would fall, the wave restarts with your base at 10 HP.' },
  { id: 'bazaar',    rarity: 'legendary', cost: 40, name: 'Grand Bazaar',      desc: 'Boss shops show 9 items instead of 6, and the first item you buy in each is free.' },
  { id: 'foundry',   rarity: 'legendary', cost: 50, name: 'Ascendant Foundry', desc: 'Every tower you build gets its first 2 level-ups free.' },
  { id: 'pact',      rarity: 'secret',    cost: 200, name: 'Demon Pact',        desc: 'Demonic shops go from 1% to 10%, and every demonic curse is half as strong.' },
  { id: 'bulwarkS',  hero: 'vanguard', rarity: 'mythic',    cost: 35, name: 'Immortal Bulwark', desc: 'Start each run with Aegis Core and Unbreakable, and Unbreakable can save you twice per wave.' },
  { id: 'dancer',    hero: 'striker',  rarity: 'mythic',    cost: 35, name: 'Blade Dancer',     desc: 'Rift Nova casts itself every 8th kill by your hero, on top of its normal cooldown.' },
  { id: 'conductor', hero: 'oracle',   rarity: 'legendary', cost: 45, name: 'Grand Conductor',  desc: 'Overclock Field is always on at half power across the whole map.' },
  { id: 'oneshot',   hero: 'sniper',   rarity: 'legendary', cost: 45, name: 'One Shot',         desc: 'The first shot of every wave deals 10× damage, and each kill gives your next brace a head start.' },
];
const BOSS_CORES = { knight: 1, warden: 2, tyrant: 5 };
const BIG_BOSS = { warden: true, tyrant: true };
const GLOBAL_META = [
  { id: 'gold',    name: 'War Chest',       max: 5, cost: r => 25 + 20 * r, desc: r => `Start with +${20 * r} gold`, stat: ['Starting gold', r => 150 + 20 * r] },
  { id: 'lives',   name: 'Reinforced Core', max: 5, cost: r => 25 + 20 * r, desc: r => `Base starts with +${2 * r} HP`, stat: ['Base HP', r => 20 + 2 * r] },
  { id: 'reroll',  name: 'Fate Weaver',     max: 3, cost: r => 50 + 40 * r, desc: r => `+${r} upgrade reroll${r > 1 ? 's' : ''} per run`, stat: ['Rerolls per run', r => 2 + r] },
  { id: 'luck',    name: 'Lucky Star',      max: 3, cost: r => 60 + 50 * r, desc: r => `Rarer upgrades are ${10 * r}% more likely`, stat: ['Rarer upgrade odds', r => '+' + 10 * r + '%'] },
  { id: 'vet',     name: 'Veteran',         max: 2, cost: r => 120 + 100 * r, desc: r => `Start each run with ${r} free hero upgrade${r > 1 ? 's' : ''}`, stat: ['Free hero upgrades at the start', r => r] },
  { id: 'fortune', name: 'Fortune’s Favor', max: 3, cost: r => 300 + 250 * r, desc: r => `Much better upgrade odds: Rare and above ${30 * r}% more likely, Common ${15 * r}% less likely`, stat: ['Rare and above odds', r => '+' + 30 * r + '%'] },
];
// Each tower has its own permanent upgrades on the Towers page: 3 basics and a unique Signature.
const TOWER_META = [
  { id: 'power',  name: 'Power',        max: 5, cost: r => 30 + 25 * r, desc: (r, k) => k === 'beacon' ? `Beacon buff +${2 * r}% damage` : `+${4 * r}% damage`,
    stat: ['Damage', (r, k) => k === 'beacon' ? '+' + (15 + 2 * r) + '% buff' : Math.round(TOWERS[k].dmg * (1 + 0.04 * r))] },
  { id: 'supply', name: 'Supply Line',  max: 4, cost: r => 40 + 30 * r, desc: r => `Builds ${5 * r}% cheaper`, stat: ['Build cost', (r, k) => Math.round(TOWERS[k].cost * (1 - 0.05 * r))] },
  { id: 'vet',    name: 'Veteran Crew', max: 2, cost: r => 120 + 100 * r, desc: r => `New copies start with ${r} free level-up${r > 1 ? 's' : ''}`, stat: ['Free level-ups', r => r] },
];
const SIGNATURES = {
  arcane: { name: 'Spellweave',    desc: 'Every 5th bolt also applies Hex Brand, even without points in it.' },
  plasma: { name: 'Napalm Shells', desc: 'Explosions leave burning ground for 2s. Burns ignore armor.' },
  frost:  { name: 'Deep Freeze',   desc: 'An enemy slowed for 3s straight freezes solid for 1s.' },
  tesla:  { name: 'Overcharge',    desc: 'Chain lightning no longer loses power on each jump.' },
  beacon: { name: 'Twin Signal',   desc: 'Two Beacons can stack on the same tower.' },
  anvil:  { name: 'Fault Line',    desc: 'Slams travel along the path in both directions for 2 tiles.' },
  laser:  { name: 'Overheat',      desc: 'The beam heats up twice as fast.' },
  mortar: { name: 'Rocket Shells', desc: 'Shells fly 40% faster and their blast is 20% wider.' },
};
const SIG_COST = 250;
let META = { v: 2, shards: 0, cores: 0, specials: {}, heroes: { vanguard: {}, striker: {}, oracle: {}, sniper: {} }, unlocked: {}, global: {}, best: {}, runs: [],
  towers: {}, towerUnlocked: {}, loadout: null, seen: {} };
try { const m = JSON.parse(localStorage.getItem('riftguard-meta') || 'null'); if (m) META = Object.assign(META, m, { v: m.v || 1 }); } catch (e) {}
if (!META.specials) META.specials = {}; if (!META.cores) META.cores = 0;
META.towers = META.towers || {}; META.towerUnlocked = META.towerUnlocked || {}; META.seen = META.seen || {};
for (const k of Object.keys(TOWERS)) META.towers[k] = META.towers[k] || {};
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
let SETTINGS = { volume: 0.6, muted: false, fullscreen: true, musicOn: true, musicVolume: 0.5, song: 'riftwalker', musicMode: 'all' };
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
// ---------- music: background songs, picked on the Music screen ----------
const SONGS = [{ id: 'riftwalker', name: 'Riftwalker', url: riftwalkerUrl }];
const MUSIC_MODES = { one: 'Repeat this song', all: 'Play all in order', shuffle: 'Shuffle' };
const bgm = new Audio(); bgm.preload = 'auto';
let bgmStarted = false;
const songIdx = () => Math.max(0, SONGS.findIndex(s => s.id === SETTINGS.song));
function applyMusic() {
  bgm.volume = SETTINGS.musicVolume; bgm.loop = SETTINGS.musicMode === 'one' || SONGS.length === 1;
  if (!SETTINGS.musicOn) bgm.pause(); else if (bgmStarted && bgm.paused) bgm.play().catch(() => {});
}
function playSong(id) {
  SETTINGS.song = id; saveSettings();
  const s = SONGS[songIdx()];
  if (bgm.dataset.song !== s.id) { bgm.dataset.song = s.id; bgm.src = s.url; }
  bgmStarted = true; applyMusic();
}
function nextSong(step = 1) {
  const n = SONGS.length, i = songIdx();
  playSong(SONGS[SETTINGS.musicMode === 'shuffle' && n > 1 ? (i + 1 + Math.floor(Math.random() * (n - 1))) % n : (i + step + n) % n].id);
}
bgm.addEventListener('ended', () => nextSong());
// browsers only allow audio after the player interacts with the page
const startMusic = () => { if (!bgm.dataset.song) playSong(SETTINGS.song); else applyMusic(); };
playSong(SETTINGS.song);
window.addEventListener('pointerdown', startMusic, { once: true });
window.addEventListener('keydown', startMusic, { once: true });

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
const shardsTag = () => `<span class="shards">◆ ${META.shards} Rift Shards</span> <span class="cores">⬢ ${META.cores || 0} Boss Cores</span>`;
function spentOn(defs, obj) { let n = 0; for (const d of defs) for (let r = 0; r < rank(obj, d.id); r++) n += d.cost(r); return n; }
function refundValue(kind, hero) {
  if (kind === 'hero') return spentOn(HERO_META[hero], META.heroes[hero]);
  if (kind === 'global') return spentOn(GLOBAL_META, META.global);
  if (kind === 'tower') return spentOn(TOWER_META, META.towers[hero]) + (META.towers[hero].sig ? SIG_COST : 0);
  return SPECIALS.filter(x => (x.hero || null) === (hero || null) && META.specials[x.id]).reduce((a, x) => a + x.cost, 0);
}
// Refunds are free: they give back everything spent in that tab.
function refundBtn(kind, hero) {
  const v = refundValue(kind, hero);
  return v ? `<button class="refund" data-refund="${kind}" ${hero ? `data-hero="${hero}"` : ''}>Refund ${kind === 'special' ? '⬢' : '◆'} ${v}</button>` : '';
}
function specialRow(x) {
  const own = !!META.specials[x.id];
  return `<div class="meta-row special"><div><b class="rar-${x.rarity}">${x.name}</b> <small class="path rar-${x.rarity}">${RAR[x.rarity].name}</small><br><span class="help">${x.desc}</span></div>
    <button data-special="${x.id}" ${own || META.cores < x.cost ? 'disabled' : ''}>${own ? 'Owned' : '⬢ ' + x.cost}</button></div>`;
}
function showMenu() {
  S = null; closeModal();
  showScreen(`<div class="title"><h1>Rift<span>guard</span></h1>
    <p class="lead">Hold the rift. Earn Rift Shards every run to make your heroes and towers stronger.</p>
    <p style="margin-top:10px">${shardsTag()}</p>
    <div class="menu">
      <button class="go" id="mStart">Play</button>
      <button id="mUpgrades">Heroes</button>
      <button id="mTowers">Towers</button>
      <button id="mMusic">Music</button>
      <button id="mSettings">Settings</button>
      <button id="mLog">Stats log</button>
      ${desktop ? '<button id="mQuit">Quit</button>' : ''}
    </div></div>`);
  $('mStart').onclick = showMapSelect; $('mUpgrades').onclick = () => showHeroes(); $('mTowers').onclick = () => showTowers(); $('mLog').onclick = showLog; $('mSettings').onclick = showSettings; $('mMusic').onclick = showMusic;
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
// "Max HP 340 → 374": what the next rank changes, in real numbers.
function metaDelta(def, key, id, r) {
  if (def.stat) { const [label, val] = def.stat; return `${label} ${val(r, id)} → ${val(r + 1, id)}`; }
  if (key === 'hero') {
    const a = makeHero(id), b = makeHero(id);
    if (r) def.apply(a, r); def.apply(b, r + 1);
    return deltaText(diffStats(heroStats(a), heroStats(b)), def.name);
  }
  return def.desc(r + 1, id);
}
function metaRow(def, obj, key, id) {
  const r = rank(obj, def.id), maxed = r >= def.max, cost = def.cost(r);
  return `<div class="meta-row"><div><b>${def.name}</b> <span class="help">${r}/${def.max}</span><br><span class="help">${r ? def.desc(r, id) : 'Not bought'}</span>${maxed ? '' : `<br><span class="delta">${metaDelta(def, key, id, r)}</span>`}</div>
    <button data-meta="${key}" data-id="${def.id}" ${id ? `data-hero="${id}"` : ''} ${maxed || META.shards < cost ? 'disabled' : ''}>${maxed ? 'Maxed' : '◆ ' + cost}</button></div>`;
}
// Towers page: unlock towers and buy their permanent upgrades.
function showTowers(sel) {
  sel = sel || 'arcane';
  const d = TOWERS[sel], open = towerUnlocked(sel), M = META.towers[sel], sig = SIGNATURES[sel], hasSig = !!M.sig;
  showScreen(`<div class="screen-head"><h2>Towers</h2>${shardsTag()}<button id="mBack">Back</button></div>
    <p class="lead">Before each run you bring your hero and 5 towers. Upgrades here are permanent and apply every time you build that tower.</p>
    <div class="heroes">
      <div class="roster">${Object.entries(TOWERS).map(([k, t]) => `<button data-tower-tab="${k}" class="${k === sel ? 'on' : ''} ${towerUnlocked(k) ? '' : 'locked'}" style="border-left-color:${t.css}">
        <small>${t.support ? 'Support' : t.cost + ' gold'}</small><b style="color:${t.css}">${t.name}</b>${towerUnlocked(k) ? '' : `<span class="lock">Locked · ◆ ${t.unlock}</span>`}</button>`).join('')}</div>
      <div class="card herodetail">
        <h3 style="color:${d.css}">${d.name}</h3>
        <p>${d.info}</p>
        <div class="stats">${d.support ? `<div><span>Buff</span>+15% damage</div>` : `<div><span>Damage</span>${d.dmg}</div><div><span>Shots/s</span>${(1 / d.rate).toFixed(2)}</div>`}
          <div><span>Range</span>${d.range}</div><div><span>Cost</span>${d.cost}</div></div>
        <p class="help">Paths: ${TOWER_PATHS[sel].map(p => p.name).join(', ')}. Each level adds ${LEVEL_BONUS[d.lvl || 'dmg'].text}.</p>
        <details class="forms"><summary>Named forms found: ${formsFound(sel).length}/${Object.keys(FORM_NAMES[sel]).length}</summary>
          <ul>${Object.keys(FORM_NAMES[sel]).map(k => { const got = META.forms && META.forms[sel + ':' + k];
            return `<li class="${got ? 'found' : ''}"><b>${got ? FORM_NAMES[sel][k] : '???'}</b><span>${k.split('').map(i => TOWER_PATHS[sel][+i].name).join(' + ')}</span></li>`; }).join('')}</ul></details>
        ${open ? `<h3 class="meta-h">${d.name} upgrades ${refundBtn('tower', sel)}</h3>${TOWER_META.map(x => metaRow(x, M, 'tower', sel)).join('')}
          <div class="meta-row special"><div><b class="rar-mythic">Signature: ${sig.name}</b><br><span class="help">${sig.desc}</span></div>
          <button data-sig="${sel}" ${hasSig || META.shards < SIG_COST ? 'disabled' : ''}>${hasSig ? 'Owned' : '◆ ' + SIG_COST}</button></div>`
          : `<div class="row"><button class="go" id="unlockTower" ${META.shards < d.unlock ? 'disabled' : ''}>Unlock ${d.name} · ◆ ${d.unlock}</button></div>`}
      </div>
    </div>`);
  $('screen').querySelectorAll('[data-tower-tab]').forEach(b => b.onclick = () => showTowers(b.dataset.towerTab));
  $('screen').querySelectorAll('[data-meta]').forEach(b => b.onclick = () => {
    const def = TOWER_META.find(x => x.id === b.dataset.id), cost = def.cost(rank(M, def.id));
    if (META.shards < cost || rank(M, def.id) >= def.max) return;
    META.shards -= cost; M[def.id] = rank(M, def.id) + 1; saveMeta(); showTowers(sel);
  });
  $('screen').querySelectorAll('[data-sig]').forEach(b => b.onclick = () => {
    if (M.sig || META.shards < SIG_COST) return;
    META.shards -= SIG_COST; M.sig = 1; saveMeta(); sfx('level'); showTowers(sel);
  });
  $('screen').querySelectorAll('[data-refund]').forEach(b => b.onclick = () => { META.shards += refundValue('tower', sel); META.towers[sel] = {}; saveMeta(); showTowers(sel); });
  if ($('unlockTower')) $('unlockTower').onclick = () => {
    if (META.shards < d.unlock) return;
    META.shards -= d.unlock; META.towerUnlocked[sel] = true; saveMeta(); sfx('level'); showTowers(sel);
  };
  $('mBack').onclick = showMenu;
}
// Heroes page: every hero (locked ones too), their permanent upgrades, and the upgrades shared by all heroes.
function showHeroes(sel) {
  sel = sel || 'vanguard';
  const d = HEROES[sel], open = isUnlocked(sel), st = d.stats;
  showScreen(`<div class="screen-head"><h2>Heroes</h2>${shardsTag()}<button id="mBack">Back</button></div>
    <div class="heroes">
      <div class="roster">${CATEGORIES.map(([c, label]) => `<h4 class="cat">${label}</h4>` + (heroesIn(c).map(([k, h]) => `<button data-hero-tab="${k}" class="${k === sel ? 'on' : ''} ${isUnlocked(k) ? '' : 'locked'}" style="border-left-color:${h.css}">
        <small>${heroAbility(k).name}</small><b style="color:${h.css}">${h.name}</b>${isUnlocked(k) ? '' : `<span class="lock">Locked · ◆ ${h.unlock}</span>`}</button>`).join('') || '<p class="help cat-empty">More heroes coming.</p>')).join('')}</div>
      <div class="card herodetail">
        <h3 style="color:${d.css}">${d.name} · ${d.role}</h3>
        <p>${d.desc}</p>
        <div class="stats">
          <div><span>HP</span>${st.hp}</div><div><span>Damage</span>${st.dmg}</div>
          <div><span>Attacks/s</span>${(1 / st.rate).toFixed(2)}</div><div><span>Range</span>${st.range >= 9999 ? 'Whole map' : st.range}</div>
          <div><span>Blocks</span>${blockText(st.block)}</div><div><span>Move speed</span>${st.speed}</div>
          ${st.brace ? `<div><span>Brace time</span>${st.brace}s</div>` : ''}${st.crit ? `<div><span>Crit chance</span>${pct(st.crit)}</div>` : ''}
        </div>
        <h3 class="meta-h">Ability · pick one</h3>
        <div class="choices ab-picks">${[['base', d.ability], ['alt', d.alt]].map(([v, ab]) => `<button class="choice ${heroAbility(sel) === ab ? 'picked' : ''}" data-ab-pick="${v}">
          <small class="path">${heroAbility(sel) === ab ? 'Equipped' : 'Click to equip'} · ${ab.cd}s cooldown</small><b class="tipname" data-tip="ability:${sel}:${v}">${ab.name}</b><span>${abilityText({ ab })}</span></button>`).join('')}</div>
        ${open ? `<h3 class="meta-h">${d.name} upgrades ${refundBtn('hero', sel)}</h3>${HERO_META[sel].map(x => metaRow(x, META.heroes[sel], 'hero', sel)).join('')}
          <h3 class="meta-h special-h">Special upgrades · Boss Cores ${refundBtn('special', sel)}</h3>
          <p class="help">Bought once with Boss Cores, which bosses drop. Game-changing, and expensive.</p>
          ${SPECIALS.filter(x => x.hero === sel).map(specialRow).join('')}`
               : `<div class="row"><button class="go" id="unlockHero" ${META.shards < d.unlock ? 'disabled' : ''}>Unlock ${d.name} · ◆ ${d.unlock}</button></div>
                  <p class="help" style="margin-top:8px">Unlock ${d.name} to play them and buy their upgrades.</p>`}
      </div>
    </div>
    <div class="card"><h3 class="meta-h">All heroes ${refundBtn('global')}</h3>${GLOBAL_META.map(x => metaRow(x, META.global, 'global')).join('')}
      <h3 class="meta-h special-h">Special upgrades for all heroes ${refundBtn('special')}</h3>${SPECIALS.filter(x => !x.hero).map(specialRow).join('')}</div>`);
  $('screen').querySelectorAll('[data-hero-tab]').forEach(b => b.onclick = () => showHeroes(b.dataset.heroTab));
  $('screen').querySelectorAll('[data-ab-pick]').forEach(b => b.onclick = () => { META.abilities = META.abilities || {}; META.abilities[sel] = b.dataset.abPick; saveMeta(); showHeroes(sel); });
  $('screen').querySelectorAll('[data-meta]').forEach(b => b.onclick = () => {
    const isHero = b.dataset.meta === 'hero', defs = isHero ? HERO_META[b.dataset.hero] : GLOBAL_META, def = defs.find(x => x.id === b.dataset.id);
    const obj = isHero ? META.heroes[b.dataset.hero] : META.global;
    const cost = def.cost(rank(obj, def.id));
    if (META.shards < cost || rank(obj, def.id) >= def.max) return;
    META.shards -= cost; obj[def.id] = rank(obj, def.id) + 1; saveMeta(); showHeroes(sel);
  });
  $('screen').querySelectorAll('[data-special]').forEach(b => b.onclick = () => {
    const x = SPECIALS.find(y => y.id === b.dataset.special);
    if (META.specials[x.id] || META.cores < x.cost) return;
    META.cores -= x.cost; META.specials[x.id] = true; saveMeta(); sfx('level'); showHeroes(sel);
  });
  $('screen').querySelectorAll('[data-refund]').forEach(b => b.onclick = () => {
    const kind = b.dataset.refund, hero = b.dataset.hero || null, v = refundValue(kind, hero);
    if (kind === 'hero') { META.shards += v; META.heroes[hero] = {}; }
    else if (kind === 'global') { META.shards += v; META.global = {}; }
    else { META.cores += v; for (const x of SPECIALS) if ((x.hero || null) === hero) delete META.specials[x.id]; }
    saveMeta(); showHeroes(sel);
  });
  if ($('unlockHero')) $('unlockHero').onclick = () => {
    if (META.shards < d.unlock) return;
    META.shards -= d.unlock; META.unlocked[sel] = true; saveMeta(); sfx('level'); showHeroes(sel);
  };
  $('mBack').onclick = showMenu;
}
const clock = t => isFinite(t) ? Math.floor(t / 60) + ':' + String(Math.floor(t % 60)).padStart(2, '0') : '0:00';
function showMusic() {
  const cur = SONGS[songIdx()], playing = !bgm.paused && SETTINGS.musicOn;
  showScreen(`<div class="screen-head"><h2>Music</h2><button id="mBack">Back</button></div>
    <p class="lead">Pick the background music. It plays on the menus and during runs.</p>
    <div class="card music-now"><small class="path">${playing ? 'Now playing' : 'Paused'}</small><b>${cur.name}</b>
      <div class="music-seek"><span id="muTime">${clock(bgm.currentTime)}</span><input type="range" id="muSeek" min="0" max="1" step="0.001" value="${bgm.duration ? bgm.currentTime / bgm.duration : 0}"><span id="muDur">${clock(bgm.duration)}</span></div>
      <div class="row"><button id="muPrev">Previous</button><button class="go" id="muPlay">${playing ? 'Pause' : 'Play'}</button><button id="muNext">Next</button></div></div>
    <h3 class="music-h">Songs</h3>
    <div class="cards songs">${SONGS.map((s, i) => `<button class="choice song-pick ${s.id === cur.id ? 'picked' : ''}" data-song="${s.id}"><small class="path">Track ${i + 1}</small><b>${s.name}</b><span>${s.id === cur.id ? (playing ? 'Playing' : 'Selected') : 'Click to play'}</span></button>`).join('')}</div>
    <div class="settings music-set">
      <label>Music <input type="checkbox" id="muOn" ${SETTINGS.musicOn ? 'checked' : ''}></label>
      <label>Music volume <input type="range" id="muVol" min="0" max="1" step="0.05" value="${SETTINGS.musicVolume}"></label>
      <label>Play mode <select id="muMode">${Object.entries(MUSIC_MODES).map(([k, v]) => `<option value="${k}" ${SETTINGS.musicMode === k ? 'selected' : ''}>${v}</option>`).join('')}</select></label>
    </div>`);
  const redraw = () => setTimeout(() => { if ($('muPlay')) showMusic(); }, 50);
  $('mBack').onclick = showMenu;
  $('muPlay').onclick = () => { if (playing) { SETTINGS.musicOn = false; saveSettings(); bgm.pause(); } else { SETTINGS.musicOn = true; playSong(cur.id); } redraw(); };
  $('muPrev').onclick = () => { if (bgm.currentTime > 3) bgm.currentTime = 0; else nextSong(-1); SETTINGS.musicOn = true; applyMusic(); redraw(); };
  $('muNext').onclick = () => { SETTINGS.musicOn = true; nextSong(); redraw(); };
  $('muSeek').oninput = e => { if (bgm.duration) bgm.currentTime = +e.target.value * bgm.duration; };
  $('muOn').onchange = e => { SETTINGS.musicOn = e.target.checked; saveSettings(); playSong(cur.id); redraw(); };
  $('muVol').oninput = e => { SETTINGS.musicVolume = +e.target.value; saveSettings(); applyMusic(); };
  $('muMode').onchange = e => { SETTINGS.musicMode = e.target.value; saveSettings(); applyMusic(); };
  document.querySelectorAll('.song-pick').forEach(b => b.onclick = () => { SETTINGS.musicOn = true; playSong(b.dataset.song); redraw(); });
}
function musicTick() {
  if (!$('muSeek')) return;
  $('muTime').textContent = clock(bgm.currentTime); $('muDur').textContent = clock(bgm.duration);
  if (bgm.duration && document.activeElement !== $('muSeek')) $('muSeek').value = bgm.currentTime / bgm.duration;
}
bgm.addEventListener('timeupdate', musicTick); bgm.addEventListener('loadedmetadata', musicTick);
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
      <label>Music <input type="checkbox" id="setMusic" ${SETTINGS.musicOn ? 'checked' : ''}></label>
      <label>Music volume <input type="range" id="setMusicVol" min="0" max="1" step="0.05" value="${SETTINGS.musicVolume}"></label>
      <label>Sound effects volume <input type="range" id="setVol" min="0" max="1" step="0.05" value="${SETTINGS.volume}"></label>
      <label>Mute sound effects <input type="checkbox" id="setMute" ${SETTINGS.muted ? 'checked' : ''}></label>
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
  $('setMusic').onchange = e => { SETTINGS.musicOn = e.target.checked; saveSettings(); bgmStarted = true; if (!bgm.dataset.song) playSong(SETTINGS.song); else applyMusic(); };
  $('setMusicVol').oninput = e => { SETTINGS.musicVolume = +e.target.value; saveSettings(); applyMusic(); };
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
    echoes: [], zones: [], delayed: [], shells: [], cores: 0, specials: Object.assign({}, META.specials), secondChance: !!META.specials.second, bossWarned: false, pointer: null, coins: [], loadout: Object.keys(TOWERS).filter(towerUnlocked).slice(0, 5), sig: {}, pathBonus: 0, freeLevels: 0, freeMerges: 0, needShop: false, shops: 0,
    mod: { towerDmg: 1, slow: 0, gold: map.gold || 1, towerRate: 1, enemyHp: map.enemyHp || 1, enemySpeed: 1, phoenix: false, allSlow: 0, allBurn: 0 },
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
    grounded: 0, execute: 0, bulletStorm: 0, attacks: 0, unbreakable: false, unbreakLeft: 1, unbreakMax: 1, tithe: 0, taunt: 0, momentum: 0, momStacks: 0, momT: 0, rapid: 0, spotter: 0, headhunter: 0, danceKills: 0, timeWarp: 0, autoCast: false,
    ab: Object.assign({ t: 0 }, heroAbility(id)), shield: 0, shieldMax: 0, shieldT: 0, odT: 0,
    boonSlow: 0, boonSplash: 0, boonRail: 0, boonVent: 0, boonChain: 0, boonIon: 0,
    xpGain: 0, retStore: 0, retT: 4, barrageT: 5,
  };
}
function applyHeroMeta(h) {
  const M = META.heroes[h.cls] || {};
  for (const def of HERO_META[h.cls]) if (rank(M, def.id)) def.apply(h, rank(M, def.id));
  h.hp = h.maxHp;
  S.pendingLevels += rank(META.global, 'vet');
}
// Special upgrades that act at the start of a run.
function applySpecials(h) {
  const sp = S.specials, give = u => { u.apply(h); S.picks.push({ perk: u, rarity: RAR.legendary, demonic: false }); };
  if (sp.bulwarkS && h.cls === 'vanguard') { give(UNIQUES.find(x => x.id === 'aegis')); give(UNIQUES.find(x => x.id === 'unbreak')); h.unbreakMax = h.unbreakLeft = 2; }
  if (sp.sovereign) { const u = pick(UNIQUES.filter(x => x.rarity === 'legendary' && x.cls === h.cls && (!x.ab || x.ab === h.ab.id) && !owns(x.id))); if (u) give(u); }
  h.hp = h.maxHp;
}
const LOADOUT_SIZE = 5;
// Loadout: pick a hero and up to 5 towers. The last loadout is remembered.
function showHeroSelect() {
  const openTowers = Object.keys(TOWERS).filter(towerUnlocked), need = Math.min(LOADOUT_SIZE, openTowers.length);
  const last = META.loadout || {};
  let hero = HEROES[last.hero] && isUnlocked(last.hero) ? last.hero : 'vanguard';
  let picks = (last.towers || []).filter(k => TOWERS[k] && towerUnlocked(k)).slice(0, LOADOUT_SIZE);
  for (const k of openTowers) if (picks.length < need && !picks.includes(k)) picks.push(k);
  let step = 'hero';
  const heroCards = () => CATEGORIES.filter(([c]) => heroesIn(c).length).map(([c, label]) => `<h3 class="cat-h">${label}</h3><div class="cards">${heroesIn(c).map(([k, d]) => { const open = isUnlocked(k);
        return `<button class="choice mapcard hero-pick ${open ? '' : 'locked'} ${hero === k ? 'picked' : ''}" data-k="${k}" style="border-color:${d.css}" ${open ? '' : 'disabled'}>
        <small class="path" style="color:${d.css}">${d.role}</small><b style="color:${d.css}">${d.name}</b><span>${d.desc}</span>
        <span>HP ${d.stats.hp} · Damage ${d.stats.dmg} · ${d.stats.range >= 9999 ? 'Whole-map range' : 'Blocks ' + blockText(d.stats.block).toLowerCase()}</span>
        <span class="help">Each level: ${ROLE_LEVEL[d.cat] ? ROLE_LEVEL[d.cat].text : ''}</span>
        ${open ? `<em class="reward">Ability: <span class="tipname" data-tip="ability:${k}">${heroAbility(k).name}</span></em>` : `<span class="lock">Locked: unlock on the Heroes page for ◆ ${d.unlock}</span>`}</button>`; }).join('')}</div>`).join('');
  const towerCards = () => `<div class="cards">${Object.entries(TOWERS).map(([k, d]) => { const open = towerUnlocked(k), on = picks.includes(k);
        return `<button class="choice mapcard tower-pick ${open ? '' : 'locked'} ${on ? 'picked' : ''}" data-k="${k}" style="border-color:${d.css}" ${open ? '' : 'disabled'}>
        <small class="path" style="color:${d.css}">${on ? 'Key ' + (picks.indexOf(k) + 1) : d.support ? 'Support' : d.cost + ' gold'}${META.towers[k].sig ? ' · ' + SIGNATURES[k].name : ''}</small><b style="color:${d.css}">${d.name}</b><span>${d.info}</span>
        ${open ? '' : `<span class="lock">Locked: unlock on the Towers page for ◆ ${d.unlock}</span>`}</button>`; }).join('')}</div>`;
  // Two pages: pick the hero first, then the towers.
  const render = () => {
    const y = $('screen').hidden ? 0 : $('screen').scrollTop;
    if (step === 'hero') showScreen(`<div class="screen-head"><h2>Choose your hero</h2><button class="go" id="heroNextTop">Next: towers</button><button id="mBack">Back</button></div>
      <p class="lead">${MAPS[S.map].name} · ${MAX_WAVE} waves. Step 1 of 2: pick the hero you’ll play.</p>
      ${heroCards()}
      <div class="row" style="margin-top:14px"><button class="go" id="heroNext">Next: towers</button></div>`);
    else showScreen(`<div class="screen-head"><h2>Choose your towers · ${picks.length}/${need}</h2><button class="go" id="startRunTop" ${picks.length ? '' : 'disabled'}>Start run</button><button id="mBack">Back</button></div>
      <p class="lead">Step 2 of 2: pick up to ${need} towers to bring with your <b style="color:${HEROES[hero].css}">${HEROES[hero].name}</b>. Bringing fewer makes the run harder.</p>
      ${towerCards()}
      <div class="row" style="margin-top:14px"><button class="go" id="startRun" ${picks.length ? '' : 'disabled'}>Start run</button>${picks.length && picks.length < need ? `<span class="help" style="color:var(--gold)">Only ${picks.length} of ${need} towers picked.</span>` : ''}</div>`);
    if (step === 'hero') {
      $('screen').querySelectorAll('.hero-pick').forEach(b => b.onclick = () => { hero = b.dataset.k; render(); });
      $('heroNext').onclick = $('heroNextTop').onclick = () => { step = 'towers'; $('screen').scrollTop = 0; render(); $('screen').scrollTop = 0; };
      $('screen').scrollTop = y;
      $('mBack').onclick = () => { S = null; showMapSelect(); };
      return;
    }
    $('screen').querySelectorAll('.tower-pick').forEach(b => b.onclick = () => {
      const k = b.dataset.k;
      if (picks.includes(k)) picks = picks.filter(x => x !== k); else if (picks.length < LOADOUT_SIZE) picks.push(k); else toast('You can bring ' + LOADOUT_SIZE + ' towers. Remove one first.');
      render();
    });
    $('startRun').onclick = $('startRunTop').onclick = () => {
      if (!picks.length) return;
      if (picks.length >= need) return startRun(hero, picks);
      // Fewer towers is allowed as a challenge, but confirm so it never happens by accident.
      openModal(`<h2>Only ${picks.length} of ${need} towers?</h2><p>You picked ${picks.length} tower${picks.length > 1 ? 's' : ''}: ${picks.map(k => TOWERS[k].name).join(', ')}. You can’t add more once the run starts.</p>
        <div class="row" style="margin-top:12px"><button class="go" id="fewGo">Start with ${picks.length}</button><button id="fewBack">Go back and pick more</button></div>`);
      $('fewGo').onclick = () => { closeModal(); startRun(hero, picks); };
      $('fewBack').onclick = closeModal;
    };
    $('screen').scrollTop = y;
    $('mBack').onclick = () => { step = 'hero'; render(); };
  };
  render();
}
function startRun(hero, towers) {
  META.loadout = { hero, towers: towers.slice() }; saveMeta();
  S.loadout = towers.slice();
  S.sig = {}; for (const k of towers) if (META.towers[k].sig) S.sig[k] = true;
  S.hero = makeHero(hero); applyHeroMeta(S.hero); applySpecials(S.hero); S.paused = false; hideScreen();
  renderBuildBar(); renderInspector(); renderCodex(); renderEnemyCodex(); renderHero();
  toast(HEROES[hero].name + ' ready. Build towers, then start the wave.');
}

const $ = id => document.getElementById(id);
let toastT = 0;
function toast(msg) { $('toast').textContent = msg; $('toast').hidden = false; toastT = 3; }

function countType(type) { return S.towers.filter(t => t.type === type || (t.parents && t.parents.includes(type))).length; }
function towerCost(type) { return Math.round(TOWERS[type].cost * (1 + 0.3 * countType(type)) * S.hero.costMul * (1 - 0.05 * rank(META.towers[type], 'supply'))); }
// Level-up price: build cost × current level. Merged towers start at double the last level-up of their
// priciest parent (cost × 12 × 2; super towers 1.5× that) and rise 10% per level.
function levelCost(t) {
  if (S.freeLevels > 0 || t.freeUps > 0) return 0;
  const base = t.hybrid ? t.upStart * (1 + 0.1 * (t.lvl - 1)) : t.baseCost * t.lvl;
  return Math.round(base * S.hero.lvlMul);
}
const hybridUpStart = (parents, sup) => Math.round(2 * (MAX_LVL - 1) * Math.max(...parents.map(k => TOWERS[k].cost)) * (sup ? 1.5 : 1));
function mergeCost() { return S.freeMerges > 0 ? 0 : Math.round(MERGE_COST * S.hero.mergeMul); }
function pathLimit() { return 3 + (S.hero.cls === 'oracle' ? 1 : 0) + (S.pathBonus || 0); }
function pathMax() { return S.hero && S.hero.cls === 'oracle' ? 3 : PATH_MAX; }
function tRange(t) { return t.range * (1 + S.hero.towerRange) * (t.buff ? (1 + t.buff.range) * (t.buff.light ? 2 : 1) : 1); }
function towerName(t) { return t.name || (t.hybrid ? RECIPES[t.type].name : TOWERS[t.type].name); }
function towerBlurb(t) { return t.super ? t.desc : t.hybrid ? RECIPES[t.type].desc : TOWERS[t.type].info; }
function towerKind(t) { return t.super ? 'Super ' : t.hybrid ? 'Hybrid ' : ''; }
function baseTypes(t) { return t.parents || [t.type]; }
function traits(t) {
  const out = ['Shoots the enemy closest to your base' + (t.multi ? `, plus ${t.multi} more at once.` : '.')];
  if (t.splash) out.push('Explodes on hit, damaging all enemies within ' + t.splash.toFixed(0) + '.');
  if (t.slow) out.push('Slows enemies by ' + Math.round(Math.min(0.85, t.slow + S.mod.slow) * 100) + '% for ' + (t.slowDur || 1.6).toFixed(1) + 's.');
  if (t.chain) out.push('Lightning jumps to ' + t.chain + ' more enemies at ' + pct(t.chainMul || 0.7) + ' damage, less each jump.');
  if (t.burn) out.push('Burns enemies for ' + pct(t.burn) + ' of hit damage over 2s.');
  if (t.ramp && !t.beam) out.push('Gains +' + pct(t.ramp) + ' damage per hit in a row on the same enemy (5 stacks).');
  if (t.surge) out.push('Every ' + t.surge + 'th shot deals triple damage.');
  if (t.brittle) out.push('Slowed enemies take +' + pct(t.brittle) + ' damage from everything.');
  if (t.mark) out.push('Marks enemies to take +' + pct(t.mark) + ' damage for 2s.');
  if (t.cluster) out.push('Throws ' + t.cluster + ' bomblets per shot.');
  if (t.orbital) out.push('Every ' + t.orbital + 'th shot is a huge triple-damage blast.');
  if (t.freeze) out.push('Every ' + t.freeze + 'th shot freezes enemies for 1.2s.');
  if (t.zero) out.push('Constantly slows every enemy in range by ' + pct(t.zero) + '.');
  if (t.beam) out.push('Beam heat: +' + pct(t.ramp) + ' damage per tick on the same target, up to ' + t.rampMax + ' ticks (+' + pct(t.ramp * t.rampMax) + ').' + (t.melt ? ' Double damage at full heat.' : '') + (t.retain ? ' Keeps half its heat when switching.' : ''));
  if (t.lob) out.push('Lobs shells up to ' + tRange(t).toFixed(0) + ' away; they land a moment later.' + (t.salvo ? ' A second shell follows for ' + pct(t.salvo) + '.' : '') + (t.firestorm ? ' Leaves burning ground.' : '') + (t.quakeStun ? ' Every 4th shell stuns.' : ''));
  if (t.hypo) out.push('Hits add chill stacks; at ' + t.hypo + ' stacks the enemy freezes for 0.8s (bosses 0.3s)' + (t.coldSnap ? ' and the freeze bursts to enemies within 70.' : '.'));
  if (t.stun) out.push('Lightning jumps have a ' + pct(t.stun) + ' chance to stun.');
  if (t.prism) out.push('Hits split to ' + t.prism.toFixed(0) + ' nearby enemies for 40% damage.');
  if (t.execute) out.push('Finishes non-boss enemies below ' + pct(t.execute) + ' HP.');
  if (t.nova) out.push('Every 6th shot blasts everything in range for ' + pct(t.nova) + ' damage.');
  if (t.echo) out.push('Shots echo for ' + pct(t.echo) + ' damage.');
  if (t.deathBlast) out.push('Kills explode for ' + pct(t.deathBlast) + ' of max HP.');
  if (t.gravity) out.push('Every 5th shot drags enemies ' + t.gravity.toFixed(0) + ' back.');
  if (t.timeLock) out.push('Every 8th shot stuns everything in range for ' + t.timeLock.toFixed(2) + 's.');
  if (t.shatter) out.push('Stunned enemies take +' + pct(t.shatter) + ' damage from it.');
  if (t.frostfire) out.push('Slowed enemies burn for ' + pct(t.frostfire) + ' of each hit.');
  if (t.storm) out.push('Every 4th shot calls lightning on ' + t.storm.toFixed(0) + ' enemies.');
  if (t.chainBlast) out.push('Lightning jumps explode for ' + pct(t.chainBlast) + ' damage.');
  if (t.overload) out.push('Every 10th shot deals +' + pct(t.overload) + ' damage and stuns.');
  if (t.pierce) out.push('Shots pierce ' + t.pierce.toFixed(0) + ' enemies behind the target.');
  if (t.loot) out.push('Kills drop +' + t.loot.toFixed(0) + ' gold.');
  if (t.leech) out.push('Kills heal your hero ' + t.leech.toFixed(0) + ' HP.');
  if (t.tempo) out.push('Each shot speeds up the next by ' + pct(t.tempo) + ' (5 stacks).');
  if (t.hex) out.push('Brands enemies: every second they pulse ' + pct(t.hex) + ' of all damage they took to themselves and enemies within 60.');
  if (t.hexNova) out.push('Branded enemies explode on death for ' + pct(t.hexNova) + ' of the damage they took.');
  if (t.buff) out.push('Beacon buff: +' + pct(t.buff.dmg) + ' damage' + (t.buff.rate ? ', +' + pct(t.buff.rate) + ' fire rate' : '') + (t.buff.range ? ', +' + pct(t.buff.range) + ' range' : '') + (t.buff.sunder ? ', ignores ' + pct(t.buff.sunder) + ' armor' : '') + '.');
  return out;
}
function supportTraits(t) {
  const out = ['Buffs every tower within ' + tRange(t).toFixed(0) + '. Buffed towers deal +' + pct(beaconDmg(t)) + ' damage.'];
  if (t.bRate) out.push('Buffed towers fire ' + pct(t.bRate) + ' faster.');
  if (t.bRange) out.push('Buffed towers get +' + pct(t.bRange) + ' range.');
  if (t.bSunder) out.push('Buffed towers ignore ' + pct(t.bSunder) + ' armor.');
  if (t.bGold) out.push('Kills by buffed towers give +' + pct(t.bGold) + ' gold.');
  if (t.bOverdrive) out.push('Overdrive: buffed towers crit 10% of the time for triple damage.');
  if (t.bTempo) out.push('Tempo Link: every 10s, buffed towers fire twice as fast for 3s.');
  if (t.bLight) out.push('Lighthouse: buffed towers hit enemies within twice their range.');
  if (t.bBreak) out.push('Armor Break: hits from buffed towers strip 15% armor for 3s (up to 45%).');
  if (t.bRush) out.push('Gold Rush: kills by buffed towers can drop 25 gold coins.');
  out.push('Buffing ' + S.towers.filter(x => x.buff && x.buff.from.includes(t)).length + ' tower(s).');
  return out;
}
function anvilTraits(t) {
  const out = ['Slams every ' + (t.rate * S.mod.towerRate).toFixed(1) + 's, hitting every enemy within ' + tRange(t).toFixed(0) + '. Moving enemies take 30%.',
    'Stopped enemies (blocked, stunned, frozen) take +' + pct(t.press) + ' more per second stopped, up to +' + pct(t.pressCap) + '.'];
  if (t.pin) out.push('Holds stopped enemies in place ' + t.pin.toFixed(1) + 's longer.');
  if (t.guard) out.push('Your hero takes ' + pct(t.guard) + ' less damage from enemies it blocks in range.');
  if (t.crushExec) out.push('Crushes stopped enemies below ' + pct(t.crushExec) + ' HP.');
  if (t.shackle) out.push('Every 4th slam roots everything in range for 1s.');
  if (t.after) out.push('Each slam has a 50% aftershock.');
  if (t.tide) out.push('Pressure fades over 3s instead of resetting.');
  if (t.pact) out.push('Slams twice as fast while your hero blocks an enemy in range.');
  if (t.buff) out.push('Beacon buff: +' + pct(t.buff.dmg) + ' damage.');
  return out;
}
const towerTraits = t => t.support ? supportTraits(t) : t.type === 'anvil' ? anvilTraits(t) : traits(t);

// ---------- "current → new" previews ----------
const fmtN = v => Math.abs(v) >= 10 || Math.abs(v - Math.round(v)) < 0.05 ? String(Math.round(v)) : v.toFixed(1);
const FMT = { n: fmtN, p: v => Math.round(v * 100) + '%', s: v => v.toFixed(1) + 's', r: v => v.toFixed(2) + '/s', x: v => v.toFixed(1) + '×' };
const HERO_STATS = [
  ['Damage', h => h.dmg, 'n'], ['Attacks', h => 1 / h.rate, 'r'], ['Max HP', h => h.maxHp, 'n'], ['Armor', h => h.armor, 'p'], ['Regen/s', h => h.regen, 'n'],
  ['Crit chance', h => h.crit, 'p'], ['Crit damage', h => h.critDmg, 'p'], ['Targets', h => 1 + h.multi, 'n'], ['Range', h => Math.min(9999, h.range), 'n'],
  ['Move speed', h => h.speed, 'n'], ['Blocks', h => Math.min(h.block, ALL_BLOCK - 1), 'n'], ['Respawn', h => h.respawn, 's'], ['Build range', h => h.buildRange, 'n'],
  ['Tower aura', h => h.aura, 'p'], ['Aura reach', h => h.auraRange, 'n'], ['Aura slow', h => h.auraSlow, 'p'], ['Heal per kill', h => h.siphon, 'n'],
  ['Hero kill gold', h => h.bounty, 'n'], ['Kill gold (all)', h => h.tithe, 'n'], ['Thorns/s', h => h.thorns, 'n'], ['Taunt', h => h.taunt, 's'],
  ['Momentum per kill', h => h.momentum, 'p'], ['Free level-ups near you', h => h.rapid, 'n'], ['Spotter', h => h.spotter, 'p'], ['Boss damage', h => h.headhunter, 'p'],
  ['Interest', h => h.interest, 'p'], ['XP gain', h => h.xpGain, 'p'], ['Brace time', h => h.brace, 's'], ['Extra hits', h => h.pierce, 'n'], ['Tower range', h => h.towerRange, 'p'],
  ['Tower build cost', h => h.costMul, 'p'], ['Level-up cost', h => h.lvlMul, 'p'], ['Merge cost', h => h.mergeMul, 'p'], ['Boss stun reduction', h => Math.min(0.8, h.grounded), 'p'],
  ['Execute below', h => h.execute, 'p'], [h => h.ab.name + ' damage', h => h.ab.dmg, 'n'], [h => h.ab.name + ' cooldown', h => h.ab.cd, 's'],
  [h => h.ab.name + ' radius', h => h.ab.r, 'n'], [h => h.ab.name + ' stun', h => h.ab.stun, 's'], [h => h.ab.name + ' duration', h => h.ab.dur, 's'],
  [h => h.ab.name + ' speed-up', h => h.ab.power, 'p'], [h => h.ab.name + ' damage', h => h.ab.mult, 'x'],
];
const RUN_STATS = [
  ['All tower damage', () => S.mod.towerDmg, 'p'], ['All tower fire rate', () => 1 / S.mod.towerRate, 'p'], ['Kill gold', () => S.mod.gold, 'p'],
  ['Base HP', () => S.lives, 'n'], ['Gold', () => S.gold, 'n'], ['Paths per tower', () => pathLimit(), 'n'], ['Free tower upgrades', () => S.freeLevels, 'n'],
  ['Free merges', () => S.freeMerges, 'n'], ['Hero upgrades to pick', () => S.pendingLevels, 'n'], ['Hit slow', () => S.mod.allSlow, 'p'], ['Hit burn', () => S.mod.allBurn, 'p'],
  ['Enemy HP', () => S.mod.enemyHp, 'p'], ['Enemy speed', () => S.mod.enemySpeed, 'p'],
];
const TOWER_STATS = [
  ['Damage', t => t.support ? 0 : t.dmg * S.mod.towerDmg, 'n'], ['Shots', t => t.support ? 0 : 1 / (t.rate * S.mod.towerRate), 'r'], ['Range', t => t.range * (1 + S.hero.towerRange), 'n'],
  ['Blast radius', t => t.splash, 'n'], ['Slow', t => t.slow, 'p'], ['Slow time', t => t.slowDur, 's'], ['Jumps', t => t.chain, 'n'], ['Jump power', t => t.chainMul, 'p'],
  ['Jump reach', t => t.chainReach, 'n'], ['Extra targets', t => t.multi, 'n'], ['Damage per hit in a row', t => t.ramp, 'p'], ['Max heat stacks', t => t.beam ? t.rampMax : 0, 'n'], ['Triple shot every', t => t.surge, 'n'],
  ['Burn', t => t.burn, 'p'], ['Brittle', t => t.brittle, 'p'], ['Mark', t => t.mark, 'p'], ['Bomblets', t => t.cluster, 'n'], ['Huge blast every', t => t.orbital, 'n'],
  ['Freeze every', t => t.freeze, 'n'], ['Chill stacks to freeze', t => t.hypo, 'n'], ['Aura slow', t => t.zero, 'p'], ['Stun chance', t => t.stun, 'p'], ['Prism splits', t => t.prism, 'n'], ['Execute below', t => t.execute, 'p'],
  ['Nova', t => t.nova, 'p'], ['Echo', t => t.echo, 'p'], ['Death blast', t => t.deathBlast, 'p'], ['Drag back', t => t.gravity, 'n'], ['Time lock', t => t.timeLock, 's'],
  ['Shatter', t => t.shatter, 'p'], ['Frostfire', t => t.frostfire, 'p'], ['Storm bolts', t => t.storm, 'n'], ['Ion burst', t => t.chainBlast, 'p'], ['Overload', t => t.overload, 'p'],
  ['Pierce', t => t.pierce, 'n'], ['Kill gold', t => t.loot, 'n'], ['Kill heal', t => t.leech, 'n'], ['Tempo', t => t.tempo, 'p'], ['Hex pulse', t => t.hex, 'p'], ['Hex Nova', t => t.hexNova, 'p'],
  ['Buff damage', t => t.support ? beaconDmg(t) : 0, 'p'], ['Buff fire rate', t => t.bRate, 'p'], ['Buff range', t => t.bRange, 'p'], ['Armor ignored', t => t.bSunder, 'p'],
  ['Buff kill gold', t => t.bGold, 'p'], ['Pressure per second', t => t.type === 'anvil' ? t.press : 0, 'p'], ['Pressure cap', t => t.type === 'anvil' ? t.pressCap : 0, 'p'],
  ['Pin', t => t.pin, 's'], ['Hero damage taken', t => t.type === 'anvil' ? 1 - t.guard : 0, 'p'], ['Crush below', t => t.crushExec, 'p'],
];
const readStats = (list, obj) => list.map(([l, f, k]) => [typeof l === 'function' ? l(obj) : l, f(obj), k]);
const heroStats = h => readStats(HERO_STATS, h);
function diffStats(a, b) {
  const out = [];
  a.forEach(([l, v, k], i) => { const w = b[i][1]; if (typeof v === 'number' && typeof w === 'number' && !isNaN(v) && !isNaN(w) && Math.abs(v - w) > 1e-9 && FMT[k](v) !== FMT[k](w)) out.push([l, v, w, k]); });
  return out;
}
function deltaText(list, name) { return list.length ? list.map(([l, a, b, k]) => `${l} ${FMT[k](a)} → ${FMT[k](b)}`).join(' · ') : 'New: ' + name; }
// Runs an upgrade on copies of the hero and run state and reports what changed.
function previewRun(apply, name) {
  const keep = { hero: S.hero, mod: S.mod, lives: S.lives, gold: S.gold, pathBonus: S.pathBonus, freeLevels: S.freeLevels, freeMerges: S.freeMerges, pendingLevels: S.pendingLevels };
  const read = () => heroStats(S.hero).concat(readStats(RUN_STATS, null));
  const before = read();
  S.hero = structuredClone(keep.hero); S.mod = Object.assign({}, keep.mod);
  try { apply(); } catch (e) {}
  const after = read();
  Object.assign(S, keep);
  return deltaText(diffStats(before, after), name);
}
function previewLevel(t, path) {
  const c = Object.assign({}, t, { ups: Object.assign({}, t.ups), rk: Object.assign({}, t.rk), order: t.order.slice() });
  const before = readStats(TOWER_STATS, t);
  const { mastered } = applyLevel(c, path);
  const txt = deltaText(diffStats(before, readStats(TOWER_STATS, c)), path.name);
  return mastered ? txt + ' · New: ' + path.mastery.name : txt;
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
  const relic = pick(RELICS.filter(r => (r.repeat || !owned.has(r.id)) && (!r.offensive || HEROES[S.hero.cls].cat === 'offensive')));
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
  for (let i = 0; i < 8 + n * 3; i++) q.push('grunt');
  if (n >= 2) for (let i = 0; i < n * 2; i++) q.push('runner');
  if (n >= 4) for (let i = 0; i < n - 2; i++) q.push('brute');
  // Special enemies join from their first wave (earlier on some maps) and grow every 2 waves. Once more than 3 are
  // available, each wave brings 2 or 3 of them so waves feel different.
  const early = MAPS[S.map].early || 0, first = k => ENEMIES[k].first - early;
  const open = SPECIAL_ENEMIES.filter(k => n >= first(k));
  const types = open.length > 3 ? shuffle(open.slice()).slice(0, Math.random() < 0.5 ? 2 : 3) : open;
  for (const k of types) for (let i = 0; i < ENEMIES[k].per * (1 + Math.floor((n - first(k)) / 2)); i++) q.push(k);
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
  S.waveActive = true; S.hero.unbreakLeft = S.hero.unbreakMax; S.bossWarned = false; S.oneShotReady = !!S.specials.oneshot && S.hero.cls === 'sniper';
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
  if (S.coins.length) { S.gold += 25 * S.coins.length; msgs.push('+' + 25 * S.coins.length + ' from coins'); S.coins = []; }
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
  if (S.wave % 10 === 0) S.needShop = true;
}
function showShop() {
  S.needShop = false; S.paused = true; S.shops++;
  const demonic = Math.random() < (S.specials.pact ? 0.1 : 0.01), scale = 1 + S.wave / 20;
  let freeLeft = !!S.specials.bazaar;
  const items = shuffle(SHOP_ITEMS.slice()).slice(0, S.specials.bazaar ? 9 : 6).map((it, i) => {
    const dem = demonic && i % 2 === 0, k = S.specials.pact ? 1.5 : 3;
    return { it, dem, m: it.m * (dem ? 2 : 1), cost: Math.round(it.cost * scale / 10) * 10, curse: dem ? pick(CURSES) : null, k, sold: false };
  });
  const render = () => {
    openModal(`<h2 class="${demonic ? 'demonic-title' : ''}">${demonic ? '☠ Demonic Bazaar' : 'Rift Bazaar'}</h2>
      <p>${demonic ? 'A demonic merchant has opened shop. Half of these are demonic: twice as strong, with a curse.' : 'The boss dropped a key to the Rift Bazaar. Everything here is sold only in this shop.'} You have <b style="color:var(--gold)">${Math.floor(S.gold)} gold</b>.</p>
      <div class="choices">${items.map((x, i) => `<button class="choice shop-item ${x.dem ? 'is-demonic' : ''}" data-i="${i}" ${x.sold || (S.gold < x.cost && !freeLeft) ? 'disabled' : ''}>
        <small class="path">${x.dem ? 'Demonic ' : ''}${x.it.kind}</small><b>${x.it.name}</b><span>${x.it.desc(x.m)}</span>${x.sold ? '' : `<span class="delta">${previewRun(() => x.it.apply(x.m), x.it.name)}</span>`}
        ${x.curse ? `<em class="cost">Curse: ${x.curse.desc(x.k)}</em>` : ''}
        <em class="reward">${x.sold ? 'Bought' : freeLeft ? 'Free' : x.cost + ' gold'}</em></button>`).join('')}</div>
      <div class="row" style="margin-top:12px"><button class="go" id="shopLeave">Leave shop</button></div>`);
    $('modalBox').querySelectorAll('.shop-item').forEach(b => b.onclick = () => {
      const x = items[+b.dataset.i];
      const price = freeLeft ? 0 : x.cost;
      if (x.sold || S.gold < price) return;
      S.gold -= price; x.sold = true; freeLeft = false; x.it.apply(x.m); if (x.curse) x.curse.apply(x.k);
      toast('Bought ' + x.it.name + '.'); sfx('level'); renderHero(); render();
    });
    $('shopLeave').onclick = () => { closeModal(); S.paused = false; renderBuildBar(); renderHero(); };
  };
  render();
}
// atD: spawn partway along the path (Splitter pieces, boss summons).
function spawn(type, atD) {
  const d = ENEMIES[type], m = S.mode, map = MAPS[S.map];
  // Enemies get much tougher each wave; bosses also scale with the wave they lead.
  let scale = d.boss ? 1 + 0.15 * Math.max(0, S.wave - 5) : 1 + 0.55 * (S.wave - 1) + 0.1 * (S.wave - 1) ** 2;
  scale *= S.mod.enemyHp;
  if (m.kind === 'hard') scale *= 1.4;
  if (m.hpMul) scale *= m.hpMul;
  if (m.challenge === 'swarm') scale *= 0.65;
  const speed = d.speed * S.mod.enemySpeed * (m.challenge === 'blitz' ? 1.4 : 1);
  const at = atD || 0, p = posAt(at);
  if (!META.seen[type]) { META.seen[type] = true; saveMeta(); renderEnemyCodex(); toast('New enemy: ' + d.name + '. ' + ENEMY_INFO[type][0]); }
  S.enemies.push({ type, boss: !!d.boss, hp: d.hp * scale, max: d.hp * scale, speed, d: at, x: atD ? p.x : p.x - 30, y: p.y,
    slow: 0, slowT: 0, stunT: 0, burnT: 0, burnDps: 0, markT: 0, mark: 0, brittle: 0, brittleT: 0, brk: 0, brkT: 0,
    armor: d.armor ? d.armor + (map.armorBonus || 0) : 0, auraArmor: 0, unslow: !!d.unslow, phase: !!d.phase, split: d.split || 0, heal: d.heal || 0, shieldAura: d.shieldAura || 0,
    taken: 0, stillT: 0, hex: 0, hexT: 0, hexTick: 1, healT: 1, slowedFor: 0,
    gold: d.gold * (m.gilded ? 3 : 1), lives: d.lives, atk: d.atk, r: d.r, color: m.gilded ? 0xf2c14e : d.color, blocked: false, dead: false });
}
// Boss powers. Targeted towers flash red for 1s before the stun lands.
const BOSS_POWER = {
  knight: { name: 'Shield Bash', every: 8,  n: 1, dur: 2, nearest: true },
  warden: { name: 'Rift Lock',   every: 10, n: 2, dur: 3 },
  tyrant: { name: 'Roar',        every: 12, n: 3, dur: 3, roar: true },
};
function bossAct(e, dt) {
  const p = BOSS_POWER[e.type]; if (!p) return;
  if (e.powT == null) e.powT = p.every * 0.6;
  if (e.stunT <= 0) e.powT -= dt;
  if (e.powT <= 0) { e.powT = p.every; bossPower(e, p); }
  if (e.type === 'warden') {
    const steps = [0.75, 0.5, 0.25]; e.sum = e.sum || 0;
    while (e.sum < 3 && e.hp / e.max <= steps[e.sum]) {
      e.sum++;
      for (let i = 0; i < 4; i++) spawn('grunt', Math.max(0, e.d - 15 - 12 * i));
      S.fx.push({ k: 'ring', x: e.x, y: e.y, r: 70, color: 0xff2e4d, t: 0.6, T: 0.6, fill: true }); shake(0.006, 200);
      toast('The Rift Warden tears open a rift!');
    }
  }
  if (e.type === 'tyrant' && !e.enraged && e.hp / e.max <= 0.5) {
    e.enraged = true; e.speed *= 1.3; e.color = 0xff0000;
    for (let i = 0; i < 2; i++) spawn('juggernaut', Math.max(0, e.d - 25 - 20 * i));
    S.fx.push({ k: 'ring', x: e.x, y: e.y, r: 140, color: 0xff0000, t: 0.9, T: 0.9, fill: true }); shake(0.02, 500); sfx('boss');
    toast('The Rift Tyrant is enraged! +30% speed, and 2 Juggernauts join it.');
  }
}
function bossPower(e, p) {
  const live = S.towers.filter(t => !(t.stunT > 0) && !(t.warnT > 0));
  const targets = p.nearest ? live.filter(t => Math.hypot(t.x - e.x, t.y - e.y) <= 260).sort((a, b) => Math.hypot(a.x - e.x, a.y - e.y) - Math.hypot(b.x - e.x, b.y - e.y)).slice(0, 1)
                            : shuffle(live).slice(0, p.n);
  for (const t of targets) {
    t.warnT = 1;
    S.fx.push({ k: 'line', x1: e.x, y1: e.y, x2: t.x, y2: t.y, color: 0xff2e4d, t: 1, T: 1, w: 2 });
    S.delayed.push({ at: S.time + 1, fn: () => {
      t.warnT = 0; if (!S.towers.includes(t)) return;
      t.stunT = Math.max(t.stunT, p.dur * (1 - Math.min(0.8, S.hero.grounded))); t.stunMax = t.stunT;
      S.fx.push({ k: 'ring', x: t.x, y: t.y, r: 26, color: 0xff2e4d, t: 0.4, T: 0.4, fill: true });
    } });
  }
  if (p.roar) {
    const h = S.hero; shake(0.014, 450); sfx('boss');
    S.fx.push({ k: 'ring', x: e.x, y: e.y, r: 220, color: 0xff2e4d, t: 0.7, T: 0.7 });
    if (!h.ko) { const dx = h.x - e.x, dy = h.y - e.y, d = Math.hypot(dx, dy) || 1; h.x = Math.max(10, Math.min(W - 10, h.x + dx / d * 120)); h.y = Math.max(10, Math.min(H - 10, h.y + dy / d * 120)); h.tx = null; }
  }
  if (targets.length || p.roar) toast(ENEMIES[e.type].name + ': ' + p.name + '!');
}

// ---------- combat ----------
// Armor: % damage taken off, capped. Brittle enemies have none; Shieldbearers add to it; Sunder and Armor Break cut it.
function armorOf(e, src) {
  if (e.brittleT > 0) return 0;
  let a = (e.armor || 0) + (e.auraArmor || 0) - (e.brkT > 0 ? e.brk : 0);
  if (src && typeof src === 'object' && src.buff) a -= src.buff.sunder;
  return Math.max(0, Math.min(ARMOR_CAP, a));
}
const coresFor = type => type === 'tyrant' && MAPS[S.map].tyrantCores ? MAPS[S.map].tyrantCores : BOSS_CORES[type] || 0;
// pierce: true = ignores armor (burns, zones, executes); 'hex' = Hex Brand pulse (ignores armor and doesn't feed the brand).
function damage(e, amt, src, pierce) {
  if (e.dead) return;
  amt *= 1 + (e.markT > 0 ? e.mark : 0) + (e.brittleT > 0 ? e.brittle : 0) + (e.spotT > 0 && src && typeof src === 'object' ? e.spot : 0);
  if (!pierce) amt *= 1 - armorOf(e, src);
  const dealt = Math.min(amt, e.hp);
  if (pierce !== 'hex') e.taken = (e.taken || 0) + dealt;
  if (src && typeof src === 'object') { src.dmgWave = (src.dmgWave || 0) + dealt; src.dmgTotal = (src.dmgTotal || 0) + dealt; }
  else if (S.ws) S.ws.heroDmg += dealt;
  e.hp -= amt;
  if (e.hp <= 0) {
    e.dead = true;
    const h = S.hero;
    const byHero = !(src && typeof src === 'object');
    let g = e.gold * S.mod.gold + (byHero ? h.bounty : 0) + h.tithe;
    if (!byHero && src.buff && src.buff.gold) g *= 1 + src.buff.gold;
    if (!byHero && src.buff && src.buff.rush && Math.random() < 0.08) S.coins.push({ x: e.x, y: e.y, t: 0 });
    if (S.heroics.goldrush && Math.random() < 0.08 * S.heroics.goldrush) { g += 15; S.fx.push({ k: 'ring', x: e.x, y: e.y, r: 14, color: 0xf2c14e, t: 0.5, T: 0.5, fill: true }); }
    S.gold += g; h.xp += e.gold * (1 + h.xpGain);
    if (S.ws) { S.ws.kills++; S.ws.gold += g; }
    if (e.split) for (let i = 0; i < e.split; i++) spawn('runner', Math.max(0, e.d - 8 + 16 * i));
    if (e.hexT > 0 && e.hexNova) {
      const boom = (e.taken || 0) * e.hexNova;
      S.fx.push({ k: 'ring', x: e.x, y: e.y, r: 80, color: 0xb07cff, t: 0.45, T: 0.45, fill: true });
      for (const o of inRange(e.x, e.y, 80)) damage(o, boom, e.hexSrc, 'hex');
    }
    if (e.boss) { S.bossKills++; S.cores += coresFor(e.type); S.fx.push({ k: 'ring', x: e.x, y: e.y, r: 80, color: 0xff6fd8, t: 0.9, T: 0.9, fill: true }); shake(0.012, 350); }
    if (h.siphon && !h.ko) h.hp = Math.min(h.maxHp, h.hp + h.siphon);
    if (byHero) {
      if (h.momentum) { h.momStacks = Math.min(10, h.momStacks + 1); h.momT = 4; }
      if (h.odT > 0 && h.ab.bloodrush && (h.odBonus || 0) < 4) { h.odT += 0.4; h.odBonus = (h.odBonus || 0) + 0.4; }
      if (S.specials.oneshot && h.brace) h.braceT = Math.max(h.braceT, h.brace * 0.5);
      if (S.specials.dancer && h.cls === 'striker' && ++h.danceKills % 8 === 0) S.delayed.push({ at: S.time + 0.05, fn: () => { if (!h.ko) castAbility(true); } });
    }
    while (h.xp >= h.next) levelHero(h);
    sfx('kill');
    if (src && typeof src === 'object') {
      if (src.loot) S.gold += src.loot;
      if (src.leech && !h.ko) { h.hp = Math.min(h.maxHp, h.hp + src.leech); h.xp += 1; }
      if (src.deathBlast) { S.fx.push({ k: 'ring', x: e.x, y: e.y, r: 55, color: 0xff8a3d, t: 0.25, T: 0.25, fill: true }); for (const o of inRange(e.x, e.y, 55)) damage(o, e.max * src.deathBlast, src); }
    }
    if (e.boss) {
      const n = coresFor(e.type);
      if (e.type !== 'tyrant') S.pendingHeroic++;
      toast(ENEMIES[e.type].name + ' defeated! +' + n + ' Boss Core' + (n > 1 ? 's' : '') + (e.type !== 'tyrant' ? ' and a heroic power.' : '.'));
    }
    S.fx.push({ k: 'ring', x: e.x, y: e.y, r: e.r + 6, color: e.color, t: 0.3, T: 0.3 });
  }
}
function slowEnemy(e, amt, dur) { if (e.unslow) return; e.slow = Math.min(0.85, Math.max(e.slow, amt + S.mod.slow)); e.slowT = Math.max(e.slowT, dur || 1.6); }
function inRange(x, y, r) { return S.enemies.filter(e => !e.dead && Math.hypot(e.x - x, e.y - y) <= r); }
function nearAura(t) { const h = S.hero; return !h.ko && Math.hypot(h.x - t.x, h.y - t.y) <= h.auraRange; }

function applyHit(t, e, dmg, freeze) {
  if (t.shatter && e.stunT > 0) dmg *= 1 + t.shatter;
  let pierce = false;
  if (t.execute && !e.boss && (e.hp - dmg) / e.max <= t.execute) { dmg = e.hp + 1; pierce = true; }
  if (t.frostfire && e.slowT > 0) { e.burnDps = Math.max(e.burnDps, dmg * t.frostfire / 2); e.burnT = 2; e.burnSrc = t.src; }
  if (t.frostfire && e.burnT > 0) slowEnemy(e, Math.min(0.5, t.frostfire / 3), 1);
  if (S.mod.allSlow) slowEnemy(e, S.mod.allSlow, 1.2);
  if (S.mod.allBurn) { e.burnDps = Math.max(e.burnDps, dmg * S.mod.allBurn / 2); e.burnT = 2; e.burnSrc = t.src; }
  damage(e, dmg, t.src, pierce);
  if (t.slow) slowEnemy(e, t.slow, t.slowDur);
  if (t.brittle) { e.brittle = Math.max(e.brittle, t.brittle); e.brittleT = Math.max(e.brittleT || 0, t.slowDur || 1.6); }
  const hx = t.hex || (S.sig.arcane && baseTypes(t).includes('arcane') && t.shots % 5 === 0 ? 0.02 : 0);
  if (hx) { e.hex = Math.max(e.hex || 0, hx); e.hexT = 4; e.hexSrc = t.src; e.hexNova = Math.max(e.hexNova || 0, t.hexNova || 0); }
  if (t.buff && t.buff.brk) { e.brk = Math.min(0.45, (e.brkT > 0 ? e.brk : 0) + 0.15); e.brkT = 3; }
  if (t.mark) { e.mark = Math.max(e.mark, t.mark); e.markT = 2; }
  if (t.burn) { e.burnDps = Math.max(e.burnDps, dmg * t.burn / 2); e.burnT = 2; e.burnSrc = t.src; }
  if (freeze) e.stunT = Math.max(e.stunT, 1.2);
  if (t.hypo && !e.dead) {
    e.chill = (e.chill || 0) + 1;
    if (e.chill >= t.hypo) {
      e.chill = 0; e.stunT = Math.max(e.stunT, e.boss ? 0.3 : 0.8);
      S.fx.push({ k: 'ring', x: e.x, y: e.y, r: e.r + 8, color: 0xdff6ff, t: 0.45, T: 0.45, fill: true });
      if (t.coldSnap) {
        for (const o of inRange(e.x, e.y, 70)) if (o !== e) o.stunT = Math.max(o.stunT, o.boss ? 0.2 : 0.5);
        S.fx.push({ k: 'ring', x: e.x, y: e.y, r: 70, color: 0x9fe6ff, t: 0.5, T: 0.5, fill: true });
      }
    }
  }
  if (t.auraSlow) slowEnemy(e, t.auraSlow, 1);
}
function fire(t, targets, mult = 1) {
  const h = S.hero, oc = overclocked(t);
  t.shots++; if (!t.lob) t.shotAt = S.time; t.firedAt = S.time; t.hitAt = targets[0] ? { x: targets[0].x, y: targets[0].y } : null;
  let dmg = t.dmg * mult * S.mod.towerDmg * (S.mode.challenge === 'lone' ? 0.6 : 1);
  const aura = h.aura && nearAura(t);
  if (aura) dmg *= 1 + h.aura;
  if (t.buff) { dmg *= 1 + t.buff.dmg; if (t.buff.overdrive && Math.random() < 0.1) dmg *= 3; }
  if (t.surge && t.shots % t.surge === 0) dmg *= 3;
  const over = t.overload && t.shots % 10 === 0;
  if (over) dmg *= 1 + t.overload;
  const big = t.orbital && t.shots % t.orbital === 0;
  const freeze = t.freeze && t.shots % t.freeze === 0;
  if (t === S.drained) dmg *= 0.5;
  if (!t.beam) sfx(t.splash ? 'boom' : 'shot');
  const hitT = Object.assign({}, t, { auraSlow: aura ? h.auraSlow : 0, src: t });
  for (const target of targets) {
    let d = dmg;
    if (t.ramp) {
      if (t.lastTarget === target) t.stacks = Math.min(t.rampMax || 5, t.stacks + (t.beam && S.sig.laser ? 2 : 1));
      else { t.stacks = t.retain ? Math.floor(t.stacks / 2) : 0; t.lastTarget = target; }
      d *= 1 + t.ramp * t.stacks;
      if (t.melt && t.stacks >= t.rampMax) d *= 2;
    }
    const splash = t.splash * (big ? 2 : 1); if (big) d *= 3;
    if (t.beam) S.fx.push({ k: 'line', x1: t.x, y1: t.y, x2: target.x, y2: target.y, color: t.stacks >= t.rampMax ? 0xffffff : t.color, t: 0.22, T: 0.22, w: 2 + t.stacks * 0.2 });
    else if (!t.lob) S.fx.push({ k: 'line', x1: t.x, y1: t.y, x2: target.x, y2: target.y, color: t.color, t: 0.12, T: 0.12, w: t.hybrid ? 3 : 2 });
    const hits = splash ? inRange(target.x, target.y, splash) : [target];
    if (splash) S.fx.push({ k: 'ring', x: target.x, y: target.y, r: splash, color: t.color, t: 0.25, T: 0.25, fill: big });
    if (splash && S.sig.plasma && baseTypes(t).includes('plasma')) S.zones.push({ x: target.x, y: target.y, r: splash * 0.7, t: 2, T: 2, dps: d * 0.25, slow: 0, color: 0xff8a3d, src: t });
    for (const e of hits) { applyHit(hitT, e, d, freeze); if (over) e.stunT = Math.max(e.stunT, 0.5); }
    if (t.prism) for (const n of inRange(target.x, target.y, 90).filter(e => !hits.includes(e)).slice(0, Math.round(t.prism))) {
      S.fx.push({ k: 'line', x1: target.x, y1: target.y, x2: n.x, y2: n.y, color: t.color, t: 0.12, T: 0.12, w: 1 }); applyHit(hitT, n, d * 0.4, false);
    }
    if (t.pierce) for (const n of S.enemies.filter(e => !e.dead && e !== target && e.d < target.d && e.d > target.d - 140).sort((a, b) => b.d - a.d).slice(0, Math.round(t.pierce))) applyHit(hitT, n, d * 0.6, false);
    if (t.gravity && t.shots % 5 === 0) { for (const e of inRange(target.x, target.y, 60)) if (!e.boss) e.d = Math.max(0, e.d - t.gravity); S.fx.push({ k: 'ring', x: target.x, y: target.y, r: 60, color: 0x9a7cff, t: 0.3, T: 0.3 }); }
    if (t.echo && !target.fake) S.echoes.push({ t: hitT, target, d: d * t.echo, at: S.time + 0.25 });
    if (t.cluster) {
      const near = shuffle(inRange(target.x, target.y, 90).filter(e => e !== target)).slice(0, t.cluster);
      for (const n of near) {
        S.fx.push({ k: 'ring', x: n.x, y: n.y, r: (t.splash || 30) * 0.6, color: t.color, t: 0.2, T: 0.2 });
        for (const e of inRange(n.x, n.y, (t.splash || 30) * 0.6)) applyHit(hitT, e, d * 0.5, false);
      }
    }
    const chainN = t.chain + (oc && h.ab.chrono ? 1 : 0);
    if (chainN) {
      const keep = (S.sig.tesla && baseTypes(t).includes('tesla')) || t.chainKeep;
      const hit = new Set(hits); let from = target, cd = d * (keep ? 1 : t.chainMul);
      for (let i = 0; i < chainN; i++) {
        let best = null, bd = t.chainReach;
        for (const e of S.enemies) { if (e.dead || hit.has(e)) continue; const dd = Math.hypot(e.x - from.x, e.y - from.y); if (dd < bd) { bd = dd; best = e; } }
        if (!best) break;
        S.fx.push({ k: 'line', x1: from.x, y1: from.y, x2: best.x, y2: best.y, color: t.color, t: 0.15, T: 0.15, w: 1.5 });
        applyHit(hitT, best, cd, false);
        if (t.chainBlast) for (const o of inRange(best.x, best.y, 40)) if (o !== best) damage(o, cd * t.chainBlast, t);
        if (t.stun && Math.random() < t.stun) best.stunT = Math.max(best.stunT, 0.6);
        hit.add(best); from = best; if (!keep) cd *= 0.85;
      }
    }
  }
  if (oc && h.ab.prismF) {
    const extra = inRange(t.x, t.y, tRange(t)).find(e => !targets.includes(e));
    if (extra) { applyHit(hitT, extra, dmg * 0.7, false); S.fx.push({ k: 'line', x1: t.x, y1: t.y, x2: extra.x, y2: extra.y, color: 0xff6fd8, t: 0.15, T: 0.15, w: 3 }); }
  }
}
// Siege Mortar: shells fly slowly toward where the target will be (leading it along the path) and blast on landing.
function lobShell(t, e, mult) {
  const fast = S.sig.mortar ? 1.4 : 1, speed = 170 * fast;
  let T = Math.max(0.6, Math.hypot(e.x - t.x, e.y - t.y) / speed);
  const lead = e.stunT > 0 || e.blocked ? 0 : e.speed * (1 - e.slow) * T;
  const p = posAt(Math.min(PATH_LEN, e.d + lead));
  T = Math.max(0.6, Math.hypot(p.x - t.x, p.y - t.y) / speed);
  t.shotAt = S.time;
  S.shells.push({ tw: t, x0: t.x, y0: t.y, x1: p.x, y1: p.y, t: 0, T, mult });
}
function landShell(sh) {
  const t = sh.tw;
  if (!S.towers.includes(t)) return;
  const spot = { x: sh.x1, y: sh.y1, d: -1, dead: false, fake: true };
  const keep = t.splash; if (S.sig.mortar) t.splash *= 1.2;
  fire(t, [spot], sh.mult);
  const r = t.splash * (t.orbital && t.shots % t.orbital === 0 ? 2 : 1);
  t.splash = keep;
  if (t.firestorm) S.zones.push({ x: spot.x, y: spot.y, r: r * 0.8, t: 3, T: 3, dps: t.dmg * S.mod.towerDmg * 0.25, slow: 0, color: 0xff8a3d, src: t });
  if (t.quakeStun && t.shots % 4 === 0) { for (const e of inRange(spot.x, spot.y, r)) e.stunT = Math.max(e.stunT, e.boss ? 0.3 : 0.8); S.fx.push({ k: 'ring', x: spot.x, y: spot.y, r: r + 15, color: 0xfff0a0, t: 0.5, T: 0.5 }); }
  shake(0.004, 110);
}
// Effects that trigger once per shot rather than per target.
function shotEffects(t, dmg) {
  const inR = () => inRange(t.x, t.y, tRange(t));
  if (t.nova && t.shots % 6 === 0) { for (const e of inR()) applyHit(Object.assign({}, t, { src: t }), e, dmg * t.nova, false); S.fx.push({ k: 'ring', x: t.x, y: t.y, r: tRange(t), color: t.color, t: 0.3, T: 0.3 }); }
  if (t.timeLock && t.shots % 8 === 0) { for (const e of inR()) e.stunT = Math.max(e.stunT, t.timeLock); S.fx.push({ k: 'ring', x: t.x, y: t.y, r: tRange(t), color: 0xb07cff, t: 0.3, T: 0.3, fill: true }); }
  if (t.storm && t.shots % 4 === 0) for (const e of shuffle(inR()).slice(0, Math.round(t.storm))) { applyHit(Object.assign({}, t, { src: t }), e, dmg * 0.8, false); S.fx.push({ k: 'line', x1: e.x, y1: e.y - 200, x2: e.x, y2: e.y, color: 0x8affff, t: 0.2, T: 0.2, w: 2 }); }
}
// Rift Beacon: each tower takes the strongest Beacon in reach (two with Twin Signal).
const beaconDmg = b => b.bDmg;
const beaconPower = b => beaconDmg(b) + b.bRate + b.bRange + b.bSunder + b.bGold;
function computeBuffs() {
  const beacons = S.towers.filter(b => b.support && !(b.stunT > 0));
  for (const t of S.towers) {
    t.buff = null;
    if (t.support || !beacons.length) continue;
    const near = beacons.filter(b => Math.hypot(b.x - t.x, b.y - t.y) <= tRange(b)).sort((a, b) => beaconPower(b) - beaconPower(a)).slice(0, S.sig.beacon ? 2 : 1);
    if (!near.length) continue;
    const f = { dmg: 0, rate: 0, range: 0, sunder: 0, gold: 0, overdrive: false, tempo: false, light: false, brk: false, rush: false, from: near };
    for (const b of near) {
      f.dmg += beaconDmg(b); f.rate += b.bRate; f.range += b.bRange; f.sunder += b.bSunder; f.gold += b.bGold;
      f.overdrive = f.overdrive || b.bOverdrive; f.tempo = f.tempo || (b.bTempo && S.time % 10 < 3);
      f.light = f.light || b.bLight; f.brk = f.brk || b.bBreak; f.rush = f.rush || b.bRush;
    }
    t.buff = f;
  }
}
// Grave Anvil: crushes enemies that aren't moving; moving ones take 30%.
function anvilSlam(t, area, mult) {
  const h = S.hero;
  t.shots++; t.shotAt = t.firedAt = S.time; t.hitAt = { x: t.x, y: t.y };
  let base = t.dmg * S.mod.towerDmg * mult * (S.mode.challenge === 'lone' ? 0.6 : 1);
  if (h.aura && nearAura(t)) base *= 1 + h.aura;
  if (t.buff) { base *= 1 + t.buff.dmg; if (t.buff.overdrive && Math.random() < 0.1) base *= 3; }
  if (t === S.drained) base *= 0.5;
  let hits = area;
  if (S.sig.anvil) { const more = S.enemies.filter(o => !o.dead && !area.includes(o) && area.some(e => Math.abs(o.d - e.d) <= 80)); hits = area.concat(more); for (const o of more) S.fx.push({ k: 'ring', x: o.x, y: o.y, r: 14, color: t.color, t: 0.25, T: 0.25 }); }
  const hitT = Object.assign({}, t, { src: t, auraSlow: 0 });
  for (const e of hits) {
    const stopped = e.stunT > 0 || e.blocked || e.tauntT > 0;
    const d = base * (stopped ? 1 + Math.min(t.pressCap, t.press * e.stillT) : 0.3);
    if (stopped && t.crushExec && !e.boss && (e.hp - d) / e.max <= t.crushExec) {
      damage(e, e.hp + 1, t, true); S.fx.push({ k: 'ring', x: e.x, y: e.y, r: e.r + 10, color: 0xffffff, t: 0.4, T: 0.4, fill: true }); continue;
    }
    applyHit(hitT, e, d, false);
    if (stopped && t.pin) e.stunT = Math.max(e.stunT, e.boss ? t.pin / 2 : t.pin);
  }
  if (t.shackle && t.shots % 4 === 0) { for (const e of hits) e.stunT = Math.max(e.stunT, e.boss ? 0.5 : 1); S.fx.push({ k: 'ring', x: t.x, y: t.y, r: tRange(t) + 10, color: 0x9a7cff, t: 0.5, T: 0.5 }); }
  S.fx.push({ k: 'ring', x: t.x, y: t.y, r: tRange(t), color: t.color, t: 0.35, T: 0.35, fill: true });
  if (mult >= 1) shake(0.002, 90);
  sfx('boom');
  if (t.after && mult >= 1) S.delayed.push({ at: S.time + 0.5, fn: () => {
    if (!S.towers.includes(t)) return;
    const a = inRange(t.x, t.y, tRange(t)); if (a.length) anvilSlam(t, a, 0.5);
  } });
}
function heroDmg() { return S.hero.dmg * (S.mode.challenge === 'lone' ? 2 : 1); }

function useAbility() {
  const h = S && S.hero, a = h && h.ab;
  if (!h || h.ko > 0 || a.t > 0 || S.over || S.paused) return;
  if ((a.id === 'pierce' || a.id === 'strike') && !S.aim && !S.enemies.some(e => !e.dead)) return toast('No target for ' + a.name + '. Press F to set an aim point.');
  a.t = a.cd;
  castAbility(false);
}
// Runs the ability's effect. Free casts (Blade Dancer) don't touch the cooldown.
function castAbility(free) {
  const h = S.hero, a = h.ab;
  if (a.id === 'pierce') return piercingShot(h, a);
  sfx('ability');
  if (a.id === 'slam') slam(h, a, 1);
  else if (a.id === 'nova') riftNova(h, a);
  else if (a.id === 'bulwark') bulwarkShield(h, a);
  else if (a.id === 'overdrive') { h.odT = a.dur; h.odBonus = 0; S.fx.push({ k: 'ring', x: h.x, y: h.y, r: 60, color: 0xff6f6f, t: 0.6, T: 0.6, fill: true }); shake(0.004, 120); }
  else if (a.id === 'strike') orbitalStrike(h, a);
  else if (a.id === 'stasis') {
    S.stasisT = a.dur; S.stasisAt = { x: h.x, y: h.y };
    if (a.anchor) for (const e of inRange(h.x, h.y, a.r)) e.stunT = Math.max(e.stunT, e.boss ? 0.5 : 1.5);
    S.fx.push({ k: 'ring', x: h.x, y: h.y, r: a.r, color: 0x7fd4ff, t: 0.7, T: 0.7, fill: true });
  } else {
    S.overclockT = a.dur; S.overclockAt = { x: h.x, y: h.y };
    S.fx.push({ k: 'ring', x: h.x, y: h.y, r: a.r, color: 0xb07cff, t: 0.6, T: 0.6, fill: true });
  }
}
// Vanguard alt: a shield that soaks damage, then bursts for part of what it soaked.
function bulwarkShield(h, a) {
  h.shieldMax = h.shield = a.dmg * 5 * (a.overflow ? 1.5 : 1); h.shieldT = a.dur; h.soaked = 0;
  S.fx.push({ k: 'ring', x: h.x, y: h.y, r: 34, color: 0x9af0ff, t: 0.6, T: 0.6, fill: true }); shake(0.004, 120);
}
function endShield(h) {
  const a = h.ab, dmg = a.dmg + (h.soaked || 0) * 0.6;
  for (const e of inRange(h.x, h.y, a.r)) damage(e, dmg);
  if (a.overflow && h.shield > 0) h.hp = Math.min(h.maxHp, h.hp + h.shield);
  S.fx.push({ k: 'ring', x: h.x, y: h.y, r: a.r, color: 0x9af0ff, t: 0.45, T: 0.45, fill: true }); shake(0.006, 160);
  h.shield = 0; h.shieldT = 0; h.soaked = 0;
}
// Damage to the hero goes through the Bulwark Shield first.
function hurtHero(h, loss) {
  if (h.shield > 0) { const soak = Math.min(h.shield, loss); h.shield -= soak; h.soaked = (h.soaked || 0) + soak; loss -= soak; if (h.shield <= 0) endShield(h); }
  h.hp -= loss; if (S.heroics.retribution) h.retStore += loss;
}
// Sniper alt: a heavy blast at the aim point (F) or the toughest enemy, after a short delay.
function orbitalStrike(h, a) {
  const tough = S.enemies.filter(e => !e.dead).sort((p, q) => (q.boss - p.boss) || (q.hp - p.hp))[0];
  const at = S.aim ? { x: S.aim.x, y: S.aim.y } : tough ? { x: tough.x, y: tough.y } : null;
  if (!at) return;
  sfx('snipe');
  S.fx.push({ k: 'line', x1: at.x, y1: 0, x2: at.x, y2: at.y, color: 0xffd36e, t: 0.8, T: 0.8, w: 2 });
  S.fx.push({ k: 'ring', x: at.x, y: at.y, r: a.r, color: 0xff5d6c, t: 0.8, T: 0.8 });
  const boom = (x, y, r, mult) => {
    for (const e of inRange(x, y, r)) damage(e, heroDmg() * a.mult * mult * (e.boss ? 1 + h.headhunter : 1));
    S.fx.push({ k: 'line', x1: x, y1: 0, x2: x, y2: y, color: 0xffffff, t: 0.25, T: 0.25, w: 10 * mult });
    S.fx.push({ k: 'ring', x, y, r, color: 0xffd36e, t: 0.5, T: 0.5, fill: true });
    if (a.scorch) S.zones.push({ x, y, r: r * 0.8, t: 4, T: 4, dps: heroDmg() * 0.6, slow: 0, color: 0xff8a3d });
  };
  S.delayed.push({ at: S.time + 0.8, fn: () => {
    boom(at.x, at.y, a.r, 1); shake(0.014, 280); sfx('boom');
    if (a.carpet) for (let i = 0; i < 3; i++) { const ang = Math.random() * Math.PI * 2, d = a.r * 0.9; S.delayed.push({ at: S.time + 0.15 * (i + 1), fn: () => boom(at.x + Math.cos(ang) * d, at.y + Math.sin(ang) * d, a.r * 0.7, 0.5) }); }
  } });
}
function slam(h, a, mult) {
  const x = h.x, y = h.y, r = a.r * (a.magnet ? 1.5 : 1);
  for (const e of inRange(x, y, r)) {
    damage(e, a.dmg * mult); e.stunT = Math.max(e.stunT, a.stun * mult);
    if (a.magnet) { if (!e.boss) e.d = Math.max(0, e.d - 50); S.fx.push({ k: 'line', x1: e.x, y1: e.y, x2: x, y2: y, color: 0x9af0ff, t: 0.35, T: 0.35, w: 2 }); }
  }
  if (h.taunt) for (const e of inRange(x, y, Math.max(120, r))) e.tauntT = Math.max(e.tauntT || 0, e.boss ? h.taunt / 2 : h.taunt);
  S.fx.push({ k: 'ring', x, y, r, color: 0x5fe39a, t: 0.4, T: 0.4, fill: true });
  shake(0.006 * mult + 0.002, 180);
  if (mult < 1) return;
  if (a.rings) for (let i = 0; i < 3; i++) S.delayed.push({ at: S.time + 0.18 * (i + 1), fn: () => {
    const rr = r * (1.3 + 0.3 * i);
    for (const e of inRange(x, y, rr)) { damage(e, a.dmg * 0.4); if (!e.boss) e.d = Math.max(0, e.d - 20); }
    S.fx.push({ k: 'ring', x, y, r: rr, color: 0x9af0ff, t: 0.35, T: 0.35 });
  } });
  if (a.molten) S.zones.push({ x, y, r: r * 0.8, t: 4, T: 4, dps: a.dmg * 0.6, slow: 0.35, color: 0xff8a3d });
  if (a.echo) S.delayed.push({ at: S.time + 1, fn: () => { if (!S.hero.ko) slam(S.hero, a, 0.5); } });
}
function riftNova(h, a) {
  if (a.dash && S.pointer) {
    const dx = S.pointer.x - h.x, dy = S.pointer.y - h.y, d = Math.hypot(dx, dy) || 1, len = Math.min(220, d);
    const nx = h.x + dx / d * len, ny = h.y + dy / d * len;
    for (let i = 0; i <= 5; i++) S.zones.push({ x: h.x + (nx - h.x) * i / 5, y: h.y + (ny - h.y) * i / 5, r: 26, t: 3, T: 3, dps: a.dmg * 0.5, slow: 0, color: 0xff6f6f });
    S.fx.push({ k: 'line', x1: h.x, y1: h.y, x2: nx, y2: ny, color: 0xffffff, t: 0.3, T: 0.3, w: 6 });
    h.x = nx; h.y = ny; h.tx = null;
  }
  const blast = (x, y, r, dmg, depth) => {
    const hit = inRange(x, y, r);
    for (const e of hit) damage(e, dmg);
    S.fx.push({ k: 'ring', x, y, r, color: depth ? 0xff6fd8 : 0xb07cff, t: 0.45, T: 0.45, fill: true });
    if (a.chainN && depth < 3) for (const e of hit) if (e.dead) S.delayed.push({ at: S.time + 0.12, fn: () => blast(e.x, e.y, 55, dmg * 0.5, depth + 1) });
  };
  if (a.hole) {
    const x = h.x, y = h.y;
    for (const e of inRange(x, y, a.r)) e.stunT = Math.max(e.stunT, 1.5);
    S.zones.push({ x, y, r: a.r, t: 1.5, T: 1.5, dps: 0, slow: 0, color: 0x9a7cff, vortex: true });
    S.delayed.push({ at: S.time + 1.5, fn: () => { blast(x, y, a.r, a.dmg * 1.5, 0); shake(0.015, 300); sfx('boom'); } });
  } else { blast(h.x, h.y, a.r, a.dmg, 0); shake(0.006, 180); }
  if (a.twin) {
    const tough = S.enemies.filter(e => !e.dead).sort((p, q) => q.hp - p.hp)[0];
    if (tough) S.delayed.push({ at: S.time + 0.25, fn: () => blast(tough.x, tough.y, a.r * 0.8, a.dmg, 0) });
  }
}
// A round through every enemy on the line from the hero toward the aim point (F), or the lead enemy if none is set.
function piercingShot(h, a) {
  const lead = S.enemies.filter(e => !e.dead).sort((x, y) => (y.boss - x.boss) || (y.d - x.d))[0];
  const goal = S.aim || lead;
  if (!goal) return;
  const dx = goal.x - h.x, dy = goal.y - h.y, len = Math.hypot(dx, dy) || 1, ux = dx / len, uy = dy / len;
  const w = a.w * (a.rail ? 3 : 1), base = heroDmg() * a.mult, hit = [];
  for (const e of S.enemies.filter(e => !e.dead)) {
    const along = (e.x - h.x) * ux + (e.y - h.y) * uy, off = Math.abs((e.x - h.x) * uy - (e.y - h.y) * ux);
    if (along > 0 && off <= w + e.r) hit.push(e);
  }
  let kills = 0;
  for (const e of hit) {
    let d = base * (e.boss ? 1 + h.headhunter : 1);
    const ex = a.execR && !e.boss && (e.hp - d) / e.max <= 0.3;
    if (ex) d = e.hp + 1;
    damage(e, d, undefined, ex); if (e.dead) kills++;
    if (a.cluster) { for (const o of inRange(e.x, e.y, 50)) if (o !== e) damage(o, base * 0.4); S.fx.push({ k: 'ring', x: e.x, y: e.y, r: 50, color: 0xffb35d, t: 0.3, T: 0.3, fill: true }); }
  }
  const ex = h.x + ux * 2000, ey = h.y + uy * 2000;
  S.fx.push({ k: 'line', x1: h.x, y1: h.y, x2: ex, y2: ey, color: 0xffd36e, t: 0.35, T: 0.35, w: a.rail ? 14 : 4 });
  if (a.rail) S.zones.push({ line: true, x1: h.x, y1: h.y, x2: ex, y2: ey, r: w, t: 3, T: 3, dps: heroDmg() * 0.8, slow: 0, color: 0xffd36e });
  if (a.bounce) {
    let from = hit.length ? hit.reduce((p, q) => p.d > q.d ? p : q) : lead; const done = new Set(hit);
    if (!from) from = { x: S.aim.x, y: S.aim.y };
    for (let i = 0; i < 5; i++) {
      const n = S.enemies.filter(e => !e.dead && !done.has(e)).sort((p, q) => Math.hypot(p.x - from.x, p.y - from.y) - Math.hypot(q.x - from.x, q.y - from.y))[0];
      if (!n) break;
      S.fx.push({ k: 'line', x1: from.x, y1: from.y, x2: n.x, y2: n.y, color: 0xffd36e, t: 0.3, T: 0.3, w: 3 });
      damage(n, base * 0.6); done.add(n); from = n;
    }
  }
  if (a.execR && kills) a.t = Math.max(0, a.t - a.cd * Math.min(0.4, 0.1 * kills));
  shake(a.rail ? 0.012 : 0.005, 200); sfx('snipe');
}
function overchargeBurst() {
  const at = S.overclockAt, h = S.hero;
  for (const t of S.towers) if (Math.hypot(at.x - t.x, at.y - t.y) <= h.ab.r) {
    const e = inRange(t.x, t.y, tRange(t)).sort((a, b) => b.d - a.d)[0]; if (!e) continue;
    applyHit(Object.assign({}, t, { src: t }), e, t.dmg * S.mod.towerDmg * 3, false);
    S.fx.push({ k: 'line', x1: t.x, y1: t.y, x2: e.x, y2: e.y, color: 0xffffff, t: 0.3, T: 0.3, w: 5 }, { k: 'ring', x: e.x, y: e.y, r: 30, color: 0xb07cff, t: 0.4, T: 0.4, fill: true });
  }
  shake(0.01, 250); sfx('boom');
}
function segDist(px, py, z) {
  const vx = z.x2 - z.x1, vy = z.y2 - z.y1, l = vx * vx + vy * vy || 1, k = Math.max(0, Math.min(1, ((px - z.x1) * vx + (py - z.y1) * vy) / l));
  return Math.hypot(px - z.x1 - k * vx, py - z.y1 - k * vy);
}
// Second Chance: the current wave starts over instead of the run ending.
function restartWave(reason) {
  S.secondChance = false;
  S.enemies = []; S.zones = []; S.delayed = []; S.echoes = []; S.shells = [];
  S.spawnQ = makeWave(S.wave, S.mode); S.spawnT = 1.5; S.lives = Math.max(S.lives, 10); S.bossWarned = false;
  for (const t of S.towers) { t.warnT = 0; t.stunT = 0; }
  S.fx.push({ k: 'ring', x: BASE.x, y: BASE.y, r: 220, color: 0xf2c14e, t: 1.2, T: 1.2, fill: true }); shake(0.015, 500);
  toast(reason + '. Second Chance: the wave starts over!'); sfx('boss');
}
function overclocked(t) { return S.overclockT > 0 && Math.hypot(S.overclockAt.x - t.x, S.overclockAt.y - t.y) <= S.hero.ab.r; }

function knockOut(h) {
  if (h.unbreakable && h.unbreakLeft > 0) { h.unbreakLeft--; h.hp = h.maxHp; S.fx.push({ k: 'ring', x: h.x, y: h.y, r: 90, color: 0x5fe39a, t: 0.7, T: 0.7, fill: true }); shake(0.01, 250); toast('Unbreakable! Back to full HP.'); return; }
  h.hp = 0; h.ko = h.respawn; h.tx = null; S.pendingBuild = null; if (S.ws) S.ws.heroKOs++;
  h.shield = 0; h.shieldT = 0; h.odT = 0;
  // Respawning at the base with Hold on would pin the hero there, so Hold always turns off.
  if (h.hold) { h.hold = false; renderBuildBar(); }
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
  if (S.needShop) return showShop();
  if (S.needChoice) { S.needChoice = false; return offerWaveChoice(); }
  dt *= S.speed;
  S.time += dt;
  const h = S.hero, HX = S.heroics;

  if (S.waveActive) {
    S.spawnT -= dt;
    if (S.spawnT <= 0 && S.spawnQ.length) { spawn(S.spawnQ.shift()); S.spawnT = S.interval; }
    if (!S.spawnQ.length && !S.enemies.length) return endWave();
  }
  if (S.overclockT > 0) {
    if (h.ab.mobile) S.overclockAt = { x: h.x, y: h.y };
    S.overclockT -= dt;
    if (S.overclockT <= 0 && h.ab.burst) overchargeBurst();
  }
  if (h.momT > 0) { h.momT -= dt; if (h.momT <= 0) h.momStacks = 0; }
  if (h.shieldT > 0) { h.shieldT -= dt; if (h.shieldT <= 0) endShield(h); }
  if (h.odT > 0) h.odT -= dt;
  if (S.stasisT > 0) S.stasisT -= dt;
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
    if (keyMove && (kx || ky) && !h.hold) {
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
        h.cd = h.rate / (1 + h.momentum * h.momStacks) / (h.odT > 0 ? 1 + h.ab.power : 1); h.attacks++; sfx(h.brace ? 'snipe' : 'shot');
        const ts = h.bulletStorm && h.attacks % h.bulletStorm === 0 ? inR : inR.slice(0, 1 + h.multi + (h.odT > 0 && h.ab.afterimg ? 2 : 0));
        for (const t of ts) {
          const crit = Math.random() < h.crit || (h.deadeye && h.attacks % h.deadeye === 0);
          let dmg = heroDmg() * (crit ? h.critDmg : 1);
          if (t.boss && h.headhunter) dmg *= 1 + h.headhunter;
          if (S.oneShotReady) { dmg *= 10; S.oneShotReady = false; S.fx.push({ k: 'ring', x: t.x, y: t.y, r: 46, color: 0xffffff, t: 0.6, T: 0.6, fill: true }); shake(0.012, 250); toast('One Shot!'); }
          if (h.boonRail && h.attacks % h.boonRail === 0) dmg *= 4;
          const ex = h.execute && !t.boss && (t.hp - dmg) / t.max <= h.execute;
          if (ex) dmg = t.hp + 1;
          damage(t, dmg, undefined, ex);
          if (h.shotStun) t.stunT = Math.max(t.stunT, t.boss ? 0.2 : h.shotStun);
          if (h.spotter) { t.spot = Math.max(t.spot || 0, h.spotter); t.spotT = 3; }
          if (HX.marked && h.attacks % 5 === 0) { t.mark = Math.max(t.mark, 0.2 * HX.marked); t.markT = 4; S.fx.push({ k: 'ring', x: t.x, y: t.y, r: t.r + 12, color: 0xff2e4d, t: 0.5, T: 0.5 }); }
          if (HX.ricochet) {
            let from = t; const done = new Set([t]);
            for (let i = 0; i < HX.ricochet; i++) {
              const n = inRange(from.x, from.y, 160).filter(e => !done.has(e))[0]; if (!n) break;
              damage(n, dmg * 0.5); S.fx.push({ k: 'line', x1: from.x, y1: from.y, x2: n.x, y2: n.y, color: 0xffd36e, t: 0.15, T: 0.15, w: 2 }); done.add(n); from = n;
            }
          }
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
    if (HX.retribution && S.waveActive) {
      h.retT -= dt;
      const near = h.retT <= 0 ? inRange(h.x, h.y, 110) : [];
      if (near.length) {
        const dmg = 20 * HX.retribution + h.retStore * 0.3 * HX.retribution;
        for (const e of near) damage(e, dmg);
        S.fx.push({ k: 'ring', x: h.x, y: h.y, r: 110, color: 0x5fe39a, t: 0.4, T: 0.4, fill: true }); if (dmg > 80) shake(0.004, 120);
        h.retT = 4; h.retStore = 0;
      }
    }
    if (HX.barrage && S.waveActive) {
      h.barrageT -= dt;
      const pool = h.barrageT <= 0 ? inRange(h.x, h.y, Math.min(h.range, 400) + 60) : [];
      if (pool.length) {
        h.barrageT = 5;
        const n = 2 + 2 * HX.barrage, per = heroDmg() * 1.5 + 10 * HX.barrage;
        for (let i = 0; i < n; i++) S.delayed.push({ at: S.time + 0.08 * i, fn: () => {
          const live = S.enemies.filter(e => !e.dead && Math.hypot(e.x - h.x, e.y - h.y) <= Math.min(h.range, 400) + 120); if (!live.length) return;
          const e = live[Math.floor(Math.random() * live.length)];
          S.fx.push({ k: 'line', x1: h.x, y1: h.y, x2: e.x, y2: e.y, color: 0xff6fd8, t: 0.18, T: 0.18, w: 2 });
          S.fx.push({ k: 'ring', x: e.x, y: e.y, r: 14, color: 0xff6fd8, t: 0.25, T: 0.25, fill: true });
          damage(e, per);
        } });
      }
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
  else if (h.autoCast && !h.ko && S.enemies.length && (h.ab.id === 'slam' || h.ab.id === 'nova' || h.ab.id === 'stasis' ? inRange(h.x, h.y, h.ab.r).length : true)) useAbility();

  let blocking = 0;
  const order = S.enemies.slice().sort((a, b) => b.d - a.d), tank = HEROES[h.cls].cat === 'defensive';
  for (const e of order) {
    e.blocked = false; e.auraArmor = 0;
    if (e.phase && !tank) continue; // Phantoms walk through every hero except Defensive ones
    if (!h.ko && blocking < h.block && Math.hypot(e.x - h.x, e.y - h.y) <= e.r + 14) { e.blocked = true; blocking++; }
  }
  for (const sb of S.enemies) if (sb.shieldAura && !sb.dead) for (const o of inRange(sb.x, sb.y, 70)) if (o !== sb) o.auraArmor += sb.shieldAura;
  const anvils = S.towers.filter(t => t.type === 'anvil' && !(t.stunT > 0));
  S.tide = anvils.some(t => t.tide);
  for (const e of S.enemies) {
    if (e.dead) continue;
    if (e.slowT > 0) { e.slowT -= dt; if (e.slowT <= 0) e.slow = 0; }
    if (e.brittleT > 0) { e.brittleT -= dt; if (e.brittleT <= 0) e.brittle = 0; }
    if (e.brkT > 0) e.brkT -= dt;
    if (e.boss) bossAct(e, dt);
    if (e.heal && (e.healT -= dt) <= 0) {
      e.healT = 1;
      const near = inRange(e.x, e.y, 70).filter(o => o !== e && !o.boss && o.hp < o.max);
      for (const o of near) o.hp = Math.min(o.max, o.hp + o.max * e.heal);
      if (near.length) S.fx.push({ k: 'ring', x: e.x, y: e.y, r: 70, color: 0x7dffb0, t: 0.4, T: 0.4 });
    }
    if (e.hexT > 0) {
      e.hexT -= dt;
      if ((e.hexTick -= dt) <= 0) {
        e.hexTick = 1;
        const pulse = e.taken * e.hex;
        if (pulse > 0) { for (const o of inRange(e.x, e.y, 60)) damage(o, pulse, e.hexSrc, 'hex'); S.fx.push({ k: 'ring', x: e.x, y: e.y, r: 60, color: 0xb07cff, t: 0.35, T: 0.35, fill: true }); }
        if (e.dead) continue;
      }
    }
    // Deep Freeze (Frost signature): slowed for 3s straight freezes solid for 1s.
    if (S.sig.frost) { if (e.slowT > 0) { e.slowedFor += dt; if (e.slowedFor >= 3) { e.slowedFor = 0; e.stunT = Math.max(e.stunT, 1); S.fx.push({ k: 'ring', x: e.x, y: e.y, r: e.r + 8, color: 0xdff6ff, t: 0.5, T: 0.5, fill: true }); } } else e.slowedFor = 0; }
    // Grave Anvil pressure: time spent not moving.
    if (e.stunT > 0 || e.blocked || e.tauntT > 0) e.stillT += dt; else e.stillT = S.tide ? Math.max(0, e.stillT - dt * 2) : 0;
    if (e.markT > 0) e.markT -= dt;
    if (e.spotT > 0) e.spotT -= dt;
    if (S.stasisT > 0 && Math.hypot(e.x - S.stasisAt.x, e.y - S.stasisAt.y) <= h.ab.r) { slowEnemy(e, Math.min(0.85, h.ab.power * 0.75), 0.3); if (h.ab.shatterS) { e.mark = Math.max(e.mark, 0.25); e.markT = Math.max(e.markT, 0.3); } }
    if (S.overclockT > 0 && h.ab.chrono && Math.hypot(e.x - S.overclockAt.x, e.y - S.overclockAt.y) <= h.ab.r) slowEnemy(e, 0.3, 0.3);
    if (e.burnT > 0) { e.burnT -= dt; damage(e, e.burnDps * dt, e.burnSrc, true); if (e.dead) continue; }
    if (S.overclockT > 0 && h.timeWarp && Math.hypot(e.x - S.overclockAt.x, e.y - S.overclockAt.y) <= h.ab.r) slowEnemy(e, h.timeWarp, 0.3);
    if (e.stunT > 0) { e.stunT -= dt; }
    else if (e.tauntT > 0 && !h.ko) { e.tauntT -= dt; hurtHero(h, e.atk * (1 - h.armor) * dt * 0.5); }
    else if (e.blocked) {
      let guard = 0;
      for (const t of anvils) if (t.guard && Math.hypot(t.x - e.x, t.y - e.y) <= tRange(t)) guard = Math.max(guard, t.guard);
      hurtHero(h, e.atk * (1 - h.armor) * (1 - Math.min(0.6, guard)) * dt);
      if (h.shield > 0 && h.ab.spiked) damage(e, 40 * dt);
      if (h.thorns) damage(e, h.thorns * dt);
    } else {
      e.d += e.speed * (1 - e.slow) * dt;
      if (e.d >= PATH_LEN) {
        e.dead = true; sfx('leak');
        S.fx.push({ k: 'ring', x: BASE.x, y: BASE.y, r: BIG_BOSS[e.type] ? 120 : 30, color: 0xff5d6c, t: 0.6, T: 0.6, fill: !!e.boss });
        shake(e.boss ? 0.02 : 0.004, e.boss ? 450 : 120);
        // Big bosses end the run if they get through; mini bosses cost 5 base HP.
        if (BIG_BOSS[e.type]) {
          if (S.mod.phoenix) { S.mod.phoenix = false; toast('Phoenix Core destroyed the ' + ENEMIES[e.type].name + ' at your gate!'); continue; }
          if (S.secondChance) return restartWave('The ' + ENEMIES[e.type].name + ' broke through');
          S.loseReason = 'The ' + ENEMIES[e.type].name + ' broke through your base.'; S.lives = 0; return endRun(false);
        }
        S.lives -= e.lives; if (S.ws) S.ws.livesLost += e.lives;
        if (S.lives <= 0 && S.mod.phoenix) { S.mod.phoenix = false; S.lives = 10; toast('Phoenix Core saved your base!'); }
        if (S.lives <= 0 && S.secondChance) return restartWave('Your base was about to fall');
        if (S.lives <= 0) { S.lives = 0; return endRun(false); }
        continue;
      }
    }
    if (!e.dead) { const p = posAt(e.d); e.x = p.x; e.y = p.y; }
  }
  if (!h.ko && h.hp <= 0) knockOut(h);
  if (!S.bossWarned && S.enemies.some(e => !e.dead && BIG_BOSS[e.type] && e.d / PATH_LEN >= 0.75)) { S.bossWarned = true; toast('Boss approaching your base! If it gets through, the run is lost.'); sfx('boss'); }
  for (const z of S.zones) {
    z.t -= dt;
    if (z.dps || z.slow) for (const e of S.enemies) {
      if (e.dead) continue;
      if (z.line ? segDist(e.x, e.y, z) > z.r + e.r : Math.hypot(e.x - z.x, e.y - z.y) > z.r) continue;
      if (z.dps) damage(e, z.dps * dt, z.src, true);
      if (z.slow) slowEnemy(e, z.slow, 0.3);
    }
  }
  S.zones = S.zones.filter(z => z.t > 0);
  for (const d of S.delayed) if (!S.over && S.time >= d.at) { d.done = true; d.fn(); }
  S.delayed = S.delayed.filter(d => !d.done);
  for (const sh of S.shells) if ((sh.t += dt) >= sh.T) { sh.done = true; landShell(sh); }
  S.shells = S.shells.filter(sh => !sh.done);

  const conductor = S.specials.conductor && h.cls === 'oracle';
  computeBuffs();
  for (const t of S.towers) {
    if (t.stunT > 0) { t.stunT -= dt; continue; }
    if (t.support) continue;
    if (t.zero) for (const e of inRange(t.x, t.y, tRange(t))) slowEnemy(e, t.zero, 0.2);
    let spd = overclocked(t) ? 1 + h.ab.power : conductor ? 1 + h.ab.power * 0.5 : 1;
    if (h.ab.haste && S.stasisT > 0 && Math.hypot(S.stasisAt.x - t.x, S.stasisAt.y - t.y) <= h.ab.r) spd *= 1 + h.ab.haste;
    if (t.buff) spd *= (1 + t.buff.rate) * (t.buff.tempo ? 2 : 1);
    if (t.pact && S.enemies.some(e => e.blocked && Math.hypot(e.x - t.x, e.y - t.y) <= tRange(t))) spd *= 2;
    t.cd -= dt * spd;
    if (t.cd > 0) continue;
    if (t.type === 'anvil') {
      const area = inRange(t.x, t.y, tRange(t));
      if (area.length) { t.cd = t.rate * S.mod.towerRate; anvilSlam(t, area, 1); }
      continue;
    }
    const targets = inRange(t.x, t.y, tRange(t)).sort((a, b) => b.d - a.d).slice(0, 1 + t.multi);
    if (t.lob) {
      if (targets.length) { t.cd = t.rate * S.mod.towerRate; for (const e of targets) { lobShell(t, e, 1); if (t.salvo) S.delayed.push({ at: S.time + 0.35, fn: () => { if (!e.dead) lobShell(t, e, t.salvo); } }); } }
      continue;
    }
    if (targets.length) {
      if (t.tempo) t.tempoStacks = Math.min(5, t.tempoStacks + 1);
      t.cd = t.rate * S.mod.towerRate * (1 - (t.tempo || 0) * (t.tempoStacks || 0)); fire(t, targets);
      shotEffects(t, t.dmg * S.mod.towerDmg);
    } else t.tempoStacks = 0;
  }
  if (!h.ko) for (const c of S.coins) if (!c.got && Math.hypot(c.x - h.x, c.y - h.y) <= 30) { c.got = true; S.gold += 25; S.fx.push({ k: 'ring', x: c.x, y: c.y, r: 20, color: 0xf2c14e, t: 0.4, T: 0.4, fill: true }); sfx('kill'); }
  S.coins = S.coins.filter(c => !c.got);
  for (const ec of S.echoes) if (S.time >= ec.at) {
    ec.done = true;
    if (!ec.target.dead) { applyHit(ec.t, ec.target, ec.d, false); S.fx.push({ k: 'ring', x: ec.target.x, y: ec.target.y, r: 8, color: ec.t.color, t: 0.15, T: 0.15 }); }
  }
  S.echoes = S.echoes.filter(ec => !ec.done);
  S.enemies = S.enemies.filter(e => !e.dead);
  for (const f of S.fx) f.t -= dt;
  S.fx = S.fx.filter(f => f.t > 0);
}

// ---------- hero upgrade offers ----------
function owns(id) { return S.picks.some(p => p.perk.id === id); }
function makeOffer(perk, rarity, demonic) {
  const o = { perk, rarity, demonic: false };
  if (perk.rarity || perk.fixed) return o; // uniques and ability upgrades have fixed effects and are never Demonic
  o.m = perk.m * rarity.mult * (demonic ? 2 : 1);
  if (demonic) { o.demonic = true; o.curse = pick(CURSES); o.k = rarity.mult * (S.specials.pact ? 0.5 : 1); }
  return o;
}
// Two slots from your hero's own pool, one shared slot (upgrades for every hero, or for heroes of your category).
// Upgrades you already own show up more often. Rare or better hero slots can roll an ability upgrade.
function rollPerks() {
  const h = S.hero, cat = HEROES[h.cls].cat, out = [];
  const weighted = list => { const bag = []; for (const p of list) { bag.push(p); if (owns(p.id)) bag.push(p, p); } return bag; };
  const shared = p => p.cls === 'any' || p.cls === cat || (p.also && p.also.includes(cat));
  const slots = shuffle(['hero', 'hero', Math.random() < 0.3 ? 'hero' : 'shared']);
  for (const slot of slots) {
    const rarity = rollRarity(), demonic = Math.random() < DEMONIC_CHANCE;
    const taken = new Set(out.map(o => o.perk.id));
    let perk = null, rar = rarity;
    if (rarity.id === 'secret') perk = pick(UNIQUES.filter(u => u.rarity === 'secret' && !owns(u.id) && !taken.has(u.id))) || null;
    if (!perk && (rarity.id === 'legendary' || rarity.id === 'secret') && Math.random() < 0.5) {
      perk = pick(UNIQUES.filter(u => u.rarity === 'legendary' && u.cls === h.cls && (!u.ab || u.ab === h.ab.id) && !owns(u.id) && !taken.has(u.id))) || null;
      if (perk) rar = RAR.legendary;
    }
    if (!perk && slot === 'hero' && rarity.mult >= RAR.rare.mult && Math.random() < 0.45)
      perk = pick(ABILITY_MODS.filter(m => m.cls === h.cls && m.ab === h.ab.id && !h.ab[m.id] && !taken.has(m.id))) || null;
    if (!perk) perk = pick(weighted(PERKS.filter(p => (slot === 'hero' ? p.cls === h.cls : shared(p)) && (!p.ab || p.ab === h.ab.id) && !taken.has(p.id))));
    out.push(makeOffer(perk, rar, demonic && !perk.fixed));
  }
  return out;
}
const perkDesc = o => typeof o.perk.desc === 'string' ? o.perk.desc : o.perk.desc(o.m);
const poolName = p => p.mod ? S.hero.ab.name + ' upgrade' : p.cls === 'any' ? 'Shared' : HEROES[p.cls] ? HEROES[p.cls].name : p.cls[0].toUpperCase() + p.cls.slice(1);
function offerHtml(o, i) {
  const p = o.perk, r = o.rarity;
  const desc = perkDesc(o);
  const label = (o.demonic ? 'Demonic ' : '') + r.name + ' · ' + poolName(p);
  return `<button class="choice rarity-${r.id} ${o.demonic ? 'is-demonic' : ''}" data-i="${i}"><small class="path rar-${r.id}">${label}</small>
    <b>${p.name}</b><span>${desc}</span><span class="delta">${previewRun(() => (p.rarity || p.fixed) ? p.apply(S.hero) : p.apply(S.hero, o.m), p.name)}</span>${o.demonic ? `<em class="cost">Curse: ${o.curse.desc(o.k)}</em>` : ''}
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
    if (o.perk.rarity || o.perk.fixed) o.perk.apply(h); else o.perk.apply(h, o.m);
    if (o.demonic) o.curse.apply(o.k);
    S.picks.push(o);
    if (o.perk.mod) { S.fx.push({ k: 'ring', x: h.x, y: h.y, r: 60, color: 0xff6fd8, t: 0.8, T: 0.8, fill: true }); toast(h.ab.name + ' upgraded: ' + o.perk.name + '!'); }
    else if (o.rarity.id !== 'common' || o.demonic) toast((o.demonic ? 'Demonic ' : '') + o.rarity.name + ' upgrade: ' + o.perk.name + '!');
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
  const fresh = shuffle(HEROICS.filter(x => !S.heroics[x.id] && x.for.includes(S.hero.cls))).slice(0, 3);
  const owned = HEROICS.filter(x => S.heroics[x.id] && S.heroics[x.id] < 3);
  if (!fresh.length && !owned.length) { S.pendingHeroic--; S.gold += 250; S.paused = false; toast('Every heroic power is maxed, so the boss dropped 250 gold instead.'); return; }
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
  META.shards += shards; META.cores = (META.cores || 0) + S.cores;
  const best = META.best[S.map];
  if (!best || cleared > best.wave) META.best[S.map] = { wave: cleared, won };
  const top = S.towers.slice().sort((a, b) => (b.dmgTotal || 0) - (a.dmgTotal || 0))[0];
  META.runs.push({ date: new Date().toISOString(), map: S.map, hero: S.hero.cls, wave: S.wave, won, shards, cores: S.cores,
    livesLost: S.startLives - S.lives, heroLvl: S.hero.lvl, top: top ? towerName(top) + ' L' + top.lvl : '',
    upgrades: S.picks.map(o => (o.demonic ? 'Demonic ' : '') + o.rarity.name + ' ' + o.perk.name), heroics: S.heroics, relics: S.relics.map(r => r.name),
    boons: Object.keys(S.boons).map(k => BOONS[k].name), waves: S.log });
  META.runs = META.runs.slice(-25); saveMeta();
  const rows = S.log.slice(-6).map(w => `<tr><td>${w.wave}</td><td>${w.mode}</td><td>${w.livesLost}</td><td>${w.heroDmg}</td><td>${w.towers[0] ? w.towers[0].name + ' (' + w.towers[0].dmg + ')' : '-'}</td></tr>`).join('');
  openModal(`<h2>${won ? 'The rift is sealed' : quit ? 'Run ended' : 'The base has fallen'}</h2>
    <p>${won ? 'You held all ' + MAX_WAVE + ' waves' : 'You reached wave ' + S.wave} on ${map.name} as a level ${S.hero.lvl} ${HEROES[S.hero.cls].name}.</p>
${!won && S.loseReason ? `<p class="lose-reason">${S.loseReason}</p>` : ''}
    <p class="shards">+◆ ${shards} Rift Shards (${META.shards} total)${S.cores ? ` · <span class="cores">+⬢ ${S.cores} Boss Cores (${META.cores} total)</span>` : ''}</p>
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
  const d = TOWERS[type], pw = rank(META.towers[type], 'power');
  return { type, c, r, x: c * C + C / 2, y: r * C + C / 2, lvl: 1, dmg: d.dmg * (1 + 0.04 * pw), rate: d.rate, range: d.range, support: !!d.support,
    hex: 0, hexNova: 0, bDmg: d.support ? 0.15 + 0.02 * pw : 0, bRate: 0, bRange: 0, bSunder: 0, bGold: 0, bOverdrive: false, bTempo: false, bLight: false, bBreak: false, bRush: false,
    press: 0.25, pressCap: 1.5, pin: 0, shackle: false, after: false, tide: false, guard: 0, pact: false, crushExec: 0, stunT: 0, stunMax: 0, warnT: 0, buff: null,
    splash: d.splash || 0, slow: d.slow || 0, slowDur: 1.6, chain: d.chain || 0, chainMul: 0.7, chainReach: 95,
    multi: 0, ramp: d.beam ? 0.08 : 0, surge: 0, burn: 0, brittle: 0, mark: 0, cluster: 0, orbital: 0, freeze: 0, zero: 0, stun: 0,
    prism: 0, execute: 0, nova: 0, echo: 0, deathBlast: 0, gravity: 0, timeLock: 0, shatter: 0, frostfire: 0, storm: 0, chainBlast: 0, overload: 0, pierce: 0, loot: 0, leech: 0, tempo: 0, tempoStacks: 0, hypo: 0, coldSnap: false,
    beam: !!d.beam, rampMax: d.beam ? 20 : 5, retain: false, melt: false, chainKeep: false, lob: !!d.lob, firestorm: false, salvo: 0, quakeStun: false,
    color: d.color, cd: 0, shots: 0, stacks: 0, spent: 0, baseCost: d.cost, ups: {}, rk: {}, order: [], freeUps: 0 };
}
function placeTower(c, r, type) {
  const cost = towerCost(type), t = newTower(type, c, r), h = S.hero;
  S.gold -= cost; t.spent = cost; S.towers.push(t);
  t.freeUps = (S.specials.foundry ? 2 : 0) + (h.rapid && Math.hypot(h.x - t.x, h.y - t.y) <= h.auraRange ? h.rapid : 0) + rank(META.towers[type], 'vet');
  if (t.freeUps) S.fx.push({ k: 'ring', x: t.x, y: t.y, r: 30, color: 0xb07cff, t: 0.5, T: 0.5, fill: true });
  if (S.build && S.gold < towerCost(S.build)) S.build = null;
  renderBuildBar(); renderInspector();
}
// Path options: base towers use their own 5 paths; merged towers use the fusion paths picked at merge time.
function towerOptions(t) { return t.hybrid ? t.fusions.map(f => fusionPath(f, t.super ? 1.5 : 1)) : TOWER_PATHS[t.type]; }
function fusionPath(f, m) {
  return { id: f.id, name: (m > 1 ? 'Ascended ' : '') + f.name, desc: f.desc(1, m) + ' Grows with each point, plus +8% damage per point.',
    rank: t => { f.apply(t, m); t.dmg *= 1.08; }, mastery: null, fusion: f, m };
}
function pathState(t, path) {
  const n = t.ups[path.id] || 0, used = t.order.length;
  if (n >= pathMax()) return 'maxed';
  if (!n && used >= pathLimit()) return 'locked';
  return 'open';
}
// Ascended forms: every combination of paths a tower can end on has its own name. Keyed by the path
// positions used (0-4, in path order), so 3, 4 or all 5 paths each name a different form.
const FORM_NAMES = {
  arcane: { '012': 'Doomglyph Obelisk', '013': 'Hexstorm Spire', '014': 'Curseweaver', '023': 'Starpiercer', '024': 'Spellblade Sentinel', '034': 'Arcane Cataclysm', '123': 'Voidbrand Monolith', '124': 'Witchfire Lens', '134': 'Plaguestar', '234': 'Mana Gatling', '1234': 'Eldritch Engine', '0234': 'Archmage’s Lance', '0134': 'Runic Maelstrom', '0124': 'Grimoire of Ruin', '0123': 'Sigil of the Void', '01234': 'Arcanum Absolute' },
  plasma: { '012': 'Inferno Mortar', '013': 'Carpet Bomber', '014': 'Meteor Hammer', '023': 'Napalm Spitter', '024': 'Magma Quake', '034': 'Shockwave Battery', '123': 'Hellfire Cannon', '124': 'Sunfall Artillery', '134': 'Thunder Howitzer', '234': 'Cinder Gatling', '1234': 'Solar Forge', '0234': 'Firestorm Engine', '0134': 'Siege Colossus', '0124': 'Volcano Heart', '0123': 'Armageddon Mortar', '01234': 'Starfall Citadel' },
  frost: { '012': 'Glacier Heart', '013': 'Blizzard Spire', '014': 'Shatterfrost Spire', '023': 'Eternal Winter', '024': 'Frostbite Obelisk', '034': 'Permafrost Tomb', '123': 'Avalanche Totem', '124': 'Crystal Storm', '134': 'Hoarfrost Bloom', '234': 'Stasis Crypt', '1234': 'Polar Vortex', '0234': 'Glacial Throne', '0134': 'Winter’s Maw', '0124': 'Diamond Dust Spire', '0123': 'Ice Age Monolith', '01234': 'Absolute Winter' },
  tesla: { '012': 'Thunderhead', '013': 'Storm Dynamo', '014': 'Skyfork Tower', '023': 'Ion Cascade', '024': 'Leyline Relay', '034': 'Static Tempest', '123': 'Arc Reactor', '124': 'Bolt Throne', '134': 'Overvolt Pylon', '234': 'Hyperion Coil', '1234': 'Tesla Colossus', '0234': 'Stormweb Array', '0134': 'Fulgurite Spire', '0124': 'Sky Breaker', '0123': 'Lightning Cathedral', '01234': 'Heart of the Storm' },
  beacon: { '012': 'Warsong Spire', '013': 'Battle Standard', '014': 'Golden Fanfare', '023': 'Dawnspear Lantern', '024': 'Merchant’s Lighthouse', '034': 'Conqueror’s Shrine', '123': 'Tempo Lighthouse', '124': 'Bazaar Bell', '134': 'Siegebreaker Totem', '234': 'Plunderer’s Lantern', '1234': 'Guildhall Beacon', '0234': 'Crusader’s Pharos', '0134': 'Warlord’s Banner', '0124': 'Golden Dawn', '0123': 'Herald of War', '01234': 'Eternal Lighthouse' },
  anvil: { '012': 'Tomb Hammer', '013': 'Executioner’s Press', '014': 'Oathkeeper', '023': 'Earthsplitter', '024': 'Bulwark Maul', '034': 'Grinding Bastion', '123': 'Gravelock', '124': 'Warden’s Shackle', '134': 'Iron Vise', '234': 'Seismic Bastion', '1234': 'Mountain’s Grip', '0234': 'Doomhammer Forge', '0134': 'Titan’s Judgment', '0124': 'Worldbreaker', '0123': 'Grave of Kings', '01234': 'The Final Anvil' },
  laser: { '012': 'Prism Lattice', '013': 'Arc Lancer', '014': 'Spectrum Web', '023': 'Refraction Core', '024': 'Rainbow Reach', '034': 'Photon Spear', '123': 'Meltdown Eye', '124': 'Searing Gaze', '134': 'Sunbeam Lance', '234': 'Deathray', '1234': 'Solar Cannon', '0234': 'Crystal Nexus', '0134': 'Hyperbeam Array', '0124': 'Kaleidoscope', '0123': 'Fusion Prism', '01234': 'Eye of the Sun' },
  mortar: { '012': 'Doomshell Battery', '013': 'Bastion Buster', '014': 'Crater Maker', '023': 'Firebomb Nest', '024': 'Scorched Earth', '034': 'Rolling Barrage', '123': 'Inferno Rain', '124': 'Quake Mortar', '134': 'Hailstorm Launcher', '234': 'Hellrain Battery', '1234': 'Ash Sky', '0234': 'Brimstone Bastion', '0134': 'Thunder Siege', '0124': 'Cataclysm Cannon', '0123': 'Ragnarok Battery', '01234': 'End of Days' },
};
const formKey = t => t.order.map(id => TOWER_PATHS[t.type].findIndex(p => p.id === id)).sort().join('');
// Form name at level 13. Falls back to adjective + noun + "of <title>" for any combination without a name.
function formName(t) {
  const named = FORM_NAMES[t.type] && FORM_NAMES[t.type][formKey(t)];
  if (named) return named;
  const paths = t.order.map(id => TOWER_PATHS[t.type].find(p => p.id === id)).sort((a, b) => (t.ups[b.id] - t.ups[a.id]) || (t.order.indexOf(a.id) - t.order.indexOf(b.id)));
  const [a, b, c, d] = paths;
  return `${a.adj} ${b ? b.noun : TOWERS[t.type].name}${c ? ' of ' + c.title : ''}${d ? ' and ' + d.title : ''}`;
}
// The stat changes of one level-up (shared by the real level-up and the "current → new" preview).
function discoverForm(t) {
  META.forms = META.forms || {};
  const id = t.type + ':' + formKey(t);
  if (!META.forms[id]) { META.forms[id] = true; saveMeta(); S.fx.push({ k: 'ring', x: t.x, y: t.y, r: 70, color: 0xfff0a0, t: 0.9, T: 0.9, fill: true }); }
}
const formsFound = type => Object.keys(FORM_NAMES[type]).filter(k => META.forms && META.forms[type + ':' + k]);
function applyLevel(t, path) {
  t.lvl++; levelBonus(t).apply(t);
  if (!t.ups[path.id]) t.order.push(path.id);
  const pts = t.ups[path.id] = (t.ups[path.id] || 0) + 1, max = pathMax();
  // Oracle points are bigger: they apply ranks in steps of 2/1/1, so 3 points reach the same rank 4.
  const target = max === 3 ? ORACLE_RANKS[pts] : pts;
  t.rk = t.rk || {};
  for (let r = (t.rk[path.id] || 0) + 1; r <= target; r++) path.rank(t, r);
  t.rk[path.id] = target;
  const mastered = pts === max && path.mastery;
  if (mastered) path.mastery.apply(t);
  if (t.lvl === MAX_LVL) levelBonus(t).ascend(t);
  return { pts, max, mastered };
}
function levelTower(t, path) {
  const lc = levelCost(t);
  if (S.gold < lc || t.lvl >= MAX_LVL || pathState(t, path) !== 'open') return;
  if (t.freeUps > 0) t.freeUps--; else if (S.freeLevels > 0) S.freeLevels--;
  S.gold -= lc; t.spent += lc;
  const { pts, max, mastered } = applyLevel(t, path);
  const oldName = towerName(t);
  // Once a tower has 3 paths it takes the name of that combination (and renames if a 4th or 5th is added).
  if (!t.hybrid && t.order.length >= 3) { t.name = formName(t); discoverForm(t); }
  let msg = towerName(t) + ' reached level ' + t.lvl + ': ' + path.name + ' ' + pts + '/' + max;
  if (towerName(t) !== oldName) { msg = oldName + ' became the ' + towerName(t) + '!'; S.fx.push({ k: 'ring', x: t.x, y: t.y, r: 50, color: t.color, t: 0.7, T: 0.7, fill: true }); sfx('level'); }
  if (mastered) msg += ', mastered: ' + path.mastery.name;
  if (t.lvl === MAX_LVL) {
    if (!t.hybrid) { t.name = formName(t); discoverForm(t); } else t.perfected = true;
    msg = towerName(t) + (t.hybrid ? ' is perfected' : ' ascended') + ' at level ' + MAX_LVL + '!';
    sfx('level');
  }
  toast(/[!.]$/.test(msg) ? msg : msg + '.');
  renderInspector(); renderBuildBar();
}

function cancelPlacing() {
  if (!S.build && !S.mergeFrom && !S.pendingBuild) return false;
  S.build = null; S.mergeFrom = null; S.pendingBuild = null;
  toast('Cancelled.'); renderBuildBar(); renderInspector();
  return true;
}
// Hold position (H): the Vanguard and Sniper can lock themselves in place so a stray click never moves them.
const canHold = h => h.cls === 'vanguard' || h.cls === 'sniper';
function holdNote() { toast('Holding position. Press H to move again.'); }
function toggleHold() {
  const h = S && S.hero; if (!h || S.over || !canHold(h)) return;
  h.hold = !h.hold; h.tx = null; S.pendingBuild = null; held.clear();
  toast(h.hold ? 'Holding position: your hero won’t move until you press H again.' : 'Your hero can move again.');
  renderBuildBar(); renderHero();
}
// Aim point (F): Piercing Shot always fires toward it. Press F near it again (or on the button) to clear it.
function toggleAim() {
  const h = S && S.hero; if (!h || S.over || h.cls !== 'sniper') return;
  const p = S.pointer;
  if (S.aim && (!p || Math.hypot(p.x - S.aim.x, p.y - S.aim.y) < 30)) { S.aim = null; toast('Aim point cleared: Piercing Shot aims at the lead enemy.'); }
  else if (p) { S.aim = { x: p.x, y: p.y }; toast('Aim point set: Piercing Shot fires toward it. Press F on it to clear.'); }
  else return toast('Point at the board, then press F to set an aim point.');
  renderBuildBar();
}
function moveHero(x, y) {
  if (S.hero.ko) return;
  if (S.hero.hold) return holdNote();
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
    if (h.hold) return toast('Out of build range, and your hero is holding position (H).');
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
  if (!a.hybrid && (!MERGEABLE[a.type] || !MERGEABLE[b.type])) return 'Rift Beacons and Grave Anvils can’t merge.';
  if (!a.hybrid && a.type === b.type) return 'Merge two different tower types.';
  return '';
}
// The tags a tower brings into a merge: its element plus the paths it actually chose.
function towerTags(t) {
  if (t.hybrid) return t.tags.concat(t.order.flatMap(id => (FUSIONS.find(f => f.id === id) || { tags: [] }).tags));
  return [ELEMENT_TAG[t.type]].concat(t.order.flatMap(id => Array(t.ups[id]).fill(TOWER_PATHS[t.type].find(p => p.id === id).tag)));
}
function tryMerge(a, b) {
  S.mergeFrom = null;
  const why = mergeProblem(a, b), cost = mergeCost();
  if (why) { toast(why); return renderInspector(); }
  if (S.gold < cost) { toast('Merging costs ' + cost + ' gold.'); return renderInspector(); }
  S.gold -= cost; if (S.freeMerges > 0) S.freeMerges--;
  const tags = towerTags(a).concat(towerTags(b));
  const base = { lvl: 1, spent: a.spent + b.spent + cost, cd: 0, shots: 0, stacks: 0, ups: {}, rk: {}, order: [], freeUps: 0, baseCost: a.baseCost + b.baseCost,
    range: Math.max(a.range, b.range) * 1.1, tags, perfected: false, tempoStacks: 0 };
  let merged, label, color, key = '';
  if (a.hybrid) {
    const parents = [...new Set(a.parents.concat(b.parents))].sort(), info = SUPERS[parents.join('+')];
    const recipe = RECIPES[a.type];
    label = info ? info.name : 'Prime ' + recipe.name; color = info ? info.color : recipe.color;
    merged = Object.assign(base, { type: a.type, hybrid: true, super: true, parents, name: label, color,
      desc: (info ? info.desc : 'Two ' + recipe.name + 's fused into one. ' + recipe.desc) + ' Its paths are ascended versions of fusion effects its hybrids never used.',
      fusions: pickFusions(tags, parents.join('+') + a.order.join() + b.order.join(), a.order.concat(b.order)),
      dmg: Math.max(a.dmg, b.dmg) * 1.6, rate: Math.min(a.rate, b.rate) * 0.9 });
  } else {
    key = [a.type, b.type].sort().join('+');
    const rec = RECIPES[key], [fa, fb] = [a, b].map(t => t.name ? t.name.split(' ')[0] : '');
    label = (fa ? fa + ' ' : '') + rec.name; color = rec.color;
    merged = Object.assign(base, { type: key, hybrid: true, parents: [a.type, b.type], color, name: label,
      desc: rec.desc + ` Fused from ${towerName(a)} and ${towerName(b)}, so its paths come from what they used.`,
      fusions: pickFusions(tags, key + a.order.join() + b.order.join(), []),
      dmg: Math.max(a.dmg, b.dmg) * 1.5, rate: Math.min(a.rate, b.rate) });
  }
  merged.upStart = hybridUpStart(merged.parents, merged.super);
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
  sfx('level');
  S.sel = b; renderInspector(); renderCodex(); renderBuildBar();
}

// ---------- UI ----------
function renderBuildBar() {
  if (!S.hero) return;
  const bar = $('buildBar');
  const modeTag = S.mode.kind !== 'normal' ? ' · ' + S.mode.name : '';
  bar.innerHTML = S.loadout.map((k, i) => { const d = TOWERS[k];
    return `<button class="tbtn ${S.build === k ? 'on' : ''}" data-k="${k}" ${S.gold < towerCost(k) ? 'disabled' : ''}>
      <span class="sw" style="background:${d.css}"></span>${d.name}<span class="c">${towerCost(k)}</span><kbd>${i + 1}</kbd></button>`; }).join('') +
    `<button id="abilityBtn" class="ability" data-tip="ability">${S.hero.ab.name} <kbd>Q</kbd></button>` +
    (canHold(S.hero) ? `<button id="holdBtn" class="${S.hero.hold ? 'on' : ''}" data-tip="hold">${S.hero.hold ? 'Holding' : 'Hold'} <kbd>H</kbd></button>` : '') +
    (S.hero.cls === 'sniper' ? `<button id="aimBtn" class="${S.aim ? 'on' : ''}" data-tip="aim">${S.aim ? 'Aim set' : 'Aim'} <kbd>F</kbd></button>` : '') +
    `<span class="spacer"></span>
     <button id="speedBtn">${S.speed}×</button>
     <button class="go" id="waveBtn" ${S.waveActive || S.over ? 'disabled' : ''}>${S.waveActive ? 'Wave ' + S.wave + modeTag : 'Start wave ' + (S.wave + 1) + modeTag + ' <kbd>Space</kbd>'}</button>`;
  bar.querySelectorAll('.tbtn').forEach(b => {
    b.onclick = () => selectBuild(b.dataset.k);
    b.onmouseenter = () => showTip(buildTipHtml(b.dataset.k), b.getBoundingClientRect(), 'above');
    b.onmouseleave = hideTip;
  });
  $('abilityBtn').onclick = useAbility;
  if ($('holdBtn')) $('holdBtn').onclick = toggleHold;
  if ($('aimBtn')) $('aimBtn').onclick = () => { if (S.aim) { S.aim = null; toast('Aim point cleared.'); renderBuildBar(); } else toast('Point at the board and press F to set an aim point.'); };
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
    <div class="tip-s">${d.support ? 'Buff +' + pct(beaconDmg(t)) : 'Damage ' + t.dmg.toFixed(0) + ' · ' + (1 / d.rate).toFixed(2) + ' shots/s'} · Range ${d.range}</div>
    <ul>${(d.support || k === 'anvil' ? towerTraits(t) : traits(t).slice(1)).map(x => `<li>${x}</li>`).join('')}</ul>
    ${S.sig[k] ? `<div class="tip-s rar-mythic">Signature: ${SIGNATURES[k].name}. ${SIGNATURES[k].desc}</div>` : ''}
    <div class="tip-s">Paths: ${TOWER_PATHS[k].map(u => u.name).join(', ')}. Pick up to 3 of them (4 with the Oracle) as it levels to ${MAX_LVL}.</div>`;
}
function towerTipHtml(t) {
  const opts = towerOptions(t), ups = t.order.map(id => { const u = opts.find(x => x.id === id); return u ? u.name + ' ' + t.ups[id] + '/' + PATH_MAX : ''; }).filter(Boolean);
  return `<b>${towerName(t)}</b> <span class="tip-c">Lv ${t.lvl}/${MAX_LVL}${t.super ? ' · Super' : t.hybrid ? ' · Hybrid' : ''}</span>${t === S.drained ? '<p style="color:var(--danger)">Drained: half damage this wave.</p>' : ''}<p>${towerBlurb(t)}</p>
    <div class="tip-s">Damage dealt: ${Math.round(t.dmgTotal || 0)} total, ${Math.round(t.dmgWave || 0)} this wave</div>
    <div class="tip-s">${t.support ? 'Buff +' + pct(beaconDmg(t)) : 'Damage ' + dmgWithBuff(t) + ' · ' + (1 / (t.rate * S.mod.towerRate)).toFixed(2) + ' shots/s'} · Range ${tRange(t).toFixed(0)}</div>
    <ul>${towerTraits(t).map(x => `<li>${x}</li>`).join('')}</ul>${ups.length ? `<div class="tip-s">Paths: ${ups.join(', ')}</div>` : ''}`;
}

// "82 → 94 (Beacon)" when a Beacon buffs this tower.
function dmgWithBuff(t) { const d = t.dmg * S.mod.towerDmg; return t.buff ? `${d.toFixed(0)} → ${(d * (1 + t.buff.dmg)).toFixed(0)} <small>(Beacon)</small>` : d.toFixed(0); }
function renderInspector() {
  if (!S.hero) return;
  const el = $('inspector'), t = S.sel;
  if (!t || !S.towers.includes(t)) {
    S.sel = null;
    if (S.build) {
      el.innerHTML = `<h3>Placing</h3>${buildTipHtml(S.build)}<p class="help">Left-click a tile to build. Right-click or press R to cancel.</p>`;
      return;
    }
    el.innerHTML = `<h3>Tower</h3><p>Hover a tower to see what it does. Pick one, then left-click a free tile. If it's out of reach, your hero walks over and builds it.</p><p>Towers level up to ${MAX_LVL}. Each level adds a point to one of 5 paths. A tower uses 3 paths of 4 points (with the Oracle, 4 paths of 3 bigger points). A path's last point unlocks its mastery, and at level ${MAX_LVL} the tower ascends into a form named after its paths. Two different level ${MERGE_LVL} towers merge into a hybrid (merging costs ${MERGE_COST} gold), and two level ${MERGE_LVL} hybrids merge into a super tower.</p>`;
    return;
  }
  const lc = levelCost(t), sell = Math.round(t.spent * SELL_RATE);
  const gc = v => `<span style="color:var(--gold)">${v}</span>`;
  const opts = towerOptions(t), canMerge = t.lvl >= MERGE_LVL && !t.super, lim = pathLimit();
  const btn = (u, i) => {
    const n = t.ups[u.id] || 0, state = pathState(t, u);
    const note = state === 'maxed' ? 'Maxed.' : state === 'locked' ? `Locked: this tower already uses ${lim} paths.` : u.desc;
    const mastery = u.mastery ? `<em class="mastery">${n >= pathMax() ? '★ Mastered: ' : 'Mastery at ' + pathMax() + ': '}${u.mastery.name}. ${u.mastery.desc}</em>` : '';
    return `<button class="up ${state}" data-u="${i}" ${S.gold < lc || state !== 'open' || t.lvl >= MAX_LVL ? 'disabled' : ''}>
      <b>${u.name} <small>${n}/${pathMax()}</small></b><span>${note}</span>${state === 'open' && t.lvl < MAX_LVL ? `<span class="delta">${previewLevel(t, u)}</span>` : ''}${mastery}
      ${state === 'open' && t.lvl < MAX_LVL ? `<i class="price">${lc ? lc + ' gold' : 'Free'}</i>` : ''}</button>`;
  };
  // Once a tower has picked all its paths, the unused ones are hidden.
  const shown = (u, i) => pathState(t, u) === 'locked' ? '' : btn(u, i);
  el.innerHTML = `<h3>${towerName(t)} · ${towerKind(t)}Lv ${t.lvl}/${MAX_LVL}</h3>
    <p>${towerBlurb(t)}${t.hybrid ? ' Contains ' + t.parents.map(p => TOWERS[p].name).join(' + ') + '.' : ''}</p>
    ${t.stunT > 0 ? `<p style="color:var(--danger)">Stunned by a boss: ${t.stunT.toFixed(1)}s left.</p>` : ''}
    <div class="stats">
      ${t.support ? `<div><span>Buff</span>+${pct(beaconDmg(t))}</div>` : `<div><span>Damage</span>${dmgWithBuff(t)}</div><div><span>${t.type === 'anvil' ? 'Slams/s' : 'Shots/s'}</span>${(1 / (t.rate * S.mod.towerRate)).toFixed(2)}</div>`}
      <div><span>Range</span>${tRange(t).toFixed(0)}</div><div><span>Spent</span>${t.spent}</div>
    </div>
    <ul class="traits">${towerTraits(t).map(x => `<li>${x}</li>`).join('')}</ul>
    ${S.mergeFrom === t ? `<p>Tap another level ${MERGE_LVL} ${t.hybrid ? 'hybrid' : 'tower of a different type'} to merge with. Tap anywhere else to cancel.</p>` : ''}
    ${t.lvl < MAX_LVL ? `<p class="help" style="margin-top:8px">Paths used: ${t.order.length}/${lim}${!t.hybrid && t.order.length === 2 && t.lvl < MAX_LVL ? ' · A 3rd path gives it a new name' : ''}${t.freeUps ? ` · ${t.freeUps} free level-up${t.freeUps > 1 ? 's' : ''}` : ''}. Each level adds ${levelBonus(t).text}; level ${MAX_LVL} ${t.hybrid ? 'perfects it' : 'ascends it into its final form'} (${levelBonus(t).asc}).</p>` : `<p class="help">Max level.${canMerge ? ` Merge it with another level ${MERGE_LVL} ${t.hybrid ? 'hybrid to make a super tower' : 'tower of a different type to make a hybrid'}.` : ''}</p>`}
    <div class="ups">${opts.map(shown).join('')}</div>
    <div class="row">
      ${canMerge ? `<button id="mergeBtn" ${S.gold < mergeCost() ? 'disabled' : ''}>${t.hybrid ? 'Super merge' : 'Merge'} · ${gc(mergeCost() || 'Free')}</button>` : ''}
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
// Enemies tab: each enemy you have met, what it does and how to beat it.
function renderEnemyCodex() {
  $('enemyCodex').innerHTML = Object.entries(ENEMIES).map(([k, d]) => META.seen[k]
    ? `<li class="found"><div><b style="color:#${d.color.toString(16).padStart(6, '0')}">${d.name}</b><span>${ENEMY_INFO[k][0]}</span><em>Counter: ${ENEMY_INFO[k][1]}</em></div></li>`
    : `<li><b>???</b><span>Not met yet</span></li>`).join('');
}
function renderHero() {
  const h = S.hero; if (!h) return;
  const f = v => v.toFixed(0), d = HEROES[h.cls];
  const picks = S.picks.map(o => `<span class="tag rar-${o.rarity.id} ${o.demonic ? 'is-demonic' : ''}" title="${perkDesc(o)}${o.demonic ? ' Curse: ' + o.curse.desc(o.k) : ''}">${o.demonic ? '☠ ' : ''}${o.perk.name}</span>`).join('');
  const heroics = HEROICS.filter(x => S.heroics[x.id]).map(x => `<span class="tag rar-heroic" title="${x.desc(S.heroics[x.id])}">${x.name} ${'I'.repeat(S.heroics[x.id])}</span>`).join('');
  const relics = S.relics.map(r => `<span class="tag relic ${r.rarity ? 'rar-' + r.rarity : ''}" title="${r.desc}">${r.name}</span>`).join('');
  $('heroCard').innerHTML = `<h3 style="color:${d.css}">${d.name} · ${d.role} · Lv ${h.lvl}${h.ko ? ' · Knocked out' : ''}</h3>
    <p class="help"><b class="tipname" data-tip="ability" style="color:var(--text)">${h.ab.name}</b> (${h.ab.cd.toFixed(0)}s): ${abilityText(h)}${ABILITY_MODS.some(m => h.ab[m.id]) ? `<br><b class="rar-mythic">Upgrades:</b> ${ABILITY_MODS.filter(m => h.ab[m.id]).map(m => `<span class="tipname" data-tip="mod:${m.id}">${m.name}</span>`).join(', ')}` : ''}${h.hold ? '<br><b style="color:var(--gold)">Holding position (H)</b>' : ''}</p>
    <div class="stats">
      <div><span>HP</span>${f(h.hp)}/${f(h.maxHp)}</div><div><span>Damage</span>${f(heroDmg())}</div>
      <div><span>Attacks/s</span>${(1 / h.rate).toFixed(2)}</div><div><span>Range</span>${h.range >= 9999 ? 'Whole map' : f(h.range)}</div>
      <div><span>Targets</span>${1 + h.multi}</div><div><span>Crit chance</span>${pct(h.crit)}</div>
      <div><span>Crit damage</span>${pct(h.critDmg)}</div>${h.brace ? `<div><span>Brace</span>${h.brace.toFixed(2)}s</div>` : ''}
      <div><span>Armor</span>${pct(h.armor)}</div><div><span>Blocks</span>${blockText(h.block)}</div>
      <div><span>Regen/s</span>${h.regen.toFixed(1)}</div><div><span>Respawn</span>${h.respawn.toFixed(1)}s</div>
      <div><span>Build range</span>${f(h.buildRange)}</div><div><span>Move speed</span>${f(h.speed)}</div>
      ${h.aura ? `<div><span>Tower aura</span>+${pct(h.aura)}</div>` : ''}
      ${h.bounty ? `<div><span>Hero kill gold</span>+${h.bounty}g</div>` : ''}${h.tithe ? `<div><span>Kill gold (all)</span>+${h.tithe}g</div>` : ''}
      ${h.momStacks ? `<div><span>Momentum</span>${h.momStacks}×</div>` : ''}
      ${h.interest ? `<div><span>Interest</span>${pct(h.interest)}</div>` : ''}
    </div>
    <p class="help"><b style="color:var(--gold)">Level bonus</b> (${h.lvl - 1} level${h.lvl === 2 ? '' : 's'} so far): ${ROLE_LEVEL[d.cat] ? ROLE_LEVEL[d.cat].text + ' per level' : 'none'}.${h.xpGain ? ` XP gain +${pct(h.xpGain)}.` : ''}</p>
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
  const h = S && S.hero; if (!h) { $('bossBar').hidden = true; return; }
  const boss = S.enemies.filter(e => !e.dead && e.boss).sort((a, b) => b.max - a.max)[0];
  $('bossBar').hidden = !boss;
  if (boss) {
    $('bossName').textContent = ENEMIES[boss.type].name + (BIG_BOSS[boss.type] ? ' · if it reaches your base, the run is lost' : ' · costs 5 base HP if it gets through');
    $('bossFill').style.width = (Math.max(0, boss.hp) / boss.max * 100) + '%';
    $('bossBar').classList.toggle('danger', !!BIG_BOSS[boss.type] && boss.d / PATH_LEN >= 0.75);
  }
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

// The board is pixel art in the same 3/4 top-down view, palette and light (from the upper left) as the
// tower art. The game renders at PX canvas pixels per world unit, so one 40-unit tile is 32 art pixels,
// the size the art was drawn for. The ground is raised metal plating; the path is a sunken lane, so the
// plating's south face shows as a wall along the lane's north side. Redrawn only when the map changes.
const PX = 0.8, TILE = C * PX;
const PAL = { ink: '#101223', deep: '#24243D', dusk: '#3B3561', violet: '#625080', mist: '#9B8BA5' };
let groundFor = null;
function drawGround(sc) {
  groundFor = pathCells;
  if (!sc.textures.exists('ground')) sc.ground = sc.add.image(0, 0, sc.textures.createCanvas('ground', COLS * TILE, ROWS * TILE)).setOrigin(0).setScale(1 / PX).setDepth(-1);
  const tex = sc.textures.get('ground'), x2 = tex.getContext(), lane = (c, r) => pathCells.has(c + ',' + r);
  const px = (x, y, w, h, col) => { x2.fillStyle = col; x2.fillRect(x, y, w, h); };
  const hash = (c, r, i) => { let v = (c * 73856093) ^ (r * 19349663) ^ (i * 83492791); v = (v ^ (v >>> 13)) * 1274126177; return ((v ^ (v >>> 16)) >>> 0) / 4294967296; };
  for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
    const x = c * TILE, y = r * TILE, T = TILE;
    if (lane(c, r)) {
      px(x, y, T, T, PAL.ink);
      for (let i = 0; i < 5; i++) px(x + Math.floor(hash(c, r, i) * T), y + Math.floor(hash(c, r, i + 9) * T), 1, 1, PAL.deep);
      px(x, y + T / 2 - 1, T, 1, PAL.deep); // worn centre track
      if (r > 0 && !lane(c, r - 1)) { // the plating's south face
        px(x, y, T, 8, PAL.dusk); px(x, y, T, 1, PAL.violet);
        for (let i = 4; i < T; i += 8) px(x + i, y + 1, 1, 7, PAL.deep);
        px(x, y + 8, T, 2, PAL.deep);
      }
      if (c > 0 && !lane(c - 1, r)) px(x, y, 2, T, PAL.deep); // shadow cast by the plating to the left
    } else {
      px(x, y, T, T, PAL.deep);
      px(x, y, T - 1, 1, PAL.dusk); px(x, y, 1, T - 1, PAL.dusk); // lit top and left bevel
      px(x, y + T - 1, T, 1, PAL.ink); px(x + T - 1, y, 1, T, PAL.ink); // shaded seam
      if (hash(c, r, 1) < 0.5) for (const [dx, dy] of [[3, 3], [T - 5, 3], [3, T - 5], [T - 5, T - 5]]) { px(x + dx, y + dy, 2, 2, PAL.ink); px(x + dx, y + dy, 1, 1, PAL.violet); }
      else if (hash(c, r, 2) < 0.4) { px(x + 6, y + T / 2, T - 12, 1, PAL.ink); px(x + 6, y + T / 2 + 1, T - 12, 1, PAL.dusk); }
      for (let i = 0; i < 3; i++) px(x + 2 + Math.floor(hash(c, r, i + 20) * (T - 4)), y + 2 + Math.floor(hash(c, r, i + 30) * (T - 4)), 1, 1, PAL.dusk);
    }
  }
  if (WP[0].x < 0) px(0, Math.floor(WP[0].y / C) * TILE, 3, TILE, PAL.dusk);
  tex.refresh();
}
const shadow = (g, x, y, w) => g.fillStyle(0x101223, 0.6).fillEllipse(x, y, w, w * 0.35);

// Tower art: one sheet per tower, 4 rows of 6 frames (idle, attack, recover, hit effect). Frames are 48px
// at the art's own pixel size and drawn 1:1 on the pixel grid. oy is where the base sits in the frame; fy
// anchors the hit effect (bolts and lightning strike down onto the target). Merged towers keep their shapes.
const ART_URLS = import.meta.glob('./assets/*.png', { eager: true, import: 'default' });
const FRAME = 48;
const ART = {
  arcane: { oy: 38 / 48, fy: 0.75 }, plasma: { oy: 40 / 48 }, frost: { oy: 41 / 48 }, tesla: { oy: 38 / 48, fy: 0.75 },
  beacon: { oy: 37 / 48 }, anvil: { oy: 39 / 48 }, laser: { oy: 36 / 48 }, mortar: { oy: 40 / 48 },
};
const spriteTower = t => !t.hybrid && !!ART[t.type];
const towerSprites = new Map();
function loadArt(sc) { for (const k in ART) sc.load.spritesheet(k, ART_URLS[`./assets/${k}.png`], { frameWidth: FRAME, frameHeight: FRAME }); }
function makeAnims(sc) {
  for (const k in ART) {
    const a = (name, start, frameRate, repeat) => sc.anims.create({ key: k + '-' + name, frames: sc.anims.generateFrameNumbers(k, { start, end: start + 5 }), frameRate, repeat });
    a('idle', 0, 8, -1); a('attack', 6, 24, 0); a('recover', 12, 16, 0); a('fx', 18, 24, 0);
  }
}
function syncSprites(sc) {
  const live = new Set(), speed = !S || S.paused || S.over ? 0 : S.speed;
  if (S && S.hero) for (const t of S.towers) {
    if (!spriteTower(t)) continue;
    live.add(t);
    const k = t.type, art = ART[k];
    let s = towerSprites.get(t);
    if (!s) {
      s = sc.add.sprite(0, 0, k).setOrigin(0.5, art.oy).setScale(1 / PX);
      s.shot = t.shotAt; s.hit = t.firedAt; s.play(k + '-idle');
      s.on('animationcomplete', an => s.play(an.key === k + '-attack' ? k + '-recover' : k + '-idle'));
      towerSprites.set(t, s);
    }
    // the beacon has no shots: it pulses while a wave is on
    if (t.support && S.waveActive && S.time - (t.firedAt || -9) > 3) { t.shotAt = t.firedAt = S.time; t.hitAt = { x: t.x, y: t.y }; }
    s.setPosition(t.x, t.y + 15).setDepth(1 + t.y / 1000).setTint(t.stunT > 0 ? 0x666677 : 0xffffff);
    s.anims.timeScale = speed;
    if (t.shotAt !== s.shot) {
      s.shot = t.shotAt;
      if (!(s.anims.isPlaying && s.anims.currentAnim.key === k + '-attack')) s.play(k + '-attack');
    }
    if (t.firedAt !== s.hit) {
      s.hit = t.firedAt;
      if (t.hitAt && !(S.time - (s.burstAt || -9) < 0.3)) { s.burstAt = S.time; burst(sc, k, t.hitAt.x, t.hitAt.y, speed); }
    }
  }
  for (const [t, s] of towerSprites) if (!live.has(t)) { s.destroy(); towerSprites.delete(t); }
}
let bursts = 0;
function burst(sc, k, x, y, speed) {
  if (bursts >= 40 || !speed) return;
  bursts++;
  const art = ART[k], f = sc.add.sprite(x, y, k).setOrigin(0.5, art.fy || 0.5).setScale(1 / PX).setDepth(3);
  f.anims.timeScale = speed; f.play(k + '-fx');
  f.once('animationcomplete', () => { f.destroy(); bursts--; });
}

// g draws under the tower art, o over it.
function draw(g, o) {
  g.clear(); o.clear();
  g.fillStyle(0x4fd8e8, 0.15).fillCircle(BASE.x, BASE.y, 26);
  g.lineStyle(2, 0x4fd8e8, 1).strokeCircle(BASE.x, BASE.y, 18);
  g.fillStyle(0x4fd8e8, 1).fillCircle(BASE.x, BASE.y, 7);
  const h = S && S.hero; if (!h) return;
  const hc = HEROES[h.cls].color;

  if (S.stasisT > 0) { g.fillStyle(0x7fd4ff, 0.08).fillCircle(S.stasisAt.x, S.stasisAt.y, h.ab.r); g.lineStyle(2, 0x7fd4ff, 0.6).strokeCircle(S.stasisAt.x, S.stasisAt.y, h.ab.r); }
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

  for (const t of S.towers) if (t.buff) for (const b of t.buff.from) g.lineStyle(1, TOWERS.beacon.color, 0.18 + 0.1 * Math.sin(S.time * 4)).lineBetween(b.x, b.y, t.x, t.y);
  for (const t of S.towers) {
    if (t.warnT > 0) g.fillStyle(0xff2e4d, 0.25 + 0.25 * Math.sin(S.time * 30)).fillRoundedRect(t.x - 20, t.y - 20, 40, 40, 6);
    const art = spriteTower(t);
    shadow(g, t.x, t.y + 15, 42);
    if (art) g.lineStyle(2, t.color, t === S.sel ? 1 : 0.35).strokeEllipse(t.x, t.y + 12, 46, 20);
    else {
      // plinth: top face plus a darker front face, matching the 3/4 view
      g.fillStyle(0x0a0d18, 1).fillRoundedRect(t.x - 16, t.y - 12, 32, 28, 5);
      g.fillStyle(0x141a2e, 1).fillRoundedRect(t.x - 16, t.y - 16, 32, 26, 5);
      g.lineStyle(2, t.color, t === S.sel ? 1 : 0.6).strokeRoundedRect(t.x - 16, t.y - 16, 32, 32, 5);
    }
    if (t === S.drained) { g.lineStyle(2, 0xff5d6c, 0.9).lineBetween(t.x - 14, t.y - 14, t.x + 14, t.y + 14); }
    if (overclocked(t)) g.lineStyle(1, 0xb07cff, 0.9).strokeRoundedRect(t.x - 19, t.y - 19, 38, 38, 6);
    if (t.super) {
      g.fillStyle(t.color, 1).fillCircle(t.x, t.y - 3, 8);
      g.lineStyle(2, t.color, 0.8).strokeCircle(t.x, t.y - 3, 11);
      g.lineStyle(1, 0xf2c14e, 0.9).strokeCircle(t.x, t.y - 3, 14);
    } else if (t.hybrid) {
      g.fillStyle(t.color, 1).fillCircle(t.x, t.y - 3, 7);
      g.lineStyle(2, t.color, 0.7).strokeCircle(t.x, t.y - 3, 11);
    } else if (!art) {
      g.fillStyle(t.color, 1);
      if (t.type === 'arcane') g.fillTriangle(t.x, t.y - 12, t.x - 8, t.y + 4, t.x + 8, t.y + 4);
      else if (t.type === 'plasma') g.fillCircle(t.x, t.y - 3, 8);
      else if (t.type === 'frost') g.fillPoints([{ x: t.x, y: t.y - 13 }, { x: t.x + 7, y: t.y - 3 }, { x: t.x, y: t.y + 7 }, { x: t.x - 7, y: t.y - 3 }], true);
      else if (t.type === 'beacon') { g.fillCircle(t.x, t.y - 3, 5); g.lineStyle(2, t.color, 0.5 + 0.3 * Math.sin(S.time * 3)).strokeCircle(t.x, t.y - 3, 10); }
      else if (t.type === 'anvil') { g.fillRect(t.x - 10, t.y - 11, 20, 7); g.fillRect(t.x - 4, t.y - 4, 8, 6); g.fillRect(t.x - 8, t.y + 2, 16, 3); }
      else if (t.type === 'laser') { g.fillPoints([{ x: t.x - 9, y: t.y + 5 }, { x: t.x + 9, y: t.y + 5 }, { x: t.x, y: t.y - 9 }], true); g.fillStyle(0xffffff, 0.5 + 0.5 * Math.min(1, t.stacks / t.rampMax)).fillCircle(t.x, t.y - 1, 3); }
      else if (t.type === 'mortar') { g.fillRect(t.x - 10, t.y + 1, 20, 6); g.fillCircle(t.x, t.y - 1, 7); g.fillStyle(0x0b0f1c, 1).fillCircle(t.x, t.y - 3, 3); }
      else g.fillRect(t.x - 4, t.y - 12, 8, 16);
    }
    if (t.stunT > 0) {
      if (!art) o.fillStyle(0x000000, 0.45).fillRoundedRect(t.x - 16, t.y - 16, 32, 32, 5);
      const a0 = S.time * 6;
      o.lineStyle(2, 0xffffff, 0.8).beginPath(); o.arc(t.x, t.y, 20, a0, a0 + 1.4); o.strokePath();
      o.lineStyle(3, 0xff2e4d, 0.9).beginPath(); o.arc(t.x, t.y, 24, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (t.stunT / (t.stunMax || 1))); o.strokePath();
    }
    // level pips: 10 small dots in two rows of 5
    for (let i = 0; i < t.lvl; i++) o.fillStyle(i >= 5 ? 0xff6fd8 : 0xf2c14e, 1).fillCircle(t.x - 10 + (i % 5) * 5, t.y + (art ? 16 : 10) + (i >= 5 ? 0 : 3), 1.6);
  }
  g = o; // everything below draws over the tower art

  for (const c of S.coins) { g.fillStyle(0xf2c14e, 1).fillCircle(c.x, c.y, 6); g.lineStyle(1, 0xffffff, 0.8).strokeCircle(c.x, c.y, 8 + 2 * Math.sin(S.time * 6)); }
  for (const e of S.enemies) {
    if (e.shieldAura) g.lineStyle(1, 0xd8b84a, 0.25).strokeCircle(e.x, e.y, 70);
    if (e.heal) g.lineStyle(2, 0x7dffb0, 0.15 + 0.15 * Math.sin(S.time * 5)).strokeCircle(e.x, e.y, e.r + 6 + 4 * Math.sin(S.time * 5));
    if (e.unslow) { const back = posAt(Math.max(0, e.d - 18)); g.lineStyle(e.r, 0x4fa8ff, 0.35).lineBetween(back.x, back.y, e.x, e.y); }
    if (e.stillT > 0.5 && S.towers.some(t => t.type === 'anvil')) { const n = Math.min(6, 2 + Math.floor(e.stillT)); for (let i = 0; i < n; i++) { const a = i * 2.4; g.lineStyle(1.5, TOWERS.anvil.color, 0.7).lineBetween(e.x, e.y, e.x + Math.cos(a) * (e.r + 4 + e.stillT * 3), e.y + Math.sin(a) * (e.r + 4 + e.stillT * 3)); } }
    shadow(g, e.x, e.y + e.r * 0.85, e.r * 2.2);
    g.fillStyle(0x101223, e.phase ? 0.45 : 1).fillCircle(e.x, e.y, e.r + 1.25);
    g.fillStyle(e.color, e.phase ? 0.45 : 1).fillCircle(e.x, e.y, e.r);
    g.fillStyle(0xffffff, e.phase ? 0.15 : 0.35).fillCircle(e.x - e.r * 0.35, e.y - e.r * 0.35, e.r * 0.35);
    const arm = armorOf(e);
    if (arm > 0) g.lineStyle(1 + arm * 8, 0xb8c0d8, 0.85).strokeCircle(e.x, e.y, e.r);
    if (e.hexT > 0) { const a0 = S.time * 4; g.lineStyle(2, 0xb07cff, 0.9).beginPath(); g.arc(e.x, e.y, e.r + 5, a0, a0 + 4); g.strokePath(); }
    if (e.stunT > 0) g.lineStyle(2, 0xffffff, 0.9).strokeCircle(e.x, e.y, e.r + 2);
    else if (e.slow) g.lineStyle(2, TOWERS.frost.color, 0.9).strokeCircle(e.x, e.y, e.r + 2);
    if (e.burnT > 0) g.fillStyle(0xff8a3d, 0.8).fillCircle(e.x, e.y - e.r, 2.5);
    if (e.boss) g.lineStyle(2, 0xf2c14e, 1).strokeCircle(e.x, e.y, e.r + 4);
    const w = e.r * 2 + 4;
    g.fillStyle(0x000000, 0.6).fillRect(e.x - w / 2, e.y - e.r - 7, w, 3);
    g.fillStyle(0x5fe39a, 1).fillRect(e.x - w / 2, e.y - e.r - 7, w * Math.max(0, e.hp / e.max), 3);
  }

  if (h.tx !== null && !h.ko) g.lineStyle(1, hc, 0.5).strokeCircle(h.tx, h.ty, 6);
  if (S.aim) {
    const a = S.aim, ready = !(h.ab.t > 0);
    if (!h.ko) { const dx = a.x - h.x, dy = a.y - h.y, d = Math.hypot(dx, dy) || 1; g.lineStyle(1, 0xffd36e, ready ? 0.35 : 0.15).lineBetween(h.x, h.y, h.x + dx / d * 1400, h.y + dy / d * 1400); }
    g.lineStyle(2, 0xffd36e, 0.95).strokeCircle(a.x, a.y, 10);
    g.lineBetween(a.x - 15, a.y, a.x - 5, a.y); g.lineBetween(a.x + 5, a.y, a.x + 15, a.y); g.lineBetween(a.x, a.y - 15, a.x, a.y - 5); g.lineBetween(a.x, a.y + 5, a.x, a.y + 15);
  }
  if (h.ko) {
    g.fillStyle(0x8d95b8, 0.3).fillCircle(h.x, h.y, 13);
    g.lineStyle(3, hc, 0.8).beginPath();
    g.arc(h.x, h.y, 17, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (1 - h.ko / h.respawn)); g.strokePath();
  } else {
    const HX = S.heroics;
    if (HX.wither) g.fillStyle(0x7a2e5a, 0.12).fillCircle(h.x, h.y, 90 + 20 * HX.wither);
    if (h.range < 9999) g.lineStyle(1, hc, 0.15).strokeCircle(h.x, h.y, h.range);
    if (h.brace) { const ready = h.braceT >= h.brace; g.lineStyle(ready ? 3 : 2, ready ? 0xffd36e : 0x8d95b8, ready ? 0.95 : 0.6).beginPath(); g.arc(h.x, h.y, 26, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (h.braceT / h.brace)); g.strokePath(); }
    if (h.hold) { g.lineStyle(2, 0xf2c14e, 0.9).strokeRect(h.x - 17, h.y - 17, 34, 34); }
    if (h.shield > 0) { g.fillStyle(0x9af0ff, 0.15).fillCircle(h.x, h.y, 28); g.lineStyle(3, 0x9af0ff, 0.9).beginPath(); g.arc(h.x, h.y, 28, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * h.shield / h.shieldMax); g.strokePath(); }
    if (h.odT > 0) g.lineStyle(2, 0xff6f6f, 0.5 + 0.4 * Math.sin(S.time * 20)).strokeCircle(h.x, h.y, 24);
    shadow(g, h.x, h.y + 12, 30);
    g.fillStyle(hc, 0.2).fillCircle(h.x, h.y, 18);
    g.fillStyle(0x101223, 1).fillCircle(h.x, h.y, 13.25);
    g.fillStyle(hc, 1).fillCircle(h.x, h.y, 12);
    g.fillStyle(0xffffff, 0.35).fillCircle(h.x - 4, h.y - 4, 4);
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

  for (const z of S.zones) {
    const a = Math.min(1, z.t / z.T * 1.5), pulse = 0.5 + 0.5 * Math.sin(S.time * 10);
    if (z.line) { g.lineStyle(z.r * 2, z.color, 0.22 * a).lineBetween(z.x1, z.y1, z.x2, z.y2); g.lineStyle(2, z.color, 0.7 * a).lineBetween(z.x1, z.y1, z.x2, z.y2); }
    else if (z.vortex) { for (let i = 0; i < 3; i++) g.lineStyle(2, z.color, 0.8 * a).strokeCircle(z.x, z.y, z.r * (1 - ((S.time * 1.5 + i / 3) % 1))); g.fillStyle(0x000000, 0.4 * a).fillCircle(z.x, z.y, z.r * 0.3); }
    else { g.fillStyle(z.color, (0.12 + 0.1 * pulse) * a).fillCircle(z.x, z.y, z.r); g.lineStyle(2, z.color, 0.6 * a).strokeCircle(z.x, z.y, z.r); }
  }
  for (const e of S.enemies) {
    if (e.tauntT > 0 && !S.hero.ko) g.lineStyle(1, 0xff5d6c, 0.5).lineBetween(e.x, e.y, S.hero.x, S.hero.y);
    if (e.markT > 0 || e.spotT > 0) g.lineStyle(1.5, 0xff2e4d, 0.9).strokeCircle(e.x, e.y, e.r + 7);
  }
  if (S.enemies.some(e => BIG_BOSS[e.type] && e.d / PATH_LEN >= 0.75)) g.lineStyle(4, 0xff2e4d, 0.5 + 0.5 * Math.sin(S.time * 12)).strokeCircle(BASE.x, BASE.y, 44);
  for (const sh of S.shells || []) {
    const u = sh.t / sh.T, gx = sh.x0 + (sh.x1 - sh.x0) * u, gy = sh.y0 + (sh.y1 - sh.y0) * u;
    const arc = Math.min(140, Math.hypot(sh.x1 - sh.x0, sh.y1 - sh.y0) * 0.4) * Math.sin(Math.PI * u);
    g.lineStyle(1, 0xff5d6c, 0.25 + 0.4 * u).strokeCircle(sh.x1, sh.y1, sh.tw.splash * (1.1 - 0.3 * u));
    g.fillStyle(0x000000, 0.35).fillCircle(gx, gy, 4);
    g.fillStyle(sh.tw.color, 1).fillCircle(gx, gy - arc, 5 + 2 * sh.mult);
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

let hudT = 0, SCENE = null;
const lineStyle0 = Phaser.GameObjects.Graphics.prototype.lineStyle;
Phaser.GameObjects.Graphics.prototype.lineStyle = function (w, c, a) { return lineStyle0.call(this, Math.max(w, 1 / PX), c, a); };
function shake(intensity, ms) { if (SCENE) SCENE.cameras.main.shake(ms, intensity); }
class Main extends Phaser.Scene {
  preload() { loadArt(this); }
  create() {
    this.cameras.main.setZoom(PX).centerOn(W / 2, H / 2);
    this.g = this.add.graphics(); this.o = this.add.graphics().setDepth(2); SCENE = this;
    makeAnims(this);
    this.input.mouse.disableContextMenu();
    this.input.on('pointerdown', p => { hideTip(); if (!S || !S.hero) return; p.rightButtonDown() ? handleRight(p.worldX, p.worldY) : handleClick(p.worldX, p.worldY, p.wasTouch); });
    this.input.on('pointermove', p => {
      if (!S || !S.hero) return;
      S.hover = cellAt(p.worldX, p.worldY); S.pointer = { x: p.worldX, y: p.worldY };
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
    update(dt);
    if (groundFor !== pathCells) drawGround(this);
    syncSprites(this); draw(this.g, this.o);
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
  const k = /^[1-9]$/.test(e.key) && S.loadout[+e.key - 1];
  if (k) selectBuild(k);
  else if (lk === 'r') { if (!S.paused && !S.over && !cancelPlacing()) sellSelected(); }
  else if (lk === 'q') useAbility();
  else if (lk === 'h') toggleHold();
  else if (lk === 'f') toggleAim();
  else if (e.key === ' ' || e.code === 'Space') { e.preventDefault(); if (document.activeElement && document.activeElement.blur) document.activeElement.blur(); if (!e.repeat) startWave(); }
  else if (e.key === 'Escape') {
    if (S.build || S.mergeFrom || S.sel || S.pendingBuild) { S.build = null; S.mergeFrom = null; S.sel = null; S.pendingBuild = null; renderBuildBar(); renderInspector(); }
    else if (!S.over) showSettings();
  }
});

window.riftguard = { get state() { return S; }, music: bgm };
new Phaser.Game({
  type: Phaser.AUTO, parent: 'board', width: W * PX, height: H * PX, backgroundColor: '#101223', pixelArt: true, roundPixels: true,
  scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
  scene: Main, banner: false,
});
})();
