## Updates the Windows game from GitHub releases, like the Electron build did.
## On launch it looks for the newest release tagged godot-v<version> with a Riftguard.exe file. If that version
## is newer than this one, it downloads it next to the running game, swaps the files and restarts.
## Offline, slow or failed checks just start the game. Only runs in an exported Windows build.
extends Node

const REPO := "Drazual/Riftguard"
const TAG_PREFIX := "godot-v"
const ASSET := "Riftguard.exe"
## Give up and just start the game if GitHub doesn't answer the check, or a download stalls, for this long.
const CHECK_TIMEOUT := 10.0
const STALL_TIMEOUT := 20.0

signal finished(installing: bool)

var state := "idle" # idle, checking, downloading, installing, current, failed, off
var latest := ""
var _http: HTTPRequest
var _wait := 0.0
var _last_bytes := 0
var _overlay: CanvasLayer
var _status: Label
var _bar: ProgressBar


func _ready() -> void:
	_clean_old()
	if OS.has_feature("windows") and OS.has_feature("template"):
		_remove_electron_install()
		_make_shortcuts()
	if not enabled():
		state = "off"
		return
	_show_overlay()
	_check.call_deferred()


func enabled() -> bool:
	return OS.has_feature("windows") and OS.has_feature("template") and not OS.has_feature("editor") \
		and OS.get_environment("RIFTGUARD_NO_UPDATE") == ""


func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


## "0.26.41" > "0.26.9": compares number by number.
static func newer(a: String, b: String) -> bool:
	var x := a.split(".")
	var y := b.split(".")
	for i in maxi(x.size(), y.size()):
		var p := int(x[i]) if i < x.size() else 0
		var q := int(y[i]) if i < y.size() else 0
		if p != q:
			return p > q
	return false


func exe_path() -> String:
	return OS.get_executable_path()


## The previous version is renamed out of the way during an update; remove it once the new one runs.
func _clean_old() -> void:
	if not OS.has_feature("template"):
		return
	var old := exe_path() + ".old"
	if FileAccess.file_exists(old):
		DirAccess.remove_absolute(old)


## The first time the game runs, add a desktop and a Start menu shortcut to this exe, so a player who just
## downloaded Riftguard.exe can find it again. Shortcuts that already exist (the installer makes them) are left alone,
## and one the player deletes later isn't put back.
func _make_shortcuts() -> void:
	if Save.settings.get("shortcuts_made", false):
		return
	Save.settings.shortcuts_made = true
	Save.save_settings()
	var exe := exe_path().replace("/", "\\").replace("'", "''")
	var ps := "$exe = '%s'; $sh = New-Object -ComObject WScript.Shell; " % exe \
		+ "foreach ($dir in [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs')) { " \
		+ "$lnk = Join-Path $dir 'Riftguard.lnk'; if ($dir -and -not (Test-Path $lnk)) { " \
		+ "$s = $sh.CreateShortcut($lnk); $s.TargetPath = $exe; $s.WorkingDirectory = Split-Path $exe; $s.Save() } }"
	var t := Thread.new()
	t.start(func():
		OS.execute("powershell", ["-NoProfile", "-NonInteractive", "-Command", ps])
		t.wait_to_finish.call_deferred())


## The old Electron version installed itself (Riftguard-x.y.z-setup.exe). The first time this version runs, find that
## install in the Windows uninstall list and run its uninstaller silently, so players only keep the new game.
## The Godot installer's own entry (Inno Setup, key ending _is1) is skipped.
## The old version's progress is in its own folder, which the uninstaller leaves alone.
func _remove_electron_install() -> void:
	if Save.settings.get("electron_removed", false):
		return
	var t := Thread.new()
	t.start(func():
		var ps := "$k = 'Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*'; " \
			+ "Get-ItemProperty ('HKCU:\\' + $k), ('HKLM:\\' + $k) -ErrorAction SilentlyContinue | " \
			+ "Where-Object { $_.DisplayName -like 'Riftguard*' -and $_.QuietUninstallString -and $_.PSChildName -notlike '*_is1' } | " \
			+ "ForEach-Object { $_.QuietUninstallString + '|' + $_.InstallLocation }"
		var out := []
		OS.execute("powershell", ["-NoProfile", "-NonInteractive", "-Command", ps], out)
		_run_uninstallers.call_deferred(str(out[0]) if out.size() else "")
		t.wait_to_finish.call_deferred())


func _run_uninstallers(found: String) -> void:
	var here := exe_path().get_base_dir().replace("/", "\\").to_lower()
	var re := RegEx.create_from_string('^"([^"]+)"\\s*(.*)$')
	var removed := false
	for line in found.split("\n", false):
		var parts := line.strip_edges().split("|")
		var where := parts[1].strip_edges().to_lower() if parts.size() > 1 else ""
		# never uninstall the folder this game is running from
		if where != "" and here.begins_with(where.trim_suffix("\\")):
			continue
		var m := re.search(parts[0].strip_edges())
		if m == null:
			continue
		var args := Array(m.get_string(2).split(" ", false))
		OS.create_process(m.get_string(1), args)
		removed = true
	Save.settings.electron_removed = true
	Save.save_settings()
	if removed:
		_new_engine_notice()


## Tells players who had the old version why their progress is gone. Waits for any other pop-up to close first.
func _new_engine_notice() -> void:
	while Ui.me == null or Ui.me.modal_open():
		await get_tree().create_timer(0.5).timeout
	var box := Ui.me.open_modal(560, Ui.me.close_modal)
	box.add_child(Kit.head("Welcome to the new Riftguard", 24))
	box.add_child(Kit.rich("Riftguard has moved to a new game engine, Godot. From now on the game updates itself "
		+ "whenever a new version comes out.\n\n"
		+ "The old version has been uninstalled. Your old progress couldn’t come across to the new engine, so "
		+ Kit.b("everything starts fresh") + ": Rift Shards, upgrades, mastery and unlocked maps. Sorry about that, "
		+ "and thanks for playing!", 15, Kit.MUTED))
	var row := Kit.hbox()
	row.add_child(Kit.go("GOT IT", Ui.me.close_modal))
	box.add_child(row)


func _check() -> void:
	state = "checking"
	_set_status("Checking for updates…", 0)
	_http = HTTPRequest.new()
	_http.timeout = CHECK_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_releases, CONNECT_ONE_SHOT)
	var err := _http.request("https://api.github.com/repos/%s/releases?per_page=30" % REPO,
		["User-Agent: Riftguard-Updater", "Accept: application/vnd.github+json"])
	if err != OK:
		_done(false, "failed")


func _on_releases(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_done(false, "failed")
		return
	var list = JSON.parse_string(body.get_string_from_utf8())
	if not (list is Array):
		_done(false, "failed")
		return
	var best := ""
	var url := ""
	for rel in list:
		if not (rel is Dictionary) or rel.get("draft", false) or rel.get("prerelease", false):
			continue
		var tag: String = str(rel.get("tag_name", ""))
		if not tag.begins_with(TAG_PREFIX):
			continue
		var v := tag.trim_prefix(TAG_PREFIX)
		if best != "" and not newer(v, best):
			continue
		for a in rel.get("assets", []):
			if a is Dictionary and a.get("name", "") == ASSET:
				best = v
				url = str(a.get("browser_download_url", ""))
	latest = best
	if best == "" or url == "" or not newer(best, version()):
		_done(false, "current")
		return
	_download(url, best)


func _download(url: String, v: String) -> void:
	state = "downloading"
	_set_status("Downloading update %s…" % v, 0)
	_http.queue_free()
	_http = HTTPRequest.new()
	_http.timeout = 0 # large file: the stall watchdog below handles hangs
	_http.download_file = exe_path() + ".new"
	add_child(_http)
	_http.request_completed.connect(_on_downloaded, CONNECT_ONE_SHOT)
	_wait = 0.0
	_last_bytes = 0
	if _http.request(url, ["User-Agent: Riftguard-Updater"]) != OK:
		_done(false, "failed")


func _process(dt: float) -> void:
	if state != "downloading" or _http == null:
		return
	var got := _http.get_downloaded_bytes()
	var total := _http.get_body_size()
	if got != _last_bytes:
		_last_bytes = got
		_wait = 0.0
		if total > 0:
			var pct := 100.0 * got / total
			_set_status("Downloading update… %d%%" % int(pct), pct)
	else:
		_wait += dt
		if _wait > STALL_TIMEOUT:
			_http.cancel_request()
			DirAccess.remove_absolute(exe_path() + ".new")
			_done(false, "failed")


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var exe := exe_path()
	var fresh := exe + ".new"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or FileAccess.get_size(fresh) < 1024 * 1024:
		DirAccess.remove_absolute(fresh)
		_done(false, "failed")
		return
	state = "installing"
	_set_status("Installing update…", 100)
	# Windows lets a running exe be renamed but not overwritten: move it aside, put the new one in its place.
	if DirAccess.rename_absolute(exe, exe + ".old") != OK:
		DirAccess.remove_absolute(fresh)
		_done(false, "failed")
		return
	if DirAccess.rename_absolute(fresh, exe) != OK:
		DirAccess.rename_absolute(exe + ".old", exe)
		_done(false, "failed")
		return
	finished.emit(true)
	OS.create_process(exe, OS.get_cmdline_args())
	get_tree().quit()


func _done(installing: bool, why: String) -> void:
	state = why
	if _http:
		_http.queue_free()
		_http = null
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	finished.emit(installing)


# ---------- the "checking for updates" splash over the menu ----------
func _show_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	var bg := ColorRect.new()
	bg.color = Color("#0b0f1c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	cc.add_child(v)
	var title := Label.new()
	title.text = "RIFTGUARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#8fd0ff"))
	v.add_child(title)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color("#9fb3d9"))
	v.add_child(_status)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(260, 6)
	_bar.show_percentage = false
	v.add_child(_bar)
	add_child(_overlay)


func _set_status(text: String, pct: float) -> void:
	if _status:
		_status.text = text
		_bar.value = pct


## A line for the main menu saying whether this copy is up to date. Null when there is nothing to say.
func status_control() -> Control:
	var text := ""
	match state:
		"current":
			text = "Up to date"
		"failed":
			text = "Couldn’t check for updates"
	if text == "":
		return null
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Kit.MUTED)
	return l
