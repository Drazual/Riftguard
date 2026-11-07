shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, fog_disabled;
uniform vec4 tint : source_color = vec4(0.58,0.94,1.0,0.75);
uniform float strength = 1.0;
uniform float emission_gain = 0.6;
uniform float beam_length = 8.0;
uniform float beam_radius = 0.45;
uniform float clock = 0.0;
uniform float twist = 1.6;
uniform float phase = 0.0;
uniform float spin = -5.0;
uniform bool helix = true;
uniform bool longitudinal_fade = true;
uniform float shimmer = 0.15;
void vertex(){
    float a = phase + clock * spin;
    if(helix){ a += VERTEX.z * beam_length * twist * (0.46 / max(beam_radius,0.001)); }
    vec2 p = VERTEX.xy * beam_radius;
    VERTEX.xy = mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a))) * p;
    VERTEX.z *= beam_length;
}
void fragment(){
    float soft = pow(max(0.0, sin(UV.y * 3.14159265)), 0.65);
    float ends = 1.0;
    if(longitudinal_fade){ ends = smoothstep(0.0,0.025,UV.x) * (1.0-smoothstep(0.92,1.0,UV.x)); }
    float wave = 1.0-shimmer + shimmer * sin(UV.x*110.0-clock*23.0 + phase);
    ALBEDO = tint.rgb;
    EMISSION = tint.rgb * emission_gain;
    ALPHA = tint.a * strength * soft * ends * wave;
}
