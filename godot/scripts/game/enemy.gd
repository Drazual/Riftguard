## One enemy walking the path.
class_name Enemy
extends RefCounted

var type := ""
var data: EnemyData
var boss := false
var hp := 1.0
var max := 1.0
var speed := 50.0
var d := 0.0 # distance along the path
var lane := 0 # which of the map's entries it came in by (MapInfo.lanes)
var x := 0.0
var y := 0.0
var r := 9.0
var color := Color.RED
var gold := 5.0
var lives := 1
var atk := 8.0
var armor := 0.0
var aura_armor := 0.0
var regen := 0.0
var steady := false
var unslow := false
var unstun := false # stuns do nothing to it
var unblockable := false # heroes and walls can't hold it up
var pushback_immune := false # push-back, knockback and pulls along the path do nothing
var phase := false
var split := 0
var heal := 0.0
var shield_aura := 0.0
var slow := 0.0
var slow_t := 0.0
var stun_t := 0.0
var rime := 0 # Rimeshard frost stacks (5 freezes, then shatters)
var rime_t := 0.0 # time since the last stack; the stacks clear after the tower's rime_decay
var rime_frz := 0.0 # frozen by rime: time left before it shatters
var rime_src = null # the Rimeshard that froze it
var rime_full := 0.0 # that tower's shot damage, for the shatter and its splinters
var burn_t := 0.0
var burn_dps := 0.0
var burn_src = null
## Tower burns: up to Game.BURN_STACKS stacks per source tower, each {dps, t, src} (burn_t/burn_dps is the one
## spell-poison and run-modifier slot).
var burns: Array = []
var fire_t := 0.0 # Fire spell burn: seconds left and share of max HP per second
var fire_pct := 0.0
var mark_t := 0.0
var mark := 0.0
var brittle := 0.0
var brittle_t := 0.0
var brk := 0.0
var brk_t := 0.0
## Armor cut (Frost Brittle's shred, supers and the Expose spell): armor points off while shred_t lasts.
var shred := 0.0
var shred_t := 0.0
## Timed "takes +X% damage" debuffs by key (Game.add_vuln): {amt, t, tw}. tw: only from towers.
var vulns := {}
var taken := 0.0
var still_t := 0.0
var still_peak := 0.0 # still_t when it started moving again (Crushing Tide fades it out over 3s)
var walled_t := 0.0 # a wall stopped it just now (the Anvil's Bulwark Pact counts it as stopped)
var pin_cd := 0.0 # the Anvil's Pin can't pin it again until this runs out
var hex := 0.0
var hex_t := 0.0
var hex_tick := 1.0
var hex_src = null
var hex_nova := 0.0
var heal_t := 1.0
var slowed_for := 0.0
var push_t := 0.0
var push_spd := 0.0
var pull_t := 0.0 # an air or earth spell is dragging it along the path to pull_to (its middle), then it walks on
var pull_to := 0.0
var pull_spd := 0.0
var pull_n := 0
var pull_at := -99.0
## Wizard push-backs in a row (they wear off) and when the last one landed.
var push_n := 0
var push_at := -99.0
var taunt_t := 0.0
var spot := 0.0
var spot_t := 0.0
var chill := 0
var blocked := false
var dead := false
var fake := false
var hit_by := {} # Tower or "hero" -> true
# bosses
var pow_t := -1.0
var summons := 0
var enraged := false


func pos() -> Vector2:
	return Vector2(x, y)
