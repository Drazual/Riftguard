shader_type spatial;
// The soft contact shadow under a model's feet (StyleRig.add_model).
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(0.1, 0.07, 0.2, 0.5);
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = color.rgb;
	ALPHA = color.a * (1.0 - smoothstep(0.55, 1.0, d));
}
