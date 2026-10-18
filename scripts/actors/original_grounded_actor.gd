extends CharacterBody3D
class_name OriginalGroundedActor
var definition: Dictionary
var visual_scene: String
var idle = "head2"
var visual: OriginalCinematicActor
var start_time = 0.0
var initialized = false
func _ready() -> void:
	add_to_group("grounded_npcs")
	visual = load(visual_scene).instantiate()
	add_child(visual)
	visual.sample_animation("start",0)
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = .45
	shape.height = 1.8
	collision.shape = shape
	collision.position.y = .9
	add_child(collision)
	call_deferred("snap_to_ground")
func snap_to_ground() -> void:
	var query = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*3,global_position-Vector3.UP*30)
	query.collision_mask = 1
	var exclusions: Array[RID] = []
	for actor in get_tree().get_nodes_in_group("grounded_npcs"): exclusions.append(actor.get_rid())
	query.exclude = exclusions
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): global_position.y = hit["position"].y+.001
func _physics_process(delta: float) -> void:
	velocity = Vector3(0,0 if is_on_floor() else maxf(-20,velocity.y-29*delta),0)
	move_and_slide()
func _process(delta: float) -> void:
	if initialized: return
	start_time += delta
	visual.sample_animation("start",start_time)
	if start_time >= float(visual.rig["animations"]["start"]["duration"]):
		initialized = true
		visual.idle(idle)
