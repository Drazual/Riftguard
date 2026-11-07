class_name GaleAirBeam
extends Node3D
## Cosmetic +Z beam. Keep scale ONE; radius and length are independent uniforms.
## No collision, damage, cooldown, automatic hero ability, or baked screen range.
signal released
signal finished

@export_range(0.1, 200.0) var length_m: float = 9.0:
 set(v):
  length_m = maxf(v, 0.1)
  _push_dimensions()
@export_range(0.05, 3.0) var radius_m: float = 0.46:
 set(v):
  radius_m = maxf(v, 0.05)
  _push_dimensions()
@export var auto_free: bool = true
@export var fade_seconds: float = 0.14

const SURFACE = preload("wind_surface.gdshader")
const ADDITIVE = preload("wind_additive.gdshader")
var _materials: Array[ShaderMaterial] = []
var _rings: Array[MeshInstance3D] = []
var _streaks: Array[MeshInstance3D] = []
var _muzzle: Array[MeshInstance3D] = []
var _clock: float = 0.0
var _active: bool = false
var _fading: bool = false
var _age: float = 0.0
var _fade_age: float = 0.0
var _duration: float = 0.5
var _strength: float = 0.0
var _anchor: Node3D
var _direction: Vector3 = Vector3.FORWARD
var _endpoint: Vector3
var _use_endpoint: bool = false

func _ready() -> void:
 _build()
 visible = false
 set_process(false)

func _material(color: Color, add: bool = false) -> ShaderMaterial:
 var m := ShaderMaterial.new()
 m.shader = ADDITIVE if add else SURFACE
 m.set_shader_parameter("tint", color)
 m.set_shader_parameter("strength", 0.0)
 _materials.append(m)
 return m

func _mesh(vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
 var arr: Array = []
 arr.resize(Mesh.ARRAY_MAX)
 arr[Mesh.ARRAY_VERTEX] = vertices
 arr[Mesh.ARRAY_TEX_UV] = uvs
 arr[Mesh.ARRAY_INDEX] = indices
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
 return mesh

func _strip(rad: float, width: float, steps: int = 180) -> ArrayMesh:
 var v := PackedVector3Array()
 var uv := PackedVector2Array()
 var ix := PackedInt32Array()
 for i in range(steps + 1):
  var z := float(i) / steps
  # Radial pitch is animated by the vertex shader, not the whole beam node.
  var swell := 0.5 + 0.5 * smoothstep(0.0, 0.12, z)
  for side in range(2):
   v.append(Vector3(rad * swell, (float(side) - 0.5) * width, z))
   uv.append(Vector2(z, float(side)))
  if i < steps:
   var b := i * 2
   ix.append_array([b,b+1,b+2,b+1,b+3,b+2])
 return _mesh(v, uv, ix)

func _tube(rad: float) -> ArrayMesh:
 var v := PackedVector3Array()
 var uv := PackedVector2Array()
 var ix := PackedInt32Array()
 for z in range(2):
  for j in range(33):
   var a := TAU * j / 32.0
   v.append(Vector3(cos(a)*rad,sin(a)*rad,float(z)))
   # Circumference soft falloff isn't needed: use UV.y midpoint.
   uv.append(Vector2(float(z),0.5))
 for j in range(32):
  ix.append_array([j,j+1,j+33,j+1,j+34,j+33])
 return _mesh(v,uv,ix)

func _ring_mesh() -> ArrayMesh:
 var v := PackedVector3Array()
 var uv := PackedVector2Array()
 var ix := PackedInt32Array()
 for i in range(97):
  var a := TAU * i / 96.0
  for side in range(2):
   var rad := 1.0 + (float(side)-0.5)*0.09
   v.append(Vector3(rad*cos(a),rad*sin(a),0.0))
   uv.append(Vector2(float(i)/96.0,float(side)))
  if i < 96:
   var b := i*2
   ix.append_array([b,b+1,b+2,b+1,b+3,b+2])
 return _mesh(v,uv,ix)

func _instance(mesh: Mesh, material: ShaderMaterial, label: String) -> MeshInstance3D:
 var n := MeshInstance3D.new()
 n.name = label
 n.mesh = mesh
 n.material_override = material
 n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 # Shader moves normalized vertices; avoid incorrect frustum culling.
 n.custom_aabb = AABB(Vector3(-2,-2,-0.1), Vector3(4,4,10))
 add_child(n)
 return n

func _build() -> void:
 # White filament, cyan sheath and very faint pressure envelope.
 var cores := [Vector3(0.075,0.92,0.0),Vector3(0.22,0.20,0.0),Vector3(0.72,0.035,0.0)]
 for i in range(cores.size()):
  var m := _material(Color(0.64,0.95,1.0,cores[i].y),true)
  m.set_shader_parameter("helix", false)
  m.set_shader_parameter("shimmer",0.10)
  _instance(_tube(cores[i].x),m,"Core%d" % i)
 # Cyan ink under the white filament preserves the beam on snow/bright floors.
 var ink := _material(Color(0.015,0.30,0.46,0.78),false)
 ink.render_priority = -8
 ink.set_shader_parameter("helix",false)
 ink.set_shader_parameter("emission_gain",0.05)
 _instance(_tube(0.155),ink,"CyanCoreContour")
 # Broad twisting white/cyan wind bands, plus thin high-speed filaments.
 for i in range(5):
  var m := _material(Color(0.68 if i%2==0 else 0.045,0.94 if i%2==0 else 0.65,1.0 if i%2==0 else 0.83,0.66 if i<3 else 0.40))
  m.set_shader_parameter("emission_gain",0.45 if i%2==0 else 0.08)
  m.set_shader_parameter("phase",TAU*i/5.0)
  m.set_shader_parameter("twist",1.35 if i<3 else -1.75)
  m.set_shader_parameter("spin",-5.2 if i<3 else 4.0)
  _instance(_strip(0.77+i*0.075,0.22 if i<3 else 0.045),m,"Helix%d" % i)
 var ring := _ring_mesh()
 for i in range(7):
  var m := _material(Color(0.17,0.70,0.90,0.65),false)
  m.set_shader_parameter("emission_gain",0.15)
  m.set_shader_parameter("helix",false)
  m.set_shader_parameter("longitudinal_fade",false)
  _rings.append(_instance(ring,m,"PressureRing%d" % i))
 for i in range(3):
  var m := _material(Color(0.37,0.90,1.0,0.70),true)
  m.set_shader_parameter("helix",false)
  m.set_shader_parameter("longitudinal_fade",false)
  _muzzle.append(_instance(ring,m,"MuzzleVortex%d" % i))
 for i in range(15):
  var m := _material(Color(0.7,0.97,1.0,0.55),true)
  m.set_shader_parameter("helix",false)
  m.set_shader_parameter("beam_radius",1.0)
  _streaks.append(_instance(_strip(0.0,0.012,2),m,"WindStreak%d" % i))
 _push_dimensions()

func _push_dimensions() -> void:
 for m in _materials:
  m.set_shader_parameter("beam_length",length_m)
  m.set_shader_parameter("beam_radius",radius_m)
 # Shader deformation is invisible to CPU culling. Update bounds in world units.
 for child in get_children():
  if child is MeshInstance3D:
   child.custom_aabb = AABB(Vector3(-radius_m*2.0,-radius_m*2.0,-0.1),Vector3(radius_m*4.0,radius_m*4.0,length_m+0.2))

## Call after add_child(). Direction is WORLD forward. Duration <0 sustains until finish().
## Anchor follows POSITION only: aim stays frozen, so recovery cannot sweep the beam.
func activate(origin: Vector3, direction: Vector3, beam_length: float = 9.0, duration: float = 0.5, anchor: Node3D = null) -> void:
 assert(is_inside_tree(),"Add beam to the scene before activate().")
 if _materials.is_empty(): _build()
 length_m = beam_length
 _direction = direction.normalized() if direction.length_squared()>0.00001 else Vector3(0,0,1)
 global_position = origin
 _orient(_direction)
 _anchor = anchor
 _use_endpoint = false
 _duration = duration
 _age = 0.0
 _clock = 0.0
 _fade_age = 0.0
 _active = true
 _fading = false
 visible = true
 set_process(true)
 preview_at(0.0,0.0)
 released.emit()

## Uses a supplied WORLD endpoint, useful for raycast/camera result.
func set_endpoint(world_endpoint: Vector3) -> void:
 _endpoint = world_endpoint
 _use_endpoint = true
 _update_anchor()

func set_direction(world_direction: Vector3) -> void:
 if world_direction.length_squared()>0.00001:
  _direction = world_direction.normalized()
  _use_endpoint = false
  _orient(_direction)

func _orient(dir: Vector3) -> void:
 var up := Vector3.UP if absf(dir.dot(Vector3.UP))<0.99 else Vector3.RIGHT
 # Godot use_model_front=true makes local +Z face the target.
 global_basis = Basis.looking_at(dir,up,true)

func _update_anchor() -> void:
 if is_instance_valid(_anchor): global_position = _anchor.global_position
 if _use_endpoint:
  var offset := _endpoint-global_position
  length_m = maxf(offset.length(),0.1)
  if offset.length_squared()>0.00001: _orient(offset.normalized())

func finish(immediate: bool = false) -> void:
 if not _active: return
 if immediate:
  _complete()
 elif not _fading:
  _fading = true
  _fade_age = 0.0

func _complete() -> void:
 _active = false
 visible = false
 set_process(false)
 finished.emit()
 if auto_free: queue_free()

func _process(delta: float) -> void:
 if not _active: return
 _age += delta
 _clock += delta
 _update_anchor()
 if not _fading and _duration >= 0.0 and _age >= _duration:
  _fading = true
  _fade_age = maxf(0.0,_age-_duration)
 elif _fading:
  _fade_age += delta
 if _fading and _fade_age >= maxf(fade_seconds,0.001):
  _complete()
  return
 var attack := smoothstep(0.0,0.055,_age)
 var envelope := attack * (1.0-smoothstep(0.0,maxf(fade_seconds,0.001),_fade_age) if _fading else 1.0)
 preview_at(_clock,envelope)

## Deterministic art-preview sampling. Does not dispatch gameplay events.
func preview_at(time: float, envelope: float = 1.0) -> void:
 _clock = time
 _strength = clampf(envelope,0.0,1.0)
 for m in _materials:
  m.set_shader_parameter("clock",time)
  m.set_shader_parameter("strength",_strength)
 # Pressure rings run outwards; number is bounded, spacing scales with length,
 # radius does NOT: lengthening the beam doesn't turn rings into huge hoops.
 for i in range(_rings.size()):
  var t := fposmod(float(i)/7.0 + time*0.72,1.0)
  var n := _rings[i]
  n.position = Vector3(0,0,t*length_m)
  n.scale = Vector3.ONE * lerpf(0.65,1.48,t)
  var m := n.material_override as ShaderMaterial
  m.set_shader_parameter("beam_length",1.0)
  m.set_shader_parameter("strength",_strength*sin(PI*t)*0.85)
 for i in range(_muzzle.size()):
  var n := _muzzle[i]
  n.position.z = 0.018 + i*0.018
  n.scale = Vector3.ONE*(0.55 + i*0.21 + 0.05*sin(time*19.0+i))
  var m := n.material_override as ShaderMaterial
  m.set_shader_parameter("beam_length",1.0)
  m.set_shader_parameter("strength",_strength)
 for i in range(_streaks.size()):
  var n := _streaks[i]
  var t := fposmod(i*0.6180339+time*(0.9+i*0.013),1.0)
  var angle := i*2.39996+time*0.5
  var rad := radius_m*(0.55+0.65*fposmod(i*0.37,1.0))
  n.position = Vector3(cos(angle)*rad,sin(angle)*rad,t*length_m)
  var m := n.material_override as ShaderMaterial
  m.set_shader_parameter("beam_length",minf(0.22+0.07*(i%3),length_m*(1.0-t)))
  m.set_shader_parameter("beam_radius",1.0)
  m.set_shader_parameter("phase",angle)
  m.set_shader_parameter("strength",_strength*sin(PI*t)*0.6)
