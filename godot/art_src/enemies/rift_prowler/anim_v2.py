"""Rift Prowler v2: a longer-striding, lower-cadence run at the same ground speed, and a slower, broader attack.
Works on the current game GLB (v1) and keeps every clip name and bone; only `run` and `attack` change.
blender -b --factory-startup -P v2.py -- prowler_v1.glb prowler_v2_raw.glb

run (SUGGESTED numbers, native mesh units; the game shows the 1.903 m mesh at 1.45 m):
  V stays 0.116 m/frame (walk_speed 52). N 16 -> 22 frames per cycle (0.533 s -> 0.733 s, cadence -27%),
  so each step is V*N/2 = 1.276 m instead of 0.928 m (+37.5%). Stance 8 of 22 frames per foot, with a short
  float (3 frames) between steps: a loping run. The upper body (arms, spine, head, tail) is v1's, stretched to the
  new cycle. Hips sit 5.5 cm lower and bounce a little more to reach the longer stride.
attack: 0.95 s -> 1.40 s. A long wind-up (0.40 s instead of 0.18 s), broader swings (every joint's swing away from the
  ready pose x1.35), and a real lunge: the left foot steps 0.22 m forward into the first slash and the body drives
  0.22 m forward (was 0.08 m), then it steps back into the ready crouch. Slashes land at 0.52 s and 0.92 s."""
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
pbs = arm.pose.bones
REST = {b.name: b.matrix_local.copy() for b in arm.data.bones}
L1 = (REST['LeftLeg'].translation - REST['LeftUpLeg'].translation).length
L2 = (REST['LeftFoot'].translation - REST['LeftLeg'].translation).length
def upd(): bpy.context.view_layer.update()
def smooth(t): t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)
def aim(pb, target):
    M = pb.matrix.copy(); y = M.col[1].xyz.normalized(); d = (target - M.translation).normalized()
    q = y.rotation_difference(d) @ M.to_quaternion()
    pb.matrix = Matrix.Translation(M.translation) @ q.to_matrix().to_4x4(); upd()
MISS = [0.0]
def leg_ik(side, T, pitch, toe_pitch):
    hip = pbs[side + 'UpLeg'].matrix.translation.copy()
    dv = T - hip; MISS[0] = max(MISS[0], dv.length - (L1 + L2 - 1e-4))
    d = min(dv.length, L1 + L2 - 1e-4); dn = dv.normalized()
    pole = Vector((0.12 if side == 'Left' else -0.12, -1, 0))
    bend = (pole - dn * pole.dot(dn)).normalized()
    a_ = (L1 * L1 - L2 * L2 + d * d) / (2 * d); h = math.sqrt(max(0.0, L1 * L1 - a_ * a_))
    knee = hip + dn * a_ + bend * h
    aim(pbs[side + 'UpLeg'], knee); aim(pbs[side + 'Leg'], hip + dn * d)
    F = pbs[side + 'Foot']; R = Matrix.Rotation(pitch, 4, 'X') @ REST[side + 'Foot']
    F.matrix = Matrix.Translation(F.matrix.translation) @ R.to_quaternion().to_matrix().to_4x4(); upd()
    Tb = pbs[side + 'ToeBase']; R2 = Matrix.Rotation(toe_pitch, 4, 'X') @ REST[side + 'ToeBase']
    Tb.matrix = Matrix.Translation(Tb.matrix.translation) @ R2.to_quaternion().to_matrix().to_4x4(); upd()
def set_hips(off, q=None):
    H = pbs['Hips']; q = q or H.matrix.to_quaternion()
    H.matrix = Matrix.Translation(REST['Hips'].translation + off) @ q.to_matrix().to_4x4(); upd()
def snapshot(): return {pb.name: (pb.rotation_quaternion.copy(), pb.location.copy(), pb.scale.copy()) for pb in pbs}
def apply(pose):
    for pb in pbs:
        q, l, s = pose[pb.name]; pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = q; pb.location = l; pb.scale = s
    upd()
def sample(action, f):
    """the full pose of `action` at frame f (fractional frames allowed)"""
    arm.animation_data.action = action
    sc.frame_set(int(math.floor(f)), subframe=f - math.floor(f)); upd()
    return snapshot()
def replace(name, rec):
    old = bpy.data.actions[name]
    new = bpy.data.actions.new(name + '_new'); arm.animation_data.action = new
    for k, pose in enumerate(rec):
        apply(pose)
        for pb in pbs:
            pb.keyframe_insert('rotation_quaternion', frame=1 + k); pb.keyframe_insert('location', frame=1 + k); pb.keyframe_insert('scale', frame=1 + k)
    for fc in new.fcurves:
        for kp in fc.keyframe_points: kp.interpolation = 'LINEAR'
    arm.animation_data.action = None
    for t in arm.animation_data.nla_tracks:
        if t.name == name: t.strips[0].action = new
    bpy.data.actions.remove(old); new.name = name; new.use_fake_user = True
for t in (arm.animation_data.nla_tracks if arm.animation_data else []): t.mute = True
if not arm.animation_data.nla_tracks or not any(t.name == 'run' for t in arm.animation_data.nla_tracks):
    for a in bpy.data.actions:   # one NLA track per clip, so the export keeps them all
        tr = arm.animation_data.nla_tracks.new(); tr.name = a.name; tr.strips.new(a.name, int(a.frame_range[0]), a); tr.mute = True
        a.use_fake_user = True

# ================= run =================
N0 = int(round(bpy.data.actions['run'].frame_range[1] - bpy.data.actions['run'].frame_range[0]))  # v1: 16
N = 22; V = 0.116; DUTY = 8
STANCE = V * DUTY
Y_C, X_ANK, Z_G = -0.02, 0.17, 0.14
LIFT = 0.34
HIP_Z, BOUNCE = -0.14, 0.045
STANCE_START = {'Left': 8, 'Right': 19}
R0 = Vector((0.0, 0.15, 0.10))
def roll(p): return Matrix.Rotation(p, 3, 'X') @ R0
P_OFF = math.radians(36)
def foot_path(side, k):
    s = (k - STANCE_START[side]) % N
    x = X_ANK if side == 'Left' else -X_ANK
    b_front = Y_C - R0.y - STANCE / 2
    if s <= DUTY:
        ball = Vector((x, b_front + V * s, Z_G - R0.z))
        late = max(0.0, (s - DUTY * 0.5) / (DUTY * 0.5))
        p = P_OFF * smooth(late)
        return ball + roll(p), p, 0.0
    w = (s - DUTY) / (N - DUTY)
    A0 = Vector((x, b_front + V * DUTY, Z_G - R0.z)) + roll(P_OFF)
    A1 = Vector((x, b_front, Z_G - R0.z)) + R0
    y = A0.y + (A1.y - A0.y) * smooth(min(1.0, w * 1.08))
    y += 0.12 * math.sin(math.pi * w) * (1 - w)
    z = A0.z + (A1.z - A0.z) * w + LIFT * math.sin(math.pi * min(1.0, w ** 0.8))
    p = P_OFF * (1 - smooth(w)) + math.radians(18) * math.sin(math.pi * w) * (1 - w)
    return Vector((x, y, z)), p, p * 0.5
run_old = bpy.data.actions['run']; f0 = run_old.frame_range[0]
rec = []
for k in range(N + 1):
    apply(sample(run_old, f0 + (k % N) * N0 / N))   # v1's upper body, stretched to the longer cycle
    u = k / N
    hz = HIP_Z - BOUNCE * math.cos(4 * math.pi * (u - (STANCE_START['Left'] + DUTY / 2) / N))
    set_hips(Vector((0, 0, hz)))
    for side in ('Left', 'Right'):
        T, p, tp = foot_path(side, k); leg_ik(side, T, p, tp)
    rec.append(snapshot())
print('run: N', N, 'V', V, 'step', round(V * N / 2, 3), 'stance', round(STANCE, 3), 'leg overreach', round(MISS[0], 4))
replace('run', rec)

# ================= attack =================
att = bpy.data.actions['attack']; a0 = att.frame_range[0]
OLD_T = [0, 0.18, 0.28, 0.48, 0.58, 0.95]          # v1 keys: ready, windR, slashR, windL, slashL, ready
NEW_T = [0, 0.40, 0.52, 0.80, 0.92, 1.40]
LEN = 1.40; NF = int(round(LEN * 30))
def warp(t):
    for i in range(len(NEW_T) - 1):
        if t <= NEW_T[i + 1]:
            w = (t - NEW_T[i]) / (NEW_T[i + 1] - NEW_T[i]); w = smooth(w) * 0.6 + w * 0.4
            return OLD_T[i] + (OLD_T[i + 1] - OLD_T[i]) * w
    return OLD_T[-1]
ready = sample(att, a0)
LEGS = {s + b for s in ('Left', 'Right') for b in ('UpLeg', 'Leg', 'Foot', 'ToeBase')}
BROAD = 1.35
# the feet where they stand in the ready crouch
apply(ready); FEET = {s: pbs[s + 'Foot'].matrix.translation.copy() for s in ('Left', 'Right')}
HIP0 = pbs['Hips'].matrix.translation - REST['Hips'].translation
def lunge(t):
    """(hips offset y/z, left foot forward step) over time: crouch back on the wind-up, drive forward into slash 1,
    hold low through slash 2, then step back"""
    back = 0.05 * smooth(t / 0.40) * (1 - smooth((t - 0.40) / 0.10))
    drive = smooth((t - 0.40) / 0.14) * (1 - smooth((t - 1.00) / 0.36))
    hy = back - 0.22 * drive - 0.04 * math.sin(math.pi * smooth((t - 0.70) / 0.30)) * drive
    hz = -0.03 * smooth(t / 0.40) - 0.05 * drive
    step = smooth((t - 0.34) / 0.16) * (1 - smooth((t - 1.02) / 0.30))
    lift = 0.09 * (math.sin(math.pi * smooth((t - 0.34) / 0.16)) if t < 0.52 else math.sin(math.pi * smooth((t - 1.02) / 0.30)) if 1.02 < t < 1.32 else 0)
    return hy, hz, step, lift
rec = []; MISS[0] = 0.0
for k in range(NF + 1):
    t = k / 30
    p = sample(att, a0 + warp(t) * 30)
    for n, (q, l, s) in p.items():   # broader: every swing away from the ready pose grows
        if n in LEGS or n == 'Hips': continue
        dq = q @ ready[n][0].inverted(); ax, ang = dq.to_axis_angle()
        if ang > math.pi: ang -= 2 * math.pi
        p[n] = (Quaternion(ax, ang * BROAD) @ ready[n][0], l, s)
    apply(p)
    hy, hz, step, lift = lunge(t)
    set_hips(HIP0 + Vector((0, hy, hz)))
    leg_ik('Left', FEET['Left'] + Vector((0, -0.22 * step, lift)), math.radians(-10) * (lift / 0.09), 0.0)
    leg_ik('Right', FEET['Right'], math.radians(14) * smooth((t - 0.40) / 0.2) * (1 - smooth((t - 1.0) / 0.3)), 0.0)
    rec.append(snapshot())
print('attack: frames', NF, 'slashes at', NEW_T[2], NEW_T[4], 'leg overreach', round(MISS[0], 4))
replace('attack', rec)
print('ACTIONS', sorted((a.name, a.frame_range[:]) for a in bpy.data.actions))
bpy.ops.wm.save_as_mainfile(filepath=dst.replace('.glb', '.blend'))
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_animation_mode='ACTIONS',
    export_force_sampling=True, export_frame_step=1, export_anim_single_armature=True, export_def_bones=False,
    export_image_format='AUTO', export_yup=True, export_apply=False, export_anim_slide_to_zero=True)
print('EXPORTED')
