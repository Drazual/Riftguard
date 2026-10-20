## Saves: meta progression (shards, upgrades, mastery, stats), settings and the merge codex, as JSON in the
## user folder (on Windows %APPDATA%\Riftguard, the same folder the old desktop app used). The first time it
## runs it picks up the old desktop app's save if it finds one.
extends Node

const META_FILE := "user://meta.json"
const SETTINGS_FILE := "user://settings.json"
const CODEX_FILE := "user://codex.json"

var meta := {}
var settings := {}
var codex := {}
var imported := false


func _ready() -> void:
	load_all()


func default_meta() -> Dictionary:
	return { v = 2, shards = 0, cores = 0, specials = {}, heroes = {}, global = {}, best = {}, runs = [], towers = {}, loadout = null, seen = {},
		tower_global = {}, kills = { towers = {}, heroes = {} }, hero_stat = {}, wins = { towers = {}, heroes = {} }, takedowns = { towers = {}, heroes = {} },
		played = {}, abilities = {}, forms = {}, tips = {}, el_stat = {}, wiz_els = {}, wiz_load = null }


func default_settings() -> Dictionary:
	return { master = 0.2, volume = 0.6, muted = false, fullscreen = true, music_on = true, music_volume = 0.5, song = "riftwalker", music_mode = "all",
		playlist = null, simple = false, keys = true }


func load_all() -> void:
	meta = default_meta()
	settings = default_settings()
	codex = {}
	var m = _read(META_FILE)
	if m is Dictionary:
		_merge(meta, m)
	elif not FileAccess.file_exists(META_FILE):
		_import_old()
	var s = _read(SETTINGS_FILE)
	if s is Dictionary:
		_merge(settings, s)
	var c = _read(CODEX_FILE)
	if c is Dictionary:
		codex = c
	_fill()


func _fill() -> void:
	for k in ["specials", "heroes", "global", "best", "towers", "seen", "tower_global", "hero_stat", "played", "abilities", "forms", "tips", "el_stat", "wiz_els", "secret_heroes"]:
		if not (meta.get(k) is Dictionary):
			meta[k] = {}
	for k in ["kills", "wins", "takedowns"]:
		if not (meta.get(k) is Dictionary):
			meta[k] = {}
		for sub in ["towers", "heroes"]:
			if not (meta[k].get(sub) is Dictionary):
				meta[k][sub] = {}
	if not (meta.get("runs") is Array):
		meta.runs = []
	_carry_first_stage()
	for id in DB.tower_order:
		if not (meta.towers.get(id) is Dictionary):
			meta.towers[id] = {}
	for id in DB.hero_order:
		if not (meta.heroes.get(id) is Dictionary):
			meta.heroes[id] = {}


## Canal Crossing became the first stage after Sunset Outpost. A save that already beat Sunset Outpost counts
## Canal Crossing as beaten too, so no map or mastery level locks again.
func _carry_first_stage() -> void:
	if not map_won("verdant") or meta.best.has("canal"):
		return
	meta.best["canal"] = meta.best["verdant"].duplicate()
	for kind in ["towers", "heroes"]:
		for k in meta.wins[kind]:
			var w = meta.wins[kind][k]
			if w is Dictionary and w.get("verdant", false):
				w["canal"] = true


func _merge(into: Dictionary, from: Dictionary) -> void:
	for k in from:
		into[k] = from[k]


func _read(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _write(path: String, data) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


func save_meta() -> void:
	_write(META_FILE, meta)


func save_settings() -> void:
	_write(SETTINGS_FILE, settings)


func save_codex() -> void:
	_write(CODEX_FILE, codex)


## Wipes every save, like a first launch.
func reset_everything() -> void:
	for p in [META_FILE, SETTINGS_FILE, CODEX_FILE]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	meta = default_meta()
	settings = default_settings()
	codex = {}
	_fill()
	save_meta()


# ---------- helpers used everywhere ----------
static func rank(obj, id: String) -> int:
	if obj is Dictionary:
		return int(obj.get(id, 0))
	return 0


func tower_meta(id: String) -> Dictionary:
	return meta.towers[id]


func hero_meta(id: String) -> Dictionary:
	return meta.heroes[id]


func map_won(id: String) -> bool:
	var b = meta.best.get(id)
	return b is Dictionary and bool(b.get("won", false))


func map_unlocked(id: String) -> bool:
	var i := DB.map_order.find(id)
	# a map you have already played stays open even if a new stage was added before it
	return i <= 0 or map_won(DB.map_order[i - 1]) or meta.best.has(id)


# ---------- the old desktop app's save ----------
# The Electron app kept its save in Chromium's Local Storage (a LevelDB folder) under the same user folder.
# Its newest copy of each key sits in the .log file as plain text, so this looks for the JSON after each key.
func _import_old() -> void:
	var dir := "user://Local Storage/leveldb"
	if not DirAccess.dir_exists_absolute(dir):
		return
	var found := {}
	var files := DirAccess.get_files_at(dir)
	var order := []
	for f in files:
		if f.ends_with(".log") or f.ends_with(".ldb"):
			order.append(f)
	order.sort()
	for f in order:
		var bytes := FileAccess.get_file_as_bytes(dir + "/" + f)
		for key in ["riftguard-meta", "riftguard-settings", "riftguard-codex"]:
			var v = _scan(bytes, key)
			if v is Dictionary:
				found[key] = v
	if found.has("riftguard-meta"):
		var m: Dictionary = found["riftguard-meta"]
		_merge(meta, _snake_meta(m))
		imported = true
	if found.has("riftguard-settings"):
		var s: Dictionary = found["riftguard-settings"]
		for k in s:
			settings[_snake(k)] = s[k]
	if found.has("riftguard-codex"):
		codex = found["riftguard-codex"]
	if imported:
		_fill()
		save_meta()
		save_settings()
		save_codex()


func _scan(bytes: PackedByteArray, key: String):
	var needle := key.to_utf8_buffer()
	var best = null
	var i := 0
	var n := bytes.size()
	while i < n:
		var at := _find(bytes, needle, i)
		if at < 0:
			break
		i = at + needle.size()
		var j := i
		while j < mini(n, i + 12) and bytes[j] != 123: # {
			j += 1
		if j >= n or bytes[j] != 123:
			continue
		# Latin-1 text: read to the matching brace
		var depth := 0
		var in_str := false
		var esc := false
		var k := j
		while k < n:
			var b := bytes[k]
			if in_str:
				if esc:
					esc = false
				elif b == 92:
					esc = true
				elif b == 34:
					in_str = false
			elif b == 34:
				in_str = true
			elif b == 123:
				depth += 1
			elif b == 125:
				depth -= 1
				if depth == 0:
					break
			k += 1
		if k >= n:
			continue
		var text := bytes.slice(j, k + 1).get_string_from_ascii()
		var v = JSON.parse_string(text)
		if v is Dictionary:
			best = v
	return best


func _find(hay: PackedByteArray, needle: PackedByteArray, from: int) -> int:
	var n := hay.size() - needle.size()
	var first := needle[0]
	var i := from
	while i <= n:
		if hay[i] == first:
			var ok := true
			for k in range(1, needle.size()):
				if hay[i + k] != needle[k]:
					ok = false
					break
			if ok:
				return i
		i += 1
	return -1


func _snake(k: String) -> String:
	return k.to_snake_case()


# The old save used camelCase names at the top level (towerGlobal, heroStat, elStat, wizEls, wizLoad).
func _snake_meta(m: Dictionary) -> Dictionary:
	var out := {}
	for k in m:
		out[_snake(k)] = m[k]
	return out
