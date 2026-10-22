extends RefCounted
# Wolf::ClimbStep, profile6:100u/s,1000u/s². Input is wall-relative,
# independent of the camera. CLIMB1..5 and SND_SCOCOLD40 are native assets.
enum State { FREE, IDLE, UP, DOWN, LEFT, RIGHT, TOP_EXIT }
var state = State.FREE
var zone: Node3D
var speed = 0.0
var elapsed = 0.0
var clip = ""
var pose_time = 0.0
var exit_motion: Dictionary = {}

func climbing() -> bool: return is_instance_valid(zone)
func active() -> bool: return climbing() or not exit_motion.is_empty()

func clear(actor):
	if active(): actor.stop_loop_sfx()
	zone = null; exit_motion.clear(); state = State.FREE
	speed = 0; elapsed = 0; clip = ""; pose_time = 0

func begin(actor,provider: Node3D) -> bool:
	if not provider.contains(actor.global_position): return false
	actor.interrupt_actions()
	# Store hand equipment without dropping or consuming it. Both hands climb.
	if is_instance_valid(actor.inventory.equipped_node):
		actor.inventory.equipped_node.store()
		actor.inventory.equipped_node = null; actor.inventory.equipped_id = ""
	zone = provider; speed = 0; elapsed = 0; clip = ""; pose_time = 0
	actor.velocity = Vector3.ZERO; actor.jump_origin_y = null
	actor.can_double_jump = false; actor.jump_void_grace = 0
	actor.set_state(actor.WolfState.CLIMB)
	state = State.IDLE; play_pose(actor,"climb_idle",0)
	return true

func release(actor,jump: bool,top: bool = false):
	var direction: Vector3 = zone.wall_direction if climbing() else actor.item_facing()
	clear(actor)
	actor.floor_probe_warmup = 3; actor.was_on_floor = false
	if not jump:
		actor.velocity = Vector3.DOWN*.1; actor.set_state(actor.WolfState.FALL)
		return
	actor.jump_origin_y = actor.global_position.y; actor.last_ground_y = actor.global_position.y
	actor.jump_timer = 0; actor.current_jump_height = actor.JUMP_HEIGHT*actor.jump_height_scale
	actor.current_jump_duration = actor.JUMP_DURATION; actor.can_double_jump = true
	actor.jump_void_grace = actor.JUMP_DURATION+actor.DOUBLE_JUMP_DURATION
	actor.velocity = direction*(actor.walk_speed if top else -actor.walk_speed)
	actor.velocity.y = 2*actor.current_jump_height/actor.current_jump_duration
	actor.set_state(actor.WolfState.JUMP)
	if top:
		# Native leaves the region into JUMP_ASCEND. Keep its wall-relative push
		# during that exit so a free camera cannot steer W back into the shaft.
		exit_motion = {"direction":direction,"time":0.0}; state = State.TOP_EXIT

func step_exit(actor,delta: float) -> bool:
	exit_motion.time += delta
	var time = exit_motion.time
	actor.state_time += delta
	actor.velocity.x = exit_motion.direction.x*actor.walk_speed
	actor.velocity.z = exit_motion.direction.z*actor.walk_speed
	if time<=actor.current_jump_duration:
		actor.jump_timer = time
		actor.velocity.y = (2*actor.current_jump_height/actor.current_jump_duration)*(1-time/actor.current_jump_duration)
	else:
		if actor.current_state==actor.WolfState.JUMP: actor.set_state(actor.WolfState.FALL)
		actor.velocity.y = maxf(-actor.TERMINAL_VELOCITY,actor.velocity.y-actor.FALL_GRAVITY*delta)
	actor.move_and_slide()
	if (time>.1 and actor.is_on_floor()) or time>1.25:
		var landed = actor.is_on_floor()
		clear(actor); actor.velocity.x = 0; actor.velocity.z = 0
		actor.jump_origin_y = null if landed else actor.jump_origin_y
		actor.set_state(actor.WolfState.LAND if landed else actor.WolfState.FALL)
	return true

func step(actor,delta: float) -> bool:
	if not exit_motion.is_empty(): return step_exit(actor,delta)
	if not climbing(): return false
	if actor.current_state!=actor.WolfState.CLIMB: clear(actor); return false
	if Input.is_action_just_pressed("jump"):
		release(actor,true); return true
	if not zone.contains(actor.global_position,.08):
		release(actor,true,true); return true
	var input = Vector2.ZERO if actor.launch_controls_locked or actor.tutorial_movement_locked else Input.get_vector("move_left","move_right","move_forward","move_backward")
	elapsed += delta; actor.state_time += delta
	var moving = input.length_squared()>.001
	speed = move_toward(speed,float(zone.rules.speed)*input.length(),float(zone.rules.acceleration if moving else zone.rules.deceleration)*delta)
	var push = float(zone.rules.speed) if moving or elapsed<float(zone.rules.wall_push_seconds) else 0.0
	var direction: Vector3 = zone.wall_right*input.x+Vector3.UP*(-input.y)
	actor.velocity = direction.normalized()*speed+zone.wall_direction*push
	var target: Vector3 = actor.global_position+actor.velocity*delta
	target.x = clampf(target.x,zone.bounds.position.x,zone.bounds.end.x)
	target.z = clampf(target.z,zone.bounds.position.z,zone.bounds.end.z)
	target.y = maxf(target.y,zone.bounds.position.y)
	if zone.definition.clamp_top: target.y = minf(target.y,zone.bounds.end.y)
	actor.velocity = (target-actor.global_position)/delta
	actor.skeleton.rotation.y = lerp_angle(actor.skeleton.rotation.y,-zone.heading,minf(1,TAU*5*delta))
	var previous: Vector3 = actor.global_position
	actor.move_and_slide()
	var moved = actor.global_position.distance_squared_to(previous)>.000001
	state = State.IDLE
	if moving and moved:
		if absf(input.x)>absf(input.y): state = State.RIGHT if input.x>0 else State.LEFT
		else: state = State.UP if input.y<0 else State.DOWN
	var pose = {State.IDLE:"climb_idle",State.UP:"climb_up",State.DOWN:"climb_down",State.LEFT:"climb_left",State.RIGHT:"climb_right"}[state]
	play_pose(actor,pose,delta)
	if state==State.IDLE: actor.play_loop_sfx("res://assets/audio/sfx/climb_40.wav")
	else: actor.stop_loop_sfx()
	if actor.global_position.y>zone.bounds.end.y and not zone.definition.clamp_top: release(actor,true,true)
	return true

func play_pose(actor,name: String,delta: float):
	if clip!=name:
		clip = name; pose_time = -.001; actor.play_anim(name)
	var source: Dictionary = actor.run_data.animations[name]
	var previous = pose_time; pose_time += delta
	for cue in source.sound_cues:
		if cue.time>previous and cue.time<=pose_time:
			var sound = actor.run_data.sounds.get(str(int(cue.sound_id)),{})
			if not sound.is_empty() and not sound.get("loop",false): actor.play_animation_sfx(sound.path)
	if pose_time>=float(source.duration): pose_time = fmod(pose_time,float(source.duration))-.001
