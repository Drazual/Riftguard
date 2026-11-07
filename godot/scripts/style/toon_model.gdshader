shader_type spatial;
// Shared stylized material for live 3D models (StyleWorld.stylize): the model's own albedo, normal and emission
// textures, with banded light, one hard highlight, a rim, ambient shadows in the palette's navy/purple, and an
// adjustable pull of the colours toward the palette ramp. Saturated accents (neon trim) keep their hue.
render_mode cull_back, depth_draw_opaque, shadows_disabled; // models cast shadows but don't self-shadow (acne at this size)

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_albedo_tex = false;
uniform float alpha_scissor = 0.0;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal = false;
uniform float normal_detail = 0.3;
uniform sampler2D emission_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_emission_tex = false;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
// simplified surfaces: the textures are read this many mip levels blurrier (fine detail is noise at a few cm a pixel)
uniform float simplify = 1.5;

uniform float palette_strength = 0.35;
uniform float keep_accents = 0.8;
uniform vec4 pal_dark : source_color = vec4(0.10, 0.08, 0.22, 1.0);
uniform vec4 pal_mid : source_color = vec4(0.36, 0.24, 0.52, 1.0);
uniform vec4 pal_light : source_color = vec4(0.96, 0.70, 0.62, 1.0);
uniform vec4 pal_top : source_color = vec4(1.0, 0.94, 0.84, 1.0);
uniform float band_edge = 0.05;
uniform float band_soft = 0.06;
uniform float highlight = 0.35;
uniform float highlight_size = 0.25;
uniform vec4 rim_color : source_color = vec4(1.0, 0.45, 0.85, 1.0);
uniform float rim = 0.35;
uniform float exposure = 1.0;

vec3 ramp(float l) {
	if (l < 0.33) return mix(pal_dark.rgb, pal_mid.rgb, l / 0.33);
	if (l < 0.72) return mix(pal_mid.rgb, pal_light.rgb, (l - 0.33) / 0.39);
	return mix(pal_light.rgb, pal_top.rgb, (l - 0.72) / 0.28);
}

void fragment() {
	vec2 uv = UV * uv_scale + uv_offset;
	vec4 c = albedo_color;
	if (use_albedo_tex) {
		c *= texture(albedo_tex, uv, simplify);
	}
	vec3 col = c.rgb;
	float mx = max(col.r, max(col.g, col.b));
	float mn = min(col.r, min(col.g, col.b));
	float sat = mx > 0.001 ? (mx - mn) / mx : 0.0;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	// the palette pull: greys and dull colours take the ramp's hue for their brightness (navy/purple darks, peach/cream
	// lights) at their own brightness, so values and silhouettes stay as modelled; neon accents keep their own hue
	vec3 pal = ramp(clamp(l, 0.0, 1.0));
	pal *= l / max(dot(pal, vec3(0.299, 0.587, 0.114)), 0.01);
	float k = palette_strength * (1.0 - keep_accents * smoothstep(0.35, 0.75, sat));
	ALBEDO = mix(col, pal, k) * exposure;
	if (alpha_scissor > 0.0) {
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	}
	if (use_normal) {
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), texture(normal_tex, uv, simplify).rgb, normal_detail);
	}
	vec3 e = emission_color.rgb * emission_energy;
	if (use_emission_tex) {
		e *= texture(emission_tex, uv).rgb;
	}
	EMISSION = e;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(band_edge - band_soft, band_edge + band_soft, ndl) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit;
	vec3 h = normalize(LIGHT + VIEW);
	float s = pow(max(dot(NORMAL, h), 0.0), mix(160.0, 12.0, highlight_size));
	SPECULAR_LIGHT += LIGHT_COLOR * step(0.5, s) * highlight * lit;
	// rim on the side turned away from the key, so a dark model still has an edge against a dark road
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * (1.0 - lit);
	DIFFUSE_LIGHT += rim_color.rgb * step(0.45, r) * rim;
}
