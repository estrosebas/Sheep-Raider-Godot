extends Node3D
class_name OriginalLevelGoal
signal level_completed(level_id: String)
var level_id = "lvl_01"
var definition: Dictionary
var player: RalphController
var bounds: AABB
var radius = 0.0
var completed = false
var completion: Node
func _ready():
	player = get_parent().get_node("Player")
	var p = definition.pos
	position = GameSpace.from_export(Vector3(p[0],p[1],p[2]))
	var box = definition.box
	var lo = GameSpace.original_point(Vector3(box.min[0],box.max[1],box.max[2]))+global_position
	var hi = GameSpace.original_point(Vector3(box.max[0],box.min[1],box.min[2]))+global_position
	bounds = AABB(lo,hi-lo)
	radius = definition.radius

func qualifies(point: Vector3, require_box: bool) -> bool:
	return point.y >= bounds.position.y and point.y <= bounds.end.y and Vector2(point.x-global_position.x,point.z-global_position.z).length_squared() <= radius*radius and (not require_box or bounds.has_point(point))
func _physics_process(_delta):
	if completed or player.cinematic_controls_locked or player.tutorial_movement_locked or player.restart_fade_remaining > 0: return
	if player.current_state in [player.WolfState.PIT_FALL,player.WolfState.SAM_DEATH,player.WolfState.BLAST_DEATH]: return
	if not qualifies(player.global_position,true): return
	for sheep in get_tree().get_nodes_in_group("sheep_targets"):
		if not sheep is OriginalSheep or sheep.dead or sheep.get_world_3d() != get_world_3d(): continue
		if qualifies(sheep.goal_position(),false):
			complete(sheep)
			return
func complete(sheep: OriginalSheep):
	if completed: return
	completed = true
	completion = preload("res://scripts/levels/original_level_completion.gd").new()
	get_parent().add_child(completion)
	completion.begin(level_id,sheep)
	level_completed.emit(level_id)
