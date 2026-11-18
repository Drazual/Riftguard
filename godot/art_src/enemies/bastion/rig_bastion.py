"""Bastion: imports the source sculpt (one fused 1.75M-triangle mesh), merges its UV-seam splits, cuts it to ~20k
triangles, puts its soles on the ground at the origin and builds a 19-bone knuckle-walker skeleton (hips, spine, chest,
neck, head; clavicle/upper arm/forearm/fist and thigh/shin/foot on each side), skinned with distance weights limited by
body region (so the long forearms never pull the legs and the other way round).
blender -b --factory-startup -P rig_bastion.py -- bastion_src.glb rigged.blend"""
import bpy, sys, bmesh
from mathutils import Vector
src, out = sys.argv[sys.argv.index('--')+1:][:2]
TRIS = 20000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=src)
ob = [o for o in bpy.data.objects if o.type == 'MESH'][0]
ob.name = ob.data.name = 'Bastion'
bpy.context.view_layer.objects.active = ob; ob.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = ob.data
bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005); bm.to_mesh(me); bm.free()
t0 = sum(len(p.vertices) - 2 for p in me.polygons)
m = ob.modifiers.new('dec', 'DECIMATE'); m.ratio = TRIS / t0; m.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier='dec')
DZ = -min(v.co.z for v in me.vertices)        # soles on the ground
for v in me.vertices: v.co.z += DZ
print('tris', t0, '->', sum(len(p.vertices) - 2 for p in me.polygons), 'verts', len(me.vertices), 'DZ', round(DZ, 4))
# ---- skeleton (source coordinates; +DZ). The model faces -Y (glTF +Z) and X+ is its left. ----
J = {
 'Root': ((0, 0, -DZ), (0, 0, -DZ + 0.2), None),
 'Hips': ((0, 0.32, -0.08), (0, 0.18, 0.12), 'Root'),
 'Spine': ((0, 0.18, 0.12), (0, 0.02, 0.30), 'Hips'),
 'Chest': ((0, 0.02, 0.30), (0, -0.15, 0.42), 'Spine'),
 'Neck': ((0, -0.15, 0.42), (0, -0.30, 0.45), 'Chest'),
 'Head': ((0, -0.30, 0.45), (0, -0.60, 0.50), 'Neck'),
}
SIDE = {'Shoulder': ((0.12, -0.04, 0.36), (0.55, -0.04, 0.33), 'Chest'),
        'UpperArm': ((0.55, -0.04, 0.33), (0.68, -0.08, -0.06), 'Shoulder'),
        'ForeArm': ((0.68, -0.08, -0.06), (0.70, -0.34, -0.62), 'UpperArm'),
        'Hand': ((0.70, -0.34, -0.62), (0.70, -0.40, -0.80), 'ForeArm'),
        'Thigh': ((0.24, 0.38, -0.05), (0.28, 0.24, -0.37), 'Hips'),
        'Shin': ((0.28, 0.24, -0.37), (0.31, 0.50, -0.68), 'Thigh'),
        'Foot': ((0.31, 0.50, -0.68), (0.33, 0.24, -0.80), 'Shin')}
for n, (h, t, p) in SIDE.items():
    for s, sg in (('L', 1), ('R', -1)):
        J[n + '.' + s] = ((sg * h[0], h[1], h[2]), (sg * t[0], t[1], t[2]), p if p in J else p + '.' + s)
arm = bpy.data.armatures.new('Armature'); ao = bpy.data.objects.new('Armature', arm)
bpy.context.scene.collection.objects.link(ao)
bpy.context.view_layer.objects.active = ao; bpy.ops.object.mode_set(mode='EDIT')
for n, (h, t, p) in J.items():
    b = arm.edit_bones.new(n); b.head = Vector(h) + Vector((0, 0, DZ)); b.tail = Vector(t) + Vector((0, 0, DZ))
    b.roll = 0
for n, (h, t, p) in J.items():
    if p: arm.edit_bones[n].parent = arm.edit_bones[p]; arm.edit_bones[n].use_connect = False
bpy.ops.object.mode_set(mode='OBJECT')
# ---- weights ----
SEG = {n: (Vector(h) + Vector((0, 0, DZ)), Vector(t) + Vector((0, 0, DZ))) for n, (h, t, p) in J.items()}
def seg_d(p, a, b):
    ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab) / ab.dot(ab))); return (p - (a + ab * t)).length
def allowed(p):
    q = p - Vector((0, 0, DZ)); ax = abs(q.x); s = 'L' if q.x > 0 else 'R'
    if q.z < -0.1 and ax >= 0.49 and q.y < 0.12:                 # forearm gauntlet and fist
        return ['ForeArm.' + s, 'Hand.' + s, 'UpperArm.' + s]
    if q.z < -0.1 and q.y > -0.05 and ax < 0.56:                  # legs
        return ['Thigh.' + s, 'Shin.' + s, 'Foot.' + s] + (['Hips'] if q.z > -0.3 else [])
    if ax > 0.36 and q.z >= -0.1:                                 # pauldron, upper arm, elbow
        return ['Shoulder.' + s, 'UpperArm.' + s, 'ForeArm.' + s] + (['Chest'] if ax < 0.5 else [])
    out = ['Hips', 'Spine', 'Chest', 'Shoulder.' + s]
    if q.z > 0.25: out += ['Neck', 'Head']
    if q.z < 0.05 and q.y > 0.1 and ax > 0.1: out += ['Thigh.' + s]
    return out
groups = {n: ob.vertex_groups.new(name=n) for n in J if n != 'Root'}
for v in me.vertices:
    ds = sorted(((seg_d(v.co, *SEG[n]), n) for n in allowed(v.co)))[:3]
    ws = [(1.0 / (d * d + 0.0006) ** 2, n) for d, n in ds]; tot = sum(w for w, _ in ws)
    for w, n in ws:
        if w / tot > 0.02: groups[n].add([v.index], w / tot, 'REPLACE')
bpy.context.view_layer.objects.active = ob
bpy.ops.object.mode_set(mode='WEIGHT_PAINT')
bpy.ops.object.vertex_group_smooth(group_select_mode='ALL', factor=0.5, repeat=5)
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
bpy.ops.object.mode_set(mode='OBJECT')
# fists and feet go rigidly with their bones below the wrist/ankle (blended over a few cm above), so a planted sole
# doesn't shift when the shin or forearm turns
def rigid(v, bone, upper, z0, z1):
    q = v.co.z - DZ
    if q >= z1: return
    w = 1.0 if q <= z0 else (z1 - q) / (z1 - z0)
    keep = {g.group: g.weight for g in v.groups}
    for gidx in list(keep):
        ob.vertex_groups[gidx].remove([v.index])
    others = {gidx: wt for gidx, wt in keep.items() if ob.vertex_groups[gidx].name != bone}
    tot = sum(others.values())
    groups[bone].add([v.index], w + (1 - w) * keep.get(groups[bone].index, 0.0) / max(1e-6, tot + keep.get(groups[bone].index, 0.0)), 'REPLACE')
    rest_w = 1.0 - groups[bone].weight(v.index)
    if rest_w > 1e-4:
        if tot > 1e-6:
            for gidx, wt in others.items(): ob.vertex_groups[gidx].add([v.index], rest_w * wt / tot, 'REPLACE')
        else:
            groups[upper].add([v.index], rest_w, 'REPLACE')
for v in me.vertices:
    names = {ob.vertex_groups[g.group].name: g.weight for g in v.groups}
    for s in ('L', 'R'):
        if names.get('Foot.' + s, 0) + names.get('Shin.' + s, 0) > 0.5:
            rigid(v, 'Foot.' + s, 'Shin.' + s, -0.71, -0.64)
        elif names.get('Hand.' + s, 0) + names.get('ForeArm.' + s, 0) > 0.5 and abs(v.co.x) > 0.45:
            rigid(v, 'Hand.' + s, 'ForeArm.' + s, -0.66, -0.58)
ob.parent = ao; mod = ob.modifiers.new('Armature', 'ARMATURE'); mod.object = ao
for n in ob.material_slots[0].material.node_tree.nodes:
    if n.type == 'TEX_IMAGE' and n.image:
        tos = [l.to_node for o in n.outputs for l in o.links]; socks = [l.to_socket.name for o in n.outputs for l in o.links]
        n.image.name = 'bastion_color' if 'Base Color' in socks else ('bastion_normal' if any(t.type == 'NORMAL_MAP' for t in tos) else 'bastion_orm')
        print('IMG', n.image.name, socks)
bpy.ops.wm.save_as_mainfile(filepath=out)
print('SAVED', out, 'bones', len(arm.bones))
