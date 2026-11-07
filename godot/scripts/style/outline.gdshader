shader_type spatial;
// Inverted-hull outline for live 3D models (StyleWorld): the back faces pushed out along the normals by `width`
// metres (StyleWorld sets it from whole render pixels), flat colour. The hull is also pushed `behind` metres away
// from the camera, so it only shows around the silhouette, never through the model's own thin parts (at a few
// centimetres a pixel those would speckle the body).
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 color : source_color = vec4(0.11, 0.07, 0.2, 1.0);
uniform float width = 0.03;
uniform float behind = 0.25;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 v = VERTEX + NORMAL * width / max(s, 0.0001);
	vec4 view = MODELVIEW_MATRIX * vec4(v, 1.0);
	view.z -= behind;
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	ALBEDO = color.rgb;
}
