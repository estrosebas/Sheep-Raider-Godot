extends CharacterBody3D
# Reusable bull43 adapter from objects/bull.cpp. Geometry/pivots are untouched.
enum State { ASLEEP, WAKING, IDLE, CHARGE, SKID, HIT, RETURN_HOME, STUNNED, ESCAPE }
var escaped = false
var definition: Dictionary
var sounds: Dictionary = {}
var visual: OriginalCinematicActor
var player: RalphController
var state = State.ASLEEP
var home = Vector3.ZERO
var home_yaw = 0.0
var grounded = false
var clip = "sleep1"
var clip_time = -.001
var clip_speed = 1.0
var state_time = 0.0
var charge_target = Vector3.ZERO
var stalled_time = 0.0
var sound: AudioStreamPlayer3D
var charge_sound: AudioStreamPlayer3D
var dust: OriginalSpriteEmitter
var wake_count = 0
var hit_count = 0

func _ready():
	player = get_parent().get_node("Player")
	visual = load(definition.directory+"/worn.tscn").instantiate(); add_child(visual)
	for box in definition.get("boxes",[]):
		if int(box.flags)&1: continue
		var lo = GameSpace.original_point(Vector3(box.min[0],box.max[1],box.max[2]))
		var hi = GameSpace.original_point(Vector3(box.max[0],box.min[1],box.min[2]))
		var shape = BoxShape3D.new(); shape.size = hi-lo
		var collider = CollisionShape3D.new(); collider.shape = shape; collider.position = (lo+hi)/2
		add_child(collider)
	sound = AudioStreamPlayer3D.new(); add_child(sound); sound.max_distance = 45
	charge_sound = AudioStreamPlayer3D.new(); add_child(charge_sound); charge_sound.max_distance = 45
	if sounds.has("253"):
		var loop: AudioStreamWAV = load(sounds["253"]).duplicate()
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD; loop.loop_end = roundi(loop.get_length()*loop.mix_rate)
		charge_sound.stream = loop
	dust = OriginalSpriteEmitter.new(); add_child(dust)
	dust.world_space = true
	dust.life = 2; dust.period = .125; dust.rise_speed = .6; dust.spread = .5
	dust.size_start = .8; dust.size_end = 1.8; dust.position.y = .25
	dust.configure(definition.get("dust_frames",[]),16)
	add_to_group("grounded_npcs"); add_to_group("bulls")
	add_to_group("loud_noise_receivers"); add_to_group("blast_targets")
	player.respawned.connect(reset_to_home)
	_set_state(State.ASLEEP if definition.asleep else State.IDLE,"sleep1" if definition.asleep else "stand1")
	call_deferred("snap_home_to_ground")

func snap_home_to_ground():
	# Native PostLoadInit SnapToGround(1) precedes saving homePos. Use the
	# authored model origin, whose collision box has maxY=0, rather than
	# adding an arbitrary visual offset to the sleep or waking poses.
	var query = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*3,global_position+Vector3.DOWN*30,1)
	var excluded: Array[RID] = [get_rid(),player.get_rid()]
	for actor in get_tree().get_nodes_in_group("grounded_npcs"):
		if actor is CollisionObject3D and actor!=self: excluded.append(actor.get_rid())
	query.exclude = excluded
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): global_position.y = hit.position.y+.001
	home = global_position; home_yaw = rotation.y; grounded = true

func _set_state(next: State,animation: String):
	state = next; state_time = 0; clip = animation; clip_time = -.001; clip_speed = 1
	stalled_time = 0
	if next == State.WAKING: clip_speed = maxf(.01,float(definition.wake_speed_pct)/100)
	if next != State.CHARGE: charge_sound.stop()
	if next == State.CHARGE:
		charge_target = player.global_position
		if charge_sound.stream and not charge_sound.playing: charge_sound.play()
	if next == State.ESCAPE:
		# bull::SetState: quarter horizontal charge, quadruple its 250 cm/s
		# downward component. ESCAPE translates directly without collision.
		velocity = Vector3(velocity.x/4,-10,velocity.z/4)
		dust.emitting = false
		if sounds.has("202"):
			var loop: AudioStreamWAV = load(sounds["202"]).duplicate()
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_end = roundi(loop.get_length()*loop.mix_rate)
			charge_sound.stream = loop; charge_sound.play()
	visual.sample_animation(clip,0)

func wake_from_noise():
	if state != State.ASLEEP or not grounded: return
	wake_count += 1
	_set_state(State.WAKING,"up1a" if definition.asleep else "stand2")

func on_loud_noise(origin: Vector3,radius: float,_source_class: int = -1):
	if global_position.distance_to(origin)<=radius: wake_from_noise()

func noisy_player() -> bool:
	return player.current_state in [player.WolfState.WALK,player.WolfState.RUN_START,player.WolfState.RUN,player.WolfState.RUN_AIR,player.WolfState.JUMP,player.WolfState.FALL]

func player_dead() -> bool:
	return player.current_state in [player.WolfState.PIT_FALL,player.WolfState.BLAST_DEATH,player.WolfState.SAM_DEATH]

func moving_zone_contains(point: Vector3) -> bool:
	return OriginalSam.contains(point,definition.movement_boxes)

func can_follow_over_edge() -> bool:
	# Native noReturnBox + MSG_WOLF_IS_USING_SPECIAL_OBJECT. Merely holding
	# an elastic in the inventory does not qualify: Ralph must be tethered.
	if not OriginalSam.contains(player.global_position,definition.get("no_return_boxes",[])): return false
	for elastic in get_tree().get_nodes_in_group("elastic_controllers"):
		if elastic.protects_from_void(player): return true
	return false

func step_escape(delta: float):
	if OriginalSam.contains(global_position,definition.get("no_return_boxes",[])):
		global_position += velocity*delta
	else:
		# Native RemoveFromWorld; Reset deliberately does not resurrect it.
		escaped = true; hide(); collision_layer = 0; collision_mask = 0
		charge_sound.stop(); sound.stop(); dust.clear()
		set_physics_process(false); set_process(false)

func _physics_process(delta: float):
	if not grounded or not is_instance_valid(player): return
	if state == State.ESCAPE:
		step_escape(delta); return
	if player.cinematic_controls_locked:
		velocity = Vector3.ZERO; dust.emitting = false
		return
	state_time += delta
	var motion = Vector3.ZERO
	match state:
		State.ASLEEP:
			if not player_dead() and (global_position.distance_squared_to(player.global_position)<pow(float(definition.close_wake_distance),2) or (OriginalSam.contains(player.global_position,definition.activation_boxes) and noisy_player())):
				wake_from_noise()
		State.WAKING:
			if clip_time>=float(visual.rig.animations[clip].duration): _set_state(State.CHARGE,"run2")
		State.IDLE:
			if not player_dead() and moving_zone_contains(player.global_position): _set_state(State.CHARGE,"run2")
		State.CHARGE:
			var runoff = can_follow_over_edge()
			if player_dead() or (not moving_zone_contains(player.global_position) and not runoff):
				_set_state(State.RETURN_HOME,"run2")
			elif global_position.distance_to(player.global_position)<=float(definition.hit_distance):
				rotation.y = atan2(player.global_position.x-global_position.x,player.global_position.z-global_position.z)
				hit_count += 1
				player.on_bull_attack(self)
				_set_state(State.HIT,"hit1")
			else:
				var toward = charge_target-global_position; toward.y = 0
				if state_time>float(definition.retarget_seconds) or toward.length()<1:
					charge_target = player.global_position; state_time = 0
					toward = charge_target-global_position; toward.y = 0
				motion = toward.normalized()*float(definition.charge_speed)
				if not moving_zone_contains(global_position+motion*delta):
					if runoff:
						velocity = Vector3(motion.x,-2.5,motion.z)
						_set_state(State.ESCAPE,"fall")
						return
					motion = Vector3.ZERO; _set_state(State.RETURN_HOME,"run2")
		State.SKID:
			if clip_time>=float(visual.rig.animations[clip].duration): _set_state(State.CHARGE,"run2")
		State.HIT:
			if clip=="hit1" and clip_time>=float(visual.rig.animations.hit1.duration):
				clip = "stand2"; clip_time = -.001
			if state_time>=float(definition.hit_recovery_seconds): _set_state(State.IDLE,"stand2")
		State.RETURN_HOME:
			var toward = home-global_position; toward.y = 0
			if toward.length()<=.25:
				global_position.x = home.x; global_position.z = home.z; rotation.y = home_yaw
				_set_state(State.ASLEEP if definition.asleep else State.IDLE,"sleep1" if definition.asleep else "stand1")
			else: motion = toward.normalized()*float(definition.charge_speed)
	if motion.length_squared()>.01: rotation.y = atan2(motion.x,motion.z)
	var before = global_position
	velocity = Vector3(motion.x,-2.5 if is_on_floor() else maxf(-20,velocity.y-29*delta),motion.z)
	move_and_slide()
	dust.emitting = state in [State.CHARGE,State.RETURN_HOME,State.SKID] and motion.length_squared()>.01
	if motion.length_squared()>.01 and global_position.distance_squared_to(before)<.0001:
		stalled_time += delta
		if state==State.CHARGE and stalled_time>.3: _set_state(State.SKID,"brake1b")
	else: stalled_time = 0

func _process(delta: float):
	if not grounded or escaped or (player.cinematic_controls_locked and state != State.ESCAPE): return
	var previous = clip_time
	clip_time += delta*clip_speed
	var duration = float(visual.rig.animations[clip].duration)
	var looping = state in [State.ASLEEP,State.IDLE,State.CHARGE,State.RETURN_HOME,State.ESCAPE] or (state==State.HIT and clip=="stand2")
	visual.sample_animation(clip,clip_time,looping)
	for cue in visual.rig.animations[clip].get("sound_cues",[]):
		var time = float(cue.time)
		if looping: time += floor(maxf(0,previous)/duration)*duration
		if previous<time and clip_time>=time and sounds.has(str(int(cue.sound_id))):
			sound.stream = load(sounds[str(int(cue.sound_id))]); sound.play()

func query_moved() -> bool:
	return state in [State.CHARGE,State.SKID,State.RETURN_HOME,State.ESCAPE] and not escaped

func on_blast(_origin: Vector3):
	if state == State.ESCAPE: return
	OriginalBurntTint.apply(visual.legacy_skin,true)
	# bull::Update has no BULL_ST_STUNNED recovery case: STRIKE2 finishes
	# and holds its final pose until Reset. Do not add a guessed wake timer.
	_set_state(State.STUNNED,"strike2")

func reset_to_home():
	if not grounded or state == State.ESCAPE: return
	global_position = home; rotation.y = home_yaw; velocity = Vector3.ZERO
	OriginalBurntTint.apply(visual.legacy_skin,false)
	dust.clear(); sound.stop()
	_set_state(State.ASLEEP if definition.asleep else State.IDLE,"sleep1" if definition.asleep else "stand1")
