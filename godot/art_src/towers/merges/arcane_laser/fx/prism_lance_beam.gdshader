// Prism Lance beam: drawn on a unit quad stretched from the Muzzle to the target (UV.x along, UV.y across).
// heat 0..1: laser cyan (cold) -> recipe pink #FF6FA0 -> hot arcane magenta with a white core; wider, brighter,
// more flicker and faster flow as it heats. Flicker steps at 16 fps like the base Prism Laser's beam sprite.
// Works on the Compatibility renderer.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float t = 0.0;            // the beam's own clock (set by the script, so it keeps game time)
uniform float length_px = 100.0;  // the quad's length in pixels
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform vec4 cold_edge : source_color = vec4(0.25, 0.86, 1.0, 1.0);  // Prism Laser cyan
uniform vec4 warm_edge : source_color = vec4(1.0, 0.435, 0.627, 1.0); // Prism Lance #FF6FA0
uniform vec4 hot_edge : source_color = vec4(1.0, 0.16, 0.72, 1.0);    // arcane magenta
uniform vec4 cold_core : source_color = vec4(0.80, 1.0, 1.0, 1.0);
uniform vec4 hot_core : source_color = vec4(1.0, 0.96, 1.0, 1.0);

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	float x = UV.x * length_px;
	float y = (UV.y - 0.5) * 2.0;
	float fr = floor(t * 16.0);
	float fl = 1.0 + (0.05 + 0.15 * heat) * (hash(fr) - 0.5) * 2.0;
	float wob = 0.05 * heat * sin(x * 0.16 - t * 38.0);
	float dd = abs(y - wob);
	float core_w = (0.11 + 0.05 * heat) * fl;
	float core = smoothstep(core_w, core_w * 0.3, dd);
	float mid_w = (0.30 + 0.10 * heat) * fl;
	float mid = smoothstep(mid_w, 0.0, dd);
	float glow = exp(-dd * dd * (8.0 - 3.0 * heat)) * (0.40 + 0.35 * heat);
	float flow = 0.5 + 0.5 * sin(x * 0.13 - t * (16.0 + 24.0 * heat));
	mid *= 0.7 + 0.3 * flow;
	vec2 cell = vec2(floor(x / 3.0), fr);
	float sp = step(0.95 - 0.10 * heat, hash2(cell)) * smoothstep(0.08, 0.0, abs(dd - (0.28 + 0.22 * hash2(cell + 3.1))));
	vec3 edge = heat < 0.5 ? mix(cold_edge.rgb, warm_edge.rgb, heat * 2.0) : mix(warm_edge.rgb, hot_edge.rgb, heat * 2.0 - 1.0);
	vec3 core_c = mix(cold_core.rgb, hot_core.rgb, heat);
	float bright = 0.85 + 0.65 * heat;
	vec3 c = edge * glow * bright + edge * mid * 0.85 * bright + core_c * core * (1.0 + 0.6 * heat) + mix(edge, vec3(1.0), 0.35) * sp * (0.6 + 0.4 * heat);
	float ends = smoothstep(0.0, 5.0, x) * smoothstep(0.0, 3.0, length_px - x);
	COLOR = vec4(c, fade * ends);
}
