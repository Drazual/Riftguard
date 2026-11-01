// Hand-painted maps: the soft neon glow, added over the board and breathing with the sign pulse.
shader_type canvas_item;
render_mode blend_add;

uniform float period = 4.0;
uniform float px_scale = 1.25;

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy * px_scale;
}

void fragment() {
	float puls = sin(TAU * TIME / period + TAU * (0.5 * wpos.x + wpos.y) / 1500.0);
	COLOR = vec4(texture(TEXTURE, UV).rgb * (0.42 + 0.16 * puls), 1.0);
}
