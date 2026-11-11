shader_type spatial;
// Shared stylized material for live 3D models (StyleRig.stylize): the model's own albedo, normal and emission
// textures, with banded light, one hard highlight, a rim, ambient shadows in the palette's navy/purple, and an
// adjustable pull of the colours toward the palette ramp. Saturated accents (neon trim) keep their hue.
//
// Optional accent masks (StyleRig.set_accents, docs/merge-art.md). With use_accent off and body_tint_strength 0
// the colour path below is unchanged. Mask RGB: R = zone 1 trim, G = zone 2 glow (also emission), B = zone 3 detail.
// A second mask (accent_mask_b) is the other parent's zones on a merge. Zone colours keep the pixel's shading;
// lighting, lift and the outline pass are untouched.
// cull_disabled: several hero meshes (Gale's shield) are authored double-sided.
render_mode cull_disabled, depth_draw_opaque, shadows_disabled; // models cast shadows but don't self-shadow (acne at this size)

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
uniform vec4 rim_color : source_color = vec4(0.4, 0.95, 1.0, 1.0);
uniform float rim = 1.1;
// black pixels are raised to this luminance (0 = the texture's own blacks). Bright pixels above it are unchanged.
uniform float lift = 0.38;
uniform float exposure = 1.0;
// nothing under this world height is drawn (a wall sinking into the ground); far below by default
uniform float clip_below = -1000.0;
// Path-colour zones. Off (and body_tint_strength 0) unless StyleRig.set_accents bound a mask or a merge tint.
uniform sampler2D accent_mask : filter_linear, repeat_enable;
uniform bool use_accent = false;
uniform vec4 accent1 : source_color = vec4(1.0);
uniform vec4 accent2 : source_color = vec4(1.0);
uniform vec4 accent3 : source_color = vec4(1.0);
uniform sampler2D accent_mask_b : filter_linear, repeat_enable;
uniform bool use_accent_b = false;
uniform vec4 accent1b : source_color = vec4(1.0);
uniform vec4 accent2b : source_color = vec4(1.0);
uniform vec4 accent3b : source_color = vec4(1.0);
uniform vec4 body_tint : source_color = vec4(1.0);
uniform float body_tint_strength = 0.0;
uniform float accent_glow = 1.6;
varying float world_y;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

// Recolour masked texels toward the zone colours, keeping a shade of the texel so the toon light still models it.
// Zone 2 (green) also adds emission. cover 0 leaves the pixel alone.
void apply_zone(vec3 mask, vec3 a1, vec3 a2, vec3 a3, inout vec3 col, inout vec3 glow) {
	float cover = clamp(max(mask.r, max(mask.g, mask.b)), 0.0, 1.0);
	if (cover <= 0.0) {
		return;
	}
	float w = max(mask.r + mask.g + mask.b, 0.001);
	vec3 tint = (mask.r * a1 + mask.g * a2 + mask.b * a3) / w;
	float shade = clamp(dot(col, LUMA) / 0.55, 0.35, 1.25);
	col = mix(col, tint * shade, cover);
	glow += a2 * mask.g * accent_glow * shade;
}

vec3 ramp(float l) {
	if (l < 0.33) return mix(pal_dark.rgb, pal_mid.rgb, l / 0.33);
	if (l < 0.72) return mix(pal_mid.rgb, pal_light.rgb, (l - 0.33) / 0.39);
	return mix(pal_light.rgb, pal_top.rgb, (l - 0.72) / 0.28);
}

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (world_y < clip_below) {
		discard;
	}
	vec2 uv = UV * uv_scale + uv_offset;
	vec4 c = albedo_color;
	if (use_albedo_tex) {
		c *= texture(albedo_tex, uv, simplify);
	}
	vec3 col = c.rgb;
	vec3 accent_emis = vec3(0.0);
	if (body_tint_strength > 0.001) {
		float shade = max(dot(col, LUMA), 0.28);
		col = mix(col, body_tint.rgb * shade, body_tint_strength);
	}
	if (use_accent) {
		apply_zone(texture(accent_mask, uv).rgb, accent1.rgb, accent2.rgb, accent3.rgb, col, accent_emis);
	}
	if (use_accent_b) {
		apply_zone(texture(accent_mask_b, uv).rgb, accent1b.rgb, accent2b.rgb, accent3b.rgb, col, accent_emis);
	}
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	// raise near-black armor to a readable navy before the palette tint; keep the pixel's own hue when it has one
	float l2 = mix(lift, l, smoothstep(0.0, max(lift, 0.001), l));
	vec3 hue = l > 0.004 ? col / l : pal_mid.rgb / max(dot(pal_mid.rgb, vec3(0.299, 0.587, 0.114)), 0.001);
	col = hue * l2;
	float mx = max(col.r, max(col.g, col.b));
	float mn = min(col.r, min(col.g, col.b));
	float sat = mx > 0.001 ? (mx - mn) / mx : 0.0;
	l = dot(col, vec3(0.299, 0.587, 0.114));
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
	if (use_accent || use_accent_b) {
		EMISSION += accent_emis;
	}
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
	// a hard rim on the silhouette (lit side included), so a dark body still has an edge on a dark road
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	DIFFUSE_LIGHT += rim_color.rgb * step(0.48, r) * rim * 0.28;
}
