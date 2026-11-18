"""Bastion clips (30 fps; whole-frame keys on every frame, every loop's last key equals its first, every clip exports
starting at t=0) and the GLB. A heavy knuckle-walker: the body is posed forward (world-axis rotations), then each fist and
foot is placed by 2-bone IK on a planned contact path, so planted fists and feet stay locked to the ground.
blender -b --factory-startup -P anim_bastion.py -- rigged.blend bastion_raw.glb"""
import bpy, sys, math
from mathutils import Euler, Vector, Matrix, Quaternion
blend, out = sys.argv[sys.argv.index('--')+1:][:2]
bpy.ops.wm.open_mainfile(filepath=blend)
ao = bpy.data.objects['Armature']; FPS = 30; sc = bpy.context.scene; sc.render.fps = FPS
ao.animation_data_create()
pbs = ao.pose.bones
REST = {b.name: b.matrix_local.copy() for b in ao.data.bones}
RQ = {n: m.to_quaternion() for n, m in REST.items()}
TAU = 2 * math.pi
def S(x): return math.sin(TAU * x)
def C(x): return math.cos(TAU * x)
def sm(t): t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)
def wq(e): return Euler([math.radians(x) for x in e], 'XYZ').to_quaternion()
def upd(): bpy.context.view_layer.update()
SIDES = (('L', 1), ('R', -1))
# ---- the numbers (native units). The game scales the mesh (1.653 tall) to height x clamp(r/9) = 0.8 x 16/9 = 1.42 m
# (the Juggernaut's radius 16), and moves it at walk_speed 26 board px/s: on the iso diagonals that's 1.325 m/s. ----
HEIGHT, RADIUS, MESH_H = 0.8, 16.0, 1.653
WALK = 26.0                      # walk_speed in enemy.json (board units/s; the Juggernaut's speed)
SCALE = HEIGHT * max(0.6, min(2.5, RADIUS / 9.0)) / MESH_H
V = WALK * 0.899 * (1.8 * math.cos(math.radians(35)) / 26) / FPS / SCALE   # native m per frame
N = 20                           # move: frames per cycle (0.667 s)
DUTY = {'Foot': 10, 'Hand': 9}   # stance frames per contact
START = {'Foot.L': 0, 'Hand.R': 5, 'Foot.R': 10, 'Hand.L': 15}   # diagonal-sequence walk: LH, RF, RH, LF
G = {}                           # ground contacts in rest: pivot (front-bottom edge) and joint offset from it
def rest_head(n): return REST[n].translation.copy()
for s, sg in SIDES:
    G['Foot.' + s] = {'pivot': Vector((sg * 0.33, 0.25, 0.0)), 'joint': rest_head('Foot.' + s), 'center': 0.17, 'lift': 0.11, 'roll': 22}
    G['Hand.' + s] = {'pivot': Vector((sg * 0.70, -0.55, 0.015)), 'joint': rest_head('Hand.' + s), 'center': -0.47, 'lift': 0.15, 'roll': 30}
# the true front edge of each sole (rest mesh): the pivot it rolls over, so the toes/knuckles never dip into the ground
_me = bpy.data.objects['Bastion']; _gi = {g.name: g.index for g in _me.vertex_groups}
for n, g in G.items():
    vs = [v.co for v in _me.data.vertices if any(x.group == _gi[n] and x.weight > 0.99 for x in v.groups)]
    lo = min(c.z for c in vs); sole = [c for c in vs if c.z < lo + 0.02]
    front = min(c.y for c in sole)
    g['center'] += front - g['pivot'].y
    g['pivot'] = Vector((g['pivot'].x, front, lo))
    print('contact', n, 'pivot', [round(x, 3) for x in g['pivot']], 'centre', round(g['center'], 3))
for g in G.values(): g['R0'] = g['joint'] - g['pivot']
def rx(deg): return Matrix.Rotation(math.radians(deg), 3, 'X')
def contact(n, k, n_frames, duty, v, lift_scale=1.0, drag=0.0):
    """joint target and roll (deg) for contact n at frame k of a walk cycle"""
    g = G[n]; st = START[n] * n_frames // N; s = (k - st) % n_frames
    stance = v * duty; y_front = g['center'] - stance / 2
    if s <= duty:
        late = max(0.0, (s - duty * 0.55) / (duty * 0.45)); roll = g['roll'] * sm(late)
        p = Vector((g['pivot'].x, y_front + v * s, g['pivot'].z))
        return p + rx(roll) @ g['R0'], roll
    w = (s - duty) / (n_frames - duty)
    y = (y_front + stance) + (y_front - y_front - stance) * sm(w)
    roll = g['roll'] * (1 - sm(w * 1.4)) + (12 if n.startswith('Hand') else 0) * math.sin(math.pi * w)
    lift = g['lift'] * lift_scale * math.sin(math.pi * min(1.0, w ** 0.85)) * (1 - drag * 0.6)
    p = Vector((g['pivot'].x, y, g['pivot'].z + lift))
    return p + rx(roll) @ g['R0'], roll
def planted(n, dy=0.0, dx=0.0, dz=0.0, roll=0.0):
    g = G[n]; p = g['pivot'] + Vector((dx, dy, dz)); return p + rx(roll) @ g['R0'], roll
# ---- IK ----
L = {}
for s, _ in SIDES:
    for a, b, c in (('Thigh', 'Shin', 'Foot'), ('UpperArm', 'ForeArm', 'Hand')):
        A, B, Cc = rest_head(a + '.' + s), rest_head(b + '.' + s), rest_head(c + '.' + s)
        ax = (Cc - A).normalized(); bend = (B - A) - ax * (B - A).dot(ax)
        L[c + '.' + s] = ((B - A).length, (Cc - B).length, bend.normalized(), a + '.' + s, b + '.' + s)
def set_dir(n, head, d):
    q = REST[n].col[1].xyz.normalized().rotation_difference(d.normalized()) @ RQ[n]
    pbs[n].matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4(); upd()
ERR = {}; MISS = {}
def ik(n, target, roll, clip):
    l1, l2, bend0, a, b = L[n]
    body = 'Hips' if n.startswith('Foot') else 'Chest'
    bq = pbs[body].matrix.to_quaternion() @ RQ[body].inverted()     # how the body part has turned from rest
    root = pbs[a].matrix.translation.copy()
    if n.startswith('Hand') and (target - root).length > (l1 + l2) * 0.985:
        # out of reach: the clavicle swings the shoulder toward the fist (a gorilla's reach), up to ~18 degrees
        sh = 'Shoulder' + n[4:]; M = pbs[sh].matrix.copy(); head = M.translation.copy(); y = M.col[1].xyz.normalized()
        want = (target - head).normalized()
        for f in [i / 20 for i in range(1, 21)]:
            d = y.slerp(want, f * 0.35) if hasattr(y, 'slerp') else (y.lerp(want, f * 0.35)).normalized()
            q = y.rotation_difference(d) @ M.to_quaternion()
            pbs[sh].matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4(); upd()
            root = pbs[a].matrix.translation.copy()
            if (target - root).length <= (l1 + l2) * 0.985: break
    dv = target - root; d = max(min(dv.length, l1 + l2 - 1e-4), abs(l1 - l2) + 1e-3); dn = dv.normalized()
    pole = bq @ bend0; bend = (pole - dn * pole.dot(dn)).normalized()
    x = (l1 * l1 - l2 * l2 + d * d) / (2 * d); h = math.sqrt(max(0.0, l1 * l1 - x * x))
    knee = root + dn * x + bend * h
    set_dir(a, root, knee - root); set_dir(b, pbs[b].matrix.translation.copy(), root + dn * d - knee)
    if roll is not None:
        q = rx(roll).to_quaternion() @ RQ[n]
        pbs[n].matrix = Matrix.Translation(pbs[n].matrix.translation.copy()) @ q.to_matrix().to_4x4(); upd()
    e = (pbs[n].matrix.translation - target).length
    ERR[clip] = max(ERR.get(clip, 0.0), e)
    if e > 0.003: MISS.setdefault(clip, set()).add(n)
# ---- clips ----
BODY = ['Root', 'Hips', 'Spine', 'Chest', 'Neck', 'Head', 'Shoulder.L', 'Shoulder.R']
def clip(name, frames, pose_at, loop=True):
    """pose_at(t, k) -> (rot {bone: world-axis euler deg}, loc {bone: world offset}, scale {bone: s}, limbs {contact: (target, roll)})"""
    act = bpy.data.actions.new(name); ao.animation_data.action = act
    for f in range(frames + 1):
        k = f % frames if loop else f
        rot, loc, scl, limbs = pose_at(f / frames, k)
        for pb in pbs:
            pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = Quaternion(); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
        for n in BODY:
            B = RQ[n]; pb = pbs[n]
            pb.rotation_quaternion = B.inverted() @ wq(rot.get(n, (0, 0, 0))) @ B
            pb.location = B.inverted() @ Vector(loc.get(n, (0, 0, 0)))
            s = scl.get(n, 1.0); pb.scale = (s, s, s)
        upd()
        for n in ('Foot.L', 'Foot.R', 'Hand.L', 'Hand.R'):
            tgt, roll = limbs[n]
            ik(n, tgt, roll, name)
        for pb in pbs:
            for p in ('rotation_quaternion', 'location', 'scale'): pb.keyframe_insert(p, frame=1 + f)
    for fc in act.fcurves:
        for kp in fc.keyframe_points: kp.interpolation = 'LINEAR'
    act.use_fake_user = True
    tr = ao.animation_data.nla_tracks.new(); tr.name = name; tr.strips.new(name, 1, act); tr.mute = True
    ao.animation_data.action = None
    print('clip', name, frames, 'frames', round(frames / FPS, 3), 's', 'loop' if loop else '', 'max IK miss', round(ERR.get(name, 0), 4), sorted(MISS.get(name, [])))
def add(*ds):
    o = {}
    for d in ds:
        for k, v in d.items():
            a = o.get(k, (0, 0, 0)); o[k] = (a[0] + v[0], a[1] + v[1], a[2] + v[2])
    return o
def all_planted(**kw): return {n: planted(n, **kw) for n in G}
# ---------- move: heavy knuckle-walk, 0.667 s; 4 footfalls per loop, the body drops on each fist plant ----------
def walk_body(t, lean=6.0, bob=0.022, low=0.0, sway=1.0):
    ph = lambda f: t - f / N
    rot = {'Hips': (2 + 1.5 * C(2 * ph(7)), 0, 4 * sway * S(ph(0) + 0.25)),
           'Spine': (2, 1.5 * sway * S(ph(5)), -2 * sway * S(ph(0) + 0.25)),
           'Chest': (lean + 1.5 * C(2 * ph(7.5)), 3.0 * sway * S(ph(5) - 0.25 + 0.5), -5 * sway * S(ph(5) + 0.25)),
           'Neck': (-lean * 0.5 - 1.5 * C(2 * ph(8)), 0, 3 * sway * S(ph(5) + 0.25)),
           'Head': (-lean * 0.4 - 2.0 * C(2 * ph(9)), -1.5 * sway * S(ph(5) - 0.25), 3 * sway * S(ph(5) + 0.25))}
    for s, sg in SIDES:     # the clavicle heaves up over the arm that's carrying the weight
        st = START['Hand.' + s] / N + DUTY['Hand'] / N / 2
        rot['Shoulder.' + s] = (0, -sg * 4 * sway * C(t - st), 0)
    loc = {'Hips': (0.012 * sway * S(ph(0) - 0.25), 0.0, -low - bob - bob * C(2 * ph(7)))}
    return rot, loc
def move(t, k):
    rot, loc = walk_body(t)
    limbs = {n: contact(n, k, N, DUTY[n.split('.')[0]], V) for n in G}
    return rot, loc, {}, limbs
clip('move', N, move)
# ---------- slowed: dragging through the frost: lower, a long laboured 1.0 s cycle, low dragging steps, shivering ----------
NS = 30; SLOWED_FOR = 0.35      # its stride matches a 35% slow (the common ones are 30-40%)
def slowed(t, k):
    rot, loc = walk_body(t, lean=12.0, bob=0.03, low=0.05, sway=1.4)
    shiver = 1.2 * S(11 * t)
    rot = add(rot, {'Chest': (shiver, 0, 0.8 * S(13 * t)), 'Head': (6 + 2 * S(9 * t), 2.5 * S(7 * t), 4 * S(t - 0.2)),
                    'Neck': (4, 0, 0)})
    duty = {'Foot': round(DUTY['Foot'] * NS / N), 'Hand': round(DUTY['Hand'] * NS / N)}
    limbs = {n: contact(n, k, NS, duty[n.split('.')[0]], V * (1 - SLOWED_FOR), lift_scale=0.6, drag=0.5) for n in G}
    return rot, loc, {}, limbs
clip('slowed', NS, slowed)
# ---------- idle: planted on its fists, heavy breathing, looking around (2 s) ----------
def idle(t, k):
    b = S(t)
    rot = {'Hips': (1 * b, 0, 0), 'Chest': (2 + 2.5 * b, 0, 0), 'Neck': (-1.5 * b, 0, 4 * S(t + 0.1)),
           'Head': (-1 * b + 3 * S(t * 1 - 0.3), 0, 6 * S(t + 0.15)), 'Shoulder.L': (0, -2.5 * b, 0), 'Shoulder.R': (0, 2.5 * b, 0)}
    loc = {'Hips': (0, 0, -0.012 + 0.012 * b)}
    return rot, loc, {}, all_planted()
clip('idle', 60, idle)
# ---------- stun: dazed, swaying in a slow circle on locked limbs, head lolling (1.4 s) ----------
def stun(t, k):
    rot = {'Hips': (4, 3 * S(t), 3 * S(t + 0.25)), 'Spine': (3, 3 * S(t - 0.1), 0), 'Chest': (8, 5 * S(t - 0.2), 4 * S(t + 0.05)),
           'Neck': (14 + 4 * C(t), 8 * S(t - 0.3), 0), 'Head': (12 + 6 * C(t), 12 * S(t - 0.35), 10 * S(t - 0.1))}
    loc = {'Hips': (0.04 * S(t), 0.03 * C(t), -0.05)}
    return rot, loc, {}, all_planted()
clip('stun', 42, stun)
# ---------- frozen: braced, caught mid-flinch (held; the game freezes the clock) ----------
def frozen(t, k):
    rot = {'Hips': (-2, 0, 0), 'Chest': (-4, 0, 6), 'Neck': (-4, 0, 0), 'Head': (-8, 0, 10), 'Shoulder.L': (0, -6, 0), 'Shoulder.R': (0, 6, 0)}
    loc = {'Hips': (0, 0.02, -0.03)}
    lim = all_planted(); lim['Hand.R'] = planted('Hand.R', dy=-0.05, roll=8)
    return rot, loc, {}, lim
clip('frozen', 30, frozen)
# ---------- knockback: rocked back onto its heels, fists torn off the ground, then slams back down (0.7 s) ----------
def knock(t, k):
    a = math.sin(math.pi * min(1.0, t / 0.55)) if t < 0.55 else 0.0
    rot = {'Hips': (-14 * a, 0, 0), 'Spine': (-8 * a, 0, 0), 'Chest': (-14 * a, 0, 0), 'Head': (18 * a, 0, 0)}
    loc = {'Hips': (0, 0.10 * a, 0.03 * a)}
    lim = all_planted()
    for s, sg in SIDES:
        tg, _ = planted('Hand.' + s)
        lim['Hand.' + s] = (tg + Vector((sg * 0.06 * a, 0.28 * a, 0.42 * a)), 30 * a)
    return rot, loc, {}, lim
clip('knockback', 21, knock, loop=False)
# ---------- attack: rears up and drives both fists down (ground pound), 0.9 s; impact at 0.45 s ----------
def attack(t, k):
    up = sm(t / 0.35) * (1 - sm((t - 0.38) / 0.12))      # rear up
    sl = sm((t - 0.38) / 0.1)                           # slam
    rc = sm((t - 0.65) / 0.35)                          # recover
    imp = math.exp(-((t - 0.5) / 0.05) ** 2)            # impact shudder
    rot = {'Hips': (-10 * up + 6 * sl * (1 - rc), 0, 0), 'Spine': (-12 * up + 6 * sl * (1 - rc), 0, 0),
           'Chest': (-20 * up + 12 * sl * (1 - rc) + 3 * imp, 0, 0), 'Neck': (6 * up, 0, 0), 'Head': (-14 * up + 8 * imp, 0, 0),
           'Shoulder.L': (0, -10 * up, 0), 'Shoulder.R': (0, 10 * up, 0)}
    loc = {'Hips': (0, 0.10 * up - 0.06 * sl * (1 - rc), 0.10 * up - 0.06 * sl * (1 - rc))}
    lim = {n: planted(n) for n in ('Foot.L', 'Foot.R')}
    for s, sg in SIDES:
        rest, _ = planted('Hand.' + s)
        high = Vector((sg * 0.45, -0.30, 1.55))                 # fists up over the head
        slam = Vector((sg * 0.42, -0.62, 0.21))                 # just in front, on the ground
        p = rest.lerp(high, up) if t < 0.4 else high.lerp(slam, sl)
        if t >= 0.4: p = p.lerp(rest, rc) + Vector((0, 0, 0.10 * math.sin(math.pi * rc)))   # lifts the fists back into place
        lim['Hand.' + s] = (p, None if (up > 0.3 and sl < 0.9) else 0.0)
    return rot, loc, {}, lim
clip('attack', 27, attack, loop=False)
# ---------- hit: a heavy flinch (0.3 s) ----------
def hit(t, k):
    a = math.sin(math.pi * t) * (1 - 0.3 * t)
    rot = {'Hips': (-4 * a, 0, 0), 'Chest': (-9 * a, 0, 4 * a), 'Neck': (-4 * a, 0, 0), 'Head': (-10 * a, 0, 8 * a)}
    loc = {'Hips': (0, 0.035 * a, 0.01 * a)}
    return rot, loc, {}, all_planted()
clip('hit', 9, hit, loop=False)
# ---------- spawn: forms out of the rift in a short hop (grows from nothing), lands in a crouch, roars (0.9 s) ----------
# (kept within a small hop: the game draws each enemy in its own little viewport)
def spawn(t, k):
    g = sm(t / 0.3)
    land = math.exp(-((t - 0.36) / 0.09) ** 2)
    roar = math.sin(math.pi * sm((t - 0.5) / 0.45))
    rot = {'Hips': (6 * land, 0, 0), 'Chest': (10 * land - 16 * roar, 0, 0), 'Neck': (-6 * roar, 0, 0), 'Head': (6 * land - 22 * roar, 0, 0),
           'Shoulder.L': (0, -8 * roar, 0), 'Shoulder.R': (0, 8 * roar, 0)}
    hop = 0.25 * math.sin(math.pi * min(1.0, t / 0.3))
    loc = {'Root': (0, 0, hop), 'Hips': (0, 0, -0.14 * land + 0.04 * roar)}
    lim = all_planted()
    if t < 0.3:          # limbs tucked while it's in the air
        for n in G:
            tg, _ = planted(n); lim[n] = (tg + Vector((0, 0, hop + 0.06 * math.sin(math.pi * t / 0.3))), None)
    sc_ = max(0.05, g * (1 + 0.06 * math.sin(math.pi * min(1.0, t / 0.36))))
    lim = {n: (tg * sc_, r) for n, (tg, r) in lim.items()}   # the limbs' targets grow with it (Root scales about the origin)
    return rot, loc, {'Root': sc_}, lim
clip('spawn', 27, spawn, loop=False)
# ---------- death: rocked back, staggers, knees buckle, crashes forward onto its chest, arms splayed (1.8 s) ----------
# Ends low and flat for the game's hold, sink and fade.
def death(t, k):
    r = sm(t / 0.1) * (1 - sm((t - 0.12) / 0.15))       # recoil
    st = sm((t - 0.15) / 0.2) * (1 - sm((t - 0.45) / 0.15))   # stagger
    b = sm((t - 0.35) / 0.3)                            # knees buckle
    f = sm((t - 0.55) / 0.25)                           # crash forward
    imp = math.exp(-((t - 0.8) / 0.05) ** 2)            # bounce on impact
    rot = {'Hips': (-8 * r + 20 * f, 4 * st * S(1.5 * t), 6 * st), 'Spine': (-6 * r + 12 * f, 3 * st, 0),
           'Chest': (-12 * r + 24 * f - 4 * imp, 6 * st, -6 * st), 'Neck': (6 * r + 12 * f, 0, 0),
           'Head': (14 * r - 10 * st + 30 * f, -10 * st + 8 * f, 12 * st - 6 * f), 'Shoulder.L': (0, 10 * f, 0), 'Shoulder.R': (0, -10 * f, 0)}
    loc = {'Hips': (0.03 * st, 0.06 * r - 0.06 * f, -0.32 * b - 0.27 * f + 0.03 * imp)}
    lim = {}
    for s, sg in SIDES:
        tg, _ = planted('Foot.' + s); lim['Foot.' + s] = (tg + Vector((0, 0.04 * b, 0)), 18 * b)
        rest, _ = planted('Hand.' + s)
        lift = Vector((sg * 0.05, 0.10, 0.35)) * (r + st * (1.0 if s == 'R' else 0.3))
        splay = Vector((sg * 0.34, -0.14, -0.10)) * f
        lim['Hand.' + s] = (rest + lift + splay, None if (r + st) > 0.4 and f < 0.5 else 25 * f)
    return rot, loc, {}, lim
clip('death', 54, death, loop=False)
bpy.ops.wm.save_as_mainfile(filepath=blend.replace('.blend', '_anim.blend'))
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animation_mode='ACTIONS', export_force_sampling=True,
    export_frame_step=1, export_anim_single_armature=True, export_def_bones=False, export_image_format='AUTO', export_yup=True,
    export_apply=False, export_anim_slide_to_zero=True)
print('V', round(V, 5), 'EXPORTED', [a.name for a in bpy.data.actions])
