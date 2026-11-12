class_name PrismLanceHeat
extends RefCounted
## The model's heat look: Prism Lance's glow parts get brighter and hotter in colour as the beam heats up, and the
## fire clip runs faster (runes spin faster, the canister pumps faster). Call apply() whenever the heat changes
## (cheap; only touches the effect materials, which Merge3D leaves alone) and scale the clip with clip_speed().
##   PrismLanceHeat.apply(merge3d.model, heat)
##   merge3d.ap.speed_scale = PrismLanceHeat.clip_speed(heat)   # Merge3D.tick's advance() honours speed_scale
## heat 0 is the model exactly as exported.

## node name -> [how much brighter at heat 1 (x energy), the colour it heats toward]
const PARTS := {
	"MuzzleGlow": [2.2, Color(1.0, 0.82, 0.95)],
	"ChargeHalo": [1.8, Color(1.0, 0.35, 0.8)],
	"MuzzleFlash": [1.8, Color(1.0, 0.92, 0.98)],
	"PrismGlow": [2.0, Color(1.0, 0.55, 0.85)],
	"ChargeRing0": [2.0, Color(1.0, 0.75, 0.95)],
	"ChargeRing1": [2.0, Color(1.0, 0.75, 0.95)],
	"ChargeRing2": [2.0, Color(1.0, 0.75, 0.95)],
	"Runes": [2.2, Color(1.0, 0.6, 0.92)],
	"CanGlow": [1.6, Color(0.75, 0.6, 1.0)],
}


static func clip_speed(heat: float) -> float:
	return 1.0 + 0.8 * clampf(heat, 0.0, 1.0)


static func apply(model: Node, heat: float) -> void:
	if model == null:
		return
	var h := clampf(heat, 0.0, 1.0)
	for nm in PARTS:
		var mi := model.find_child(nm, true, false) as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var m: StandardMaterial3D
		if mi.has_meta("heat_mat"):
			m = mi.get_meta("heat_mat")
		else:
			var src := mi.get_active_material(0) as StandardMaterial3D
			if src == null:
				continue
			m = src.duplicate() as StandardMaterial3D # per tower, so towers heat up on their own
			m.set_meta("e0", m.emission_energy_multiplier)
			m.set_meta("c0", m.emission)
			m.set_meta("a0", m.albedo_color)
			mi.set_surface_override_material(0, m)
			mi.set_meta("heat_mat", m)
		var gain: float = PARTS[nm][0]
		var hot: Color = PARTS[nm][1]
		m.emission_energy_multiplier = float(m.get_meta("e0")) * (1.0 + (gain - 1.0) * h)
		m.emission = (m.get_meta("c0") as Color).lerp(hot, 0.6 * h)
		var a0: Color = m.get_meta("a0")
		var ac := a0.lerp(hot, 0.5 * h)
		ac.a = a0.a
		m.albedo_color = ac
