# Changelog

Every change to Riftguard, newest first. Each section matches a merged pull request, and each GitHub release uses the newest section as its notes.

## 0.16: Tower projectiles from the art

- **Towers fire their own art instead of lines.** Each shot is the first frame of the tower's effect row, flying from the tower's muzzle (the crystal, barrel or coil tip, not the tile centre) to the enemy and following it as it moves. The rest of the row plays as the explosion where it lands. Long shots such as the Arcane Bolt turn to face where they fly.
- **Tesla Coil lightning hops between enemies** as sparks that leave from the last enemy hit, one after another.
- **Prism Laser fires its beam art.** The beam runs from the laser's orb to its target, turning and stretching as the target moves, and grows thicker as it heats up on one target. Chain Laser hops use the same beam.
- **Siege Mortar shells are the shell art**, leaving the barrel and tipping over as they climb and fall along the arc, then exploding where they land.
- Merged towers still use lines until they get art.

## 0.15: Pixel-art board and music fix

- **The whole board is now pixel art in the same view as the tower art.** The game draws at the art's own pixel size (one tile is 32 art pixels) with hard pixel edges, and the ground is raised metal plating in the art's palette, lit from the upper left. The path is a sunken lane with the plating's wall along its far side. Tower art is redrawn pixel for pixel in the art bible's 16 colors, and enemies and the hero get dark outlines and a highlight to match.
- **Music starts as soon as the desktop game opens.** In a browser it starts on your first click or key press, since browsers block sound until then.

## 0.14: Music and tower colors

- **Background music.** The first song, **Riftwalker**, plays on the menus and during runs. A new **Music** button on the main menu lets you pick a song, play, pause, skip and seek, set the music volume, and choose a play mode (repeat one, play all, shuffle). Settings also has a music on/off switch and a music volume slider, separate from the sound effects.
- **Tower colors match the art.** Arcane Bolt is now pink, Plasma Cannon teal, Frost Pylon ice mint, Tesla Coil electric blue, Rift Beacon rose, Grave Anvil amber, Prism Laser coral and Siege Mortar cream. Shots, range circles and the build bar use the new colors.

## 0.13: Tower art and a 3/4 view board

- **Every tower has real art.** Arcane Bolt, Plasma Cannon, Frost Pylon, Tesla Coil, Rift Beacon, Grave Anvil, Prism Laser and Siege Mortar each idle, play an attack and recover animation when they fire, and throw a hit effect on the target: bolts strike down, plasma bursts, ice shatters, lightning lands, mortar shells explode where they fall, and the anvil slams around itself. The Rift Beacon pulses every few seconds during a wave. Merged towers keep their shapes for now.
- **The board now matches the art's 3/4 top-down view.** The ground is a raised tile floor and the path is a sunken lane with a wall along its far side. Towers, enemies and the hero cast shadows, and tower art stands up out of its tile.

## 0.12: Two abilities per hero, path names and Hold fix

### Heroes
- **Every hero has two abilities.** Pick one on the Heroes page (main menu); the choice is saved and used in every run.
  - **Vanguard:** Shield Slam (area stun), or **Bulwark Shield**: a shield that soaks damage for 5s, then bursts for part of what it soaked.
  - **Striker:** Rift Nova (area blast), or **Overdrive**: attack twice as fast for 5s.
  - **Oracle:** Overclock Field (towers fire faster), or **Stasis Field**: enemies in the area are slowed for 6s.
  - **Sniper:** Piercing Shot (line shot), or **Orbital Strike**: a heavy blast on your aim point or the toughest enemy.
- Each new ability has its own upgrades (two ability upgrades each, plus a few hero upgrades). Upgrades for the other ability no longer show up.
- **Hold** turns off when your hero is knocked out, so it never respawns stuck at the base.

### Towers
- **Names after 3 paths:** once a tower has 3 paths picked, it takes the name of that combination right away, without waiting for level 13. A Plasma Cannon with Bigger Shells, Hot Plasma and Burning Ground becomes an Inferno Mortar. The Towers page counts these named forms as found.

## 0.11: Laser and Mortar towers, role level bonuses, pricier upgrades

### Pre-run screens
- Picking a loadout is now two pages: choose your hero first, then your towers. **Back** on the tower page returns to the hero page.

### Hero
- **Skill points are gone.** Each level still gives an upgrade pick, and now also a small automatic bonus based on the hero's role:
  - **Damage heroes** (Striker, Sniper): +2% damage, +1% range and +1.5% attack speed per level.
  - **Tanks** (Vanguard): +3% max HP, +0.5% damage reduction and regen equal to 0.2% of max HP per second, per level.
  - **Support** (Oracle): +1% range and aura reach, and +1% XP gain per level (0% at level 1).
- The hero panel and the hero cards show the role's level bonus.

### Towers
- **Upgrade prices doubled:** a level-up now costs the tower's build cost × its level.
- **Merged towers cost more to upgrade:** a hybrid's first level-up costs double the last level-up of its priciest parent (build cost × 12 × 2), and the price rises 10% per level after that. Super towers start at 1.5× that.
- **New: Prism Laser** (unlock for ◆ 250). Holds a beam on one enemy, and every tick on the same target heats it up for more damage (up to +160%). Switching targets cools it down. Paths: **Chain Laser** (the beam jumps to more enemies; its mastery, Prism Web, keeps full damage on every jump), Focusing Lens, Heat Sink, Amplifier and Long Lens.
- **New: Siege Mortar** (unlock for ◆ 250). Very long range (320). It fires rarely, and its slow shells arc across the map, leading their target, before landing in a heavy blast. Paths: Heavy Payload, Wide Blast, Napalm, Quick Reload and Shockwave.
- Both new towers have signatures (Overheat and Rocket Shells) and 16 ascended forms each, for 128 forms in total.

## 0.10.1: Skill point tuning

- Hero levels give **2 skill points** instead of 3. Heroes level up fast enough that 3 points stacked milestones too quickly.

## 0.10: Skill points, ascended forms and a new Frost path

### Hero
- **Skill points:** every hero level still gives an upgrade pick, and now also skill points (2 per level as of 0.10.1). Spend them right after the pick, or any time with **K** (or the Skills button). Unspent points are saved.
- Seven stats: **Might** (damage), **Haste** (attack speed), **Vitality** (max HP), **Toughness** (damage reduction), **Focus** (ability cooldown), **Precision** (crit) and **Command** (damage for towers near your hero).
- **Milestones:** every 10 points in one stat adds a big bonus to that stat, for example Might 10 gives +15% hero damage.
- **Orbiting Blades** is retired for now and saved for a future melee hero. In its place:
  - **Retribution** (Vanguard): every 4s, a shockwave hits nearby enemies for flat damage plus part of the damage you took.
  - **Rift Barrage** (Striker): every 5s, fires a volley of homing missiles at nearby enemies.
- Weaker picks got stronger: **Rift Boots** also adds attack speed, **Long Reach** also adds tower range, and **Quick Reboot** also adds max HP.

### Towers
- **Fewer towers:** you can start a run with fewer than 5 towers as a challenge. The game asks you to confirm so it never happens by accident.
- **Level-up bonus by tower type:** damage towers still get +5% damage per level. The Frost Pylon gets +4% attack speed per level instead, and the Rift Beacon gets +3 range. Their level 13 bonus matches: Frost fires 20% faster and slows harder, and the Beacon gets +10% range and +5% to its damage buff.
- **Frost Pylon:** the Ice Shards damage path is replaced by **Hypothermia**. Each hit adds a chill stack, and at enough stacks the enemy freezes solid. Its mastery, **Cold Snap**, makes the freeze burst out to every enemy nearby.
- **Ascended forms:** every combination of paths now ascends into its own named form, 16 per tower and 96 in total. The inspector shows the name a tower is heading for, and the Towers page tracks which forms you have found.
- **Balance:**
  - Speed paths (Quickcast, Autoloader, Capacitor Bank) fire 14% faster per point, up from 12%.
  - Lingering Cold adds 0.8s per point, up from 0.6s.
  - Beacon Empower gives +8% per point, up from 6%, to make up for the level bonus moving to range.
  - Beacon Tithe gives +10% gold per point, up from 6%, and Gold Rush drops coins 8% of the time, up from 5%.
  - Anvil Guardian cuts hero damage by 6% per point, up from 4%.

## 0.9.1: Sniper aim point, hold position and ability tooltips

- **Sniper aim point:** point at the board and press **F**. Piercing Shot then always fires toward that spot, wherever the Sniper stands. Press F on the point (or click the Aim button) to clear it.
- **Hold position:** the Vanguard and Sniper can press **H** to lock themselves in place so a stray click or key never moves them.
- **Execution Round:** its cooldown refund from kills is capped at 40% per shot, so Piercing Shot can't refresh itself forever.
- **Vanguard:** blocks every enemy that reaches it, with no limit. The Bulwark upgrade (+1 block) is gone, and Aegis Core now gives +150 max HP instead of +2 blocks.
- **Ability tooltips:** hover any hero ability name (hero panel, ability button, Heroes page, loadout) for a box with its exact numbers, cooldown and upgrades.

## 0.9: Tougher enemies, new towers, loadouts and Rift Maelstrom

### Enemies
- Enemies are much tougher: more base HP, a steeper HP curve each wave, and bigger waves.
- **Armor:** Brutes, Juggernauts, Shieldbearers and bosses take less damage from hits (capped at 60%). Burns, damage zones, executes, Hex Brand and Brittle ignore armor.
- New enemies:
  - **Wraith:** very fast and can't be slowed.
  - **Phantom:** only Defensive heroes can block it.
  - **Splitter:** splits into 2 Runners when it dies.
  - **Juggernaut:** huge, armored and can't be slowed.
  - **Shieldbearer:** gives nearby enemies extra armor.
  - **Mender:** heals nearby enemies.
- From wave 6, each wave brings 2 or 3 of the special enemy types, so waves feel different.
- Stuns still work on enemies that can't be slowed.
- A new **Enemies** panel lists every enemy you've met, what it does and how to beat it.

### Bosses
- **Rift Knight, Shield Bash:** stuns the nearest tower.
- **Rift Warden, Rift Lock:** stuns 2 random towers, and opens rifts that summon Grunts.
- **Rift Tyrant, Roar:** stuns 3 towers and knocks your hero back. At half HP it enrages and calls in 2 Juggernauts.
- Targeted towers flash red a second before every stun.
- New upgrade for every hero, **Grounded**, makes boss stuns shorter.

### Towers
- **Rift Beacon (new):** a support tower that never attacks and buffs every tower in its range. Its paths add damage, fire rate, range, armor piercing or gold.
- **Grave Anvil (new):** slams enemies that aren't moving (blocked, stunned or frozen), hitting harder the longer they stay still. It's built to pair with the Vanguard.
- Both new towers unlock for 200 shards and can't be merged.
- **Arcane Bolt:** Twin Cast is replaced by **Hex Brand**. Branded enemies pulse damage based on everything they've taken so far, to themselves and enemies nearby. Its mastery, **Hex Nova**, makes them explode when they die.

### Loadouts and the Towers page
- Before a run you pick your hero and **5 towers**. The build bar shows only those, on keys 1 to 5, and your last loadout is remembered.
- New **Towers** page with permanent upgrades for each tower: Power, Supply Line, Veteran Crew, and a unique **Signature** upgrade.
- Every tab has a free Refund button.

### Clearer upgrades
- Hero upgrades, tower paths, shop items and permanent upgrades now show real before and after numbers, like "Damage 23 → 28".

### Maps
- New **Rift Maelstrom** (Level 4) is a 35-wave spiral into a base in the middle of the board.
  - Enemies have 80% more HP, armored enemies get +10% armor, and special enemies show up 2 waves early.
  - The final Tyrant drops 8 Boss Cores.

### Specials
- Demon Pact now costs 200 Boss Cores.

## 0.8: Hero roles, ability upgrades, Boss Cores and level 13 towers

### Towers
- Towers now go up to **level 13**, so the 12 level-ups max out 3 paths of 4 points and every chosen path gets its mastery.
- Once a tower has picked all its paths, the unused paths disappear from the panel.
- With the **Oracle**, towers use **4 paths of 3 points**. Each Oracle point is bigger, so a maxed path ends exactly as strong as a normal 4-point path and unlocks its mastery on the 3rd point.
- Merging now needs two level 13 towers.

### Hero upgrades
- Heroes are grouped into **Offensive** (Striker, Sniper), **Defensive** (Vanguard) and **Support** (Oracle), with an empty **Special** group for future heroes.
- Each hero only gets upgrades that fit it: its own list, a small list for its category, and 3 upgrades every hero can get (Rift Boots, Quick Reboot, and the rare Secret upgrades). The Sniper no longer sees armor, healing or Orbiting Blades.
- Damage and crit upgrades are Offensive only, HP, regen and healing are Defensive only, and tower discounts and build range are Support only.
- Gold per kill now comes in two clear versions: **Bounty Sigil** (Offensive: enemies your hero kills drop more gold) and **War Tithe** (Defensive and Support: every enemy killed by your towers or hero drops more gold, at a lower amount).
- New upgrades: Taunt (Vanguard), Momentum (Striker), Rapid Construction (Oracle), Spotter and Headhunter (Sniper).
- Boss heroic powers are split by hero too, with two new Sniper powers: **Ricochet** and **Marked for Death**.
- The War Banner relic (+hero damage) only shows up for Offensive heroes.

### Ability upgrades
Every ability has 4 upgrades that change what it does, offered at Rare or better:
- **Shield Slam:** Shockwave Rings, Magnetic Slam, Molten Crater, Echo Slam.
- **Rift Nova:** Twin Nova, Black Hole, Chain Nova, Nova Dash.
- **Overclock Field:** Mobile Field, Chrono Field, Overcharge Burst, Prism Field.
- **Piercing Shot:** Railgun, Ricochet Round, Cluster Round, Execution Round.
Big moments now come with screen shake, burning zones, vortexes and shockwaves.

### Bosses
- If a **big boss** (Rift Warden or Rift Tyrant) reaches your base, the run is lost. A **mini boss** (Rift Knight) costs 5 base HP.
- Bosses show a health bar at the top of the board, and a warning flashes when a big boss is three quarters of the way to your base.
- Bosses drop **Boss Cores**: 1 from a Rift Knight, 2 from a Rift Warden, 5 from the Rift Tyrant. You keep them even if you lose.

### Special upgrades
New permanent upgrades bought once with Boss Cores on the Heroes page:
- All heroes: Rift Sovereign, Second Chance, Grand Bazaar, Ascendant Foundry, Demon Pact.
- Vanguard: Immortal Bulwark. Striker: Blade Dancer. Oracle: Grand Conductor. Sniper: One Shot.

### Heroes page
- Every upgrade tab has a free **Refund** button that gives back everything spent there, so trying a build is never a mistake.

## 0.7: Tower paths, forms and the boss shop

### Towers
- Towers now go up to **level 12** (up from 10). Merging needs two level 12 towers.
- Each tower type has **5 upgrade paths** that stay the same every level. Each level adds one point to a path, and a path holds up to 4 points.
- A tower can only use **3 different paths**. Once it has picked 3, the other 2 lock and it keeps upgrading the ones it chose. Playing the **Oracle** raises the limit to **4 paths**.
- The 4th point in a path unlocks that path's **mastery**, a special effect such as Executioner, Prism Split, Echo, Mana Nova or Shatter.
- At level 12 a tower **ascends into a form** named after the paths it used most, like "Runic Prism of Focus" or "Brittle Shard of Ice". The same tower type can end in many different forms.
- Every level still adds +5% damage, and reaching level 12 gives a bigger bonus on top.
- The price of each upgrade is shown on its button, or "Free" when it costs nothing.

### Merging
- Merging costs **1000 gold** (shown on the Merge button).
- A merged tower no longer gets plain damage or speed upgrades. Its 5 paths are **fusion effects** chosen from the paths its two parents used, so different forms make different hybrids. Fusion effects include Executioner, Phase Rounds, Gilded Rounds, Shatter, Echo Shot, Gravity Well, Time Lock, Storm Call, Frostfire, Chain Blast, Overload, Nova, Death Blast, Leech, Tempo and more. Each point also adds +8% damage.
- A hybrid takes its name from its parent's form, like "Runic Rimeshard".
- Super towers get **ascended** versions of fusion effects their two hybrids didn't already use.

### Boss shop
- After every boss wave (every 10th wave) the **Rift Bazaar** opens with 6 items you can only get there: tower upgrades (fusion power, free level-ups, free merges, an extra path slot, and more) and hero upgrades.
- There is a **1% chance** it's a **Demonic Bazaar** instead. Half its items are demonic: twice as strong, but each comes with a curse.
- Prices go up with the wave number.

### Wording
- Discount upgrades now name what they discount: "New towers cost X% less to build", "Tower upgrades (level-ups) cost X% less", "Tower merges cost X% less".

### Project
- Added this changelog. Each release on GitHub now shows the newest section as its notes.

## 0.6.3: Heroes page, the Sniper, settings and harder maps (PR #3)

### Heroes and meta upgrades
- Meta upgrades are now **unique to each hero**, on their own Heroes page instead of a popup. Locked heroes show there too, with what they cost to unlock.
- Old shared hero upgrades were refunded as shards.
- New general upgrades: **Veteran**, and **Fortune's Favor**, an expensive upgrade that raises the odds of rarer upgrade choices.
- New hero: the **Sniper** (250 shards to unlock). It has to stand still and brace before it can shoot, but has unlimited range and heavy, slow shots. Its ability Piercing Shot hits everything in a line.
- "Double damage" is now called **crit**, with crit chance and a new **crit damage** upgrade.

### Maps
- Maps are longer and harder: Verdant Rift has 20 waves, Ironhold 25 and Warped Spire 30.
- Each map unlocks after you beat the one before it.
- Bosses appear every 5th wave, a stronger boss every 10th, and the Tyrant on the final wave.
- Enemy health grows faster each wave. Boss scaling was eased after test runs kept losing to the wave 20 Tyrant.

### Interface
- The game opens **fullscreen** by default (F11 also toggles it).
- New **settings menu** (Esc or the gear button): volume, mute, fullscreen, return to menu and quit. The game pauses while it's open.
- Sound effects were added.
- The layout was rebuilt to fill the screen, with the stats on top, the board in the middle, hero and tower details on the side, and the build bar at the bottom.

## 0.6.2: Tower upgrade and merge rework (PR #2)

- The ability button now shows its cooldown as a bar that empties when used and fills back up.
- **Space** starts the next wave.
- Hero health and ability cooldowns no longer recover between waves, which removes the wait-and-heal exploit.
- Each tower type now always offers the same **5 upgrades** at every level, and picking one no longer removes the others.
- Towers maxed at level 10, and only level 10 towers could merge.
- Added **super towers**: merge two level 10 hybrids.

## 0.6.1: Windows desktop app (PR #1)

- Riftguard runs as a Windows app, with an installer and a portable exe.
- Every merge to main builds a new release on GitHub automatically.
- The installed game shows a "Checking for updates" screen when it opens, downloads and installs any new version, then starts. If there's no internet it just starts the game.

## 0.5: First playable version

- Roguelike tower defense built with Phaser 3 and Vite.
- A hero you move around the map who fights and builds towers in range.
- Four tower types (Arcane Bolt, Plasma Cannon, Frost Pylon, Tesla Coil) with upgrades, and merging two towers into hybrids with their own recipes.
- Upgrade choices after waves with rarities from common to legendary, demonic and secret.
- Three maps, a codex of hybrid recipes, meta progression with shards, and a run log with stats.
