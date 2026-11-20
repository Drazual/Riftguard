# Planted-contact slide check (front edge of each sole, the pivot it rolls over): for each contact bone, the rest-pose sole vertices (weighted >0.5 to it, lowest 3 cm);
# per frame their mean position in model space. While planted (sole within 1.5 cm of its rest height) the sole must move
# backward (+Y, the model faces -Y) at exactly V per frame, so in the world it stays put. args: glb clip V bones(csv) out.json
import bpy, sys, json
a = sys.argv[sys.argv.index('--')+1:]; glb, clip, V, bones, outp = a[0], a[1], float(a[2]), a[3].split(','), a[4]
bpy.ops.wm.read_factory_settings(use_empty=True); sc = bpy.context.scene; sc.render.fps = 30
bpy.ops.import_scene.gltf(filepath=glb)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
me = max([o for o in bpy.data.objects if o.type == 'MESH'], key=lambda o: len(o.data.vertices))
act = [x for x in bpy.data.actions if x.name == clip or x.name.startswith(clip + '_')][0]
arm.animation_data_create(); arm.animation_data.action = act
for tr in list(arm.animation_data.nla_tracks): arm.animation_data.nla_tracks.remove(tr)
gi = {g.name: g.index for g in me.vertex_groups}; W = me.matrix_world
dg = bpy.context.evaluated_depsgraph_get()
sc.frame_set(0)   # glTF importer: rest is before the action; use the mesh data (unposed)
base = [W @ v.co for v in me.data.vertices]
zmin = min(p.z for p in base)
soles = {}
for b in bones:
    ids = [v.index for v in me.data.vertices if any(g.group == gi[b] and g.weight > 0.5 for g in v.groups)]
    lo = min(base[i].z for i in ids); sole = [i for i in ids if base[i].z < lo + 0.02]
    fy = min(base[i].y for i in sole); soles[b] = [i for i in sole if base[i].y < fy + 0.04]   # the front edge it pivots on
f0, f1 = map(int, act.frame_range); rows = {b: [] for b in bones}
for f in range(f0, f1 + 1):
    sc.frame_set(f); e = me.evaluated_get(dg); m = e.to_mesh()
    for b, ids in soles.items():
        ps = [W @ m.vertices[i].co for i in ids]
        rows[b].append([sum(p.x for p in ps) / len(ps), sum(p.y for p in ps) / len(ps), min(p.z for p in ps)])
    e.to_mesh_clear()
res = {'zmin_rest': zmin, 'rows': rows, 'summary': {}}
for b, r in rows.items():
    rest_z = min(base[i].z for i in soles[b])
    worst = 0.0; n = 0; plant = []
    for i in range(1, len(r)):
        if r[i][2] < rest_z + 0.003 and r[i - 1][2] < rest_z + 0.003:
            slide = ((r[i][1] - r[i - 1][1] - V) ** 2 + (r[i][0] - r[i - 1][0]) ** 2) ** 0.5
            worst = max(worst, slide); n += 1; plant.append(i)
    res['summary'][b] = {'planted_steps': n, 'max_slide_per_frame': round(worst, 5), 'rest_sole_z': round(rest_z, 4),
                         'min_z': round(min(x[2] for x in r), 4), 'planted_frames': plant}
json.dump(res, open(outp, 'w')); print('SUMMARY', json.dumps(res['summary']))
