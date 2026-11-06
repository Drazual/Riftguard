# Writes the hand-posed clips (Hero3D "poses") into a hero.json: the Vanguard's run, punch and shield brace,
# or with "gale" Gale's stance (idle), run, sword slash and shield brace. python3 tools/pose_tank.py art_src/heroes/tank/hero.json [gale]
import json, math, sys
p = sys.argv[1]
hero = sys.argv[2] if len(sys.argv) > 2 else "tank"
cfg = json.load(open(p))
R = lambda v: round(v, 1)

def run(n=12, length=0.6):
    keys = []
    for i in range(n):
        f = 2 * math.pi * i / n
        b = {}
        for side, ph in (("Left", f), ("Right", f + math.pi)):
            thigh = -40 * math.sin(ph) - 6
            knee = 18 + 75 * max(0.0, math.cos(ph)) ** 1.5
            foot = -0.6 * (thigh + knee) + (15 * max(0.0, -math.cos(ph)) if True else 0)
            b[side + "UpLeg"] = [R(thigh), 0, 0]
            b[side + "Leg"] = [R(knee), 0, 0]
            b[side + "Foot"] = [R(foot), 0, 0]
        s = math.sin(f)
        b["RightArm"] = [R(-38 * s - 8), 0, 14]
        b["RightForeArm"] = [R(-70 - 20 * s), 0, 0]
        b["LeftArm"] = [R(8 * s - 14), 0, -4]
        b["LeftForeArm"] = [-30, 0, 0]
        b["Spine"] = [12, R(9 * s), 0]
        b["Spine1"] = [4, 0, 0]
        b["Head"] = [-10, R(-6 * s), 0]
        keys.append({"t": round(length * i / n, 4), "bones": b, "hips": [0, R(-0.05 - 0.035 * math.cos(2 * f)) if False else round(-0.05 - 0.035 * math.cos(2 * f), 3), 0]})
    return {"length": length, "loop": True, "keys": keys}

brace_b = {
    "LeftUpLeg": [-28, 0, 0], "LeftLeg": [42, 0, 0], "LeftFoot": [-12, 0, 0],
    "RightUpLeg": [14, 0, 0], "RightLeg": [30, 0, 0], "RightFoot": [-30, 0, 0],
    "Spine": [10, -22, 0], "Spine1": [4, 0, 0], "Head": [-10, 14, 0],
    "LeftArm": [-50, 0, -25], "LeftForeArm": [-60, 0, 0], "LeftHand": [8, 20, 0],
    "RightArm": [-40, 0, 18], "RightForeArm": [-75, 0, 0],
}
def brace(length=2.0, copy=None):
    breathe = {k: list(v) for k, v in brace_b.items()}
    breathe["Spine"] = [12, -22, 0]
    c = {"length": length, "loop": True, "keys": [
        {"t": 0, "bones": brace_b, "hips": [0, -0.08, 0]},
        {"t": length / 2, "bones": breathe, "hips": [0, -0.09, 0]}]}
    if copy:
        c["copy"] = copy
    return c

def punch():
    zero = {}
    wind = {"Spine": [6, -28, 0], "RightArm": [28, 0, 10], "RightForeArm": [-105, 0, 0],
            "LeftArm": [-30, 0, -10], "LeftForeArm": [-35, 0, 0]}
    hit = {"Spine": [14, 32, 0], "Spine1": [4, 0, 0], "Head": [-8, -20, 0],
           "RightArm": [-82, 0, 26], "RightForeArm": [-8, 0, 0],
           "LeftArm": [-20, 0, -8], "LeftForeArm": [-45, 0, 0],
           "LeftUpLeg": [-22, 0, 0], "LeftLeg": [26, 0, 0], "LeftFoot": [-6, 0, 0],
           "RightUpLeg": [16, 0, 0], "RightLeg": [12, 0, 0], "RightFoot": [-20, 0, 0]}
    return {"length": 0.7, "loop": False, "keys": [
        {"t": 0, "bones": zero},
        {"t": 0.16, "bones": wind, "hips": [0, -0.03, -0.02]},
        {"t": 0.3, "bones": hit, "hips": [0, -0.06, 0.06]},
        {"t": 0.42, "bones": hit, "hips": [0, -0.06, 0.06]},
        {"t": 0.7, "bones": zero}]}

def gale_stance(length=2.0):
    # stands upright with a slight forward set, shield carried at the chest, sword hanging angled down at the side;
    # the chest rises and the arms ease out a little on each breath
    a = {"Spine": [6, -4, 0], "Spine1": [2, 0, 0], "Head": [-2, 3, 0],
         "LeftArm": [-6, 0, -3], "LeftForeArm": [-10, 0, 0],
         "RightArm": [-4, 0, 4], "RightForeArm": [-10, 0, 0], "RightHand": [40, 0, 0]}
    b = {k: list(v) for k, v in a.items()}
    b["Spine"] = [9, -4, 0]
    b["LeftArm"] = [-8, 0, -4]
    b["RightArm"] = [-3, 0, 5]
    return {"length": length, "loop": True, "keys": [
        {"t": 0, "bones": a, "hips": [0, -0.005, 0]},
        {"t": length / 2, "bones": b, "hips": [0, -0.02, 0]}]}

def gale_brace(length=2.0):
    a = {"LeftUpLeg": [-28, 0, 0], "LeftLeg": [40, 0, 0], "LeftFoot": [-12, 0, 0],
         "RightUpLeg": [14, 0, 0], "RightLeg": [30, 0, 0], "RightFoot": [-30, 0, 0],
         "Spine": [10, -24, 0], "Spine1": [4, 0, 0], "Head": [-12, 16, 0],
         "LeftArm": [-52, 0, -28], "LeftForeArm": [-62, 0, 0],
         "RightArm": [18, 0, 12], "RightForeArm": [-70, 0, 0], "RightHand": [20, 0, 0]}
    b = {k: list(v) for k, v in a.items()}
    b["Spine"] = [12, -24, 0]
    return {"length": length, "loop": True, "keys": [
        {"t": 0, "bones": a, "hips": [0, -0.08, 0]},
        {"t": length / 2, "bones": b, "hips": [0, -0.09, 0]}]}

def gale_slash():
    zero = {}
    wind = {"Spine": [-6, -34, 0], "Spine1": [-2, -8, 0], "Head": [4, 20, 0],
            "RightArm": [-150, 0, -22], "RightForeArm": [-55, 0, 0], "RightHand": [-10, 0, 0],
            "LeftArm": [-34, 0, -12], "LeftForeArm": [-40, 0, 0],
            "RightUpLeg": [8, 0, 0], "RightLeg": [10, 0, 0]}
    hit = {"Spine": [16, 36, 0], "Spine1": [6, 8, 0], "Head": [-10, -24, 0],
           "RightArm": [-48, 0, 48], "RightForeArm": [-12, 0, 0], "RightHand": [10, 0, 0],
           "LeftArm": [-14, 0, -10], "LeftForeArm": [-30, 0, 0],
           "LeftUpLeg": [-24, 0, 0], "LeftLeg": [28, 0, 0], "LeftFoot": [-6, 0, 0],
           "RightUpLeg": [16, 0, 0], "RightLeg": [14, 0, 0], "RightFoot": [-22, 0, 0]}
    follow = {k: list(v) for k, v in hit.items()}
    follow["RightArm"] = [-18, 0, 56]
    follow["Spine"] = [18, 42, 0]
    return {"length": 0.7, "loop": False, "keys": [
        {"t": 0, "bones": zero},
        {"t": 0.18, "bones": wind, "hips": [0, -0.02, -0.03]},
        {"t": 0.3, "bones": hit, "hips": [0, -0.07, 0.07]},
        {"t": 0.42, "bones": follow, "hips": [0, -0.07, 0.07]},
        {"t": 0.7, "bones": zero}]}

if hero == "gale":
    fx = ["ShieldAirFX", "SwordAirFX"]
    cfg["poses"] = {"run": run(), "stance": gale_stance(), "brace": gale_brace(), "slash": gale_slash()}
    cfg["poses"]["run"].update({"keep": ["LeftHand", "RightHand"], "copy": {"clip": "walk", "bones": fx, "fit": True}})
    cfg["poses"]["stance"]["copy"] = {"clip": "idle", "bones": fx, "fit": True}
    cfg["poses"]["brace"].update({"keep": ["LeftHand"], "copy": {"clip": "block", "bones": fx, "fit": True}})
    cfg["poses"]["slash"]["copy"] = {"clip": "attack", "bones": fx, "fit": True}
    for c in cfg["poses"].values():
        c["fill_from"] = "attack"
    cfg["anims"].update({"idle": "@stance", "walk": "@run", "fire": "@slash", "block": "@brace"})
    json.dump(cfg, open(p, "w"), indent="\t")
    open(p, "a").write("\n")
    sys.exit()
cfg["poses"] = {
    "run": run(),
    "punch": punch(),
    "brace": brace(),
    "brace_glow": brace(2.0, {"clip": "bulwark_hold", "bones": ["BulwarkFX"]}),
}
for c in cfg["poses"].values():
    c["fill_from"] = "attack"
    c["keep"] = ["LeftHand"]
cfg["anims"] = {"idle": "idle", "walk": "@run", "fire": "@punch", "block": "@brace", "hold": "@brace_glow"}
json.dump(cfg, open(p, "w"), indent="\t")
open(p, "a").write("\n")
