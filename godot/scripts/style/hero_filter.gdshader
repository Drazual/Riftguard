shader_type canvas_item;
// The unified style's filter on a hero's picture (heroes keep their own clear, smooth render: Hero3D's viewport and
// studio light). It pulls dull colours toward the scenery palette's hues at their own brightness (navy and purple
// darks, peach and cream lights), keeps saturated accents, and draws a thin navy outline around the silhouette,
// so heroes sit in the painted scenery without losing their shape.
uniform float strength = 0.3;
uniform float keep_accents = 0.8;
uniform float outline = 1.0; // texels (one texel is one scenery pixel on the painted maps)
uniform vec4 outline_color : source_color = vec4(0.11, 0.07, 0.2, 1.0);
uniform vec4 pal_dark : source_color = vec4(0.10, 0.08, 0.22, 1.0);
uniform vec4 pal_mid : source_color = vec4(0.36, 0.24, 0.52, 1.0);
uniform vec4 pal_light : source_color = vec4(0.96, 0.70, 0.62, 1.0);
uniform vec4 pal_top : source_color = vec4(1.0, 0.94, 0.84, 1.0);

vec3 ramp(float l) {
	if (l < 0.33) return mix(pal_dark.rgb, pal_mid.rgb, l / 0.33);
	if (l < 0.72) return mix(pal_mid.rgb, pal_light.rgb, (l - 0.33) / 0.39);
	return mix(pal_light.rgb, pal_top.rgb, (l - 0.72) / 0.28);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.5 && outline > 0.0) {
		vec2 px = TEXTURE_PIXEL_SIZE * outline;
		float a = max(max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
			max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
		COLOR = a >= 0.5 ? outline_color * COLOR : c * COLOR;
	} else {
		vec3 col = c.rgb;
		float mx = max(col.r, max(col.g, col.b));
		float mn = min(col.r, min(col.g, col.b));
		float sat = mx > 0.001 ? (mx - mn) / mx : 0.0;
		float l = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 pal = ramp(clamp(l, 0.0, 1.0));
		pal *= l / max(dot(pal, vec3(0.299, 0.587, 0.114)), 0.01);
		float k = strength * (1.0 - keep_accents * smoothstep(0.35, 0.75, sat));
		COLOR = vec4(mix(col, pal, k), c.a) * COLOR;
	}
}
