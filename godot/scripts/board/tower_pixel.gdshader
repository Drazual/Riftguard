// Draws a tower at the board's base pixel size (one pixel per 768x416 board pixel), the chunky look towers have on
// the 1x tile maps, even on a hi-res board: every block x block screen block shows one sample, taken at its middle.
shader_type canvas_item;

uniform float block = 1.0;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 mid = (floor(FRAGCOORD.xy / block) + 0.5) * block;
	vec2 per_px = vec2(dFdx(UV.x), dFdy(UV.y));
	COLOR = texture(TEXTURE, UV + (mid - FRAGCOORD.xy) * per_px) * tint;
}
