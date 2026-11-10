import bpy, math, os
from mathutils import Vector
W="/workspace/riftguard/rift_beacon/work/"; P="/workspace/riftguard/rift_beacon/previews/frames/"
os.makedirs(P,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=W+"stage4_anim.blend")
exec(open("/workspace/riftguard/render_common.py").read())
sc=bpy.context.scene; setup_render(sc); sc.render.fps=60
# dim the ambient a bit so emission reads; add glare in compositor
sc.world.node_tree.nodes["Background"].inputs[1].default_value=0.6
sc.use_nodes=True; nt=sc.node_tree
rl=nt.nodes.get("Render Layers"); comp=nt.nodes.get("Composite")
gl=nt.nodes.new("CompositorNodeGlare"); gl.glare_type="FOG_GLOW"; gl.threshold=1.0; gl.size=7; gl.mix=0.0
nt.links.new(rl.outputs["Image"],gl.inputs["Image"]); nt.links.new(gl.outputs["Image"],comp.inputs["Image"])
REST={"Rotor":((1,1,1),(0,0,0)),"InnerPivot":((1,1,1),(0,0,0)),"CoreGlow":((1,1,1),(0,0,0)),"Crystal":((1,1,1),(0,0,0)),
      "PulseRing":((0.001,)*3,(0,0,0)),"BeamFlare":((0.001,)*3,(0,0,0)),"CoreFlash":((0.001,)*3,(0,0,0))}
def solo(name):
    for k,(s_,r_) in REST.items(): bpy.data.objects[k].scale=s_; bpy.data.objects[k].rotation_euler=r_
    for ob in bpy.data.objects:
        if ob.animation_data:
            for tr in ob.animation_data.nla_tracks: tr.mute = (tr.name!=name)
C=(0,0,0.95)
def shot(fn,d,t,clip,res=(480,480),samples=24,ortho=2.5):
    solo(clip); sc.frame_set(int(round(t*60)))
    shoot(sc,P,fn,C,d,res,ortho=ortho); 
import sys
mode=sys.argv[-1]
TQ=(1,-1.2,0.95)   # front-right, ~30-35 deg down (game-ish)
if mode=="sheet":
    for k,d in {"front":(0,-1,0.05),"tq":TQ,"side":(1,0,0.05),"back":(-0.8,1,0.6),"top":(0.001,-0.3,1)}.items():
        shot("s_%s.png"%k,d,0,"none")
    for t in [0.25,0.5,0.75,1.0]: shot("i_%.2f.png"%t,TQ,t,"idle")
    for t in [0.1,0.3,0.55]: shot("b_%.2f.png"%t,TQ,t,"buff_pulse")
    for t in [0.3,0.7]: shot("sp_%.2f.png"%t,TQ,t,"spawn")
elif mode=="gif":
    for i in range(24): shot("g_%02d.png"%i,TQ,4.0*i/24,"idle",res=(360,360))
    for i in range(10): shot("gb_%02d.png"%i,TQ,1.0*i/10,"buff_pulse",res=(360,360))
