## Checks the Striker's (and Sniper's) gun points at the target on screen at every angle: the screen angle of
## the barrel (weapon to Muzzle, as drawn) against the angle asked for, after turning and firing.
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/hero_aim.tscn
extends Node


func _ready() -> void:
	var worst := 0.0
	for id in ["striker", "sniper"]:
		var h := Hero3D.new()
		add_child(h)
		h.setup("res://art_src/heroes/%s" % id)
		for i in 10:
			await get_tree().process_frame
		var line := PackedStringArray()
		for k in 16:
			var a := k * TAU / 16
			h.face(a)
			for f in 4:
				h.play("fire")
				for j in 8:
					await get_tree().process_frame
			var gun: Node3D = h.held if h.held else h.muzzle.get_parent()
			var p0 := h.cam.unproject_position(h._on_bone(gun))
			var p1 := h.cam.unproject_position(h.muzzle_at())
			var err := rad_to_deg(angle_difference(a, (p1 - p0).angle()))
			if (p1 - p0).length() > 2:
				worst = maxf(worst, absf(err))
			line.append("%d:%+.0f" % [roundi(rad_to_deg(a)), err])
		print(id, " barrel error (deg) ", " ".join(line))
		h.queue_free()
	print("worst %.1f deg" % worst)
	print("AIM DONE")
	get_tree().quit()
