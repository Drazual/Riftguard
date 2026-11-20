# Riftguard QA wrapper: open a prepped .blend, put every object on action <name> (its own slot) at frame <f>, save a copy. args: action frame out.blend
import bpy, sys
a = sys.argv[sys.argv.index('--')+1:]; act = bpy.data.actions[a[0]]; f = int(a[1])
for o in bpy.data.objects:
    sl = next((s for s in act.slots if s.identifier == "OB" + o.name), None)
    if sl is None: continue
    o.animation_data_create(); o.animation_data.action = act; o.animation_data.action_slot = sl
bpy.context.scene.frame_set(f)
mins = []
for o in bpy.data.objects:
    if o.type == 'MESH' and o.name != 'Icosphere':
        e = o.evaluated_get(bpy.context.evaluated_depsgraph_get()); m = e.to_mesh()
        mins.append((min((o.matrix_world @ v.co).z for v in m.vertices) if len(m.vertices) else 9, o.name)); e.to_mesh_clear()
print("@@POSE@@", a, sorted(mins)[:3])
bpy.ops.wm.save_as_mainfile(filepath=a[2])
