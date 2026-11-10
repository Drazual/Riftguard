import bpy, bmesh
from mathutils import Vector, Matrix
W="/workspace/riftguard/rift_beacon/work/"
bpy.ops.wm.open_mainfile(filepath=W+"stage1_split.blend")
targets={"Base":22000,"OuterRing":8000,"InnerRing":3600,"Crystal":700}
zmin=min((ob.matrix_world@Vector(v.co)).z for ob in bpy.data.objects if ob.type=="MESH" for v in ob.data.vertices)
print("zmin",zmin)
for nm,t in targets.items():
    ob=bpy.data.objects[nm]
    # merge exact-duplicate verts within a part (helps decimation), keep UV seams
    bm=bmesh.new(); bm.from_mesh(ob.data); bmesh.ops.triangulate(bm,faces=bm.faces[:]); n=len(bm.faces); bm.to_mesh(ob.data); bm.free()
    m=ob.modifiers.new("dec","DECIMATE"); m.decimate_type="COLLAPSE"; m.ratio=min(1.0,t/n); m.use_collapse_triangulate=True
    bpy.context.view_layer.objects.active=ob
    with bpy.context.temp_override(object=ob, active_object=ob):
        bpy.ops.object.modifier_apply(modifier="dec")
    # bake translation so base sits on z=0
    ob.data.transform(Matrix.Translation((0,0,-zmin))); ob.location=(0,0,0)
    print(nm,n,"->",len(ob.data.polygons))
bpy.ops.wm.save_as_mainfile(filepath=W+"stage2_dec.blend")
print("saved")
