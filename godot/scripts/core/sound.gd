## Music (the songs in assets/music, picked on the Music screen) and the small synthesized sound effects.
extends Node

signal song_changed

const XFADE := 10.0
const RATE := 22050
## name: [start Hz, end Hz, seconds, wave, volume, min gap between plays]
const SFX := {
	shot = [900, 450, 0.05, "square", 0.035, 0.07],
	boom = [500, 0, 0.25, "noise", 0.16, 0.09],
	snipe = [1600, 120, 0.2, "sawtooth", 0.12, 0.0],
	kill = [520, 260, 0.08, "triangle", 0.07, 0.04],
	leak = [160, 60, 0.3, "sawtooth", 0.2, 0.15],
	wave = [300, 620, 0.35, "sawtooth", 0.1, 0.0],
	boss = [110, 55, 0.9, "sawtooth", 0.18, 0.0],
	level = [600, 1300, 0.3, "triangle", 0.14, 0.0],
	ability = [220, 900, 0.3, "sine", 0.2, 0.0],
	click = [760, 700, 0.04, "sine", 0.06, 0.03],
}
## unlock: the map you must beat to hear the song.
var songs := [
	{ id = "riftwalker", name = "Riftwalker", path = "res://assets/music/riftwalker.ogg", unlock = "" },
	{ id = "phase", name = "Just a Phase", path = "res://assets/music/just_a_phase.ogg", unlock = "verdant" },
]
const MODES := { one = "Loop one song", all = "Play the playlist in order", shuffle = "Shuffle the playlist" }

var _sfx := {}
var _last := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: Array[AudioStreamPlayer] = []
var _cur := 0 # which music player is the main one
var _fading := 0.0
var _next_id := ""
var started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for k in SFX:
		_sfx[k] = _make(SFX[k])
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		p.finished.connect(_on_finished.bind(p))
		_music.append(p)
	apply()


func _make(s: Array) -> AudioStreamWAV:
	var f0: float = s[0]
	var f1: float = s[1]
	var dur: float = s[2]
	var kind: String = s[3]
	var vol: float = s[4]
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var lp := 0.0
	var a := 1.0 - exp(-TAU * f0 / RATE) # one-pole low-pass for the noise burst
	for i in n:
		var t := float(i) / RATE
		var g := vol * pow(0.0001 / vol, t / dur) # exponential fade like the original
		var v := 0.0
		if kind == "noise":
			lp += a * ((randf() * 2.0 - 1.0) * (1.0 - float(i) / n) - lp)
			v = lp
		else:
			var f := f0 * pow(f1 / f0, t / dur)
			phase = fmod(phase + f / RATE, 1.0)
			match kind:
				"square": v = 1.0 if phase < 0.5 else -1.0
				"sawtooth": v = phase * 2.0 - 1.0
				"triangle": v = 4.0 * absf(phase - 0.5) - 1.0
				_: v = sin(phase * TAU)
		data.encode_s16(i * 2, int(clampf(v * g, -1.0, 1.0) * 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


func play(name: String) -> void:
	var st: Dictionary = Save.settings
	if st.get("muted", false) or float(st.get("volume", 0.6)) <= 0.0 or not _sfx.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var gap: float = SFX[name][5]
	if gap > 0 and _last.has(name) and now - _last[name] < gap:
		return
	_last[name] = now
	for p in _pool:
		if not p.playing:
			p.stream = _sfx[name]
			p.play()
			return


## Volumes from the settings.
func apply() -> void:
	var st: Dictionary = Save.settings
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(st.get("master", 0.2)))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(0.0001 if st.get("muted", false) else maxf(0.0001, float(st.get("volume", 0.6)))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, float(st.get("music_volume", 0.5)))))
	var p := _music[_cur]
	if p.stream is AudioStreamOggVorbis:
		(p.stream as AudioStreamOggVorbis).loop = _looping()
	if not st.get("music_on", true):
		for m in _music:
			m.stream_paused = true
	elif started:
		if p.stream == null:
			play_song(st.get("song", "riftwalker"))
		else:
			p.stream_paused = false
			if not p.playing:
				p.play()


# ---------- music ----------
func song(id: String) -> Dictionary:
	for s in songs:
		if s.id == id:
			return s
	return songs[0]


func song_open(s: Dictionary) -> bool:
	return s.unlock == "" or Save.map_won(s.unlock)


func playlist() -> Array:
	var pl = Save.settings.get("playlist")
	var out := []
	for s in songs:
		if song_open(s) and (pl == null or (pl as Array).has(s.id)):
			out.append(s)
	if out.is_empty():
		out.append(current())
	return out


func current() -> Dictionary:
	var s := song(Save.settings.get("song", "riftwalker"))
	return s if song_open(s) else songs[0]


func _looping() -> bool:
	return Save.settings.get("music_mode", "all") == "one" or playlist().size() == 1


func _stream(s: Dictionary) -> AudioStreamOggVorbis:
	var st: AudioStreamOggVorbis = load(s.path).duplicate()
	st.loop = false
	return st


func play_song(id: String) -> void:
	Save.settings.song = id
	Save.save_settings()
	started = true
	_fading = 0.0
	_next_id = ""
	for m in _music:
		m.stop()
		m.volume_db = 0.0
	var p := _music[_cur]
	p.stream = _stream(current())
	(p.stream as AudioStreamOggVorbis).loop = _looping()
	if Save.settings.get("music_on", true):
		p.play()
	song_changed.emit()


func start() -> void:
	if not started:
		play_song(Save.settings.get("song", "riftwalker"))


func pick_next(step := 1) -> String:
	var list := playlist()
	var n := list.size()
	var i := -1
	for k in n:
		if list[k].id == Save.settings.get("song"):
			i = k
	if i < 0:
		return list[0].id
	if Save.settings.get("music_mode") == "shuffle" and n > 1:
		return list[(i + 1 + randi() % (n - 1)) % n].id
	return list[(i + step + n) % n].id


func next_song(step := 1) -> void:
	play_song(pick_next(step))


func is_playing() -> bool:
	return _music[_cur].playing and not _music[_cur].stream_paused


func position() -> float:
	return _music[_cur].get_playback_position()


func length() -> float:
	var s = _music[_cur].stream
	return s.get_length() if s else 0.0


func seek(t: float) -> void:
	_music[_cur].seek(t)


func pause() -> void:
	_music[_cur].stream_paused = true


func resume() -> void:
	started = true
	var p := _music[_cur]
	if p.stream == null:
		play_song(Save.settings.get("song", "riftwalker"))
	else:
		p.stream_paused = false
		if not p.playing:
			p.play()


func _on_finished(p: AudioStreamPlayer) -> void:
	if p == _music[_cur] and _fading <= 0.0 and Save.settings.get("music_on", true):
		next_song()


# In a playlist the next song fades in over the last 10 seconds of the one playing.
func _process(delta: float) -> void:
	if _fading > 0.0:
		_fading -= delta
		var k := clampf(_fading / XFADE, 0.0, 1.0)
		var old := _music[1 - _cur]
		old.volume_db = linear_to_db(maxf(0.0001, k))
		_music[_cur].volume_db = linear_to_db(maxf(0.0001, 1.0 - k))
		if _fading <= 0.0:
			old.stop()
			_music[_cur].volume_db = 0.0
		return
	var p := _music[_cur]
	if not Save.settings.get("music_on", true) or not p.playing or p.stream_paused or _looping() or playlist().size() < 2:
		return
	var left := length() - p.get_playback_position()
	if length() < XFADE * 3 or left > XFADE:
		return
	var id := pick_next()
	if id == Save.settings.get("song"):
		return
	Save.settings.song = id
	Save.save_settings()
	_cur = 1 - _cur
	var n := _music[_cur]
	n.stream = _stream(song(id))
	n.volume_db = linear_to_db(0.0001)
	n.play()
	_fading = maxf(1.0, left)
	song_changed.emit()
