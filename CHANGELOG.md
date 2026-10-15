# Changelog

Every change to Riftguard, newest first. Each section matches a merged pull request, and each GitHub release uses the newest section as its notes.

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
