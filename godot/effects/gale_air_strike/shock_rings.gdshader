shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, fog_disabled;
uniform float path_radius=0.55;
uniform float clock=0.0;
uniform float blast_age=-1.0;
uniform float blast_duration=0.7;
uniform float ripple_seconds=0.0;
varying float local_age;
void vertex(){
 local_age=blast_age-ripple_seconds*INSTANCE_CUSTOM.y;
 float t=clamp(local_age/blast_duration,0.0,1.0);
 VERTEX.xz*=path_radius*(0.25+1.2*sqrt(t));
 VERTEX.y=0.025+sin(t*3.14159)*0.035;
}
void fragment(){
 float soft=pow(max(0.0,sin(UV.y*3.14159265)),0.7);
 float a=local_age>=0.0?(1.0-smoothstep(0.08,blast_duration,local_age)):0.0;
 ALBEDO=vec3(0.08,0.67,0.85);
 EMISSION=vec3(0.22,0.72,0.9)*0.3;
 ALPHA=soft*a*0.85;
}
