# Roguelike TD: Design Doc (v0.1)

A browser roguelike tower defense game. You control a mobile hero who fights, blocks paths and builds towers. The towers level up and merge into hybrids. Each run is a chain of fights you choose yourself.

## Pillars
1. **The hero is you.** You move them, fight with them and decide where they stand.
2. **Build, level, merge.** Towers grow, and merging two maxed towers creates something new.
3. **Choose your risk.** Every fight is a choice between safe and greedy.
4. **Runs differ, progress sticks.** Random upgrades shape each run, and unlocks persist between runs.

## Setting: fantasy sci-fi
Magic and machines side by side: arcane turrets, plasma crossbows and mech knights.
- Enemies: void creatures, rogue machines, corrupted mages.
- Example towers: Arcane Bolt, Plasma Cannon, Frost Pylon, Rune Wall, Drone Bay.

## The hero
- Moves freely on the map and auto-attacks nearby enemies. Has one or two active abilities.
- **Can block the path.** Enemies stop and fight the hero, so the hero acts as a living wall.
- **Knockout, not death.** At 0 HP the hero is down for about 8 to 10 seconds, then respawns at the base.
- **Levels up during the run.** Each level offers 3 random upgrades, picking 1. Upgrade types:
  - Offense: damage, attack speed, new ability effects
  - Defense: armor, taunt, thorns, faster respawn
  - Builder: cheaper towers, buffs to nearby towers, faster leveling
- You start with one hero. More are unlocked through meta progression, and each has its own kit and tower affinity.

## Towers
- **No build limit.** Each extra tower of the same type costs more, so spamming is allowed but not cost-effective.
- **Leveling:** towers go from level 1 to 3 (cap TBD) through gold and/or kills, picking an upgrade at each level.
- **Merging:** two max-level towers plus a **gold cost** make one hybrid that combines both abilities.
  - Fire + Frost = Steam (blinding, slowing clouds)
  - Arcane Bolt + Lightning = Railgun (piercing shots)
  - Recipes stay hidden until discovered, and found recipes are saved in a codex.
- Hybrids can level up further. Whether hybrids can merge again is still open.

## Run structure
- **Map of fight nodes.** After each fight you pick the next one from a few options.
- **Difficulty per node.** Harder fights give better rewards: more gold, rarer upgrades and relics.
- Node types:
  - Normal fight
  - Elite / hard fight (higher risk, better loot)
  - **Challenge round** (special rules such as "no building", "hero only", "double-speed enemies" or "survive 60s") with unique rewards
  - Shop / event / rest (ideas, not confirmed yet)
  - Boss at the end of each act
- **Fight flow:** a build phase where you place, level and merge towers and position the hero, then a wave, then another build phase, and so on until the fight ends.
- **Relics:** run-long passive modifiers from elites and bosses (e.g. "Frost towers chain to 1 extra enemy").

## Meta progression
Earned currency carries between runs.
- **Heroes:** unlock new heroes, upgrade existing ones (stats, new starting abilities, new upgrade options added to their pool).
- **Global buffs:** account-wide perks (starting gold, tower discount, extra reroll).
- **Base upgrades:** make the base you defend stronger (more HP, a base turret, passive income).
- Unlocks mostly **add options** rather than raw power, so runs stay challenging.

## Open questions
- Run length: how many fights per act, and how many acts?
- Tower level cap, and whether hybrids can merge again (tier 3 towers?)
- Does the hero earn XP from kills, wave clears or both?
- Lives: does the base have HP, or does each leaked enemy cost a life?
- Art style: pixel art, simple vector shapes or something else?
- Engine: plain HTML5 canvas, Phaser, or something else?

## First playable (suggested scope)
One map, one hero, 4 base towers, 3 merge recipes, 10 waves, a basic build phase, and hero movement and blocking. No meta progression yet. This proves the core loop is fun before anything is built around it.
