// Rift Beacon aura ring: ground decal that shows the buff radius.
// Put it on a PlaneMesh of size (2*radius, 2*radius) lying flat (PlaneMesh is XZ, faces +Y).
// Idle: soft fill + bright edge + slow outward ripples. pulse_t 0->1 (tweened by script) sends one bright wave out.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 edge_color : source_color = vec4(0.37, 0.94, 1.0, 1.0);   // cyan #5ff0ff
uniform vec4 fill_color : source_color = vec4(0.85, 0.25, 0.85, 1.0);  // magenta
uniform float edge_width = 0.035;      // fraction of radius
uniform float edge_strength = 1.2;
uniform float fill_alpha = 0.10;
uniform float ripple_count = 3.0;
uniform float ripple_speed = 0.25;     // ripples per second travelling outward
uniform float ripple_strength = 0.25;
uniform float pulse_t = -1.0;          // <0 = no pulse; 0..1 = wave position (0 centre, 1 edge)
uniform float pulse_strength = 1.6;
uniform float pulse_width = 0.08;
uniform float intensity = 1.0;         // master fade (e.g. 0 when tower not selected/active)

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;           // 0 centre .. 1 edge
	if (d > 1.0) discard;
	float edge = smoothstep(1.0 - edge_width * 2.5, 1.0 - edge_width * 0.5, d) * (1.0 - smoothstep(0.985, 1.0, d));
	float fill = fill_alpha * smoothstep(0.0, 1.0, d);
	float rp = fract(d * ripple_count - TIME * ripple_speed * ripple_count);
	float ripple = smoothstep(0.0, 0.08, rp) * (1.0 - smoothstep(0.08, 0.22, rp)) * ripple_strength * d;
	float pulse = 0.0;
	if (pulse_t >= 0.0) {
		pulse = (1.0 - smoothstep(0.0, pulse_width, abs(d - pulse_t))) * (1.0 - pulse_t * 0.6) * pulse_strength;
	}
	vec3 col = edge_color.rgb * (edge * edge_strength + ripple + pulse) + fill_color.rgb * fill;
	ALBEDO = col * intensity;
}
