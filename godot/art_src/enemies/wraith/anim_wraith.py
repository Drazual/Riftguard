"""Wraith clips (30 fps; every loop's last key equals its first and every clip exports starting at t=0) and the GLB.
blender -b --factory-startup -P anim_wraith.py -- rigged.blend wraith_raw.glb"""
import bpy, sys, math
from mathutils import Euler, Vector, Quaternion
blend, out = sys.argv[sys.argv.index('--')+1:][:2]
bpy.ops.wm.open_mainfile(filepath=blend)
ao = bpy.data.objects['Armature']; FPS = 30; bpy.context.scene.render.fps = FPS
ao.animation_data_create()
REST = {b.name: b.matrix_local.to_quaternion() for b in ao.data.bones}
TAU = 2 * math.pi
def S(x): return math.sin(TAU * x)
def C(x): return math.cos(TAU * x)
def sm(t): t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)
def lerp(a, b, t): return a + (b - a) * t
def wq(e): return Euler([math.radians(x) for x in e], 'XYZ').to_quaternion()
SIDES = (('L', 1), ('R', -1))
def clip(name, frames, pose_at, loop=True):
    """pose_at(t) -> (rot {bone: world-axis euler deg}, loc {bone: world offset m}, scale {bone: s}); keyed on every frame"""
    act = bpy.data.actions.new(name); ao.animation_data.action = act
    for f in range(frames + 1):
        t = f / frames
        rot, loc, scl = pose_at(t)
        for pb in ao.pose.bones:
            B = REST[pb.name]; pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = B.inverted() @ wq(rot.get(pb.name, (0, 0, 0))) @ B
            pb.location = B.inverted() @ Vector(loc.get(pb.name, (0, 0, 0)))
            s = scl.get(pb.name, 1.0); pb.scale = (s, s, s)
            for p in ('rotation_quaternion', 'location', 'scale'): pb.keyframe_insert(p, frame=1 + f)
    act.use_fake_user = True
    tr = ao.animation_data.nla_tracks.new(); tr.name = name; tr.strips.new(name, 1, act); tr.mute = True
    ao.animation_data.action = None
    print('clip', name, frames, 'frames', round(frames / FPS, 3), 's', 'loop' if loop else '')
def add(*ds):
    o = {}
    for d in ds:
        for k, v in d.items():
            a = o.get(k, (0, 0, 0)); o[k] = (a[0] + v[0], a[1] + v[1], a[2] + v[2])
    return o
# ---------- building blocks (degrees about world axes; X+ leans forward / swings a hanging part back) ----------
def tail(t, amp=8.0, trail=6.0, lat=7.0, speed=1, lag=0.11):
    d = {}
    for i in range(1, 8):
        ph = speed * t - lag * i
        d['Tail%d' % i] = (trail * (0.4 + 0.12 * i) + amp * (0.5 + 0.1 * i) * S(ph), lat * (0.5 + 0.12 * i) * S(ph + 0.25), 0)
    return d
def ribbons(t, amp=10.0, trail=12.0, speed=1):
    d = {}
    for s, sg in SIDES:
        for i in range(1, 4):
            ph = speed * t - 0.13 * i + (0.0 if s == 'L' else 0.37)
            d['Ribbon%d.%s' % (i, s)] = (trail * (0.5 + 0.3 * i) + amp * S(ph), sg * 4 * S(ph + 0.2), 0)
    return d
def hair(t, lift=8.0, amp=6.0, speed=1):
    return {'Hair%d' % i: (-lift * (0.6 + 0.2 * i) + amp * S(speed * t - 0.12 * i), 0, 3 * S(speed * t - 0.12 * i + 0.3)) for i in (1, 2, 3)}
def arms(raise_=0.0, back=0.0, bend=0.0, wave=0.0, t=0.0, speed=1, shiver=0.0):
    d = {}
    for s, sg in SIDES:
        ph = speed * t + (0 if s == 'L' else 0.5)
        w = wave * S(ph)
        sh = shiver * S(8 * t + (0.1 if s == 'L' else 0.6))
        d['UpperArm.' + s] = (w * 0.3 + sh, -sg * raise_ + w * 0.6, sg * back)
        d['ForeArm.' + s] = (-bend + w * 0.5, -sg * raise_ * 0.3 + w * 0.8 + sh, sg * back * 0.4)
        d['Hand.' + s] = (-bend * 0.5 + w, sh * 1.5, sg * back * 0.3)
    return d
def crystals(t, amp=0.035, speed=1, orbit=0.03, spread=1.0, drop=0.0, scale=1.0):
    loc, scl, rot = {}, {}, {}
    for i, ph in ((1, 0.0), (2, 0.33), (3, 0.66)):
        a = TAU * (speed * t + ph)
        loc['Crystal%d' % i] = (orbit * math.cos(a) * spread, orbit * math.sin(a) * spread, amp * S(speed * t + ph) - drop)
        rot['Crystal%d' % i] = (0, 0, 360 * speed * t + 120 * i)
        scl['Crystal%d' % i] = scale
    return rot, loc, scl
def merge(*parts):
    r, l, s = {}, {}, {}
    for p in parts:
        r = add(r, p[0]); l = add(l, p[1]); s.update(p[2])
    return r, l, s
# ---------- idle: hovering in place, breathing, tail and ribbons drifting (2 s) ----------
def idle(t):
    body = add({'Hips': (2 * S(t), 0, 2 * S(t + 0.2)), 'Spine': (3, 0, 0), 'Chest': (2 * S(t - 0.1), 0, 0), 'Neck': (-2, 0, 0),
                'Head': (-4 + 3 * S(t - 0.2), 0, 4 * S(t * 1 + 0.4))},
               tail(t, 6, 2, 6), ribbons(t, 8, 4), hair(t, 2, 4), arms(raise_=6, back=4, bend=14, wave=6, t=t))
    return merge((body, {'Hips': (0, 0, 0.035 * S(t))}, {}), crystals(t))
clip('idle', 60, idle)
# ---------- move: a gliding drift, leaning in, tail and ribbons streaming back in a travelling wave (1.2 s) ----------
# Everything is a sine of the loop (no steps), so it reads the same played at any rate: at 0.5x it is a slower glide.
def move(t):
    body = add({'Root': (0, 0, 0), 'Hips': (10 + 2 * S(t), 0, 3 * S(t)), 'Spine': (8 + 2 * S(t - 0.08), 0, -2 * S(t)),
                'Chest': (4 + 2 * S(t - 0.16), 0, -2 * S(t - 0.1)), 'Neck': (-8, 0, 0), 'Head': (-10 - 2 * S(t - 0.25), 0, 3 * S(t - 0.2))},
               tail(t, 9, 16, 9), ribbons(t, 12, 30), hair(t, 18, 7, 2),
               arms(raise_=14, back=34, bend=22, wave=9, t=t))
    return merge((body, {'Hips': (0.012 * S(t + 0.25), 0, 0.05 * S(t) - 0.01)}, {}), crystals(t, amp=0.03, orbit=0.02, spread=1.3))
clip('move', 36, move)
# ---------- slowed: dragging itself on, heavy and low, a slow labouring surge, frost-shivering arms (1.6 s) ----------
def slowed(t):
    surge = 0.5 - 0.5 * C(t)                      # one slow push per loop
    sag = S(t - 0.1)
    body = add({'Hips': (16 + 5 * surge, 0, 2 * S(t)), 'Spine': (10 + 4 * surge, 0, -3 * S(t)),
                'Chest': (6 + 3 * sag + 0.8 * S(10 * t), 0, 0), 'Neck': (-4 + 2 * sag, 0, 0),
                'Head': (2 + 4 * sag + 1.2 * S(12 * t), 1.5 * S(6 * t), 5 * S(t - 0.3))},   # head shaking off the cold
               tail(t, 6, 6, 5, lag=0.14), ribbons(t, 6, 10), hair(t, 6, 4),
               arms(raise_=-6, back=16, bend=48 - 10 * surge, wave=6, t=t, shiver=2.5))
    return merge((body, {'Hips': (0, 0.0, -0.09 + 0.05 * surge - 0.012 * sag)}, {}), crystals(t, amp=0.02, orbit=0.012, drop=0.05))
clip('slowed', 48, slowed)
# ---------- stun: dazed, lolling, the crystals spinning wide (1.4 s) ----------
def stun(t):
    body = add({'Hips': (6, 6 * S(t), 0), 'Spine': (4, 4 * S(t - 0.1), 0), 'Chest': (4, 3 * S(t - 0.2), 0),
                'Neck': (14 + 5 * C(t), 8 * S(t), 0), 'Head': (10 + 8 * C(t), 12 * S(t), 8 * S(t))},
               tail(t, 5, 0, 4), ribbons(t, 5, 0), hair(t, 0, 5), arms(raise_=-12, back=6, bend=8, wave=4, t=t))
    return merge((body, {'Hips': (0.02 * S(t), 0.015 * C(t), -0.06)}, {}), crystals(t, amp=0.02, speed=2, orbit=0.08, spread=1.0, drop=0.02))
clip('stun', 42, stun)
# ---------- frozen: caught recoiling, arms up (held; the game stops the clock on it) ----------
def frozen(t):
    body = add({'Hips': (-6, 0, 0), 'Spine': (-4, 0, 0), 'Chest': (-2, 0, 0), 'Head': (12, 0, -10)},
               {'UpperArm.L': (-50, 0, 30), 'UpperArm.R': (-50, 0, -30), 'ForeArm.L': (-60, 0, 0), 'ForeArm.R': (-60, 0, 0)},
               tail(0.1, 0, 6, 0), ribbons(0.1, 0, 8), hair(0.0, 4, 0))
    return merge((body, {'Hips': (0, 0, -0.03)}, {}), crystals(0.0, amp=0, orbit=0.02))
clip('frozen', 30, frozen)
# ---------- knockback: thrown back, recovers (0.7 s) ----------
def knock(t):
    k = math.sin(math.pi * min(1, t / 0.45)) if t < 0.45 else 0.0
    r = sm((t - 0.3) / 0.7)
    body = add({'Hips': (-24 * k, 0, 0), 'Spine': (-12 * k, 0, 0), 'Head': (20 * k, 0, 0)},
               arms(raise_=30 * k, back=-20 * k, bend=10, t=t), tail(t, 4, -20 * k + 8 * r, 4), ribbons(t, 4, -15 * k), hair(t, -10 * k, 3))
    return merge((body, {'Hips': (0, 0.12 * k, 0.04 * k)}, {}), crystals(t))
clip('knockback', 21, knock, loop=False)
# ---------- attack: a raking two-claw swipe at whatever holds it up (0.9 s) ----------
def attack(t):
    w = sm(t / 0.25) * (1 - sm((t - 0.3) / 0.15))          # right wind-up
    s1 = sm((t - 0.25) / 0.1) * (1 - sm((t - 0.55) / 0.2))  # right slash
    w2 = sm((t - 0.35) / 0.15) * (1 - sm((t - 0.55) / 0.1))
    s2 = sm((t - 0.55) / 0.1) * (1 - sm((t - 0.8) / 0.2))
    body = add({'Hips': (8 + 10 * (s1 + s2), 0, 14 * w - 18 * s1 - 14 * w2 + 18 * s2), 'Spine': (6 + 6 * (s1 + s2), 0, 8 * w - 10 * s1 - 8 * w2 + 10 * s2),
                'Head': (-8, 0, -6 * w + 6 * s1)},
               {'UpperArm.R': (-60 * w - 70 * s1, 0, -40 * w + 50 * s1), 'ForeArm.R': (-40 * w + 10 * s1, 0, 0),
                'UpperArm.L': (-60 * w2 - 70 * s2, 0, 40 * w2 - 50 * s2), 'ForeArm.L': (-40 * w2 + 10 * s2, 0, 0)},
               arms(raise_=10, back=10, bend=20, t=t), tail(t, 6, 8, 8), ribbons(t, 8, 10), hair(t, 6, 4))
    return merge((body, {'Hips': (0, -0.1 * (s1 + s2), -0.02)}, {}), crystals(t))
clip('attack', 27, attack, loop=False)
# ---------- hit: a quick flinch (0.3 s) ----------
def hit(t):
    k = math.sin(math.pi * t) * (1 - t * 0.3)
    body = add({'Hips': (-10 * k, 0, 0), 'Spine': (-8 * k, 0, 0), 'Head': (12 * k, 0, 6 * k)}, arms(raise_=10 * k, back=10, bend=20, t=0),
               tail(t, 3, 6 - 8 * k, 3), ribbons(t, 3, 6), hair(t, 4 - 6 * k, 2))
    return merge((body, {'Hips': (0, 0.05 * k, 0.02 * k)}, {}), crystals(t))
clip('hit', 9, hit, loop=False)
# ---------- spawn: rises out of the ground, unfurling (0.9 s) ----------
def spawn(t):
    g = sm(t / 0.75); u = sm((t - 0.35) / 0.55)
    body = add({'Hips': (20 * (1 - u), 0, 0), 'Spine': (20 * (1 - u), 0, 0), 'Head': (25 * (1 - u), 0, 0)},
               arms(raise_=-20 + 30 * u, back=-10 + 10 * u, bend=60 * (1 - u) + 14 * u, t=t), tail(t, 6, 30 * (1 - u), 6), ribbons(t, 6, 25 * (1 - u)), hair(t, -10 * (1 - u), 3))
    cr = crystals(t, scale=sm((t - 0.5) / 0.4), drop=0.3 * (1 - u))
    return merge((body, {'Root': (0, 0, 0), 'Hips': (0, 0, -0.5 * (1 - g))}, {'Root': max(0.05, g)}), cr)
clip('spawn', 27, spawn, loop=False)
# ---------- death: recoils, writhes up, then collapses and dissipates into a small crumpled wisp on the ground ----------
# The end pose is held (the game holds it, then sinks and fades it): compact, crystals gone, nothing sticking out.
def death(t):
    r = sm(t / 0.12) * (1 - sm((t - 0.15) / 0.2))          # recoil
    w = sm((t - 0.12) / 0.3) * (1 - sm((t - 0.5) / 0.2))   # writhing rise
    c = sm((t - 0.45) / 0.4)                                # collapse
    f = sm((t - 0.6) / 0.35)                                # dissipate (shrink)
    body = add({'Hips': (-18 * r - 10 * w + 40 * c, 10 * w * S(3 * t), 0), 'Spine': (-10 * r + 30 * c, 8 * w * S(3 * t + 0.2), 0),
                'Chest': (20 * c, 0, 0), 'Neck': (15 * c, 0, 0), 'Head': (20 * r - 10 * w + 25 * c, 0, 12 * w)},
               arms(raise_=40 * r + 50 * w - 70 * c, back=-10 * r + 20 * c, bend=10 + 60 * c, t=t),
               {'Tail%d' % i: (-20 * c + 35 * c * (i % 2), 0, 0) for i in range(1, 8)},
               tail(t, 10 * (1 - c), 0, 10 * (1 - c), speed=2), ribbons(t, 10 * (1 - c), -20 * c, speed=2), hair(t, 10 * w - 20 * c, 6 * (1 - c), speed=2))
    cr = crystals(t, amp=0.02, orbit=0.03 + 0.2 * c, spread=1.0, drop=0.9 * c, scale=1 - sm((t - 0.55) / 0.3))
    return merge((body, {'Hips': (0, 0.0, 0.08 * w - 0.75 * c)}, {'Hips': 1 - 0.45 * f, 'Tail5': 1 - 0.6 * f, 'Tail6': 1 - 0.8 * f, 'Tail7': 1 - 0.9 * f,
                                                                   'Ribbon3.L': 1 - 0.8 * f, 'Ribbon3.R': 1 - 0.8 * f, 'Hair3': 1 - 0.6 * f}), cr)
clip('death', 45, death, loop=False)
bpy.ops.wm.save_as_mainfile(filepath=blend.replace('.blend', '_anim.blend'))
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animation_mode='ACTIONS', export_force_sampling=True,
    export_frame_step=1, export_anim_single_armature=True, export_def_bones=False, export_image_format='AUTO', export_yup=True,
    export_apply=False, export_anim_slide_to_zero=True)
print('EXPORTED', [a.name for a in bpy.data.actions])
