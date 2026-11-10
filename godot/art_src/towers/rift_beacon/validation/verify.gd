extends SceneTree
var out := {}
func aabb_center_global(mi: MeshInstance3D) -> Vector3:
	var a := mi.get_aabb()
	return mi.global_transform * (a.position + a.size * 0.5)
func _initialize() -> void:
	var ps: PackedScene = load("res://art_src/towers/rift_beacon/rift_beacon.glb")
	var root: Node3D = ps.instantiate()
	get_root().add_child(root)
	var lines := []
	for n in root.find_children("*", "", true, false):
		lines.append("%s %s pos=%s" % [root.get_path_to(n), n.get_class(), (n as Node3D).position if n is Node3D else ""])
	out["tree"] = lines
	var ap: AnimationPlayer = root.get_node("AnimationPlayer")
	var anims := {}
	for an in ap.get_animation_list():
		var a := ap.get_animation(an)
		var tr := []
		for i in a.get_track_count(): tr.append("%s:%s" % [a.track_get_path(i), a.track_get_type(i)])
		anims[an] = {"length": a.length, "loop": a.loop_mode, "tracks": tr}
	out["anims"] = anims
	var rotor: Node3D = root.get_node("Turret/Rotor")
	var inner: Node3D = root.get_node("Turret/Rotor/InnerPivot")
	var outer_mi: MeshInstance3D = root.get_node("Turret/Rotor/OuterRing")
	var inner_mi: MeshInstance3D = root.get_node("Turret/Rotor/InnerPivot/InnerRing")
	var samples := []
	ap.play("idle")
	for t in [0.0, 0.5, 1.0, 1.5, 2.0, 3.0, 3.99, 4.0]:
		ap.seek(t, true)
		samples.append({"t": t, "rotor_euler_deg": rotor.rotation_degrees, "inner_euler_deg": inner.rotation_degrees,
			"rotor_axis_up": rotor.global_transform.basis.y, "inner_axis_x_global": inner.global_transform.basis.x,
			"outer_center": aabb_center_global(outer_mi), "inner_center": aabb_center_global(inner_mi),
			"coreglow_scale": (root.get_node("Turret/Glow/CoreGlow") as Node3D).scale.x})
	out["idle_samples"] = samples
	# two-player test: idle on main, buff_pulse on a second player
	var fx := AnimationPlayer.new(); root.add_child(fx)
	fx.add_animation_library("", ap.get_animation_library(""))
	ap.play("idle"); ap.seek(1.0, true)
	fx.play("buff_pulse"); fx.seek(0.4, true)
	ap.advance(0.0)
	out["two_player"] = {"rotor_deg_after": rotor.rotation_degrees.y, "pulse_ring_scale": (root.get_node("Turret/aura_center/PulseRing") as Node3D).scale,
		"beam_scale": (root.get_node("Turret/beam_top/BeamFlare") as Node3D).scale, "crystal_scale": (root.get_node("Turret/Rotor/Crystal") as Node3D).scale}
	fx.seek(1.0, true)
	out["buff_end"] = {"pulse": (root.get_node("Turret/aura_center/PulseRing") as Node3D).scale.x, "flash": (root.get_node("Turret/Glow/CoreFlash") as Node3D).scale.x, "crystal": (root.get_node("Turret/Rotor/Crystal") as Node3D).scale.x}
	ap.play("spawn"); ap.seek(0.0, true)
	var s0 := rotor.scale.x
	ap.seek(1.2, true)
	out["spawn"] = {"rotor_scale_start": s0, "rotor_scale_end": rotor.scale.x, "rotor_deg_end": rotor.rotation_degrees, "inner_deg_end": inner.rotation_degrees}
	# materials
	var mats := {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
		mats[mi.name] = {"name": m.resource_name, "emission": m.emission_enabled, "emission_tex": m.emission_texture != null, "energy": m.emission_energy_multiplier,
			"transparency": m.transparency, "albedo_tex": m.albedo_texture != null and m.albedo_texture.get_width(), "tris": (mi as MeshInstance3D).mesh.get_faces().size() / 3}
	out["materials"] = mats
	var aabb := AABB()
	var first := true
	for mi in [root.get_node("Turret/Base"), outer_mi, inner_mi, root.get_node("Turret/Rotor/Crystal")]:
		var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		aabb = a if first else aabb.merge(a); first = false
	out["body_aabb"] = [aabb.position, aabb.end]
	# wrapper scene
	var w: PackedScene = load("res://art_src/towers/rift_beacon/fx/rift_beacon.tscn")
	var wi = w.instantiate(); get_root().add_child(wi)
	out["wrapper_ok"] = wi != null and wi.has_method("buff_pulse")
	print("VERIFY_JSON " + JSON.stringify(out, "  "))
	quit()
