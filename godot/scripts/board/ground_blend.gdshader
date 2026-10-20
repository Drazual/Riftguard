// The animated backdrop: a soft crossfade between two of its frames, so the motion glides instead of snapping.
shader_type canvas_item;

uniform sampler2D next_frame : filter_nearest;
uniform float blend = 0.0;

void fragment() {
	COLOR = mix(texture(TEXTURE, UV), texture(next_frame, UV), blend);
}
