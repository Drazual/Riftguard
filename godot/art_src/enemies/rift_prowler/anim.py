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

def world_q(e, order='XYZ'):
    return Euler((math.radians(e[0]),math.radians(e[1]),math.radians(e[2])),order).to_quaternion()

ARM_ORDER=['XYZ']
def order_of(name):
    # in the run the arms come in toward the body (Y) first, then swing (X), so a swung arm stays tucked in
    return ARM_ORDER[0] if name.endswith('Arm') else 'XYZ'

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
            pb.rotation_quaternion=B.inverted()@world_q(e,order_of(pb.name))@B
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
            pb.rotation_quaternion=B.inverted()@world_q(e,order_of(pb.name))@B; pb.keyframe_insert("rotation_quaternion",frame=f)
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
        "LeftArm":(0,arms_in,0),"RightArm":(0,-arms_in,0),
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

# ---------- run: a loose, bouncy, exaggerated sprint, in place ----------
# Legs: big forward reach, a high heel tuck on the recovery, a flat foot through stance and a toe push-off.
# Arms: tucked in close with the elbows bent, pumping against the legs. Everything after the hips trails a little
# behind it (forearms, hands, head, each tail segment), so nothing moves in lockstep.
def run(L=0.52, n=26):
    ks=[]
    for i in range(n):
        x=i/n; f=2*math.pi*x
        p={}
        for side,ph,sg in (("Left",f,1),("Right",f+math.pi,-1)):
            thigh=-44*math.sin(ph)-14
            knee=16+105*max(0.0,math.cos(ph-0.35))**1.3+16*max(0.0,-math.cos(ph))
            foot=-0.55*(thigh+knee)+28*max(0.0,-math.sin(ph-0.3))
            p[side+"UpLeg"]=(thigh,0,sg*-4)
            p[side+"Leg"]=(knee,0,0)
            p[side+"Foot"]=(foot,0,0)
            p[side+"ToeBase"]=(-22*max(0.0,-math.sin(ph-0.2)),0,0)
            # the arm on this side swings with the other leg: forward when this leg is back
            swing=math.sin(ph)
            lag=math.sin(ph-0.45)
            p[side+"Shoulder"]=(0,0,sg*4*swing)
            p[side+"Arm"]=(40*swing-8,sg*24,sg*6*swing)
            p[side+"ForeArm"]=(-88-26*max(0.0,-lag)+10*max(0.0,lag),0,0)
            p[side+"Hand"]=(-12-10*math.sin(ph-0.8),0,0)
        s1=math.sin(f)
        bounce=math.cos(2*(f-math.pi/2-0.35))
        p["Hips"]=(0,4*s1,-11*s1)
        p["Spine"]=(20+3*bounce,0,13*s1)
        p["Spine1"]=(6,-2*s1,5*s1)
        p["Spine2"]=(2+2*math.cos(2*f-1.0),0,2*s1)
        p["Neck"]=(-12-2*bounce,0,-6*s1)
        p["Head"]=(-14-3*math.cos(2*f-1.4),0,-7*math.sin(f-0.4))
        for k,nme in enumerate(["Tail","Tail1","Tail2","Tail3","Tail4"]):
            lagk=0.5+0.45*k
            lift=(38,16,6,2,0)[k]
            p[nme]=(lift+5*math.cos(2*f-lagk), 0, (6+4*k)*math.sin(f+math.pi-lagk))
        ks.append((L*x,p,(0,0.0,-0.05-0.045*bounce)))
    return ks
ARM_ORDER[0]="YXZ"
clip("run",0.52,run())
ARM_ORDER[0]="XYZ"

base=add(stance(),tail(0,0))

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

# ---------- attack: a lunging two-claw combo at whatever holds it up (the hero, a wall) ----------
ready=add(base,{"Spine":(14,0,0),"Neck":(-8,0,0),"Head":(-10,0,0),"LeftArm":(-30,-24,0),"RightArm":(-30,24,0),
                "LeftForeArm":(-70,0,0),"RightForeArm":(-70,0,0),"LeftUpLeg":(-26,0,0),"LeftLeg":(40,0,0),"RightUpLeg":(6,0,0),"RightLeg":(30,0,0)})
windR=add(ready,{"Spine":(-2,0,-28),"Spine1":(-4,0,-14),"Head":(4,0,20),"RightArm":(-70,70,-40),"RightForeArm":(-60,0,0),
                 "RightHand":(-20,0,0),"LeftArm":(-50,-20,0),"Tail":(0,0,20),"Tail1":(0,0,15)})
slashR=add(ready,{"Spine":(26,0,30),"Spine1":(8,0,14),"Neck":(-6,0,0),"Head":(-18,0,-16),"RightArm":(-80,-20,50),"RightForeArm":(-10,0,0),
                  "RightHand":(15,0,0),"LeftArm":(-10,-30,0),"LeftUpLeg":(-44,0,0),"LeftLeg":(50,0,0),"RightUpLeg":(16,0,0),
                  "Tail":(0,0,-25),"Tail1":(0,0,-20),"Tail2":(0,0,-10)})
windL=add(slashR,{"Spine":(-14,0,-10),"Spine1":(-6,0,-6),"LeftArm":(-75,-70,40),"LeftForeArm":(-60,0,0),"RightArm":(-30,0,-20)})
slashL=add(ready,{"Spine":(28,0,-32),"Spine1":(8,0,-14),"Head":(-18,0,16),"LeftArm":(-85,20,-50),"LeftForeArm":(-10,0,0),
                  "LeftHand":(15,0,0),"RightArm":(-20,30,0),"RightForeArm":(-80,0,0),"RightUpLeg":(-40,0,0),"RightLeg":(48,0,0),
                  "LeftUpLeg":(10,0,0),"LeftLeg":(30,0,0),"Tail":(0,0,25),"Tail1":(0,0,20),"Tail2":(0,0,10)})
clip("attack",0.95,[(0,ready,(0,0,CROUCH_DROP-0.04)),(0.18,windR,(0,0.03,CROUCH_DROP-0.03)),(0.28,slashR,(0,-0.08,CROUCH_DROP-0.07)),
                    (0.48,windL,(0,-0.04,CROUCH_DROP-0.05)),(0.58,slashL,(0,-0.1,CROUCH_DROP-0.08)),(0.95,ready,(0,0,CROUCH_DROP-0.04))],loop=False)

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
bpy.ops.wm.save_as_mainfile(filepath=blend.replace('.blend','_anim.blend'))
bpy.ops.wm.save_as_mainfile(filepath=blend.replace('.blend','_anim.blend'))  # for checking the clips in Blender
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animation_mode='ACTIONS',
    export_force_sampling=True, export_frame_step=1, export_anim_single_armature=True, export_def_bones=False,
    export_image_format='AUTO', export_yup=True, export_apply=False)
print("EXPORTED", [a.name for a in bpy.data.actions])
