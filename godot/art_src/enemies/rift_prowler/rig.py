# Rift Prowler: imports the Meshy model, sets its feet on the origin, cuts it to ~12k triangles, builds the
# skeleton from joints.json and skins the mesh to it (automatic weights). See README.md.
import bpy, sys, json, bmesh, mathutils
src, out_blend = sys.argv[sys.argv.index('--')+1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
ob=[o for o in bpy.data.objects if o.type=='MESH'][0]
ob.name="Prowler"; ob.data.name="Prowler"
# recentre: feet on the ground at the origin
me=ob.data
me.transform(mathutils.Matrix.Translation((0.22,0,0.95)))
print("tris before", sum(len(p.vertices)-2 for p in me.polygons))
bpy.context.view_layer.objects.active=ob; ob.select_set(True)
# merge seams first so decimation keeps a closed shell
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=0.0005); bpy.ops.object.mode_set(mode='OBJECT')
m=ob.modifiers.new("dec",'DECIMATE'); m.ratio=0.02 # about 12k triangles, plenty for a small enemy
m.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier="dec")
print("tris after", sum(len(p.vertices)-2 for p in me.polygons), "verts", len(me.vertices))
J=json.load(open(__import__('os').path.join(__import__('os').path.dirname(__file__),'joints.json')))
arm=bpy.data.armatures.new("Armature"); ao=bpy.data.objects.new("Armature",arm)
bpy.context.scene.collection.objects.link(ao)
bpy.context.view_layer.objects.active=ao; bpy.ops.object.mode_set(mode='EDIT')
for n,(h,t,p) in J.items():
    e=arm.edit_bones.new(n); e.head=h; e.tail=t
for n,(h,t,p) in J.items():
    if p: 
        e=arm.edit_bones[n]; e.parent=arm.edit_bones[p]
        e.use_connect = (mathutils.Vector(arm.edit_bones[p].tail)-mathutils.Vector(h)).length<1e-4
# roll: keep each bone's local X pointing to world +X (a consistent hinge axis for knees, elbows, the tail)
for e in arm.edit_bones:
    e.align_roll(mathutils.Vector((0,-1,0)) if abs(e.vector.normalized().y)<0.9 else mathutils.Vector((0,0,1)))
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT')
ob.select_set(True); ao.select_set(True); bpy.context.view_layer.objects.active=ao
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
vg=[g.name for g in ob.vertex_groups]
empty=[g for g in vg if not any(g_.group==ob.vertex_groups[g].index for v in me.vertices for g_ in v.groups)]
unw=sum(1 for v in me.vertices if not v.groups)
print("groups",len(vg),"empty",empty,"unweighted verts",unw)
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
