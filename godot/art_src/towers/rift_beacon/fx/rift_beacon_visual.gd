## Optional visual wrapper for the Rift Beacon (aura/buff tower). Pure visuals: no gameplay numbers live here.
## Scene: rift_beacon.tscn -> Node3D (this script) / Model (rift_beacon.glb instance) / AuraRing (MeshInstance3D).
class_name RiftBeaconVisual
extends Node3D

@export var aura_radius := 3.0:          ## world units; set from the tower's real buff radius (placeholder)
	set(v):
		aura_radius = v
		_apply_radius()
@export var spin_speed := 1.0            ## 1.0 = outer ring 1 rev / 4 s, inner ring 1 rev / 2 s
@export var burst_spin := 3.0            ## spin multiplier at the peak of a buff pulse
@export var show_aura := true:
	set(v):
		show_aura = v
		if is_node_ready():
			aura.visible = v

@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var aura: MeshInstance3D = $AuraRing
var fx: AnimationPlayer                  ## second player so buff_pulse never interrupts the idle spin
var _aura_mat: ShaderMaterial

func _ready() -> void:
	anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR   # safety net if the sidecar was lost
	fx = AnimationPlayer.new()
	fx.name = "FxPlayer"
	model.add_child(fx)                  # root_node ".." = Model, same as the imported player
	fx.add_animation_library("", anim.get_animation_library(""))
	_aura_mat = aura.get_active_material(0) as ShaderMaterial
	if _aura_mat:
		_aura_mat = _aura_mat.duplicate()
		aura.material_override = _aura_mat
	aura.visible = show_aura
	_apply_radius()
	anim.speed_scale = spin_speed

## Call when the tower is placed/built.
func play_spawn() -> void:
	if not is_node_ready():
		await ready
	anim.play("spawn")
	anim.queue("idle")

## Call once if you skip spawn.
func play_idle() -> void:
	if not is_node_ready():
		await ready
	anim.play("idle")

## Call every time the aura ticks / applies its buff.
func buff_pulse() -> void:
	if not is_node_ready():
		await ready
	fx.stop()
	fx.play("buff_pulse")
	var t := create_tween()
	t.tween_property(anim, "speed_scale", spin_speed * burst_spin, 0.12)
	t.tween_property(anim, "speed_scale", spin_speed, 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if _aura_mat:
		var p := create_tween()
		p.tween_method(func(v: float): _aura_mat.set_shader_parameter("pulse_t", v), 0.0, 1.0, 0.8)
		p.tween_callback(func(): _aura_mat.set_shader_parameter("pulse_t", -1.0))

func _apply_radius() -> void:
	if not is_node_ready():
		return
	var pm := aura.mesh as PlaneMesh
	if pm: pm.size = Vector2(aura_radius * 2.0, aura_radius * 2.0)
