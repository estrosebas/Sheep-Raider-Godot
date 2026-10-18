extends RigidBody3D
class_name MagneticItemTarget

@export var anchored = false
@export var magnetic_response = 1.0

func _ready() -> void:
	add_to_group("magnetic_targets")
	add_to_group("fan_targets")
	freeze = anchored

func magnet_query(_source: Node) -> bool:
	return magnetic_response > 0.0

func magnet_is_anchored() -> bool:
	return anchored

func magnet_pull(source: Node3D, force: float, delta: float) -> void:
	if not anchored:
		apply_central_impulse((source.global_position - global_position).normalized() * force * delta * mass * magnetic_response)

func magnet_contact(_source: Node) -> void:
	pass

func magnet_release(_source: Node) -> void:
	pass

func on_fan_blow(direction: Vector3, delta: float) -> void:
	if not anchored:
		apply_central_impulse(direction * delta * mass * 4.0)
