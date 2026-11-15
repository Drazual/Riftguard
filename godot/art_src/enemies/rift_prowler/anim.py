# Rift Prowler: keys every clip (idle, walk, slowed, hit, stun, frozen, knockback, attack, death) on the rigged
# .blend from rig.py and exports the game GLB. Rotations are written about world axes (see clip()). See README.md.
import bpy, sys, math, mathutils
from mathutils import Matrix, Quaternion, Euler, Vector
args=sys.argv[sys.argv.index('--')+1:]
blend, out = args[0], args[1]
bpy.ops.wm.open_mainfile(filepath=blend)
ao=bpy.data.objects["Armature"]; ob=bpy.data.objects["Prowler"]
FPS=30; bpy.context.scene.render.fps=FPS
ao.animation_data_create()
REST={b.name: b.matrix_local.to_quaternion() for b in ao.data.bones}
def S(x): return math.sin(2*math.pi*x)
def C(x): return math.cos(2*math.pi*x)

def world_q(e):
    return Euler((math.radians(e[0]),math.radians(e[1]),math.radians(e[2])),'XYZ').to_quaternion()

def clip(name, length, keys, loop=True):
    """keys: list of (t, {bone:(rx,ry,rz) world degrees}, hips_offset (x,y,z) world)"""
    act=bpy.data.actions.new(name); ao.animation_data.action=act
    bones=set(); [bones.update(k[1].keys()) for k in keys]
    bones.add("Hips")
    for t,pose,hip in keys:
        f=1+round(t*FPS)
        for pb in ao.pose.bones:
            if pb.name not in bones: continue
            e=pose.get(pb.name,(0,0,0))
            B=REST[pb.name]
            pb.rotation_mode='QUATERNION'
            pb.rotation_quaternion=B.inverted()@world_q(e)@B
            pb.keyframe_insert("rotation_quaternion",frame=f)
            if pb.name=="Hips":
                pb.location=B.inverted()@Vector(hip)
                pb.keyframe_insert("location",frame=f)
    if loop:  # close the loop with the first key
        t,pose,hip=keys[0]; keys2=[(length,pose,hip)]
        f=1+round(length*FPS)
        for pb in ao.pose.bones:
            if pb.name not in bones: continue
            e=pose.get(pb.name,(0,0,0)); B=REST[pb.name]
            pb.rotation_quaternion=B.inverted()@world_q(e)@B; pb.keyframe_insert("rotation_quaternion",frame=f)
            if pb.name=="Hips": pb.location=B.inverted()@Vector(hip); pb.keyframe_insert("location",frame=f)
    act.use_fake_user=True
    tr=ao.animation_data.nla_tracks.new(); tr.name=name
    tr.strips.new(name,1,act); tr.mute=True
    ao.animation_data.action=None
    for pb in ao.pose.bones:
        pb.rotation_quaternion=(1,0,0,0); pb.location=(0,0,0)

def add(a,b):
    out=dict(a)
    for k,v in b.items():
        o=out.get(k,(0,0,0)); out[k]=(o[0]+v[0],o[1]+v[1],o[2]+v[2])
    return out

# A-pose arms come in a little toward the body: rotate about world Y (left arm +x side: negative Y brings it down)
def stance(crouch=1.0, arms_in=14):
    return {
        "LeftArm":(0,-arms_in,0),"RightArm":(0,arms_in,0),
        "LeftForeArm":(-25,0,0),"RightForeArm":(-25,0,0),
        "LeftUpLeg":(-14*crouch,0,0),"RightUpLeg":(-14*crouch,0,0),
        "LeftLeg":(26*crouch,0,0),"RightLeg":(26*crouch,0,0),
        "LeftFoot":(-12*crouch,0,0),"RightFoot":(-12*crouch,0,0),
        "Spine":(8*crouch,0,0),"Neck":(-4,0,0),"Head":(-6*crouch,0,0),
    }
CROUCH_DROP=-0.035

def tail(phase, amp=10, droop=0):
    # a travelling wave down the tail: each segment swings a little later than the one before it
    d={}
    for i,n in enumerate(["Tail","Tail1","Tail2","Tail3","Tail4"]):
        d[n]=(droop*(1 if i<2 else 0.5), 0, amp*(0.5+0.25*i)*S(phase-0.12*i))
    return d

# ---------- idle: ready crouch, breathing, tail swishing ----------
keys=[]; L=2.0; n=16
for i in range(n):
    x=i/n
    p=add(stance(), tail(x,9))
    p=add(p,{"Spine1":(2*S(x),0,0),"Spine2":(2*S(x),0,0),"Head":(-2*S(x+0.1),3*S(x*0.5),0),
             "LeftArm":(2*S(x+0.2),0,0),"RightArm":(2*S(x+0.25),0,0),
             "LeftHand":(0,0,0),"LeftForeArm":(-3*S(x),0,0),"RightForeArm":(-3*S(x),0,0)})
    keys.append((L*x,p,(0,0,CROUCH_DROP-0.008*S(x))))
clip("idle",L,keys)

# ---------- walk: a prowling stride, in place ----------
def walk(L, n, lean, stride, knee_lift, arm_swing, bob, slump=0, shiver=0, tail_amp=12):
    ks=[]
    for i in range(n):
        x=i/n; f=2*math.pi*x
        p=stance(1.0)
        for side,ph,sg in (("Left",f,1),("Right",f+math.pi,-1)):
            thigh=-stride*math.sin(ph)-12
            knee=24+knee_lift*max(0.0,math.cos(ph))**1.5
            foot=-0.55*(thigh+knee)+12*max(0.0,-math.cos(ph))
            p[side+"UpLeg"]=(thigh,0,0); p[side+"Leg"]=(knee,0,0); p[side+"Foot"]=(foot,0,0)
            p[side+"ToeBase"]=(-10*max(0.0,-math.sin(ph)),0,0)
            # arms swing against the legs on the same side
            arm=(arm_swing*math.sin(ph))
            p[side+"Arm"]=(arm, -sg*14+sg*slump*0.4, 0)
            p[side+"ForeArm"]=(-30-0.5*abs(arm)-slump, 0, 0)
        s=math.sin(f)
        p["Spine"]=(lean,0,6*s); p["Spine1"]=(4+slump*0.5,0,0); p["Spine2"]=(slump*0.3,3*s,0)
        p["Neck"]=(-lean*0.6,0,0); p["Head"]=(-lean*0.5+slump*0.6,0,-5*s)
        p["Hips"]=(0,3*s,-7*s)
        if shiver:
            j=shiver*math.sin(f*7.0)
            p["Spine2"]=(p["Spine2"][0],p["Spine2"][1]+j,0); p["Head"]=(p["Head"][0]+j,p["Head"][1],j)
        p=add(p,tail(x,tail_amp,droop=slump*0.4))
        ks.append((L*x,p,(0,0,CROUCH_DROP-0.02-bob*abs(math.cos(f)))))
    return ks
clip("walk",0.8,walk(0.8,16,lean=16,stride=34,knee_lift=70,arm_swing=26,bob=0.03))

# ---------- slowed: frost-heavy, hunched, short dragging steps, shivering ----------
clip("slowed",1.5,walk(1.5,24,lean=26,stride=16,knee_lift=30,arm_swing=8,bob=0.012,slump=22,shiver=2.5,tail_amp=4))

# ---------- hit: a sharp flinch back, then settles into the stance ----------
base=add(stance(),tail(0,0))
flinch=add(base,{"Spine":(-14,0,0),"Spine1":(-8,0,0),"Spine2":(-6,4,0),"Neck":(-10,0,0),"Head":(-14,0,8),
                 "LeftArm":(-18,-10,0),"RightArm":(-18,10,0),"LeftForeArm":(-30,0,0),"RightForeArm":(-30,0,0),
                 "Tail":(-15,0,0),"Tail1":(-10,0,0)})
clip("hit",0.4,[(0,base,(0,0,CROUCH_DROP)),(0.07,flinch,(0,0.03,CROUCH_DROP-0.01)),(0.4,base,(0,0,CROUCH_DROP))],loop=False)

# ---------- stunned: dazed, head lolling in circles, arms hanging, wobbling on bent knees ----------
keys=[]; L=1.4; n=16
for i in range(n):
    x=i/n
    p=stance(1.6, arms_in=22)
    p=add(p,{"Spine":(10,6*S(x),0),"Spine1":(8,0,0),"Spine2":(6,4*S(x),0),
             "Neck":(18+6*C(x),10*S(x),0),"Head":(14+8*C(x),14*S(x),8*S(x)),
             "LeftArm":(4,8,0),"RightArm":(4,-8,0),"LeftForeArm":(10,0,0),"RightForeArm":(10,0,0),
             "LeftHand":(15,0,0),"RightHand":(15,0,0),
             "Hips":(0,5*S(x),0)})
    p=add(p,tail(x,4,droop=22))
    keys.append((L*x,p,(0.025*S(x),0.015*C(x),CROUCH_DROP-0.04)))
clip("stun",L,keys)

# ---------- frozen: caught mid-flinch, arms up to shield the face (held; the game stops the clock on it) ----------
fz=add(stance(1.3),{"Spine":(-4,0,0),"Spine1":(6,0,0),"Spine2":(4,0,0),"Neck":(6,0,0),"Head":(10,0,-12),
       "LeftArm":(-55,-30,0),"RightArm":(-55,30,0),"LeftForeArm":(-95,0,20),"RightForeArm":(-95,0,-20),
       "LeftHand":(-20,0,0),"RightHand":(-20,0,0),"Tail":(10,0,10),"Tail1":(10,0,10),"Tail2":(0,0,10)})
clip("frozen",1.0,[(0,fz,(0,0,CROUCH_DROP-0.03)),(0.5,fz,(0,0,CROUCH_DROP-0.03))])

# ---------- knockback: thrown backward, arms flung forward, stumbles and recovers ----------
kb=add(base,{"Spine":(-22,0,0),"Spine1":(-10,0,0),"Neck":(14,0,0),"Head":(10,0,0),
             "LeftArm":(-60,-25,0),"RightArm":(-60,25,0),"LeftForeArm":(-20,0,0),"RightForeArm":(-20,0,0),
             "LeftUpLeg":(-40,0,0),"LeftLeg":(30,0,0),"RightUpLeg":(10,0,0),"RightLeg":(40,0,0),
             "Tail":(-30,0,0),"Tail1":(-20,0,0),"Tail2":(-10,0,0)})
st=add(base,{"Spine":(18,0,0),"Spine1":(6,0,0),"Head":(-12,0,0),"LeftArm":(-20,-30,0),"RightArm":(-10,30,0),
             "LeftUpLeg":(-30,0,0),"LeftLeg":(50,0,0),"RightUpLeg":(-4,0,0),"RightLeg":(34,0,0)})
clip("knockback",0.7,[(0,base,(0,0,CROUCH_DROP)),(0.1,kb,(0,0.04,0.02)),(0.35,st,(0,0,CROUCH_DROP-0.06)),(0.7,base,(0,0,CROUCH_DROP))],loop=False)

# ---------- attack: a lunging claw swipe with the right hand ----------
wind=add(base,{"Spine":(4,0,-25),"Spine1":(0,0,-10),"Head":(0,0,15),"RightArm":(-40,60,-30),"RightForeArm":(-80,0,0),
               "LeftArm":(-20,-20,0),"RightUpLeg":(10,0,0),"LeftUpLeg":(-30,0,0),"LeftLeg":(40,0,0)})
swipe=add(base,{"Spine":(22,0,25),"Spine1":(8,0,12),"Head":(-14,0,-12),"RightArm":(-70,-10,40),"RightForeArm":(-15,0,0),
                "RightHand":(10,0,0),"LeftArm":(10,-25,0),"LeftUpLeg":(-40,0,0),"LeftLeg":(45,0,0),"RightUpLeg":(14,0,0),
                "Tail":(0,0,-20),"Tail1":(0,0,-15)})
clip("attack",0.6,[(0,base,(0,0,CROUCH_DROP)),(0.22,wind,(0,0.03,CROUCH_DROP-0.02)),(0.32,swipe,(0,-0.06,CROUCH_DROP-0.05)),(0.6,base,(0,0,CROUCH_DROP))],loop=False)

# ---------- death: knees buckle, it sinks, then topples forward ----------
kneel=add(base,{"LeftUpLeg":(-75,0,-8),"RightUpLeg":(-60,0,8),"LeftLeg":(125,0,0),"RightLeg":(120,0,0),
                "LeftFoot":(-40,0,0),"RightFoot":(-40,0,0),"Spine":(-10,0,0),"Spine1":(-6,0,0),"Head":(-20,0,10),
                "LeftArm":(10,-10,0),"RightArm":(10,10,0),"Tail":(30,0,0)})
down=add(base,{"Hips":(55,0,0),"LeftUpLeg":(-95,0,-10),"RightUpLeg":(-80,0,10),"LeftLeg":(135,0,0),"RightLeg":(130,0,0),
               "LeftFoot":(-35,0,0),"RightFoot":(-35,0,0),"Spine":(15,0,0),"Spine1":(8,0,0),"Neck":(10,0,0),"Head":(10,0,25),
               "LeftArm":(-70,-30,0),"RightArm":(-60,35,0),"LeftForeArm":(-20,0,0),"RightForeArm":(-30,0,0),
               "Tail":(-40,0,0),"Tail1":(-10,0,0),"Tail2":(0,0,20),"Tail3":(0,0,20)})
clip("death",1.1,[(0,base,(0,0,CROUCH_DROP)),(0.1,add(base,{"Spine":(-16,0,0),"Head":(-20,0,0)}),(0,0.02,CROUCH_DROP)),
                  (0.45,kneel,(0,0.05,-0.42)),(0.8,down,(0,-0.15,-0.62)),(1.1,down,(0,-0.16,-0.66))],loop=False)

# textures down to a size that suits a small enemy
for im in bpy.data.images:
    if im.size[0]>1024:
        im.scale(1024,1024)
# name the textures by what they are (the game's importer extracts them under these names)
mat=ob.data.materials[0]; bs=[n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'][0]
def src(sock):
    n=sock.links[0].from_node if sock.links else None
    while n and n.type!='TEX_IMAGE':
        n=n.inputs[0].links[0].from_node if n.inputs and n.inputs[0].links else (n.inputs[1].links[0].from_node if len(n.inputs)>1 and n.inputs[1].links else None)
    return n.image if n else None
for sock,name in ((bs.inputs['Base Color'],'prowler_color'),(bs.inputs['Normal'],'prowler_normal'),(bs.inputs['Metallic'],'prowler_orm')):
    im=src(sock)
    if im:
        im.name=name
        if name!='prowler_color' and im.size[0]>512: im.scale(512,512)
        im.file_format='PNG'
        print('IMG',name,im.size[:])

bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animation_mode='ACTIONS',
    export_force_sampling=True, export_frame_step=1, export_anim_single_armature=True, export_def_bones=False,
    export_image_format='AUTO', export_yup=True, export_apply=False)
print("EXPORTED", [a.name for a in bpy.data.actions])
