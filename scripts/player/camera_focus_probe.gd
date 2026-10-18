extends Node
class_name CameraFocusProbe

@export var distance = 50.0
@export var required_seconds = 1.0
@export_flags_3d_physics var collision_mask = 257
var camera: Camera3D
var expected_target: Node3D
var exclude: Array[RID] = []
var focused_target: Node3D
var focus_seconds = 0.0
var completed = false

func reset() -> void:
	focused_target = null
	focus_seconds = 0
	completed = false

func evaluate(delta: float) -> bool:
	if not is_instance_valid(camera) or not is_instance_valid(expected_target):
		reset()
		return false
	var view = camera.get_camera_transform()
	var origin = view.origin
	var ray = PhysicsRayQueryParameters3D.create(origin,origin-view.basis.z*distance,collision_mask,exclude)
	ray.collide_with_areas = true
	ray.collide_with_bodies = true
	var hit = camera.get_world_3d().direct_space_state.intersect_ray(ray)
	var target: Node3D = null
	if not hit.is_empty() and hit["collider"].has_meta("camera_focus_target"):
		target = hit["collider"].get_meta("camera_focus_target")
	if target != expected_target:
		reset()
		return false
	focused_target = target
	focus_seconds += delta
	completed = focus_seconds >= required_seconds
	return completed
