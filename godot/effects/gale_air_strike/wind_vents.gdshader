shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, fog_disabled;
uniform float path_radius=0.55;
uniform float vent_height=1.2;
uniform float clock=0.0;
uniform float blast_age=-1.0;
uniform float blast_duration=0.7;
uniform float ripple_seconds=0.0;
varying vec4 instance_info;
varying float local_age;
void vertex(){
 instance_info=INSTANCE_CUSTOM;
 local_age=blast_age-ripple_seconds*INSTANCE_CUSTOM.y;
 float grow=local_age>=0.0?smoothstep(0.0,0.20,local_age):0.0;
 float a=INSTANCE_CUSTOM.x*6.2831853+clock*(local_age>=0.0?8.0:3.0)+VERTEX.y*5.2;
 vec2 p=VERTEX.xz*path_radius*(0.28+grow*0.95);
 VERTEX.xz=mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)))*p;
 VERTEX.y*=vent_height*(local_age>=0.0?(0.2+grow*0.8):0.13);
}
void fragment(){
 float width=pow(max(0.0,sin(UV.y*3.14159265)),0.8);
 float tip=pow(max(0.0,1.0-UV.x),0.7)*smoothstep(0.0,0.08,UV.x);
 float burst=local_age>=0.0?(1.0-smoothstep(0.15,blast_duration,local_age)):0.13;
 ALBEDO=mix(vec3(0.03,0.55,0.75),vec3(0.72,0.97,1.0),max(burst,0.0));
 EMISSION=vec3(0.35,0.88,1.0)*max(burst,0.0)*1.0;
 ALPHA=width*tip*max(burst,0.0);
}
