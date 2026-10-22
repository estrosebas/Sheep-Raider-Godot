extends RefCounted
class_name OriginalSheepCarry

# Wolf's mode-1 table, movement bank and g_wolfIdleAnimsCarry.
enum Phase { GROUND, JUMP_START, ASCEND, FALL, LAND }
const JUMP_HEIGHT = 1.3
const JUMP_DURATION = 0x48b/4096.0
var phase = Phase.GROUND
var time = 0.0
var clip = ""
var clip_time = 0.0
var idle_loops = 0
var tired = false
var was_moving = false

func select_clip(actor: RalphController, name: String) -> void:
	if clip == name:
		if actor.animation_player.current_animation != name: actor.play_anim(name)
		return
	clip = name
	clip_time = 0
	actor.play_anim(name)
	if name == "sheep_carry_idle": idle_loops = randi_range(3,5)
	elif name == "sheep_carry_tired": idle_loops = randi_range(1,2)

func step(sheep: OriginalSheep, delta: float) -> void:
	var actor = sheep.carried_by
	var on_ground = actor.is_on_floor()
	var input = Vector2.ZERO if actor.launch_controls_locked else Input.get_vector("move_left","move_right","move_forward","move_backward")
	var direction = actor.camera_pivot.global_basis*Vector3(input.x,0,input.y)
	direction.y = 0
	var moving = direction.length_squared() > .01
	direction = direction.normalized() if moving else Vector3.ZERO
	var sneak = Input.is_action_pressed("sneak") and not actor.launch_controls_locked
	var speed = 2.0 if sneak else 4.5
	var acceleration = 8.0 if sneak else 20.0
	actor.can_double_jump = false
	actor.jump_void_grace = maxf(0,actor.jump_void_grace-delta)
	if phase == Phase.GROUND:
		if not on_ground:
			phase = Phase.FALL
		elif Input.is_action_just_pressed("jump") and not actor.launch_controls_locked:
			phase = Phase.JUMP_START
			time = 0
			tired = false
			actor.jump_origin_y = actor.global_position.y
		elif moving:
			tired = false
	elif phase == Phase.JUMP_START:
		time += delta
		if time >= actor.animation_player.get_animation("sheep_carry_jump_start").length:
			phase = Phase.ASCEND
			time = 0
			actor.velocity.y = 2*JUMP_HEIGHT/JUMP_DURATION
			actor.jump_void_grace = JUMP_DURATION
	elif phase == Phase.ASCEND:
		time += delta
		actor.velocity.y = 2*JUMP_HEIGHT/JUMP_DURATION*(1-time/JUMP_DURATION)
		if time >= JUMP_DURATION:
			phase = Phase.FALL
			time = 0
	elif phase == Phase.FALL:
		if on_ground:
			phase = Phase.LAND
			time = 0
	elif phase == Phase.LAND:
		time += delta
		if time >= actor.animation_player.get_animation(clip).length:
			phase = Phase.GROUND
			tired = false
	if phase == Phase.GROUND and on_ground:
		actor.jump_origin_y = null
		actor.last_ground_y = actor.global_position.y
	if moving:
		actor.skeleton.rotation.y = lerp_angle(actor.skeleton.rotation.y,atan2(direction.x,direction.z),minf(1,16*delta))
	var target = direction*speed if phase != Phase.JUMP_START else Vector3.ZERO
	actor.velocity.x = move_toward(actor.velocity.x,target.x,(acceleration if moving else (4.0 if sneak else 15.0))*delta)
	actor.velocity.z = move_toward(actor.velocity.z,target.z,(acceleration if moving else (4.0 if sneak else 15.0))*delta)
	if phase not in [Phase.ASCEND]:
		actor.velocity.y = 0 if on_ground else maxf(-20,actor.velocity.y-29*delta)
	var desired_state = actor.WolfState.IDLE
	var desired_clip = "sheep_carry_tired" if tired else "sheep_carry_idle"
	if phase == Phase.JUMP_START:
		desired_state = actor.WolfState.JUMP
		desired_clip = "sheep_carry_jump_start"
	elif phase == Phase.ASCEND:
		desired_state = actor.WolfState.JUMP
		desired_clip = "sheep_carry_jump"
	elif phase == Phase.FALL:
		desired_state = actor.WolfState.FALL
		desired_clip = "sheep_carry_apex" if time < actor.animation_player.get_animation("sheep_carry_apex").length else "sheep_carry_fall"
		time += delta
	elif phase == Phase.LAND:
		desired_state = actor.WolfState.LAND
		desired_clip = "sheep_carry_land_move" if moving else "sheep_carry_land_idle"
	elif moving:
		desired_state = actor.WolfState.SNEAK if sneak else actor.WolfState.WALK
		desired_clip = "sheep_carry_sneak" if sneak else "sheep_carry_walk"
	elif sneak: desired_state = actor.WolfState.SNEAK
	if actor.current_state != desired_state: actor.set_state(desired_state)
	select_clip(actor,desired_clip)
	if moving and not was_moving and desired_state == actor.WolfState.SNEAK:
		actor.sneak_step_count = 0
		actor.footstep_timer = 0
	if not moving: actor.sneak_audio_player.stop()
	actor.handle_audio(delta,moving,on_ground)
	was_moving = moving
	# Sheep::MSG_CARRY_ANIM: 0/2/3 -> STAND8; 1/4 -> RUN2.
	var sheep_clip = "run2" if phase in [Phase.GROUND,Phase.LAND] and moving else "stand8"
	if sheep.visual.idle_clip != sheep_clip: sheep.visual.idle(sheep_clip)
	var previous = clip_time
	clip_time += delta
	for cue in actor.run_data["animations"][clip]["sound_cues"]:
		var duration: float = actor.animation_player.get_animation(clip).length
		var cue_time = float(cue["time"])+floor(previous/duration)*duration
		if cue_time <= previous: cue_time += duration
		if cue_time <= clip_time and (actor.animation_player.get_animation(clip).loop_mode == Animation.LOOP_LINEAR or clip_time <= duration):
			var sound = actor.run_data["sounds"].get(str(int(cue["sound_id"])))
			if sound: actor.play_animation_sfx(sound["path"])
	if phase == Phase.GROUND and not moving and not sneak:
		var duration: float = actor.animation_player.get_animation(clip).length
		if floor(clip_time/duration) > floor(previous/duration):
			idle_loops -= 1
			if idle_loops <= 0:
				tired = not tired
				select_clip(actor,"sheep_carry_tired" if tired else "sheep_carry_idle")
	actor.was_on_floor = on_ground
	# Wolf::Move applies registered MSG_MODIFY_MOVE riders in carry mode too.
	# Keep the untethered velocity for the next tick, as ordinary walking does.
	var base_velocity = actor.velocity
	var elastic_adjusted = false
	for elastic in actor.get_tree().get_nodes_in_group("elastic_controllers"):
		if elastic.get_world_3d()==actor.get_world_3d(): elastic_adjusted = elastic.modify_move(actor,delta) or elastic_adjusted
	if is_instance_valid(actor.elastic_motion_owner): return
	actor.move_and_slide()
	if elastic_adjusted:
		actor.velocity = base_velocity
		for index in range(actor.get_slide_collision_count()):
			var normal = actor.get_slide_collision(index).get_normal()
			if actor.velocity.dot(normal)<0: actor.velocity = actor.velocity.slide(normal)
	actor.check_void_below()
