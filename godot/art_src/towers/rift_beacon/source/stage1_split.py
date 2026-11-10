import bpy, bmesh, numpy as np
from mathutils import Vector
W="/workspace/riftguard/rift_beacon/work/"
bpy.ops.wm.open_mainfile(filepath=W+"stage0_raw.blend")
o=bpy.data.objects["Mesh_0"]; me=o.data
cls=np.load(W+"face_cls.npy").astype(np.int32)
c=np.load(W+"faces.npz")["c"]; x,y,z=c.T; cz=0.1043; R=0.445
crown=(np.abs(x)<0.2)&(z>cz+0.25)&(cls==0)
post=(np.abs(x)<0.13)&(np.abs(y)<0.13)&(z<cz-0.25)&(z>-0.395)&(cls==0)
g=cls.copy(); g[crown|post]=1
zone=np.zeros(len(c),dtype=np.int32); zone[crown]=1; zone[post]=2
bm=bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
lg=bm.faces.layers.int.new("grp"); lz=bm.faces.layers.int.new("zone")
for i,f in enumerate(bm.faces): f[lg]=int(g[i]); f[lz]=int(zone[i])
uvl=bm.loops.layers.uv.active
def cut(zid, zplane, keep_above):
    faces=[f for f in bm.faces if f[lz]==zid]
    edges=list({e for f in faces for e in f.edges}); verts=list({v for f in faces for v in f.verts})
    res=bmesh.ops.bisect_plane(bm,geom=faces+edges+verts,dist=1e-5,plane_co=(0,0,zplane),plane_no=(0,0,1))
    # delete zone faces on the wrong side
    dele=[]
    for f in bm.faces:
        if f[lz]!=zid: continue
        mz=sum(v.co.z for v in f.verts)/len(f.verts)
        if (mz<zplane) if keep_above else (mz>zplane): dele.append(f)
    bmesh.ops.delete(bm,geom=dele,context="FACES")
    # cap: boundary edges lying on the plane, belonging to zone faces
    bnd=[e for e in bm.edges if e.is_boundary and all(abs(v.co.z-zplane)<1e-4 for v in e.verts) and any(f[lz]==zid for f in e.link_faces)]
    r=bmesh.ops.holes_fill(bm,edges=bnd,sides=0)
    # cap uv: copy from a neighbouring face corner so the cap gets that surface's colour
    for f in r["faces"]:
        f[lg]=1; f[lz]=zid
        nb=None
        for e in f.edges:
            for lf in e.link_faces:
                if lf is not f: nb=lf; break
            if nb: break
        uv=nb.loops[0][uvl].uv.copy() if nb else Vector((0.5,0.5))
        for l in f.loops: l[uvl].uv=uv
    print("zone",zid,"deleted",len(dele),"caps",len(r["faces"]),"bnd",len(bnd))
cut(1, cz+R, True)     # crown: keep above the inner ring's sweep sphere
cut(2, cz-R, False)    # post: keep below it
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context="VERTS")
bm.to_mesh(me); bm.free()
names={0:"Base",1:"OuterRing",2:"InnerRing",3:"Crystal"}
for gi,nm in names.items():
    ob=o.copy(); ob.data=me.copy(); ob.name=nm; ob.data.name=nm+"_mesh"; bpy.context.scene.collection.objects.link(ob)
    bm=bmesh.new(); bm.from_mesh(ob.data); l=bm.faces.layers.int["grp"]
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if f[l]!=gi],context="FACES")
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context="VERTS")
    bm.to_mesh(ob.data); bm.free(); print(nm,len(ob.data.polygons))
bpy.data.objects.remove(o)
bpy.ops.wm.save_as_mainfile(filepath=W+"stage1_split.blend"); print("saved")
