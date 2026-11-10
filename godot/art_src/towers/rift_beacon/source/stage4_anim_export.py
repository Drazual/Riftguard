import bpy, math
W="/workspace/riftguard/rift_beacon/work/"
bpy.ops.wm.open_mainfile(filepath=W+"stage3_rig.blend")
sc=bpy.context.scene; FPS=60; sc.render.fps=FPS
O=bpy.data.objects
def keys(obj,path,frames,anim,interp="LINEAR"):
    """frames: list of (t_seconds, value tuple/float, index or None)"""
    act=bpy.data.actions.new(f"{anim}_{obj.name}_{path}")
    return act
tracks={}  # (obj)->{anim:[(path,idx,[(t,v)],interp)]}
def add(obj,anim,path,idx,pts,interp="LINEAR"):
    tracks.setdefault(obj,{}).setdefault(anim,[]).append((path,idx,pts,interp))
TAU=2*math.pi
IDLE=4.0
# ---- idle (loop): rotor 1 rev / 4 s about vertical; inner 2 rev / 4 s about horizontal X; core breath x2
add("Rotor","idle","rotation_euler",2,[(0,0),(IDLE,TAU)])
add("InnerPivot","idle","rotation_euler",0,[(0,0),(IDLE,2*TAU)])
n=16
for i in range(3):
    add("CoreGlow","idle","scale",i,[(IDLE*k/n,1.0+0.12*0.5*(1-math.cos(2*TAU*k/n))) for k in range(n+1)],"BEZIER")
# ---- buff_pulse (1.0 s, one-shot, FX only, no ring rotation tracks)
BP=1.0
def ease_out(t): return 1-(1-t)**3
pts=[(0,0.001),(0.02,0.25)]+[(0.02+0.78*k/10,0.25+1.0*ease_out(k/10)) for k in range(1,11)]+[(0.84,0.001),(BP,0.001)]
for i in (0,1): add("PulseRing","buff_pulse","scale",i,pts)
add("PulseRing","buff_pulse","scale",2,[(0,0.001),(0.02,1),(0.84,1),(0.86,0.001),(BP,0.001)])
for i in range(3): add("CoreFlash","buff_pulse","scale",i,[(0,0.001),(0.08,1.0),(0.25,1.25),(0.6,0.5),(0.75,0.001),(BP,0.001)])
for i in (0,1): add("BeamFlare","buff_pulse","scale",i,[(0,0.001),(0.06,1.3),(0.35,0.8),(0.65,0.25),(0.7,0.001),(BP,0.001)])
add("BeamFlare","buff_pulse","scale",2,[(0,0.001),(0.06,0.6),(0.2,1.0),(0.65,1.0),(0.7,0.001),(BP,0.001)])
for i in range(3): add("Crystal","buff_pulse","scale",i,[(0,1.0),(0.1,1.18),(0.45,1.0),(BP,1.0)],"BEZIER")
# ---- spawn (1.2 s, one-shot): rings spin up into the idle start pose, grow in; core lights up
SP=1.2
k=12
def eob(t):  # ease out back
    c1=1.70158; c3=c1+1; return 1+c3*(t-1)**3+c1*(t-1)**2
for i in range(3): add("Rotor","spawn","scale",i,[(SP*j/k,max(0.02,eob(j/k))) for j in range(k+1)])
add("Rotor","spawn","rotation_euler",2,[(SP*j/k,-1.5*TAU*(1-ease_out(j/k))) for j in range(k+1)])
add("InnerPivot","spawn","rotation_euler",0,[(SP*j/k,-TAU*(1-ease_out(j/k))) for j in range(k+1)])
for i in range(3): add("CoreGlow","spawn","scale",i,[(0,0.001),(0.6,0.001),(1.0,1.15),(SP,1.0)])
# build actions + NLA
for objn,anims in tracks.items():
    ob=O[objn]; ob.animation_data_create()
    for anim,lst in anims.items():
        act=bpy.data.actions.new(f"{anim}__{objn}")
        for path,idx,pts,interp in lst:
            fc=act.fcurves.new(path,index=idx)
            fc.keyframe_points.add(len(pts))
            for kp,(t,v) in zip(fc.keyframe_points,pts):
                kp.co=(t*FPS,v); kp.interpolation=interp
            fc.update()
        tr=ob.animation_data.nla_tracks.new(); tr.name=anim
        st=tr.strips.new(anim,0,act); st.action_frame_end=max(p[0] for l in lst for p in l[2])*FPS
    ob.animation_data.action=None
for ob in O:
    if ob.animation_data:
        for tr in ob.animation_data.nla_tracks: tr.mute=True
for nm in ["Rotor","InnerPivot","CoreGlow","Crystal"]: O[nm].scale=(1,1,1); O[nm].rotation_euler=(0,0,0)
for nm in ["PulseRing","BeamFlare","CoreFlash"]: O[nm].scale=(0.001,)*3
sc.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=W+"stage4_anim.blend")
out="/workspace/riftguard/rift_beacon/final/rift_beacon.glb"
bpy.ops.export_scene.gltf(filepath=out,export_format="GLB",export_animation_mode="NLA_TRACKS",
    export_force_sampling=True,export_frame_step=1,export_optimize_animation_size=False,export_anim_slide_to_zero=True,
    export_yup=True,export_apply=False,export_image_format="AUTO",export_cameras=False,export_lights=False,
    export_extras=False,use_selection=False,export_tangents=False,export_reset_pose_bones=True)
print("exported")
