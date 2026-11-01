// Hand-painted map sprites: a slow neon pulse on the bright sign colours, a gentle sway for palms, a
// per-pad pulse for build pads and a swirl in the portal ring. Runs on real time, so it keeps moving in pause.
shader_type canvas_item;

uniform float period = 4.0;
uniform float pad_phase = -1.0; // 0..1 for a build pad, which pulses on its own beat
uniform float sway = 0.0; // palm sway: horizontal shear per pixel of height
uniform float sway_phase = 0.0;
uniform vec2 ring = vec2(-1.0); // portal ring centre in texture pixels
uniform vec2 ring_r = vec2(70.0, 66.67); // ring half-width and half-height in mockup pixels (an upright oval for a portal seen side-on)
uniform float px_scale = 1.25; // mockup pixels per board pixel, so the motion matches the mockup

varying vec2 wpos;

void vertex() {
	if (sway > 0.0) {
		VERTEX.x += sway * sin(TAU * (TIME / period + sway_phase)) * (-VERTEX.y);
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy * px_scale;
}

// how much a pixel is lit neon: bright, saturated pink, cyan or violet
float emissive(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	bool hue = (c.r > c.g + 0.15 && c.b > c.g + 0.10) || (c.b > c.r + 0.10 && c.g > c.r) || (c.b > c.r + 0.15 && c.b > c.g + 0.05);
	return hue ? clamp((mx - 0.72) / 0.2, 0.0, 1.0) * clamp((sat - 0.40) / 0.2, 0.0, 1.0) : 0.0;
}

void fragment() {
	vec4 c = COLOR;
	float e = emissive(c.rgb);
	float w = TAU * TIME / period;
	if (pad_phase >= 0.0) {
		c.rgb *= 1.0 + 0.16 * e * sin(w - TAU * pad_phase);
	} else {
		c.rgb *= 1.0 + 0.10 * e * sin(w + TAU * (0.5 * wpos.x + wpos.y) / 1500.0);
	}
	if (ring.x >= 0.0) {
		vec2 d = (UV / TEXTURE_PIXEL_SIZE - ring) * px_scale / ring_r * 70.0;
		float r = length(d);
		if (r < 70.0) {
			float sw = 0.5 + 0.5 * sin(3.0 * atan(d.y, d.x) - w - r / 9.0);
			c.rgb = c.rgb * (1.0 + 0.35 * e * (sw - 0.5)) + e * sw * vec3(60.0, 10.0, 50.0) / 255.0;
		}
	}
	COLOR = c;
}
