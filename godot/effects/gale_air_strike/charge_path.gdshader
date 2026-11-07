shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, fog_disabled;
uniform float path_length = 10.0;
uniform float path_radius = 0.55;
uniform float clock = 0.0;
uniform float progress = 0.0;
uniform float blast_age = -1.0;
uniform float blast_duration = 0.7;
uniform float ripple_seconds = 0.0;
void vertex(){VERTEX.x*=path_radius;VERTEX.z*=path_length;}
void fragment(){
 float x=(UV.y-0.5)*2.0;
 float z=UV.x*path_length;
 float age=blast_age-ripple_seconds*UV.x;
 float endfade=smoothstep(0.0,0.025,UV.x)*(1.0-smoothstep(0.97,1.0,UV.x));
 float edge=pow(max(0.0,1.0-abs(x)),0.4);
 float borders=exp(-pow((abs(x)-0.86)/0.045,2.0));
 float strand=exp(-pow((x-0.54*sin(z*5.0-clock*8.0))/0.045,2.0));
 float dash=0.35+0.65*smoothstep(0.25,0.45,sin(z*12.0-clock*9.0));
 vec2 cell=vec2(x,(fract(z/1.15)-0.5)*2.0);
 float swirl=exp(-pow((length(cell)-0.64)/0.07,2.0))*(0.45+0.55*sin(atan(cell.y,cell.x)*2.0-clock*7.0+z));
 float charge=(0.13+0.10*progress)*edge + borders*0.8*dash + strand*0.5 + swirl*0.3;
 float flash=0.0;
 if(age>=0.0){flash=(1.0-smoothstep(0.08,blast_duration,age))*smoothstep(0.0,0.035,age);}
 vec3 cyan=vec3(0.025,0.47,0.66);
 vec3 white=vec3(0.65,0.97,1.0);
 ALBEDO=mix(cyan,white,flash*0.9);
 EMISSION=vec3(0.08,0.57,0.72)*charge*0.2 + white*flash*1.1;
 float alpha=(charge*(1.0-flash*0.3)+flash*edge*0.7)*endfade;
 if(blast_age>=0.0){alpha*=1.0-smoothstep(blast_duration*0.75+ripple_seconds,blast_duration+ripple_seconds,blast_age);}
 ALPHA=clamp(alpha,0.0,0.92);
}
