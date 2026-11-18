"""Rift Prowler run fix: rebuilds the legs of `run` with planted feet (2-bone IK on a designed foot path that moves
backward at exactly the ground speed the game moves it at), puts the body's bounce in phase with the footfalls, and
re-exports every clip starting at t=0 (the old GLB started all clips at 1/30 s, which makes a one-frame freeze at
every loop of run/idle/stun). The upper body (arms, spine, head, tail) is kept from the old run.
blender -b --factory-startup -P fix_run.py -- old.glb new.glb"""
import bpy, sys, math
from mathutils import Vector, Matrix, Quaternion
src, dst = sys.argv[sys.argv.index('--')+1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene; sc.render.fps = 30
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    if o.type == 'MESH' and o.name.startswith('Icosphere'): bpy.data.objects.remove(o)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
for a in bpy.data.actions:
    if a.name.endswith('_Armature'): a.name = a.name[:-9]
old = bpy.data.actions['run']
# ---- the numbers (native model units; the game shows it at 1.45 m tall from a 1.903 m mesh, factor 0.762) ----
N = 16                      # frames per cycle (0.533 s at 30 fps)
V = 0.116                   # m/frame native = 2.65 m/s at game scale = walk_speed 52 on the iso maps' diagonals
DUTY = 6                    # stance frames per foot (of 16): a sprint with a short flight phase between steps
STANCE = V * DUTY           # 0.696 m
Y_C, X_ANK, Z_G = -0.04, 0.17, 0.14   # stance centre (y), ankle track half-width, ankle height with the foot flat
LIFT = 0.30                 # swing: how high the ankle comes up (heel tuck)
HIP_Z, BOUNCE = -0.085, 0.035         # hips offset (crouch) and bounce: lowest at mid-stance, highest in flight
STANCE_START = {'Left': 6, 'Right': 14}
def smooth(t): return t * t * (3 - 2 * t)
R0 = Vector((0.0, 0.15, 0.10))          # ankle relative to the ball of the foot (rest pose)
def roll(pitch):                       # the ankle around the ball when the heel comes up by `pitch`
    return Matrix.Rotation(pitch, 3, 'X') @ R0
P_OFF = math.radians(32)               # heel-up at toe-off
def foot_path(side, k):
    s = ((k - STANCE_START[side]) % N)  # frames since touch-down
    x = X_ANK if side == 'Left' else -X_ANK
    b_front = Y_C - R0.y - STANCE / 2   # where the ball of the foot lands
    if s <= DUTY:                       # planted: the ball slides back at exactly the ground speed
        ball = Vector((x, b_front + V * s, Z_G - R0.z))
        late = max(0.0, (s - DUTY * 0.5) / (DUTY * 0.5))   # the heel comes up over the second half (toe pivot)
        pitch = P_OFF * smooth(late)
        return ball + roll(pitch), pitch
    w = (s - DUTY) / (N - DUTY)         # swing 0..1
    A0 = Vector((x, b_front + V * DUTY, Z_G - R0.z)) + roll(P_OFF)   # ankle at toe-off
    A1 = Vector((x, b_front, Z_G - R0.z)) + R0                       # ankle at the next touch-down
    y = A0.y + (A1.y - A0.y) * smooth(min(1.0, w * 1.08))
    y += 0.10 * math.sin(math.pi * w) * (1 - w)   # heel tucks up behind early in the swing
    z = A0.z + (A1.z - A0.z) * w + LIFT * math.sin(math.pi * min(1.0, w ** 0.8))
    pitch = P_OFF * (1 - smooth(w)) + math.radians(18) * math.sin(math.pi * w) * (1 - w)
    return Vector((x, y, z)), pitch
REST = {b.name: b.matrix_local.copy() for b in arm.data.bones}
L1 = (REST['LeftLeg'].translation - REST['LeftUpLeg'].translation).length
L2 = (REST['LeftFoot'].translation - REST['LeftLeg'].translation).length
def upd(): bpy.context.view_layer.update()
def aim(pb, target):
    M = pb.matrix.copy(); y = M.col[1].xyz.normalized(); d = (target - M.translation).normalized()
    q = y.rotation_difference(d) @ M.to_quaternion()
    pb.matrix = Matrix.Translation(M.translation) @ q.to_matrix().to_4x4(); upd()
arm.animation_data.action = old
for t in arm.animation_data.nla_tracks: t.mute = True
pbs = arm.pose.bones
rec = []; err = 0.0
for k in range(N + 1):
    sc.frame_set(1 + k); upd()
    # body bounce in phase with the feet (lowest at each mid-stance)
    u = k / N
    hz = HIP_Z - BOUNCE * math.cos(4 * math.pi * (u - (STANCE_START['Left'] + DUTY / 2) / N))
    H = pbs['Hips']; M = H.matrix.copy()
    H.matrix = Matrix.Translation(REST['Hips'].translation + Vector((0, 0, hz))) @ M.to_quaternion().to_matrix().to_4x4(); upd()
    for side in ('Left', 'Right'):
        T, pitch = foot_path(side, k)
        hip = pbs[side + 'UpLeg'].matrix.translation.copy()
        dv = T - hip; d = min(dv.length, L1 + L2 - 1e-4); dn = dv.normalized()
        pole = Vector((0.12 if side == 'Left' else -0.12, -1, 0))
        bend = (pole - dn * pole.dot(dn)).normalized()
        a_ = (L1 * L1 - L2 * L2 + d * d) / (2 * d); h = math.sqrt(max(0.0, L1 * L1 - a_ * a_))
        knee = hip + dn * a_ + bend * h
        aim(pbs[side + 'UpLeg'], knee); aim(pbs[side + 'Leg'], hip + dn * d)
        # the foot: its rest (flat) orientation, pitched heel-up / toes-down; the toes stay flat on the ground while planted
        F = pbs[side + 'Foot']; R = Matrix.Rotation(pitch, 4, 'X') @ REST[side + 'Foot']
        F.matrix = Matrix.Translation(F.matrix.translation) @ R.to_quaternion().to_matrix().to_4x4(); upd()
        s = (k - STANCE_START[side]) % N
        toe_pitch = 0.0 if s <= DUTY else pitch * 0.5
        Tb = pbs[side + 'ToeBase']; R2 = Matrix.Rotation(toe_pitch, 4, 'X') @ REST[side + 'ToeBase']
        Tb.matrix = Matrix.Translation(Tb.matrix.translation) @ R2.to_quaternion().to_matrix().to_4x4(); upd()
        err = max(err, (F.matrix.translation - T).length if dv.length < L1 + L2 else 0)
    rec.append({pb.name: (pb.rotation_quaternion.copy(), pb.location.copy(), pb.scale.copy()) for pb in pbs})
print('max ankle error (reachable frames)', round(err, 4))
# the new run: every bone keyed on frames 1..17 (17 == 1, so the loop closes on itself)
new = bpy.data.actions.new('run_new'); arm.animation_data.action = new
for k, pose in enumerate(rec):
    for pb in pbs:
        q, l, s = pose[pb.name]
        pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = q; pb.location = l; pb.scale = s
        pb.keyframe_insert('rotation_quaternion', frame=1 + k); pb.keyframe_insert('location', frame=1 + k); pb.keyframe_insert('scale', frame=1 + k)
for fc in new.fcurves:
    for kp in fc.keyframe_points: kp.interpolation = 'LINEAR'
arm.animation_data.action = None
for t in arm.animation_data.nla_tracks:
    if t.name == 'run':
        t.strips[0].action = new
old.name = 'run_old'; old.use_fake_user = False
bpy.data.actions.remove(old)
new.name = 'run'; new.use_fake_user = True
for t in arm.animation_data.nla_tracks: t.mute = True
print('ACTIONS', [(a.name, a.frame_range[:]) for a in bpy.data.actions])
bpy.ops.wm.save_as_mainfile(filepath=dst.replace('.glb', '.blend'))
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_animation_mode='ACTIONS',
    export_force_sampling=True, export_frame_step=1, export_anim_single_armature=True, export_def_bones=False,
    export_image_format='AUTO', export_yup=True, export_apply=False, export_anim_slide_to_zero=True)
print('EXPORTED')
