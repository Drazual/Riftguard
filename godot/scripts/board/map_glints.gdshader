// Hand-painted maps: packets of light running along the road's edge lines toward the portal.
// The texture holds the line strength in red and the distance along the road (0..1, 16 bit) in green/blue.
shader_type canvas_item;
render_mode blend_add;

uniform float period = 4.0;
uniform float packets = 8.0;
uniform vec3 tint = vec3(1.0, 0.47, 0.86);

void fragment() {
	vec3 t = texture(TEXTURE, UV).rgb;
	float s = (t.g * 255.0 * 256.0 + t.b * 255.0) / 65535.0;
	float pk = pow(clamp(cos(TAU * (s * packets - TIME / period)), 0.0, 1.0), 10.0);
	COLOR = vec4(tint * t.r * pk * 0.85, 1.0);
}
