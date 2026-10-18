## Runs the small bits of code stored in the data files (upgrade effects) and fills in description templates.
##
## Effect code: one statement per line (or separated by ";"). A statement is either an assignment such as
## `t.dmg *= 1.2` or `h.ab.stun += 0.1 * r` (=, +=, -=, *=, /=), or a call such as `run.crown()`.
## Description templates: text with {expressions} in braces, e.g. "+{pct(m)} hero damage."
## Both can use Godot's built-in functions (min, max, round, clamp...) and the helpers in FxLib below.
class_name Fx
extends RefCounted

static var _lib := FxLib.new()
static var _exprs := {}
static var _stmts := {}
static var _warned := {}


## Runs effect code. `inputs` maps names (t, h, run, m, r...) to values.
static func run(code: String, inputs: Dictionary) -> void:
	if code.strip_edges() == "":
		return
	var names: PackedStringArray = inputs.keys()
	var vals: Array = inputs.values()
	for st in _statements(code):
		if st.lhs == "":
			_eval(st.rhs, names, vals, code)
			continue
		var v = _eval(st.rhs, names, vals, code)
		if v == null:
			continue
		var dot: int = st.lhs.rfind(".")
		if dot < 0:
			_warn(code, "can't assign to '%s' (use t.%s, h.%s...)" % [st.lhs, st.lhs, st.lhs])
			continue
		var obj = _eval(st.lhs.substr(0, dot), names, vals, code)
		var prop: String = st.lhs.substr(dot + 1)
		if not (obj is Object):
			_warn(code, "'%s' is not an object" % st.lhs.substr(0, dot))
			continue
		var cur = obj.get(prop)
		if cur == null:
			_warn(code, "unknown property '%s'" % st.lhs)
			continue
		if typeof(cur) == TYPE_BOOL:
			v = bool(v)
		elif st.op != "=":
			match st.op:
				"+=": v = cur + v
				"-=": v = cur - v
				"*=": v = cur * v
				"/=": v = cur / v
		if typeof(cur) == TYPE_INT and typeof(v) == TYPE_FLOAT:
			v = int(round(v))
		obj.set(prop, v)


## Evaluates one expression and returns its value (or `fallback` if it fails).
static func value(expr: String, inputs: Dictionary, fallback = 0.0):
	var v = _eval(expr, PackedStringArray(inputs.keys()), inputs.values(), expr)
	return fallback if v == null else v


## Fills in a {template}.
static func text(template: String, inputs: Dictionary) -> String:
	if template.find("{") < 0:
		return template
	var names: PackedStringArray = inputs.keys()
	var vals: Array = inputs.values()
	var out := ""
	var i := 0
	while i < template.length():
		var a := template.find("{", i)
		if a < 0:
			out += template.substr(i)
			break
		var b := template.find("}", a)
		if b < 0:
			out += template.substr(i)
			break
		out += template.substr(i, a - i)
		var v = _eval(template.substr(a + 1, b - a - 1), names, vals, template)
		out += _lib.str_of(v)
		i = b + 1
	return out


static func _statements(code: String) -> Array:
	if _stmts.has(code):
		return _stmts[code]
	var out := []
	var re := RegEx.create_from_string("^([A-Za-z_][A-Za-z0-9_.]*)\\s*(\\+=|-=|\\*=|/=|=)(?!=)\\s*(.+)$")
	for line in code.replace(";", "\n").split("\n"):
		var s := line.strip_edges()
		if s == "" or s.begins_with("#"):
			continue
		var m := re.search(s)
		if m:
			out.append({ lhs = m.get_string(1), op = m.get_string(2), rhs = m.get_string(3) })
		else:
			out.append({ lhs = "", op = "", rhs = s })
	_stmts[code] = out
	return out


static func _eval(src: String, names: PackedStringArray, vals: Array, where: String):
	var key := src + "|" + ",".join(names)
	var e: Expression = _exprs.get(key)
	if e == null:
		e = Expression.new()
		if e.parse(src, names) != OK:
			_warn(where, "can't read '%s': %s" % [src, e.get_error_text()])
			return null
		_exprs[key] = e
	var v = e.execute(vals, _lib, false)
	if e.has_execute_failed():
		_warn(where, "'%s' failed: %s" % [src, e.get_error_text()])
		return null
	return v


static func _warn(where: String, msg: String) -> void:
	var k := where + msg
	if _warned.has(k):
		return
	_warned[k] = true
	push_warning("Riftguard data: %s  (in: %s)" % [msg, where.replace("\n", "; ")])
