## Helper functions that data descriptions and effects can call, e.g. {pct(m)} or {f1(h.ab.stun)}.
class_name FxLib
extends RefCounted


## 0.2 -> "20%"
func pct(v: float) -> String:
	return str(int(round(v * 100))) + "%"


## Rounded whole number: 12.6 -> "13"
func f0(v: float) -> String:
	return str(int(round(v)))


## One decimal: 1.25 -> "1.3"
func f1(v: float) -> String:
	return "%.1f" % v


## Two decimals.
func f2(v: float) -> String:
	return "%.2f" % v


## One decimal without a trailing ".0": 2.5 -> "2.5", 5.0 -> "5"
func f1t(v: float) -> String:
	var s := "%.1f" % v
	return s.trim_suffix(".0")


## iff(condition, a, b): a when the condition holds, else b. (Data code has no "a if c else b".)
func iff(c, a, b):
	return a if c else b


## Veteran tier of a meta rank: 1-3 -> 1, 4-6 -> 2...
func vet(r: float) -> int:
	return int(floor((r + 2) / 3.0))


## "s" when n is not 1 (for plurals).
func s(n: float) -> String:
	return "" if int(round(n)) == 1 else "s"


func str_of(v) -> String:
	if v == null:
		return "?"
	if typeof(v) == TYPE_FLOAT:
		return str(int(v)) if v == floorf(v) and absf(v) < 1e9 else str(snappedf(v, 0.01))
	return str(v)
