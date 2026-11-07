## The unified art style in the real game (Board + Live3D): Ocean Drive with Gale and live 3D towers, checked and
## photographed. Gale behind a building is hidden by it and in front of it draws over it; an enemy in front of Gale
## shows over Gale; the towers turn and fire live with shots from their own muzzles; Gale's beam reaches the edge of
## the shared camera's view; and the Settings switch puts the old look back and the new one again.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/style_game.tscn -- <out dir>
extends Node

var out := "user://style_game"
var fails := 0
var main: Main


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))


## The board's picture, cropped around a board world point and blown up.
func _crop(name: String, at: Vector2, half: Vector2, z: int) -> void:
	await RenderingServer.frame_post_draw
	var b := main.board
	var bi := b.viewport.get_texture().get_image()
	var c: Vector2 = b.viewport.canvas_transform * (b.world.transform * at)
	var r := Rect2i(Vector2i(c - half), Vector2i(half * 2)).intersection(Rect2i(Vector2i.ZERO, bi.get_size()))
	var img := bi.get_region(r)
	img.resize(img.get_width() * z, img.get_height() * z, Image.INTERPOLATE_NEAREST)
	img.save_png(out.path_join(name + ".png"))


## How many of the live layer's pixels are drawn in a box around a board world point (feet), up to `tall` above it.
func _drawn(at: Vector2, tall: float) -> int:
	await RenderingServer.frame_post_draw
	var lv := main.board.live
	var img := lv.vp.get_texture().get_image()
	var k := Vector2(lv.vp.size) / Live3D.VIEW
	var n := 0
	for y in range(int((at.y - tall) * k.y), int(at.y * k.y) + 1):
		for x in range(int((at.x - 14) * k.x), int((at.x + 14) * k.x) + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and img.get_pixel(x, y).a > 0.5:
				n += 1
	return n


func _put(h: Hero, world: Vector2) -> void:
	h.x = world.x
	h.y = (world.y - Board.TOP) / Board.K
	h.tx = null


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(150).timeout.connect(func(): print("TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.settings.style3d = true
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("gale", ["arcane", "laser", "mortar", "frost"])
	await _frames(10)
	var g := main.game
	var S := g.S
	var b := main.board
	S.gold = 99999
	_check(b.live != null, "the board has the shared 3D layer")
	_check(b.live.vp.size == Vector2i(1536, 832), "it renders at the scenery's own 1536x832 (%s)" % b.live.vp.size)
	await _frames(5)
	var h := S.hero
	_check(b.hero_3d != null and b.hero_3d.rig == b.live.rig and b.hero_3d.vp == null, "Gale is drawn in the shared world, with no viewport of its own")
	# towers on open ground around the middle
	var spot := Vector2(480, 300)
	var placed := 0
	for type in ["arcane", "laser", "mortar", "frost"]:
		var best := Vector2i(-1, -1)
		for c in g.build_cells():
			if g.build_problem(c.x, c.y, type) == "" and (best.x < 0 or g.cell_pos(c.x, c.y).distance_to(spot) < g.cell_pos(best.x, best.y).distance_to(spot)):
				best = c
		if best.x >= 0:
			g.place_tower(best.x, best.y, type)
			placed += 1
			spot += Vector2(70, 10 if placed % 2 else -40)
	await _frames(5)
	var lives := 0
	for t: Tower in S.towers:
		if t.has_meta("view") and t.get_meta("view") is Live3D.LiveTower:
			lives += 1
	_check(lives == placed and placed == 4, "all %d towers with models are drawn live (%d)" % [placed, lives])
	_put(h, Vector2(560, 300))
	await _frames(30)
	await _shot("game_full")

	print("phase occlusion")
	# occlusion: a building in the middle of the map, Gale just behind its ground line, then just in front
	var bld: Sprite2D = null
	for sp in b.art_sprites:
		var s2: Sprite2D = sp
		var sz := s2.texture.get_size() * s2.scale
		if sz.y > 80 and sz.x > 60 and s2.position.y > 70 and s2.position.y < 470 and s2.position.x > 20 and s2.position.x + sz.x < 940 \
				and s2.texture.resource_path.get_file().begins_with("bld_"):
			bld = s2
			break
	_check(bld != null, "found a building to stand behind (%s)" % (bld.texture.resource_path.get_file() if bld else "-"))
	if bld:
		var sz := bld.texture.get_size() * bld.scale
		var cx := bld.position.x + sz.x / 2
		var open_n := 0
		_put(h, Vector2(560, 300))
		await _frames(8)
		open_n = await _drawn(Vector2(560, 300), 40)
		_put(h, Vector2(cx, bld.position.y - 12))
		await _frames(8)
		var hid := await _drawn(Vector2(cx, bld.position.y - 12), 40)
		await _crop("game_behind", Vector2(cx, bld.position.y - 40), Vector2(170, 120), 3)
		_put(h, Vector2(cx, bld.position.y + 40))
		await _frames(8)
		var front := await _drawn(Vector2(cx, bld.position.y + 40), 40)
		await _crop("game_front", Vector2(cx, bld.position.y - 40), Vector2(170, 120), 3)
		_check(open_n > 200, "in the open Gale covers %d render pixels" % open_n)
		_check(hid < open_n / 10, "behind the building Gale is hidden (%d of %d pixels show)" % [hid, open_n])
		_check(front > open_n * 0.6, "in front of it Gale draws over it (%d of %d)" % [front, open_n])

	print("phase wave")
	# a wave: the towers turn to their targets and fire, shots leave the models' muzzles
	_put(h, Vector2(560, 300))
	g.start_wave()
	var turned := 0
	var fired := 0
	var muzzle_ok := true
	var yaw0 := {}
	for t: Tower in S.towers:
		yaw0[t] = (t.get_meta("view") as Live3D.LiveTower).yaw
	for i in 500:
		await get_tree().process_frame
		if main.ui.modal_open(): # a level-up offer pauses the game: take it away so the wave keeps going
			main.ui.close_modal()
			S.paused = false
		for t: Tower in S.towers:
			var v = t.get_meta("view") if t.has_meta("view") else null
			if not v is Live3D.LiveTower:
				continue
			var lt: Live3D.LiveTower = v
			if lt.ap and lt.ap.current_animation == lt.fire and lt.fire != lt.idle:
				lt.set_meta("fired", true)
			var m := b.turret_muzzle_at(t, DB.towers[t.type])
			if m.distance_to(Vector2(t.x, Board.SY(t.y))) > 60:
				muzzle_ok = false
		turned = 0
		fired = 0
		for t: Tower in S.towers:
			var lt: Live3D.LiveTower = t.get_meta("view")
			if absf(angle_difference(lt.yaw, yaw0[t])) > 0.2:
				turned += 1
			if lt.get_meta("fired", false):
				fired += 1
		if turned >= 3 and fired >= 3 and i > 200:
			break
		if i % 50 == 0:
			print("wave frame ", i, " turned ", turned, " fired ", fired, " enemies ", S.enemies.size())
		if i == 260:
			var e = S.enemies[0] if S.enemies.size() else null
			if e:
				await _crop("game_wave", Vector2(560, 300), Vector2(330, 190), 2)
				# an enemy just in front of Gale shows over Gale
				_put(h, Vector2(e.x, Board.SY(e.y) - 6))
				await _frames(2)
				h.x = e.x
				h.y = e.y - 6 / Board.K
				await _frames(3)
				await _crop("game_enemy_front", Vector2(e.x, Board.SY(e.y)), Vector2(60, 50), 6)
	for t: Tower in S.towers:
		var lt: Live3D.LiveTower = t.get_meta("view")
		print("  %s at %s shot_at %.2f target %s yaw %.2f->%.2f fire '%s' idle '%s' has_fire %s" % [t.type, Vector2(t.x, t.y), t.shot_at, t.last_target != null,
			yaw0[t], lt.yaw, lt.fire, lt.idle, lt.ap.has_animation(lt.fire) if lt.ap else false])
	_check(turned >= 3, "the turrets turn to their targets (%d of %d)" % [turned, S.towers.size()])
	_check(fired >= 3, "the towers play their fire clips as they shoot (%d)" % fired)
	_check(muzzle_ok, "every shot leaves the tower's own muzzle, on the tower")
	await _shot("game_wave_full")
	for t: Tower in S.towers:
		var v: Node2D = t.get_meta("view")
		await _crop("tower_" + t.type, v.position + Vector2(0, -20), Vector2(50, 50), 6)
	await _crop("gale_close", b.hero_3d.position + Vector2(0, -16), Vector2(50, 45), 6)

	print("phase beam")
	# Gale's beam ends on the shared camera's edge (the gameplay camera and its low-res viewport)
	if b.beam_layer:
		_check(b.beam_layer.shared and b.beam_layer.cam == b.live.rig.cam, "Gale's beam uses the board's one camera")
		_put(h, Vector2(480, 300))
		await _frames(5)
		var ok := b.beam_layer.strike_at(Vector2(1, 0), Board.K, 30.0, 0.5, func(): pass)
		await _frames(3)
		if ok:
			var tip := b.beam_layer.strike_from + b.beam_layer.strike.global_basis.z * b.beam_layer.strike_len
			var on := b.live.rig.cam.unproject_position(tip) / Vector2(b.live.vp.size)
			_check(on.x >= 0.99, "Air Strike's trail reaches the right edge of the render (%.3f)" % on.x)
			await _shot("game_strike")
		else:
			_check(false, "Air Strike laid its trail")

	print("phase switch")
	# the Settings switch: the old look, then the new one again
	Save.settings.style3d = false
	b.restyle()
	await _frames(10)
	_check(b.live == null and b.hero_3d != null and b.hero_3d.vp != null, "style off: Gale is back in its own viewport")
	var sprites := 0
	for t: Tower in S.towers:
		if t.has_meta("view") and t.get_meta("view") is AnimatedSprite2D:
			sprites += 1
	_check(sprites == S.towers.size(), "style off: the towers are their baked sprites again (%d)" % sprites)
	await _shot("game_old_look")
	Save.settings.style3d = true
	b.restyle()
	await _frames(10)
	_check(b.live != null and b.hero_3d != null and b.hero_3d.rig == b.live.rig, "style on again: back in the shared world")
	print("STYLE GAME DONE, %d failed" % fails)
	get_tree().quit(1 if fails else 0)
