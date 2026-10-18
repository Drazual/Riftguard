## The same small hashes the original game used to scatter tiles, props and road specks, so maps look identical.
class_name Hash32
extends RefCounted


static func i32(x: int) -> int:
	x &= 0xFFFFFFFF
	return x - 0x100000000 if x >= 0x80000000 else x


static func u32(x: int) -> int:
	return x & 0xFFFFFFFF


## 0..1 from a cell and a salt.
static func cell(c: int, r: int, i: int) -> float:
	var v := i32(i32(c * 73856093) ^ i32(r * 19349663) ^ i32(i * 83492791))
	v = i32(i32(v ^ (u32(v) >> 13)) * 1274126177)
	return float(u32(v ^ (u32(v) >> 16))) / 4294967296.0


## The board-edge variant (multiplies in floating point, like the original).
static func edge(c: int, r: int, i: int) -> float:
	var v := i32(i32(c * 73856093) ^ i32(r * 19349663) ^ i32(i * 83492791))
	var p := float(i32(v ^ (u32(v) >> 13))) * 1274126177.0
	var w := i32(int(p))
	return float(u32(w ^ (u32(w) >> 16))) / 4294967296.0


## FNV-1a of a string (picks hybrid paths).
static func text(s: String) -> int:
	var h := 2166136261
	for ch in s.to_utf8_buffer():
		h = u32((h ^ ch) * 16777619)
	return h
