# ours: the loop_check "kink" metric (jerk = accel at a frame unlike its neighbours) at EVERY frame of a cyclic clip,
# so a seam flag can be compared with what the clip does mid-cycle. args: object action[,action...]
import bpy, sys, math, json
from mathutils import Vector
a = sys.argv[sys.argv.index('--')+1:]; ob = bpy.data.objects[a[0]]
def w(p, q):
    d = p.to_quaternion().rotation_difference(q.to_quaternion())
    if d.w < 0: d.negate()
    return Vector(d.to_exponential_map()) * (180 / math.pi)
out = {}
for an in a[1].split(','):
    act = bpy.data.actions[an]; ob.animation_data_create(); ob.animation_data.action = act
    f0, f1 = (int(round(v)) for v in act.frame_range); n = f1 - f0
    P = []
    for f in range(f0, f1):
        bpy.context.scene.frame_set(f); P.append({b.name: b.matrix.copy() for b in ob.pose.bones})
    res = {}
    for bn in P[0]:
        V = [w(P[i][bn], P[(i + 1) % n][bn]) for i in range(n)]          # V[i]: i -> i+1 (cyclic)
        J = []
        for i in range(n):                                               # jerk at frame i (between V[i-1] and V[i])
            vb2, vb1, va0, va1 = V[(i - 2) % n], V[(i - 1) % n], V[i], V[(i + 1) % n]
            ab, aseam, aa = vb1 - vb2, va0 - vb1, va1 - va0
            J.append((aseam - (ab + aa) / 2).length)
        sp = [v.length for v in V]
        res[bn] = {"seam_jerk": round(J[0], 2), "max_interior_jerk": round(max(J[1:]), 2), "rank": sorted(J, reverse=True).index(J[0]) + 1,
                   "speed_max": round(max(sp), 1), "speed_seam": [round(sp[-1], 1), round(sp[0], 1)]}
    worst = sorted(res.items(), key=lambda kv: -kv[1]["seam_jerk"])[:6] + [(k, res[k]) for k in ("Shin.R","Foot.R","Cloth1.R","RightForeArm","RightHand") if k in res]
    out[an] = {"frames": n, "worst_at_seam": worst,
               "bones_where_seam_is_the_max": [k for k, v in res.items() if v["rank"] == 1 and v["seam_jerk"] > 2 and v["seam_jerk"] > 1.5 * v["max_interior_jerk"]]}
print("@@SEAM@@" + json.dumps(out))
