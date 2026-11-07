class_name GaleAirStrike
extends Node3D
## Visual-only, world-locked beam -> charge trail -> ONE delayed whole-line eruption.
## Snapshot dimensions/aim at activate(). No timer nodes, collision, damage or cooldown.
signal cast_released
signal blast_triggered(path_start: Vector3, path_end: Vector3, radius: float)
signal cancelled
signal finished

@export var path_radius: float = 0.55
@export var blast_delay: float = 0.65 # Configurable art-preview default, NOT game balance.
@export var blast_duration: float = 0.70
@export var ripple_seconds: float = 0.0 # Default simultaneous whole-line blast.
@export var vent_spacing: float = 1.0
@export_range(2,24) var max_vents: int = 18
@export var vent_height: float = 1.2
@export var beam_radius: float = 0.42
@export var beam_seconds: float = 0.22
@export var auto_free: bool = true

const BEAM=preload("../gale_air_beam/air_beam.tscn")
const PATH_SHADER=preload("charge_path.gdshader")
const VENT_SHADER=preload("wind_vents.gdshader")
const RING_SHADER=preload("shock_rings.gdshader")
var _active: bool = false
var _pending: bool = false
var _age: float = 0.0
var _delay: float = 0.65
var _length: float = 1.0
var _radius: float = 0.55
var _duration: float = 0.7
var _ripple: float = 0.0
var _ground_start: Vector3
var _ground_end: Vector3
var _path: MeshInstance3D
var _vents: MultiMeshInstance3D
var _rings: MultiMeshInstance3D
var _beam: GaleAirBeam
var _materials: Array[ShaderMaterial] = []
var vent_count: int = 0
var blast_count: int = 0

func _ready() -> void:
 set_process(false)
 visible=false

func _exit_tree() -> void:
 _active=false
 _pending=false

func _mesh(v: PackedVector3Array, uv: PackedVector2Array, ix: PackedInt32Array) -> ArrayMesh:
 var a: Array=[]
 a.resize(Mesh.ARRAY_MAX)
 a[Mesh.ARRAY_VERTEX]=v
 a[Mesh.ARRAY_TEX_UV]=uv
 a[Mesh.ARRAY_INDEX]=ix
 var m:=ArrayMesh.new()
 m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
 return m

func _vent_mesh() -> ArrayMesh:
 var v:=PackedVector3Array()
 var uv:=PackedVector2Array()
 var ix:=PackedInt32Array()
 for strand in range(3):
  var start:=v.size()
  var phase:=TAU*strand/3.0
  for i in range(49):
   var t:=float(i)/48
   for side in range(2):
    var a:=phase+(float(side)-0.5)*0.40
    var rad:=0.6+0.35*sin(PI*t)
    v.append(Vector3(cos(a)*rad,t,sin(a)*rad))
    uv.append(Vector2(t,float(side)))
   if i<48:
    var b:=start+i*2
    ix.append_array([b,b+1,b+2,b+1,b+3,b+2])
 return _mesh(v,uv,ix)

func _ring_mesh() -> ArrayMesh:
 var v:=PackedVector3Array()
 var uv:=PackedVector2Array()
 var ix:=PackedInt32Array()
 for i in range(65):
  var a:=TAU*i/64.0
  for side in range(2):
   var r:=1.0+(float(side)-0.5)*0.14
   v.append(Vector3(cos(a)*r,0,sin(a)*r));uv.append(Vector2(i/64.0,float(side)))
  if i<64:
   var b:=i*2
   ix.append_array([b,b+1,b+2,b+1,b+3,b+2])
 return _mesh(v,uv,ix)

func _material(shader: Shader) -> ShaderMaterial:
 var m:=ShaderMaterial.new();m.shader=shader
 m.set_shader_parameter("path_length",_length)
 m.set_shader_parameter("path_radius",_radius)
 m.set_shader_parameter("blast_duration",_duration)
 m.set_shader_parameter("ripple_seconds",_ripple)
 m.set_shader_parameter("vent_height",vent_height)
 _materials.append(m)
 return m

func _multi(mesh: Mesh, material: ShaderMaterial, ground_offset: float) -> MultiMeshInstance3D:
 var mm:=MultiMesh.new()
 mm.transform_format=MultiMesh.TRANSFORM_3D
 mm.use_custom_data=true
 mm.mesh=mesh
 mm.instance_count=vent_count
 for i in range(vent_count):
  var t: float=(float(i)+0.5)/vent_count
  mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(0,ground_offset,t*_length)))
  mm.set_instance_custom_data(i,Color(fposmod(i*0.6180339,1.0),t,0,1))
 var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.material_override=material
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 node.custom_aabb=AABB(Vector3(-_radius*2,ground_offset-0.1,-_radius*2),Vector3(_radius*4,vent_height+0.5,_length+_radius*4))
 add_child(node)
 return node

func _clear() -> void:
 for child in get_children(): child.free()
 _materials.clear()
 _beam=null

## Call after add_child; parent must have world scale ONE. Aim is flattened to ground.
## Delay override <0 uses blast_delay. Radius/length/delay snapshot for this cast.
func activate(world_origin: Vector3, world_direction: Vector3, path_length: float, ground_y: float = 0.0, delay_override: float = -1.0) -> bool:
 assert(is_inside_tree(),"Add AirStrike to world before activate().")
 var aim:=Vector3(world_direction.x,0,world_direction.z)
 if aim.length_squared()<0.000001 or path_length<=0.0: return false
 if _active and _pending: cancelled.emit()
 _clear()
 global_position=world_origin
 global_basis=Basis.looking_at(aim.normalized(),Vector3.UP,true)
 _length=maxf(path_length,0.1)
 _radius=maxf(path_radius,0.05)
 _delay=maxf(blast_delay if delay_override<0.0 else delay_override,0.0)
 _duration=maxf(blast_duration,0.05)
 _ripple=maxf(ripple_seconds,0.0)
 _ground_start=Vector3(world_origin.x,ground_y,world_origin.z)
 _ground_end=_ground_start+aim.normalized()*_length
 _age=0.0;blast_count=0;_pending=true;_active=true
 vent_count=clampi(int(ceil(_length/maxf(vent_spacing,0.2))),2,max_vents)
 var y:=ground_y-world_origin.y+0.035
 _path=MeshInstance3D.new()
 _path.name="LockedChargePath"
 _path.mesh=_mesh(PackedVector3Array([Vector3(-1,0,0),Vector3(1,0,0),Vector3(-1,0,1),Vector3(1,0,1)]),PackedVector2Array([Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,1)]),PackedInt32Array([0,1,2,1,3,2]))
 _path.material_override=_material(PATH_SHADER)
 _path.position.y=y
 _path.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 _path.custom_aabb=AABB(Vector3(-_radius*2,-0.1,-0.1),Vector3(_radius*4,0.5,_length+0.2))
 add_child(_path)
 _vents=_multi(_vent_mesh(),_material(VENT_SHADER),y)
 _vents.name="WindVentsBounded"
 _rings=_multi(_ring_mesh(),_material(RING_SHADER),y)
 _rings.name="WholeLineShockRings"
 _beam=BEAM.instantiate()
 add_child(_beam)
 _beam.auto_free=false
 _beam.radius_m=beam_radius
 _beam.activate(world_origin,aim.normalized(),_length,-1.0)
 _beam.set_process(false) # Parent owns all visual clock; no secondary lifetime/timers.
 visible=true
 set_process(true)
 _apply_phase(0.0)
 cast_released.emit()
 return true

func _process(delta: float) -> void:
 if not _active: return
 _age+=maxf(delta,0.0)
 if _pending and _age>=_delay:
  _pending=false # Latch before signal: re-entrant cancellation cannot duplicate blast.
  blast_count+=1
  blast_triggered.emit(_ground_start,_ground_end,_radius)
  if not _active: return
 _apply_phase(_age)
 if _age>=_delay+_ripple+_duration:
  _complete()

func _apply_phase(time: float) -> void:
 for m in _materials:
  m.set_shader_parameter("clock",time)
  m.set_shader_parameter("progress",clampf(time/maxf(_delay,0.001),0,1))
  m.set_shader_parameter("blast_age",time-_delay if time>=_delay else -1.0)
 if is_instance_valid(_beam):
  var alpha:=smoothstep(0.0,0.04,time)*(1.0-smoothstep(beam_seconds,beam_seconds+0.14,time))
  _beam.visible=alpha>0.001
  _beam.preview_at(time,alpha)

## Art preview sampling ONLY: no blast/gameplay signal dispatched.
func preview_at(time: float) -> void:
 _apply_phase(maxf(0.0,time))

## Cancel pending blast safely. No orphan async callbacks; freeing this node is safe too.
func cancel() -> void:
 if not _active:return
 _pending=false;_active=false
 visible=false
 set_process(false)
 cancelled.emit()
 finished.emit()
 if auto_free:queue_free()
 else:_clear()

func _complete() -> void:
 _active=false;_pending=false
 visible=false;set_process(false)
 finished.emit()
 if auto_free:queue_free()
 else:_clear()
