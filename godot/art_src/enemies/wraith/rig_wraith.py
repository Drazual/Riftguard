"""Wraith: imports the source model, merges its UV-seam splits, cuts it to ~14k triangles, lifts it so the tail tip
hovers HOVER m off the ground at the origin, builds a 40-bone skeleton (body, arms, hair, a 7-bone tail, two arm
ribbons, three floating crystals) and skins the mesh with distance weights limited by region (islands: the bangles go
rigidly with the forearms, the crystals with their own bones, the loose ribbon with its ribbon chain).
blender -b --factory-startup -P rig_wraith.py -- wraith_src.glb rigged.blend"""
import bpy, sys, bmesh, math
from mathutils import Vector
src, out = sys.argv[sys.argv.index('--')+1:][:2]
HOVER = 0.2                      # tail tip above the ground (native m; the game scales the model to `height`)
DZ = 0.95 + HOVER
TRIS = 14000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=src)
ob = [o for o in bpy.data.objects if o.type == 'MESH'][0]
ob.name = ob.data.name = 'Wraith'
bpy.context.view_layer.objects.active = ob; ob.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = ob.data
bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005); bm.to_mesh(me); bm.free()
t0 = sum(len(p.vertices) - 2 for p in me.polygons)
m = ob.modifiers.new('dec', 'DECIMATE'); m.ratio = TRIS / t0; m.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier='dec')
for v in me.vertices: v.co.z += DZ
print('tris', t0, '->', sum(len(p.vertices) - 2 for p in me.polygons), 'verts', len(me.vertices))
# ---- skeleton (source coordinates, lifted by DZ); the model faces -Y (glTF +Z), X is its left ----
def mir(p): return (-p[0], p[1], p[2])
J = {
 'Root': ((0, 0, -DZ), (0, 0, -DZ + 0.2), None),
 'Hips': ((0, -0.17, 0.02), (0, -0.16, 0.16), 'Root'),
 'Spine': ((0, -0.16, 0.16), (0, -0.15, 0.32), 'Hips'),
 'Chest': ((0, -0.15, 0.32), (0, -0.14, 0.46), 'Spine'),
 'Neck': ((0, -0.14, 0.46), (0, -0.17, 0.56), 'Chest'),
 'Head': ((0, -0.17, 0.56), (0, -0.2, 0.76), 'Neck'),
 'Hair1': ((0, -0.1, 0.64), (0, 0.08, 0.6), 'Head'), 'Hair2': ((0, 0.08, 0.6), (0, 0.24, 0.5), 'Hair1'), 'Hair3': ((0, 0.24, 0.5), (0, 0.24, 0.3), 'Hair2'),
 'Tail1': ((0, -0.17, 0.02), (0.03, -0.15, -0.18), 'Hips'), 'Tail2': ((0.03, -0.15, -0.18), (-0.06, -0.08, -0.36), 'Tail1'),
 'Tail3': ((-0.06, -0.08, -0.36), (-0.12, 0.0, -0.5), 'Tail2'), 'Tail4': ((-0.12, 0.0, -0.5), (-0.12, 0.08, -0.62), 'Tail3'),
 'Tail5': ((-0.12, 0.08, -0.62), (0.03, 0.02, -0.74), 'Tail4'), 'Tail6': ((0.03, 0.02, -0.74), (-0.05, -0.02, -0.86), 'Tail5'),
 'Tail7': ((-0.05, -0.02, -0.86), (-0.05, 0.01, -0.97), 'Tail6'),
 'Crystal1': ((-0.30, 0.115, 0.62), (-0.30, 0.115, 0.70), 'Root'), 'Crystal2': ((-0.42, 0.115, 0.46), (-0.42, 0.115, 0.54), 'Root'),
 'Crystal3': ((0.315, 0.115, 0.61), (0.315, 0.115, 0.69), 'Root'),
}
ARM = {'Shoulder': ((0.04, -0.14, 0.42), (0.17, -0.13, 0.40), 'Chest'), 'UpperArm': ((0.17, -0.13, 0.40), (0.31, -0.12, 0.22), 'Shoulder'),
       'ForeArm': ((0.31, -0.12, 0.22), (0.44, -0.12, 0.07), 'UpperArm'), 'Hand': ((0.44, -0.12, 0.07), (0.58, -0.14, -0.02), 'ForeArm'),
       'Ribbon1': ((0.33, -0.1, 0.15), (0.40, -0.02, -0.08), 'ForeArm'), 'Ribbon2': ((0.40, -0.02, -0.08), (0.38, 0.12, -0.28), 'Ribbon1'),
       'Ribbon3': ((0.38, 0.12, -0.28), (0.22, 0.2, -0.40), 'Ribbon2')}
RIB_R = {'Ribbon1': ((-0.33, -0.1, 0.15), (-0.40, -0.02, -0.1)), 'Ribbon2': ((-0.40, -0.02, -0.1), (-0.40, 0.12, -0.3)), 'Ribbon3': ((-0.40, 0.12, -0.3), (-0.36, 0.25, -0.45))}
for n, (h, t, p) in ARM.items():
    J[n + '.L'] = (h, t, p + '.L' if p != 'Chest' else p)
    hr, tr = RIB_R[n] if n in RIB_R else (mir(h), mir(t))
    J[n + '.R'] = (hr, tr, p + '.R' if p != 'Chest' else p)
arm = bpy.data.armatures.new('Armature'); ao = bpy.data.objects.new('Armature', arm)
bpy.context.scene.collection.objects.link(ao)
bpy.context.view_layer.objects.active = ao; bpy.ops.object.mode_set(mode='EDIT')
for n, (h, t, p) in J.items():
    b = arm.edit_bones.new(n); b.head = Vector(h) + Vector((0, 0, DZ)); b.tail = Vector(t) + Vector((0, 0, DZ)); b.roll = 0
for n, (h, t, p) in J.items():
    if p: arm.edit_bones[n].parent = arm.edit_bones[p]; arm.edit_bones[n].use_connect = False
bpy.ops.object.mode_set(mode='OBJECT')
# ---- weights ----
SEG = {n: (Vector(h) + Vector((0, 0, DZ)), Vector(t) + Vector((0, 0, DZ))) for n, (h, t, p) in J.items()}
def seg_d(p, a, b):
    ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab) / ab.dot(ab))); return (p - (a + ab * t)).length
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
seen = set(); islands = []
for v in bm.verts:
    if v.index in seen: continue
    st = [v]; comp = []; seen.add(v.index)
    while st:
        x = st.pop(); comp.append(x.index)
        for e in x.link_edges:
            o = e.other_vert(x)
            if o.index not in seen: seen.add(o.index); st.append(o)
    islands.append(comp)
islands.sort(key=len, reverse=True)
fixed = {}       # vertex -> {bone: w}
allowed_island = {}
for comp in islands[1:]:
    c = sum((bm.verts[i].co for i in comp), Vector()) / len(comp); c0 = c - Vector((0, 0, DZ))
    size = max((bm.verts[i].co - c).length for i in comp)
    if size < 0.12:
        b = min(('Crystal1', 'Crystal2', 'Crystal3', 'ForeArm.L', 'ForeArm.R'), key=lambda n: seg_d(c, *SEG[n]))
        for i in comp: fixed[i] = {b: 1.0}
        print('island', len(comp), 'rigid ->', b, [round(x, 2) for x in c0])
    else:
        side = 'L' if c.x > 0 else 'R'
        for i in comp: allowed_island[i] = ['ForeArm.' + side, 'Ribbon1.' + side, 'Ribbon2.' + side, 'Ribbon3.' + side]
        print('island', len(comp), 'ribbon ->', side, [round(x, 2) for x in c0])
def allowed(p):
    q = p - Vector((0, 0, DZ)); ax = abs(q.x); side = 'L' if q.x > 0 else 'R'
    out = []
    if q.z > 0.0: out += ['Hips', 'Spine', 'Chest'] if q.z < 0.55 else ['Chest']
    if q.z > 0.36: out += ['Neck', 'Head']
    if q.z > 0.25 and q.y > -0.12: out += ['Hair1', 'Hair2', 'Hair3']
    if q.z < 0.2 and ax < 0.32: out += ['Tail%d' % i for i in range(1, 8)]
    if ax > 0.13 and q.z > -0.06 and q.z < 0.48: out += [n + '.' + side for n in ('Shoulder', 'UpperArm', 'ForeArm', 'Hand')]
    if ax > 0.24 and q.z < 0.24: out += ['Ribbon1.' + side, 'Ribbon2.' + side, 'Ribbon3.' + side]
    if q.z <= 0.0: out += ['Hips']
    return out or ['Hips']
groups = {n: ob.vertex_groups.new(name=n) for n in J if n != 'Root'}
for v in me.vertices:
    if v.index in fixed:
        for b, w in fixed[v.index].items(): groups[b].add([v.index], w, 'REPLACE')
        continue
    cand = allowed_island.get(v.index) or allowed(v.co)
    ds = sorted(((seg_d(v.co, *SEG[n]), n) for n in cand))[:3]
    ws = [(1.0 / (d * d + 0.0004) ** 2, n) for d, n in ds]; tot = sum(w for w, _ in ws)
    for w, n in ws:
        if w / tot > 0.02: groups[n].add([v.index], w / tot, 'REPLACE')
# smooth the body's weights a little (seams between bones), leaving the rigid islands alone
bpy.context.view_layer.objects.active = ob
rigid = set(fixed)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='DESELECT'); bpy.ops.object.mode_set(mode='OBJECT')
for v in me.vertices: v.select = v.index not in rigid
bpy.ops.object.mode_set(mode='WEIGHT_PAINT'); me.use_paint_mask_vertex = True
bpy.ops.object.vertex_group_smooth(group_select_mode='ALL', factor=0.5, repeat=4)
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
bpy.ops.object.mode_set(mode='OBJECT'); me.use_paint_mask_vertex = False
ob.parent = ao; mod = ob.modifiers.new('Armature', 'ARMATURE'); mod.object = ao
# textures: colour 1024, normal and metal/rough 512 (the game draws it ~25 px tall)
mat = me.materials[0]
for n in mat.node_tree.nodes:
    if n.type == 'TEX_IMAGE' and n.image:
        links = [l.to_socket.name for o in n.outputs for l in o.links]
        im = n.image
        name = 'wraith_color' if 'Base Color' in links else ('wraith_normal' if 'Color' in links and any(l.to_node.type == 'NORMAL_MAP' for o in n.outputs for l in o.links) else 'wraith_orm')
        im.name = name; size = 1024 if name == 'wraith_color' else 512
        if im.size[0] > size: im.scale(size, size)
        im.file_format = 'PNG'; print('IMG', name, im.size[:])
bpy.ops.wm.save_as_mainfile(filepath=out)
print('SAVED', out, 'bones', len(arm.bones))
