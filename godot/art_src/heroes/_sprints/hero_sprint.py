"""Hero sprints ("run" clips) authored for the speed each hero really crosses the board at (SUGGESTED numbers).
blender -b --factory-startup -P hero_sprint.py -- <hero> <model.glb> <out_run.glb> [KEY=value ...]
Writes <out_run.glb> (the rig and one clip, "run", 60 keys/s) for hero.json "anims": {"run": "<hero>_run.glb"} with
"run_speed" (the clip's ground speed in model metres a second), plus <out>_preview.blend / <out>_preview.glb (with the
mesh, for previews and contact_check.py).

Legs: IK onto planted feet. The ball of the foot lands ahead of the hip, rolls back under him at exactly the ground
speed, the heel rises and he pushes off; the swing kicks the heel up, drives the knee through, reaches and paws back.
Each step has a flight phase. The hips sit as high as the legs allow (solved per rig), bob (lowest mid-stance), turn
with the swinging leg and drop on the swing side.
Upper body, in step with the legs: the chest counter-turns against the pelvis, the trunk leans forward, flexes a
little on every footfall and sways over the stance leg; arms swing opposite the legs (a free arm pumps from the
shoulder with a bent elbow; a weapon or shield arm swings less, from its carry pose; a two-handed rifle moves as one
piece with the chest and bounces on the footfalls); the head is held level and forward."""
import bpy, sys, math
from mathutils import Vector, Matrix, Quaternion
_a = sys.argv[sys.argv.index('--') + 1:]; HERO, src, dst = _a[:3]; OVR = dict(x.split('=') for x in _a[3:])
PRESETS = {
    # V: ground speed in model m/s = board speed (px/s) x 0.8 x 1.8/26 / the model's fit scale in game (measured)
    'striker': dict(V=10.25, N=32, DUTY=5, LAND=-0.42, X_FOOT=0.085, LEAN=16, YAW=8, TWIST=1.6, BOUNCE=0.035,
                    arms=dict(both=('carry2', dict(yaw=6, pitch=3.5)))),
    'sniper':  dict(V=8.49, N=34, DUTY=6, LAND=-0.44, X_FOOT=0.09, LEAN=14, YAW=8, TWIST=1.6, BOUNCE=0.035,
                    arms=dict(both=('carry2', dict(yaw=6, pitch=3.5)))),
    'wizard':  dict(V=8.68, N=34, DUTY=6, LAND=-0.42, X_FOOT=0.09, LEAN=13, YAW=8, TWIST=1.5, BOUNCE=0.035,
                    arms=dict(Left=('pump', dict(amp=46, fwd=-8, elbow=80, elbow_amp=20, abd=10)),
                              Right=('swing', dict(amp=16, elbow_amp=6)))),
    'tank':    dict(PIVOT='tip', PMAX=34, V=8.19, N=36, DUTY=6, LAND=-0.44, X_FOOT=0.13, LEAN=12, YAW=7, TWIST=1.4, BOUNCE=0.045,
                    arms=dict(Right=('pump', dict(amp=40, fwd=-6, elbow=85, elbow_amp=18, abd=14)),
                              Left=('swing', dict(amp=7, elbow_amp=3)))),
    'gale_tank': dict(PIVOT='tip', PMAX=34, V=8.49, N=36, DUTY=6, LAND=-0.44, X_FOOT=0.13, LEAN=12, YAW=7, TWIST=1.4, BOUNCE=0.045,
                    arms=dict(Right=('swing', dict(amp=30, elbow_amp=12)),
                              Left=('swing', dict(amp=7, elbow_amp=3)))),
}
C = dict(PRESETS[HERO]); C.update({k: float(v) if k not in ('N', 'DUTY') else int(v) for k, v in OVR.items()})
FPS = 60
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene; sc.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    if o.name.startswith('Icosphere'): bpy.data.objects.remove(o)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
for t in list(arm.animation_data.nla_tracks): arm.animation_data.nla_tracks.remove(t)
pbs = arm.pose.bones; M = 'mixamorig:'
REST = {b.name: b.matrix_local.copy() for b in arm.data.bones}
def upd(): bpy.context.view_layer.update()
def smooth(t): t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)
# ---- the carry pose: the walk's average pose (rifle carry, staff, shield and sword as he holds them) ----
walk = [a for a in bpy.data.actions if a.name.startswith('walk')][0]
arm.animation_data.action = walk
f0, f1 = walk.frame_range; NS = 24; acc = {}
for pb in pbs: pb.rotation_mode = 'QUATERNION'
for i in range(NS):
    sc.frame_set(int(f0 + (f1 - f0) * i / NS)); upd()
    for pb in pbs:
        q = pb.rotation_quaternion.copy(); a = acc.setdefault(pb.name, [Quaternion((0, 0, 0, 0)), q])
        if q.dot(a[1]) < 0: q = -q
        a[0] = Quaternion([a[0][k] + q[k] for k in range(4)])
CARRY = {n: v[0].normalized() for n, v in acc.items()}
arm.animation_data.action = None
# ---- leg geometry ----
L1 = (REST[M + 'LeftLeg'].translation - REST[M + 'LeftUpLeg'].translation).length
L2 = (REST[M + 'LeftFoot'].translation - REST[M + 'LeftLeg'].translation).length
kL = (L1 + L2) / 0.869                                   # vs the Striker's legs, to scale the swing path
# the point the foot rolls over: the ball (toe joint) for a bendy shoe; the toe tip for a rigid armoured boot whose
# toes are skinned to the foot bone (the Vanguard and Gale)
def boot_tip():   # the front of the left sole on the rest mesh (lowest 2 cm of the foot, front-most 3 cm)
    me = max([o for o in bpy.data.objects if o.type == 'MESH'], key=lambda o: len(o.data.vertices))
    gi = {g.name: g.index for g in me.vertex_groups}; want = {gi.get(M + 'LeftFoot'), gi.get(M + 'LeftToeBase')}
    W = me.matrix_world
    ps = [W @ v.co for v in me.data.vertices if any(g.group in want and g.weight > 0.3 for g in v.groups)]
    lo = min(p.z for p in ps); sole = [p for p in ps if p.z < lo + 0.02]
    fy = min(p.y for p in sole); tip = [p for p in sole if p.y < fy + 0.03]
    c = sum(tip, Vector()) / len(tip); return Vector((REST[M + 'LeftFoot'].translation.x, c.y, lo))
PIV = REST[M + 'LeftToeBase'].translation if C.get('PIVOT', 'ball') == 'ball' else boot_tip()
A_OFF = REST[M + 'LeftFoot'].translation - PIV                                   # pivot -> ankle at rest
GROUND = PIV.z
PMAX = math.radians(C.get('PMAX', 64))
V = C['V']; N = C['N']; DUTY = C['DUTY']; T = N / FPS; STANCE = V * DUTY / FPS
LAND = C['LAND'] * kL; X_FOOT = C['X_FOOT']
LEAN = math.radians(C['LEAN']); YAW = math.radians(C['YAW']); TWIST = C['TWIST']; BOUNCE = C['BOUNCE']
SAG = C.get('SAG', 0.02)
def ankle_from_ball(ball, p): return ball + Matrix.Rotation(p, 3, 'X') @ A_OFF
def stance(s):
    u = s / DUTY
    return LAND + STANCE * u, math.radians(12) * (1 - smooth(u / 0.35)) + PMAX * smooth((u - 0.45) / 0.55)
def cr(p0, p1, p2, p3, t):
    t2, t3 = t * t, t * t * t
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
START = {'Left': 0, 'Right': N // 2}
def foot(side, k):
    x = X_FOOT if side == 'Left' else -X_FOOT
    s = (k - START[side]) % N
    if s <= DUTY:
        by, p = stance(s)
        return ankle_from_ball(Vector((x, by, GROUND)), p), p, -p
    w = (s - DUTY) / (N - DUTY)
    by0, p0 = stance(DUTY); a0 = ankle_from_ball(Vector((x, by0, GROUND)), p0)
    by1, p1 = stance(0); a1 = ankle_from_ball(Vector((x, by1, GROUND)), p1)
    e = 1.0 / (N - DUTY); step = V / FPS
    # one key after toe-off the foot is still travelling back with the ground and lifting; one key before landing it
    # is already moving back at ground speed and coming down, so it meets the ground without skidding
    pts = [(0.0, a0.y, a0.z, p0), (e, a0.y + step * 0.4, a0.z + 0.035, p0 + math.radians(6)), (0.18, 0.50 * kL, 0.50 * kL, math.radians(50)),
           (0.40, 0.16 * kL, 0.66 * kL, math.radians(25)), (0.62, -0.32 * kL, 0.52 * kL, math.radians(-8)),
           (0.84, -0.48 * kL, 0.28 * kL, math.radians(-4)), (1.0 - e, a1.y - step, a1.z + 0.025, p1), (1.0, a1.y, a1.z, p1)]
    pts = [pts[0]] + pts + [pts[-1]]
    for i in range(1, len(pts) - 2):
        if w <= pts[i + 1][0] or i == len(pts) - 3:
            t = max(0.0, min(1.0, (w - pts[i][0]) / max(1e-6, pts[i + 1][0] - pts[i][0])))
            y, z, p = (cr(pts[i - 1][j], pts[i][j], pts[i + 1][j], pts[i + 2][j], t) for j in (1, 2, 3))
            break
    return Vector((x, y, z)), p, -p * (1 - 0.7 * smooth(w / 0.3))   # the toes ease out of their flat stance
def aim(pb, target):
    Mx = pb.matrix.copy(); y = Mx.col[1].xyz.normalized(); d = (target - Mx.translation).normalized()
    q = y.rotation_difference(d) @ Mx.to_quaternion()
    pb.matrix = Matrix.Translation(Mx.translation) @ q.to_matrix().to_4x4(); upd()
MISS = [0.0]; STANCE_ONLY = [False]
def leg_ik(side, A, pitch, toe, planted=True):
    hip = pbs[M + side + 'UpLeg'].matrix.translation.copy()
    dv = A - hip
    if planted or not STANCE_ONLY[0]: MISS[0] = max(MISS[0], dv.length - (L1 + L2 - 1e-4))
    d = min(dv.length, L1 + L2 - 1e-4); dn = dv.normalized()
    pole = Vector((0.10 if side == 'Left' else -0.10, -1, 0))
    bend = (pole - dn * pole.dot(dn)).normalized()
    a_ = (L1 * L1 - L2 * L2 + d * d) / (2 * d); h = math.sqrt(max(0.0, L1 * L1 - a_ * a_))
    knee = hip + dn * a_ + bend * h
    aim(pbs[M + side + 'UpLeg'], knee); aim(pbs[M + side + 'Leg'], hip + dn * d)
    F = pbs[M + side + 'Foot']; R = Matrix.Rotation(pitch, 4, 'X') @ REST[M + side + 'Foot']
    F.matrix = Matrix.Translation(F.matrix.translation) @ R.to_quaternion().to_matrix().to_4x4(); upd()
    Tb = pbs[M + side + 'ToeBase']; R2 = Matrix.Rotation(pitch + toe, 4, 'X') @ REST[M + side + 'ToeBase']
    Tb.matrix = Matrix.Translation(Tb.matrix.translation) @ R2.to_quaternion().to_matrix().to_4x4(); upd()
def rot_about(pb, pivot, R):
    pb.matrix = Matrix.Translation(pivot) @ R.to_4x4() @ Matrix.Translation(-pivot) @ pb.matrix; upd()
def Rax(axis, ang): return Matrix.Rotation(ang, 3, axis)
def chest_delta():    # how the chest is turned from its rest orientation (armature space)
    return pbs[M + 'Spine2'].matrix.to_3x3() @ REST[M + 'Spine2'].to_3x3().inverted()
UP_LEN = (REST[M + 'LeftForeArm'].translation - REST[M + 'LeftArm'].translation).length
FO_LEN = (REST[M + 'LeftHand'].translation - REST[M + 'LeftForeArm'].translation).length
def arms(ph):
    spec = C['arms']
    if 'both' in spec:                              # a two-handed rifle: arms and gun move as one piece with the chest
        o = spec['both'][1]; piv = pbs[M + 'Spine2'].matrix.translation.copy()
        Rd = chest_delta()
        R = Rd @ Rax('Z', math.radians(o['yaw']) * math.cos(ph)) @ Rax('X', math.radians(o['pitch']) * math.cos(2 * ph - 0.9)) @ Rd.inverted()
        for s in ('Left', 'Right'): rot_about(pbs[M + s + 'Shoulder'], piv, R)
        return
    for side, (mode, o) in spec.items():
        sgn = 1 if side == 'Left' else -1               # the right arm is forward when the left leg is (ph = 0)
        fwd = -sgn * math.cos(ph)                       # +1 = this arm fully forward
        Rd = chest_delta(); X = Rd @ Vector((1, 0, 0))
        if mode == 'pump':
            sh = pbs[M + side + 'Shoulder']
            rot_about(sh, sh.matrix.translation.copy(), Rax(Rd @ Vector((0, 0, 1)), sgn * math.radians(5) * fwd))
            sw = math.radians(-o['amp'] * fwd + o['fwd'])     # negative = forward
            abd = math.radians(o['abd']) * (-sgn)
            flex = math.radians(o['elbow'] + o['elbow_amp'] * fwd)
            d_up = Rd @ (Rax('X', sw) @ Rax('Y', abd) @ Vector((0, 0, -1)))
            d_fo = Rd @ (Rax('X', sw - flex) @ Rax('Y', abd * 0.4) @ Vector((0, 0, -1)))
            ua = pbs[M + side + 'Arm']; elbow = ua.matrix.translation + d_up * UP_LEN
            aim(ua, elbow); aim(pbs[M + side + 'ForeArm'], elbow + d_fo * FO_LEN)
        else:                                            # 'swing': a weapon/shield arm swings from its carry pose
            ua = pbs[M + side + 'Arm']
            rot_about(ua, ua.matrix.translation.copy(), Rax(X, math.radians(-o['amp'] * fwd)))
            fa = pbs[M + side + 'ForeArm']
            rot_about(fa, fa.matrix.translation.copy(), Rax(X, math.radians(-o['elbow_amp'] * fwd)))
H0 = REST[M + 'Hips']
def pose(k, hipz):
    ph = 2 * math.pi * k / N                          # 0 = left ball lands, pi = right
    for pb in pbs:
        pb.rotation_quaternion = CARRY.get(pb.name, Quaternion()); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
    upd()
    mid = (DUTY / 2) / N
    hz = hipz - BOUNCE * math.cos(4 * math.pi * (k / N - mid))
    Hq = (Quaternion((0, 0, 1), -YAW * math.cos(ph)) @ Quaternion((0, 1, 0), math.radians(4) * math.sin(ph))
          @ Quaternion((1, 0, 0), math.radians(8)))
    pbs[M + 'Hips'].matrix = Matrix.Translation(H0.translation + Vector((0, 0, hz))) @ (Hq.to_matrix().to_4x4() @ H0.to_3x3().to_4x4()); upd()
    # trunk: lean (spread over the spine), counter-turn, a little flex just after each footfall, sway over the stance leg
    for i, n in enumerate(('Spine', 'Spine1', 'Spine2')):
        pb = pbs[M + n]; piv = pb.matrix.translation.copy()
        R = Rax('X', (LEAN - math.radians(8)) / 3 + math.radians(1.2) * math.cos(2 * ph - 0.7))
        if n != 'Spine': R = Rax('Z', YAW * TWIST * math.cos(ph) / 2) @ R
        if n == 'Spine1': R = Rax('Y', math.radians(2.5) * math.cos(ph - 2 * math.pi * mid)) @ R
        rot_about(pb, piv, R)
    arms(ph)
    # head held level and facing forward (eyes steady), whatever the trunk does under it
    for n, w in (('Neck', 0.45), ('Head', 0.85)):
        pb = pbs[M + n]; cur = pb.matrix.to_quaternion()
        tgt = (Rax('X', LEAN * 0.15) @ REST[M + n].to_3x3()).to_quaternion()
        q = cur.slerp(tgt, w); pb.matrix = Matrix.Translation(pb.matrix.translation) @ q.to_matrix().to_4x4(); upd()
    for side in ('Left', 'Right'):
        A, p, tb = foot(side, k); leg_ik(side, A, p, tb, (k - START[side]) % N <= DUTY)
# ---- the hips as high as the legs reach (then a little lower, for a soft knee) ----
hipz = 0.0; STANCE_ONLY[0] = True     # (a swing foot that can't quite reach its path just swings a straight leg)
for _ in range(80):
    MISS[0] = 0.0
    for k in range(N): pose(k, hipz)
    if MISS[0] <= 0.0: break
    hipz -= 0.005
hipz -= SAG; STANCE_ONLY[0] = False
act = bpy.data.actions.new('run'); arm.animation_data.action = act
MISS[0] = 0.0
for k in range(N + 1):
    pose(k, hipz)
    for pb in pbs:
        pb.keyframe_insert('rotation_quaternion', frame=1 + k); pb.keyframe_insert('location', frame=1 + k)
for fc in act.fcurves:
    for kp in fc.keyframe_points: kp.interpolation = 'LINEAR'
print('PIVOT', [round(x, 3) for x in PIV], 'ankle', [round(x, 3) for x in REST[M + 'LeftFoot'].translation])
print('RUN', HERO, 'V', V, 'cycle', round(T, 3), 'step', round(V * T / 2, 3), 'stance', round(STANCE, 3),
      'flight', round(T / 2 - DUTY / FPS, 3), 'hips', round(hipz, 3), 'leg overreach', round(MISS[0], 4))
for a in list(bpy.data.actions):
    if a != act: bpy.data.actions.remove(a)
act.use_fake_user = True
sc.frame_start, sc.frame_end = 1, N + 1
base = dst[:-4]
bpy.ops.wm.save_as_mainfile(filepath=base + '_preview.blend', copy=True)
bpy.ops.export_scene.gltf(filepath=base + '_preview.glb', export_format='GLB', export_animation_mode='ACTIONS',
    export_force_sampling=True, export_frame_step=1, export_def_bones=False, export_yup=True, export_apply=False,
    export_anim_slide_to_zero=True, export_reset_pose_bones=True)
for o in list(bpy.data.objects):
    if o.type != 'ARMATURE': bpy.data.objects.remove(o)
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_animation_mode='ACTIONS', export_force_sampling=True,
    export_frame_step=1, export_def_bones=False, export_yup=True, export_apply=False, export_anim_slide_to_zero=True,
    export_reset_pose_bones=True)
print('EXPORTED')
