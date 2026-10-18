extends Node
class_name OriginalFallZone

# Local map safety boundary; global movement rules remain in RalphController.
var player: RalphController
var minimum: Vector2
var maximum: Vector2
var fall_height: float
var use_jump_reach = false
var minimum_origin_y = 0.0

func _ready() -> void:
	add_to_group("original_fall_zones")
	process_physics_priority = 10

func _physics_process(_delta: float) -> void:
	check_fall()

func check_fall() -> bool:
	if not is_instance_valid(player): return false
	var p = player.global_position
	if p.x < minimum.x or p.x > maximum.x or p.z < minimum.y or p.z > maximum.y or p.y >= fall_height: return false
	if use_jump_reach:
		# The first takeoff survives the second jump; do not use its higher apex.
		# Clamp to the lip so landing on a decorative pit bottom cannot make it safe.
		var origin = float(player.jump_origin_y) if player.jump_origin_y != null else player.last_ground_y
		origin = maxf(origin,minimum_origin_y)
		var reach = maxf(player.DOUBLE_JUMP_HEIGHT*player.jump_height_scale,player.jump_void_drop_margin)
		if p.y >= minf(fall_height,origin-reach): return false
	if player.cinematic_controls_locked or player.tutorial_movement_locked or player.restart_fade_remaining > 0 or is_instance_valid(player.active_rocket): return false
	if player.current_state in [player.WolfState.PIT_FALL,player.WolfState.BLAST_DEATH,player.WolfState.SAM_DEATH,player.WolfState.JUMP,player.WolfState.RUN_AIR]: return false
	if player.jump_void_grace > 0: return false
	# A bottom reached after an editor teleport or an unusually large physics
	# step is still inside this hazard, even if move_and_slide reports grounded.
	if not use_jump_reach or not player.is_on_floor():
		if player.coyote_remaining > 0 or player.velocity.y >= 0: return false
	if player.jump_origin_y != null and p.y >= float(player.jump_origin_y)-player.jump_void_drop_margin: return false
	player.set_state(player.WolfState.PIT_FALL)
	return true
