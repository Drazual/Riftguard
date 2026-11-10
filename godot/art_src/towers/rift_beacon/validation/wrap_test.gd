extends SceneTree
var vis; var t := 0.0; var pulsed := false; var rotor: Node3D
func _initialize() -> void:
	vis = load("res://art_src/towers/rift_beacon/fx/rift_beacon.tscn").instantiate()
	get_root().add_child(vis)
	vis.aura_radius = 2.5
	vis.play_spawn()
	rotor = vis.get_node("Model/Turret/Rotor")
func _process(delta: float) -> bool:
	t += delta
	if t > 1.5 and not pulsed:
		pulsed = true; vis.buff_pulse(); print("PULSE at ", t, " rotor_y=", rotor.rotation_degrees.y, " anim=", vis.anim.current_animation)
	if pulsed and t > 1.9 and t < 1.95:
		print("MID rotor_y=", rotor.rotation_degrees.y, " speed=", vis.anim.speed_scale, " pulse_ring=", vis.get_node("Model/Turret/aura_center/PulseRing").scale.x, " fx=", vis.fx.current_animation, " pulse_t=", vis._aura_mat.get_shader_parameter("pulse_t"), " plane=", (vis.aura.mesh as PlaneMesh).size)
	if t > 3.0:
		print("END rotor_y=", rotor.rotation_degrees.y, " anim=", vis.anim.current_animation, " speed=", vis.anim.speed_scale); quit()
	return false
