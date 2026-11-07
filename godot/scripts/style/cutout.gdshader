shader_type spatial;
// A "cut-out" (StyleRig.add_cutout): an upright plane standing where a 2D sprite drawn UNDER the 3D layer stands
// (a building, an enemy, a baked tower). Drawn last, it multiplies the 3D layer's colour and alpha by zero wherever
// it is nearer the camera than the model there, so the sprite underneath shows through: the board's y-sort, per
// pixel. It writes no depth and casts no shadow. Its shape is the sprite's alpha, or a disc with no texture.
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D tex : filter_nearest;
uniform bool use_tex = false; // else a disc
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
	float a;
	if (use_tex) {
		a = texture(tex, region.xy + UV * region.zw).a;
	} else {
		a = length(UV - vec2(0.5)) < 0.5 ? 1.0 : 0.0;
	}
	if (a < 0.5) {
		discard;
	}
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
