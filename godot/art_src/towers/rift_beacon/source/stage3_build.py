import bpy, bmesh, math
from mathutils import Vector, Matrix
W="/workspace/riftguard/rift_beacon/work/"
bpy.ops.wm.open_mainfile(filepath=W+"stage2_dec.blend")
sc=bpy.context.scene; sc.render.fps=60; sc.frame_start=0
C=Vector((0,0,1.0344))
col=sc.collection
for _n in ["Base","OuterRing","InnerRing","Crystal"]:
    _bm=bmesh.new(); _me=bpy.data.objects[_n].data; _bm.from_mesh(_me)
    bmesh.ops.delete(_bm,geom=[v for v in _bm.verts if not v.link_faces],context="VERTS"); _bm.to_mesh(_me); _bm.free()
    print(_n,"verts",len(_me.vertices),"tris",len(_me.polygons))
def empty(name,loc,parent=None):
    e=bpy.data.objects.new(name,None); col.objects.link(e); e.empty_display_size=0.1
    if parent: e.parent=parent
    e.location=loc; return e
turret=empty("Turret",(0,0,0))
rotor=empty("Rotor",C,turret)
inner_p=empty("InnerPivot",(0,0,0),rotor)
def reparent(ob,parent,origin_world,scale=1.0):
    ob.data.transform(Matrix.Translation(-origin_world))
    if scale!=1.0: ob.data.transform(Matrix.Scale(scale,4))
    ob.parent=parent; ob.matrix_parent_inverse=Matrix.Identity(4); ob.location=(0,0,0)
base=bpy.data.objects["Base"]; base.parent=turret

def add_cap(ob,zp,xlim,uv,face_up):
    me=ob.data; bm=bmesh.new(); bm.from_mesh(me)
    vs=[v for v in bm.verts if abs(v.co.z-zp)<0.004 and abs(v.co.x)<xlim and abs(v.co.y)<0.14]
    x0=min(v.co.x for v in vs); x1=max(v.co.x for v in vs); y0=min(v.co.y for v in vs); y1=max(v.co.y for v in vs)
    e=0.002; x0-=e; x1+=e; y0-=e; y1+=e
    q=[bm.verts.new((x0,y0,zp)),bm.verts.new((x1,y0,zp)),bm.verts.new((x1,y1,zp)),bm.verts.new((x0,y1,zp))]
    f=bm.faces.new(q if face_up else q[::-1]); f.smooth=False
    uvl=bm.loops.layers.uv.active
    for l in f.loops: l[uvl].uv=uv
    bm.to_mesh(me); bm.free(); print("cap",ob.name,zp,round(x0,3),round(x1,3),round(y0,3),round(y1,3),len(vs))
def add_arc(ob,a0,a1,r0,r1,hy,uv,step=3.0):
    me=ob.data; bm=bmesh.new(); bm.from_mesh(me); uvl=bm.loops.layers.uv.active
    n=max(2,int(abs(a1-a0)/step)+1); rings=[]
    for i in range(n):
        a=math.radians(a0+(a1-a0)*i/(n-1)); ca,sa=math.cos(a),math.sin(a)
        rings.append([bm.verts.new((C.x+r*ca,C.y+yy,C.z+r*sa)) for (r,yy) in ((r0,-hy),(r1,-hy),(r1,hy),(r0,hy))])
    nf=0
    for i in range(n-1):
        A,B=rings[i],rings[i+1]
        for k in range(4):
            k2=(k+1)%4; f=bm.faces.new((A[k],A[k2],B[k2],B[k]))
            for l in f.loops: l[uvl].uv=uv
            nf+=1
    for cap_,rev in ((rings[0],True),(rings[-1],False)):
        f=bm.faces.new(cap_[::-1] if rev else cap_)
        for l in f.loops: l[uvl].uv=uv
    bm.normal_update(); bmesh.ops.recalc_face_normals(bm,faces=bm.faces[-(nf+2):])
    bm.to_mesh(me); bm.free(); print("arc",ob.name,a0,a1,nf)
NAVY=(0.1794,0.5667)
_i=bpy.data.objects["InnerRing"]
for a0,a1 in ((62,114),(-114,-66),(-9,9),(171,189)):
    add_arc(_i,a0,a1,0.354,0.427,0.042,NAVY)
add_arc(bpy.data.objects["OuterRing"],-102,-78,0.437,0.49,0.064,NAVY)

_o=bpy.data.objects["OuterRing"]
add_cap(_o,0.1043+0.445+0.9301,0.21,(0.1794,0.5667),False)   # crown underside, navy, faces down
add_cap(_o,0.1043-0.445+0.9301,0.14,(0.6326,0.5862),True)    # post top, cream, faces up
reparent(bpy.data.objects["OuterRing"],rotor,C)
reparent(bpy.data.objects["InnerRing"],inner_p,C,0.985)
cr=bpy.data.objects["Crystal"]
zs=[v.co.z for v in cr.data.vertices]; cc=Vector((0,0,(min(zs)+max(zs))/2))
crystal_top=max(zs)
reparent(cr,rotor,cc); cr.location=cc-C
print("crystal centre",cc,"top",crystal_top)
# main material: add emission texture
m=bpy.data.materials["Material_0"]; m.name="RiftBeacon_Mat"
nt=m.node_tree; bsdf=nt.nodes["Principled BSDF"]
img=bpy.data.images.load(W+"tex/rift_beacon_emission.png"); img.name="rift_beacon_emission"
tn=nt.nodes.new("ShaderNodeTexImage"); tn.image=img
nt.links.new(tn.outputs["Color"],bsdf.inputs["Emission Color"]); bsdf.inputs["Emission Strength"].default_value=2.0
names={"Image_0":"rift_beacon_color","Image_1":"rift_beacon_orm","Image_2":"rift_beacon_normal"}
for k,v in names.items(): bpy.data.images[k].name=v
def fxmat(name,rgb,alpha,strength):
    mm=bpy.data.materials.new(name); mm.use_nodes=True; b=mm.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*rgb,1); b.inputs["Alpha"].default_value=alpha
    b.inputs["Emission Color"].default_value=(*rgb,1); b.inputs["Emission Strength"].default_value=strength
    b.inputs["Roughness"].default_value=1.0
    mm.surface_render_method="BLENDED"; mm.use_backface_culling=False; return mm
CYAN=(0.37,0.94,1.0); MAG=(1.0,0.25,0.85)
def mesh_obj(name,bm,mat,parent,loc):
    me=bpy.data.meshes.new(name+"_mesh"); bm.to_mesh(me); bm.free(); me.materials.append(mat)
    for p in me.polygons: p.use_smooth=True
    ob=bpy.data.objects.new(name,me); col.objects.link(ob); ob.parent=parent; ob.location=loc; return ob
glow=empty("Glow",cc,turret)
bm=bmesh.new(); bmesh.ops.create_icosphere(bm,subdivisions=2,radius=0.105)
core=mesh_obj("CoreGlow",bm,fxmat("FX_CoreGlow",MAG,0.12,1.2),glow,(0,0,0))
bm=bmesh.new(); bmesh.ops.create_icosphere(bm,subdivisions=2,radius=0.15)
flash=mesh_obj("CoreFlash",bm,fxmat("FX_CoreFlash",(1.0,0.45,0.95),0.3,2.5),glow,(0,0,0)); flash.scale=(0.001,)*3
# beam flare: thin cylinder, origin at its bottom, rises from crystal tip
bm=bmesh.new(); bmesh.ops.create_cone(bm,cap_ends=False,segments=12,radius1=0.05,radius2=0.012,depth=1.0)
bmesh.ops.translate(bm,verts=bm.verts,vec=(0,0,0.5))
beam_top=empty("beam_top",(0,0,crystal_top+0.01),turret)
flare=mesh_obj("BeamFlare",bm,fxmat("FX_BeamFlare",CYAN,0.55,4.0),beam_top,(0,0,0)); flare.scale=(0.001,)*3
# pulse ring: flat annulus radius 1.0 (scaled by anim)
bm=bmesh.new(); seg=64
for i in range(seg):
    pass
outer=[bm.verts.new((math.cos(2*math.pi*i/seg),math.sin(2*math.pi*i/seg),0)) for i in range(seg)]
inn=[bm.verts.new((0.9*math.cos(2*math.pi*i/seg),0.9*math.sin(2*math.pi*i/seg),0)) for i in range(seg)]
for i in range(seg):
    j=(i+1)%seg; bm.faces.new((inn[i],inn[j],outer[j],outer[i]))
aura=empty("aura_center",(0,0,0.03),turret)
pr=mesh_obj("PulseRing",bm,fxmat("FX_PulseRing",CYAN,0.65,3.0),aura,(0,0,0)); pr.scale=(0.001,)*3
for p in pr.data.polygons: p.use_smooth=False
empty("BuffPoint",(0,0,crystal_top+0.01),turret)
bpy.ops.wm.save_as_mainfile(filepath=W+"stage3_rig.blend"); print("saved")
