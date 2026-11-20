# Riftguard QA wrapper: import a GLB copy, strip the importer NLA tracks (so one action can be evaluated alone),
# list actions + slots, save a .blend for the blender-skills CLI scripts. args: glb fps out.blend
import bpy, sys, json
a = sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = int(a[1])
bpy.ops.import_scene.gltf(filepath=a[0])
for o in bpy.data.objects:
    ad = o.animation_data
    if ad:
        for tr in list(ad.nla_tracks): ad.nla_tracks.remove(tr)
        ad.action = None
info = {}
for act in bpy.data.actions:
    act.use_fake_user = True
    info[act.name] = {"range": list(act.frame_range), "slots": [s.identifier for s in act.slots],
                      "users": sorted({u.name for s in act.slots for u in s.users()})}
objs = {o.name: o.type for o in bpy.data.objects}
print("@@PREP@@" + json.dumps({"actions": info, "objects": objs}))
bpy.ops.wm.save_as_mainfile(filepath=a[2])
