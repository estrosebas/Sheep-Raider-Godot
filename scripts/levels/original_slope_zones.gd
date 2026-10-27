extends Node
# WAR zone104 + native Wolf_SurfaceVelocity; CameraRestriction follows the
# active player, never teleports him or substitutes a launch trajectory.
var data: Dictionary
var player: RalphController
var slope_time = 0.0
var pose_time = 0.0
var active = false

func _ready():
	data = JSON.parse_string(FileAccess.get_file_as_string(get_parent().asset_directory+"/data/slopes.json"))
	player = get_parent().player
	add_to_group("original_slopes")
	player.respawned.connect(reset)

func contains(point: Vector3) -> bool:
	return OriginalSam.contains(point,data.slide_boxes)

func ground(actor: CharacterBody3D) -> Dictionary:
	var query = PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.2,actor.global_position-Vector3.UP*.65,1)
	var excluded: Array[RID] = [actor.get_rid()]
	for sheep in get_tree().get_nodes_in_group("sheep_targets"):
		if sheep is CollisionObject3D: excluded.append(sheep.get_rid())
	query.exclude = excluded
	return actor.get_world_3d().direct_space_state.intersect_ray(query)

func release_motion():
	if active and player.current_state==player.WolfState.SLOPE_SLIDE:
		player.set_state(player.WolfState.IDLE if player.is_on_floor() else player.WolfState.FALL)
	active = false; slope_time = 0; pose_time = 0

func step_player(actor: RalphController,delta: float) -> bool:
	if actor.cinematic_controls_locked or actor.launch_controls_locked or actor.item_actions.busy or actor.inventory_controls_locked or actor.current_state in [actor.WolfState.PIT_FALL,actor.WolfState.SAM_DEATH,actor.WolfState.BLAST_DEATH,actor.WolfState.JUMP] or is_instance_valid(actor.active_rocket) or is_instance_valid(actor.push_target):
		release_motion(); return false
	var hit = ground(actor)
	if hit.is_empty() or actor.global_position.y-hit.position.y>.4:
		release_motion(); return false
	var board = hit.collider as OriginalSeesaw
	if is_instance_valid(board):
		if not board.definition.get("free_tilt",false) or board.slide_velocity().is_zero_approx(): release_motion(); return false
	elif not contains(actor.global_position): release_motion(); return false
	var normal: Vector3 = hit.normal
	# SLIDEBOX enables slope time even on shallow ramps; flat snow remains walkable.
	if normal.y>.995:
		release_motion(); return false
	if Input.is_action_just_pressed("jump"):
		release_motion(); return false
	if not active:
		active = true; pose_time = 0
		actor.set_state(actor.WolfState.SLOPE_SLIDE)
		actor.sneak_audio_player.stop(); actor.stop_loop_sfx()
	slope_time += delta; pose_time += delta
	var carry = is_instance_valid(actor.carried_sheep)
	var input = Input.get_vector("move_left","move_right","move_forward","move_backward")
	var desired = actor.movement_camera_basis()*Vector3(input.x,0,input.y)
	# Native normal surface:1+14*slopeTime (doubled SLIDEBOX rate),
	# carrying:2+20*slopeTime. X/Z cap12m/s, vertical cap20m/s.
	var pull = minf(80,(2 if carry else 1)+(20 if carry else 14)*slope_time)
	var velocity = (desired*(4.5 if carry else 6)+Vector3.DOWN*pull).slide(normal)
	velocity.x = clampf(velocity.x,-12,12); velocity.z = clampf(velocity.z,-12,12)
	velocity.y = maxf(-20,velocity.y-1.2)
	actor.velocity = velocity
	actor.move_and_slide()
	var horizontal = Vector3(velocity.x,0,velocity.z)
	if horizontal.length_squared()>.01: actor.skeleton.rotation.y = lerp_angle(actor.skeleton.rotation.y,atan2(horizontal.x,horizontal.z),minf(1,6*delta))
	var clip = "sheep_carry_slide" if carry else "slope_slide"
	if actor.animation_player.current_animation!=clip: actor.play_anim(clip)
	actor.last_ground_y = actor.global_position.y
	actor.jump_origin_y = null; actor.coyote_remaining = actor.coyote_time
	return true

func step_sheep(actor: OriginalSheep,delta: float) -> bool:
	if actor.carried_by or actor.dead or not actor.seesaw_arc.is_empty() or not contains(actor.global_position): return false
	var hit = ground(actor)
	if hit.is_empty() or hit.collider is OriginalSeesaw or hit.normal.y>.97 or actor.global_position.y-hit.position.y>.4: return false
	# Sheep::FALL / FallStep: slope gravity15m/s², capped14m/s.
	var normal: Vector3 = hit.normal
	actor.slope_fall_time += delta
	actor.velocity = (Vector3.DOWN*minf(14,7.5+15*actor.slope_fall_time)).slide(normal)
	actor.move_and_slide(); actor.last_floor_y = actor.global_position.y
	if actor.visual.idle_clip!="stand1": actor.visual.idle("stand1")
	return true

func reset(): release_motion()
