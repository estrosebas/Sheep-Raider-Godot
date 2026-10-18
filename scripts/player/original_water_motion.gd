extends RefCounted
# Shared adapter of WaterSinkStep/SwimMove. Native surface offset: 90 units.
var zone: Dictionary = {}
var elapsed = 0.0
var sink_time = 0.0
var sinking = false
var speed = 3.0 # Original normal-surface movement profile 8.
var acceleration = 10.0
var jump_surface: Variant = null
var surface_mode = true # Native WOLF_ST_WADE, distinct from submerged SWIM.
var pose_clip = ""
var pose_time = 0.0

func reset(actor):
	zone = {}; elapsed = 0; sink_time = 0; sinking = false
	actor.skeleton.rotation.x = 0
	actor.stop_loop_sfx()
	jump_surface = null
	surface_mode = true
	pose_clip = ""; pose_time = 0

func jump_out(actor,surface: float):
	# Wolf::SwimStateStep: a fresh jump press within20 native units of
	# the swim surface enters WATER_JUMP, followed by WATER_DOUBLEJUMP.
	# Hand the ascent to the existing parabolic jump controller, and keep
	# the water volume from recapturing the capsule before its return.
	reset(actor)
	jump_surface = surface
	actor.jump_origin_y = actor.global_position.y
	actor.last_ground_y = actor.global_position.y
	actor.jump_timer = 0
	actor.current_jump_height = actor.JUMP_HEIGHT*actor.jump_height_scale
	actor.current_jump_duration = actor.JUMP_DURATION
	actor.can_double_jump = true
	actor.coyote_remaining = 0
	actor.jump_void_grace = actor.JUMP_DURATION+actor.DOUBLE_JUMP_DURATION
	actor.velocity.y = 2*actor.current_jump_height/actor.current_jump_duration
	actor.set_state(actor.WolfState.JUMP)
	actor.was_on_floor = false
	actor.move_and_slide()

func step(actor,delta: float) -> bool:
	if actor.current_state in [actor.WolfState.PIT_FALL,actor.WolfState.BLAST_DEATH,actor.WolfState.SAM_DEATH]: return false
	if jump_surface != null:
		if actor.is_on_floor():
			jump_surface = null
			return false
		if actor.current_state==actor.WolfState.JUMP or actor.global_position.y>float(jump_surface)+.01:
			return false
		jump_surface = null
	var found: Dictionary = {}
	for provider in actor.get_tree().get_nodes_in_group("water_regions"):
		if provider.get_parent() == actor.get_parent():
			found = provider.water_at(actor.global_position)
			if not found.is_empty(): break
	if found.is_empty():
		if not zone.is_empty(): reset(actor); actor.set_state(actor.WolfState.FALL)
		return false
	# Adjacent/overlapping native water boxes may have different heights.
	# Refresh the current region without replaying the entry plunge.
	if not zone.is_empty(): zone = found
	var surface = -float(found.min[1])*.01-.9
	if not zone.is_empty() and not sinking:
		var controls_free = not actor.launch_controls_locked and not actor.inventory_controls_locked and not actor.tutorial_movement_locked
		if controls_free and Input.is_action_just_pressed("jump") and actor.global_position.y>=surface-.2 and actor.global_position.y<=surface+.01:
			jump_out(actor,surface)
			return true
		# Native SWIM -> WALK when shallow terrain raises the feet above
		# the swim line. Do not force Ralph down against a walkable bank.
		if actor.is_on_floor() and actor.global_position.y>surface+.01:
			reset(actor); actor.set_state(actor.WolfState.IDLE)
			return false
	if zone.is_empty():
		# interrupt_actions clears velocity; preserve the incoming fall before it.
		var entry_velocity: Vector3 = actor.velocity
		actor.interrupt_actions()
		actor.velocity = entry_velocity
		zone = found; elapsed = 0; sinking = true; surface_mode = true
		sink_time = clampf(maxf(0,-entry_velocity.y)/15,0,20.0/15)
		actor.set_state(actor.WolfState.SWIM)
		actor.play_anim("fall")
	elapsed += delta
	var input = Vector2.ZERO if actor.launch_controls_locked else Input.get_vector("move_left","move_right","move_forward","move_backward")
	var direction: Vector3 = actor.camera_pivot.global_basis*Vector3(input.x,0,input.y); direction.y = 0
	if direction.length_squared()>.01: actor.skeleton.rotation.y = lerp_angle(actor.skeleton.rotation.y,atan2(direction.x,direction.z),minf(1,TAU*delta))
	actor.velocity.x = move_toward(actor.velocity.x,direction.x*speed,acceleration*delta)
	actor.velocity.z = move_toward(actor.velocity.z,direction.z*speed,acceleration*delta)
	if sinking:
		sink_time = maxf(0,sink_time-3*delta)
		actor.velocity.y = -minf(20,15*sink_time)
		if sink_time <= 0 or actor.is_on_floor(): sinking = false
	else:
		var up = Input.is_action_pressed("jump") and not actor.launch_controls_locked
		var down = Input.is_action_pressed("run") and not actor.launch_controls_locked
		actor.velocity.y = move_toward(actor.velocity.y,(speed if up else 0.0)-(speed if down else 0.0),3.0*delta)
		if actor.global_position.y > surface: actor.velocity.y = minf(actor.velocity.y,-minf(2,(actor.global_position.y-surface)*4))
		# Clamp only ascending motion at the surface. Applying this to sinking
		# cancelled Shift and the plunge as soon as Ralph entered from above.
		if actor.velocity.y>0 and actor.global_position.y+actor.velocity.y*delta>surface:
			actor.velocity.y = maxf(0,(surface-actor.global_position.y)/delta)
	# Keep the collider inside this water volume while it brakes after a high
	# drop; a hazard must not lose the water state before its one-second delay.
	var bottom = -float(zone.max[1])*.01+.1
	if actor.velocity.y<0 and actor.global_position.y+actor.velocity.y*delta<bottom:
		actor.velocity.y = minf(0,(bottom-actor.global_position.y)/delta)
	actor.move_and_slide()
	if not sinking: update_swim_pose(actor,delta,surface,input)
	return true

func update_swim_pose(actor,delta: float,surface: float,input: Vector2):
	# Wolf::UpdateState WADE/SWIM compares depth AFTER SwimStateStep moves.
	# Enter surface motion above surface-20u; dive back below surface-50u.
	# This hysteresis prevents wave/rounding jitter from restarting the loops.
	if surface_mode:
		if actor.global_position.y<surface-.5: surface_mode = false
	elif actor.global_position.y>surface-.2: surface_mode = true
	var up = Input.is_action_pressed("jump") and not actor.launch_controls_locked
	var down = Input.is_action_pressed("run") and not actor.launch_controls_locked
	# SwimMove only pitches when vertical velocity is nonzero. Holding Space
	# against the surface must return upright instead of keeping the dive pose.
	var pitch = 0.0
	if absf(actor.velocity.y)>.001: pitch = PI/4 if down else -PI/4 if up else 0.0
	actor.skeleton.rotation.x = move_toward(actor.skeleton.rotation.x,pitch,PI*delta)
	var moving = input.length_squared()>.01
	var clip: String
	if surface_mode:
		clip = "swim1" if moving or absf(actor.skeleton.rotation.x)>.001 else "swim4"
	else: clip = "swim3" if moving or up or down else "swim2"
	if actor.animation_player.current_animation!=clip:
		actor.play_anim(clip); pose_clip = ""
	advance_pose_audio(actor,clip,delta)
	if clip=="swim3": actor.play_loop_sfx("res://assets/audio/sfx/original_swim_loop.wav")
	else: actor.stop_loop_sfx()

func advance_pose_audio(actor,clip: String,delta: float):
	# Anim_DecodeKey: SWIM1 emits sound51 at80ms, once per1500ms cycle.
	# Water returns before Ralph's normal animation-cue update, so track this
	# shared pose clock here. SWIM2/3/4 have no native key sounds.
	var previous = pose_time
	if pose_clip!=clip:
		pose_clip = clip; pose_time = 0; previous = -.001
	pose_time += delta
	var animation: Dictionary = actor.run_data.animations[clip]
	var duration = float(animation.duration)
	for cycle in range(maxi(0,int(maxf(previous,0)/duration)),int(pose_time/duration)+1):
		for cue in animation.sound_cues:
			var at = float(cue.time)+cycle*duration
			if at<=previous or at>pose_time: continue
			var sound: Dictionary = actor.run_data.sounds.get(str(int(cue.sound_id)),{})
			if not sound.is_empty(): actor.play_animation_sfx(sound.path)
