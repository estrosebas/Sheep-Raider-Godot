extends Node
# A local adapter for tight native corridors. Preserve real wall collision,
# while allowing grounded walking to slide around a nearly frontal corner.
var entries: Array = []
var actor: RalphController
var prior_angle = 0.0
var prior_block = true
var applied = false
func _ready():
	actor = get_parent().player
	process_physics_priority = -20
func _physics_process(_delta):
	var walking = actor.current_state in [actor.WolfState.IDLE,actor.WolfState.WALK,actor.WolfState.SNEAK,actor.WolfState.LAND]
	var enabled = false
	if walking and not actor.cinematic_controls_locked and actor.is_on_floor():
		for entry in entries:
			var a = entry.min; var b = entry.size
			if AABB(Vector3(a[0],a[1],a[2]),Vector3(b[0],b[1],b[2])).has_point(actor.global_position): enabled = true; break
	if enabled:
		if not applied:
			prior_angle = actor.wall_min_slide_angle; prior_block = actor.floor_block_on_wall
			applied = true
		actor.wall_min_slide_angle = 0.0
		actor.floor_block_on_wall = false
	else: restore()
func restore():
	if applied and is_instance_valid(actor):
		actor.wall_min_slide_angle = prior_angle; actor.floor_block_on_wall = prior_block
	applied = false
func _exit_tree(): restore()
