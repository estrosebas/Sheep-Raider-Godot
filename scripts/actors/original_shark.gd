extends CharacterBody3D
# Shark50: objects/shark.cpp. Routes, boxes and sprites belong to the level;
# distances below are extracted native units converted by GameSpace (1:100).
enum State { PATROL, FACE, AIM, WIND_UP, LUNGE, BITE, MISS, HIT, BRAKE, RETURN, LOOK }
var definition: Dictionary
var sounds: Dictionary = {}
var visual: OriginalCinematicActor
var player: RalphController
var state = State.PATROL
var state_time = 0.0
var clip = "swim3"
var clip_time = -.001
var route: Array[Vector3] = []
var waypoint = 0
var home_height = 0.0
var initialized = false
var corner_distance = -1.0
var corner_in = 0.0
var corner_out = 0.0
var idle_pending = false
var idle_remaining = 3.0
var bite_accepted = false
var lunge_from = Vector3.ZERO
var lunge_to = Vector3.ZERO
var lunge_velocity = Vector3.ZERO
var lunge_traveled = 0.0
var return_velocity = Vector3.ZERO
var bite_count = 0
var played_cues: Array[int] = []
var sound_players: Array[AudioStreamPlayer3D] = []
var solid_boxes: Array[CollisionShape3D] = []
var breath: OriginalSpriteEmitter
var charge: OriginalSpriteEmitter
var ripples: OriginalSpriteEmitter

func _ready():
	player = get_parent().get_node("Player")
	visual = load(definition.directory+"/worn.tscn").instantiate(); add_child(visual)
	for box in definition.boxes:
		if int(box.flags)&1: continue
		var lo = GameSpace.original_point(Vector3(box.min[0],box.max[1],box.max[2]))
		var hi = GameSpace.original_point(Vector3(box.max[0],box.min[1],box.min[2]))
		var shape = BoxShape3D.new(); shape.size = hi-lo
		var collider = CollisionShape3D.new(); collider.shape = shape; collider.position = (lo+hi)/2
		collider.set_meta("native_center",collider.position); solid_boxes.append(collider)
		add_child(collider)
	# Wolf EAT and Shark EAT share their origin and orientation. The native
	# dying Wolf skips box tests; never let his live capsule stop a lunge.
	add_collision_exception_with(player)
	for i in range(4):
		var audio = AudioStreamPlayer3D.new(); audio.max_distance = 45
		add_child(audio); sound_players.append(audio)
	breath = make_emitter(definition.bubble_frames,8,2,.25,1.2,.1,.2)
	charge = make_emitter(definition.bubble_frames,16,2,.03125,1.2,.1,.2)
	ripples = make_emitter(definition.ripple_frames,8,2,.25,0,.5,2)
	for particle in ripples.particles:
		particle.sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		particle.sprite.rotation.x = -PI/2
	add_to_group("sharks")
	player.respawned.connect(reset_effects)
	call_deferred("initialize_route")

func make_emitter(paths: Array,capacity: int,lifetime: float,interval: float,rise: float,start: float,end: float) -> OriginalSpriteEmitter:
	var emitter = OriginalSpriteEmitter.new(); add_child(emitter)
	emitter.world_space = true; emitter.life = lifetime; emitter.period = interval
	emitter.rise_speed = rise; emitter.size_start = start; emitter.size_end = end
	emitter.configure(paths,capacity)
	return emitter

func initialize_route():
	home_height = global_position.y
	for point in definition.route:
		var world = GameSpace.original_point(Vector3(point[0],point[1],point[2]))
		world.y = home_height; route.append(world)
	initialized = true
	align_boxes()
	visual.sample_animation(clip,0)

func align_boxes():
	# ScnMobile's native boxes translate with the origin but never rotate
	# with artwork. In particular, pitching up during a lunge must not dig
	# the long shark box into the riverbed.
	var inverse = basis.inverse()
	for box in solid_boxes:
		box.transform = Transform3D(inverse,inverse*Vector3(box.get_meta("native_center")))

func reset_effects():
	# Shark::Reset clears emitters and the accepted-kill latch, not the
	# trajectory or state. Sharks keep swimming across checkpoint reloads.
	bite_accepted = false
	for emitter in [breath,charge,ripples]: emitter.clear()

func player_alive() -> bool:
	return player.restart_fade_remaining<=0 and player.current_state not in [player.WolfState.PIT_FALL,player.WolfState.SAM_DEATH,player.WolfState.BLAST_DEATH]

func player_in_zone() -> bool:
	return OriginalSam.contains(player.global_position,definition.zones)

func water_provider():
	return get_parent().get_node_or_null("LevelEnvironment")

func player_in_water() -> bool:
	var provider = water_provider()
	return provider!=null and not provider.water_at(player.global_position).is_empty()

func can_detect() -> bool:
	# DETECTRANGE=640 is loaded but UpdateAi actually compares with 9600.
	# Preserve that literal, the assigned BOX, and strict DETECTHEIGHT.
	return player_alive() and player_in_water() and player_in_zone() and global_position.distance_to(player.global_position)<=float(definition.detection_distance) and absf(global_position.y-player.global_position.y)<float(definition.detect_height)

func face(point: Vector3,pitch: bool = true):
	var delta = point-global_position
	rotation = Vector3(-atan2(delta.y,Vector2(delta.x,delta.z).length()) if pitch else 0,atan2(delta.x,delta.z),0)

func set_state(next: State):
	if state==next: return
	state = next; state_time = 0; clip_time = -.001
	match state:
		State.PATROL: clip = "swim2" if idle_pending else "swim3"
		State.FACE,State.AIM: clip = "stand1"
		State.WIND_UP: clip = "stand2"
		State.LUNGE:
			clip = "swim1"; face(player.global_position)
			lunge_from = global_position; lunge_to = player.global_position; lunge_traveled = 0
			lunge_velocity = (lunge_to-lunge_from).normalized()*float(definition.lunge_speed)
		State.BITE:
			clip = "eat"; bite_accepted = player.on_shark_attack(self)
			if bite_accepted: bite_count += 1
		State.MISS: clip = "attack1"
		State.HIT: clip = "hit1"
		State.BRAKE: clip = "brake"
		State.RETURN:
			clip = "swim1"
			# Native return uses current Wolf distance as its divisor, rather
			# than constant speed. Recover the distance actually traveled.
			return_velocity = (lunge_from-lunge_to)*float(definition.lunge_speed)/maxf(.01,global_position.distance_to(player.global_position))
			face(global_position-lunge_velocity)
		State.LOOK:
			clip = "look"; rotation.x = 0; rotation.z = 0
	visual.sample_animation(clip,0)

func patrol(delta: float):
	if route.is_empty(): return
	var toward = route[waypoint]-global_position; toward.y = 0
	if corner_distance<0 and toward.length()<float(definition.corner_entry_distance):
		var previous = route[posmod(waypoint-1,route.size())]
		var following = route[(waypoint+1)%route.size()]
		corner_in = atan2(route[waypoint].x-previous.x,route[waypoint].z-previous.z)
		corner_out = atan2(following.x-route[waypoint].x,following.z-route[waypoint].z)
		corner_distance = 0
	if toward.length()<=float(definition.patrol_speed)*delta:
		waypoint = (waypoint+1)%route.size()
		toward = route[waypoint]-global_position; toward.y = 0
	var before = global_position
	velocity = toward.normalized()*float(definition.patrol_speed)
	move_and_slide()
	if corner_distance>=0:
		rotation.y = lerp_angle(corner_in,corner_out,clampf(corner_distance/float(definition.corner_blend_distance),0,1))
		corner_distance += global_position.distance_to(before)
		if corner_distance>float(definition.corner_blend_distance): corner_distance = -1
	else: rotation.y = atan2(toward.x,toward.z)

func _physics_process(delta: float):
	if not initialized: return
	if player.cinematic_controls_locked:
		for emitter in [breath,charge,ripples]: emitter.emitting = false
		return
	state_time += delta
	if state==State.PATROL or (state==State.FACE and waypoint!=0): patrol(delta)
	var wet = player_alive() and player_in_water()
	var in_zone = player_in_zone()
	var reach = global_position.distance_to(player.global_position)<=float(definition.bite_distance)
	if wet and state not in [State.HIT,State.WIND_UP,State.LUNGE,State.BITE] and reach and in_zone and not bite_accepted:
		set_state(State.BITE)
	elif state in [State.PATROL,State.FACE] and can_detect():
		idle_pending = true
		set_state(State.AIM)
	elif state==State.PATROL and bool(definition.watch_over_cave) and waypoint==0 and wet:
		set_state(State.FACE)
	match state:
		State.PATROL:
			if idle_pending:
				idle_remaining -= delta
				if idle_remaining<=0:
					idle_pending = false; idle_remaining = 3; clip = "swim3"; clip_time = -.001
		State.FACE:
			face(player.global_position,false)
			if not wet or waypoint!=0: set_state(State.PATROL)
		State.AIM:
			if not in_zone or not wet: set_state(State.LOOK)
			elif state_time>=float(definition.aim_seconds): set_state(State.WIND_UP)
			else: face(player.global_position)
		State.WIND_UP:
			if not in_zone or not wet: set_state(State.LOOK)
			elif clip_time>=float(visual.rig.animations[clip].duration): set_state(State.LUNGE)
		State.LUNGE:
			if not in_zone: set_state(State.MISS)
			elif wet and reach: set_state(State.BITE)
			else:
				var before = global_position
				velocity = lunge_velocity; move_and_slide()
				lunge_traveled += global_position.distance_to(before)
				if get_slide_collision_count()>0: set_state(State.HIT)
				elif lunge_traveled>=lunge_from.distance_to(lunge_to): set_state(State.MISS)
		State.BITE,State.MISS,State.HIT:
			if clip_time>=float(visual.rig.animations[clip].duration): set_state(State.BRAKE)
		State.BRAKE:
			if clip_time>=float(visual.rig.animations[clip].duration): set_state(State.RETURN)
		State.RETURN:
			var step = minf(return_velocity.length()*delta,lunge_traveled)
			global_position += return_velocity.normalized()*step
			lunge_traveled -= step
			if lunge_traveled<=.001:
				# Also handles an immediate close bite, with no preceding lunge.
				set_state(State.LOOK)
		State.LOOK: set_state(State.PATROL)
	advance_animation(delta)
	align_boxes()
	update_effects()

func advance_animation(delta: float):
	var previous = clip_time; clip_time += delta
	var duration = float(visual.rig.animations[clip].duration)
	var looping = state in [State.PATROL,State.FACE,State.AIM,State.LUNGE,State.RETURN,State.LOOK]
	visual.sample_animation(clip,clip_time,looping)
	for cue in visual.rig.animations[clip].get("sound_cues",[]):
		var time = float(cue.time)
		if looping: time += floor(maxf(0,previous)/duration)*duration
		if previous<time and clip_time>=time:
			var identity = int(cue.sound_id)
			played_cues.append(identity)
			if played_cues.size()>32: played_cues.pop_front()
			if not sounds.has(str(identity)): continue
			for audio in sound_players:
				if audio.playing: continue
				audio.stream = load(sounds[str(identity)]); audio.play(); break

func update_effects():
	var provider = water_provider()
	var water: Dictionary = provider.water_at(global_position) if provider!=null else {}
	for emitter in [breath,charge,ripples]: emitter.emitting = false
	if water.is_empty(): return
	var surface = -float(water.min[1])*.01
	# Shark::Render applies its quarter-strength blue tint only when the
	# camera is outside water; the underwater camera supplies the water tint.
	var tint = .25 if provider.water_at(player.camera.global_position).is_empty() else 0.0
	for material in visual.legacy_skin.materials:
		material.set_shader_parameter("original_tint_color",Vector3(.37647,.37647,1))
		material.set_shader_parameter("original_tint_amount",tint)
	var depth = surface-global_position.y
	var forward = global_basis.z
	breath.global_position = global_position+forward*.9+Vector3(randf_range(-.25,.25),randf_range(.5,.75),randf_range(-.25,.25))
	breath.emitting = depth>=1.5
	charge.global_position = global_position-forward*.9
	charge.life = .25 if state==State.WIND_UP else 2.0
	charge.rise_speed = 1.2 if state==State.WIND_UP else .3
	charge.emitting = depth>=.25 and state in [State.WIND_UP,State.LUNGE]
	ripples.global_position = Vector3(global_position.x+randf_range(-.25,.25),surface+.01,global_position.z+randf_range(-.25,.25))
	ripples.emitting = depth>=0 and depth<=1.5
	for emitter in [breath,charge]:
		for particle in emitter.particles:
			if particle.age<emitter.life and particle.sprite.global_position.y>surface:
				particle.age = emitter.life; particle.sprite.hide()
	for particle in ripples.particles: particle.sprite.modulate.a = clampf(1-particle.age/ripples.life,0,1)
