## Optional cosmetic driver for Oracle's inner orb crystal.
## Runs after AnimationPlayer (SkeletonModifier3D), so it overrides only the
## PropCore bone rotation and keeps a constant spin phase across every clip
## and blend. Add as a child of the Skeleton3D. No gameplay logic.
@tool
class_name OracleOrbSpin
extends SkeletonModifier3D

@export var bone_name: StringName = &"PropCore"
@export var degrees_per_second: float = 240.0
var _angle: float = 0.0
var _bone: int = -2

func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _bone == -2:
		_bone = sk.find_bone(bone_name)
	if _bone < 0:
		return
	_angle = fposmod(_angle + deg_to_rad(degrees_per_second) * delta, TAU)
	# Spin about the bone's own +Y (world up at rest) through its own head = crystal center.
	sk.set_bone_pose_rotation(_bone, sk.get_bone_rest(_bone).basis.get_rotation_quaternion() * Quaternion(Vector3.UP, _angle))
