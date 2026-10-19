## Numbers that shape every run: prices, waves, scaling, rewards. Edit here to rebalance.
@tool
class_name GameRules
extends Resource

@export_group("Content")
## Maps in unlock order: beat one to open the next.
@export var maps: Array[PackedScene] = []
## Towers in build-bar order (keys 1-8 before the loadout is picked).
@export var towers: Array[TowerData] = []
## Heroes in menu order.
@export var heroes: Array[HeroData] = []
@export var enemies: Array[EnemyData] = []
@export var spells: SpellList
@export var elements: ElementList
@export var fusions: FusionList
## Hybrids (two towers) and super towers (three or four).
@export var recipes: RecipeList
@export_group("Upgrade lists")
## Hero upgrades offered at level-ups.
@export var perks: UpgradeList
## Ability upgrades (Rare or better).
@export var ability_mods: UpgradeList
## Legendary and Secret one-offs.
@export var uniques: UpgradeList
## Demonic downsides (k = curse strength).
@export var curses: UpgradeList
## Boss drops with 3 ranks.
@export var heroics: UpgradeList
@export var relics: UpgradeList
@export var legendary_relics: UpgradeList
@export var secret_relics: UpgradeList
## Hard wave toughness mods, challenge debuffs and challenge goals (pts = difficulty).
@export var tough: UpgradeList
@export var challenges: UpgradeList
@export var requirements: UpgradeList
## Boss shop (after every 10th wave).
@export var shop: UpgradeList
## Menu upgrades: all heroes, all towers, Boss Core specials.
@export var global_meta: UpgradeList
@export var tower_global: UpgradeList
@export var specials: UpgradeList
## Short "Simple" explanations.
@export var simple_texts: TextData
@export_group("Run start")
@export var start_gold := 150
@export var start_lives := 20
@export var rerolls := 2
@export var hero_first_level_xp := 30
@export var hero_xp_growth := 1.3
@export var build_range := 170.0
@export var aura_range := 130.0
@export var respawn := 8.0
## Wave number from which you choose Normal, Hard or Challenge.
@export var choice_from := 5
@export var loadout_size := 5
@export_group("Towers")
@export var max_level := 13
## Points per path (the Oracle uses 3 bigger points).
@export var path_max := 4
## Paths a tower can use (the Oracle adds 1).
@export var path_limit := 3
@export var merge_cost := 1000
@export var super_cost := 20000
@export var sell_rate := 0.8
## Each tower bought makes that tower this much pricier...
@export var own_price_growth := 1.5
## ...and every other tower this much.
@export var other_price_growth := 1.15
## Level-up price = build cost x this x (points in that path + 1) x level_cost_extra.
@export var level_cost_mult := 2.5
@export var oracle_level_cost_mult := 3.1
@export var level_cost_extra := 1.15
## Seconds between a super tower's signature powers.
@export var super_cooldown := 5.0
## Boss Cores for a tower's Signature.
@export var signature_cores := 20
@export_multiline var level_dmg := "t.dmg *= 1.05"
@export var level_dmg_text := "+5% damage"
@export_multiline var ascend_dmg := "t.dmg *= 1.3\nt.rate *= 0.87"
@export var ascend_dmg_text := "+30% damage and fires 15% faster"
@export_multiline var level_rate := "t.rate *= 0.96"
@export var level_rate_text := "+4% attack speed"
@export_multiline var ascend_rate := "t.rate *= 0.8\nt.slow = min(0.85, t.slow + 0.1)"
@export var ascend_rate_text := "fires 20% faster and slows 10% harder"
@export_multiline var level_range := "t.range += 3"
@export var level_range_text := "+3 range"
@export_multiline var ascend_range := "t.range *= 1.1\nt.b_dmg += 0.05"
@export var ascend_range_text := "+10% range and +5% to its damage buff"
@export_multiline var level_hero := "t.hb_dmg += 0.01\nt.hb_armor += 0.003"
@export var level_hero_text := "+1% hero damage and +0.3% hero damage reduction"
@export_multiline var ascend_hero := "t.hb_dmg += 0.1\nt.hb_armor += 0.05\nt.hb_regen += 0.004"
@export var ascend_hero_text := "+10% hero damage, +5% damage reduction and more regen"
@export_group("Enemies and waves")
@export var armor_cap := 0.6
## Bosses can go past the normal armor cap, up to this.
@export var boss_armor_cap := 0.75
## Every enemy's HP is multiplied by this.
@export var enemy_hp_mult := 1.25
## Normal enemy HP x (1 + a(n-1) + b(n-1)^2) on wave n.
@export var hp_growth_a := 0.55
@export var hp_growth_b := 0.1
## Boss HP x (1 + this x (wave - 5)).
@export var boss_hp_growth := 0.2
@export var grunts_base := 8
@export var grunts_per_wave := 3
@export var runners_from := 2
@export var runners_per_wave := 2
@export var brutes_from := 4
@export var spawn_gap_start := 0.9
@export var spawn_gap_per_wave := 0.04
@export var spawn_gap_min := 0.3
@export var knight_every := 5
@export var warden_every := 10
@export var wave_gold_base := 25
@export var wave_gold_per_wave := 5
@export var shop_every := 10
@export_group("Hard and Challenge rules")
@export var tough_hp := 1.4
@export var tough_armor := 0.15
@export var tough_speed := 1.2
@export var tough_regen := 0.02
@export var tough_horde := 0.25
@export var swarm_hp := 0.65
@export var blitz_speed := 1.4
@export var lone_tower := 0.6
@export var lone_hero := 2.0
@export var weak_tower := 0.75
@export_group("Rewards")
@export var shards_per_wave := 4
@export var shards_per_boss := 15
@export var shards_for_win := 60
@export_group("Hero upgrades")
@export var rarity_names: PackedStringArray = ["Common", "Uncommon", "Rare", "Mythic", "Legendary", "Secret"]
@export var rarity_mults: PackedFloat32Array = [1.0, 1.4, 1.9, 2.6, 3.5, 4.5]
@export var rarity_weights: PackedFloat32Array = [50.0, 25.0, 15.0, 6.5, 3.0, 0.5]
@export var demonic_chance := 0.01
## How many enemies Gale holds at once in Bruiser Form (other heroes hold 1 or 2, tanks hold all).
@export var bruiser_block := 6
## Gold upgrades only roll at Legendary or rarer, and only in this share of level-ups.
@export_range(0.0, 1.0) var gold_perk_chance := 1.0
@export_multiline var level_offensive := "h.dmg *= 1.02\nh.range = iff(h.range < 9999, h.range * 1.01, h.range)\nh.rate /= 1.015"
@export var level_offensive_text := "+2% damage, +1% range, +1.5% attack speed"
@export_multiline var level_defensive := "h.grow_tank(0.03, 0.005, 0.002)"
@export var level_defensive_text := "+3% max HP, +0.5% damage reduction, +0.2% of max HP as regen per second"
@export_multiline var level_support := "h.range = iff(h.range < 9999, h.range * 1.01, h.range)\nh.aura_range *= 1.01\nh.xp_gain += 0.01"
@export var level_support_text := "+1% range and aura reach, +1% XP gain"
@export_multiline var level_special := "h.spell *= 1.04\nh.max_mana += 3\nh.mana_regen += 0.15"
@export var level_special_text := "+4% spell damage, +3 max mana, +0.15 mana per second"
@export_group("Wizard")
@export var triple_at := 10
@export var element_rest := 2.0
## Share of max mana refilled when a wave is cleared.
@export var wave_mana_refill := 0.3
@export_group("Mastery")
@export var mastery_max := 50
