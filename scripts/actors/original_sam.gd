extends OriginalGroundedActor
class_name OriginalSam

enum State { GUARD, CHASE, RETURN_HOME, CATCH, STUNNED, INVESTIGATE, HYPNOTIZED }
enum KnockoutPhase { FALL, LYING, GET_UP }
signal alert_changed(level: int)
var rules: Dictionary
var state = State.GUARD
var alert_level = -1
var head_phase = 0.0
var head_yaw = 0.0
var relative_angle = 0.0
var home: Vector3
var home_yaw = 0.0
var player: RalphController
var graph = AStar3D.new()
var path = PackedVector3Array()
var repath = 0.0
var state_elapsed = 0.0
var investigate_point: Vector3
var indicator: OriginalSamIndicator
var audio: AudioStreamPlayer3D
var sounds: Dictionary
var clip = "start"
var clip_time = -0.001
var catch_punched = false
var forced_alert = false
var burnt = false
var route_target = Vector3.INF
var stall_anchor: Vector3
var stall_time = 0.0
var force_nodes = false
var blocked_nodes: Dictionary = {}
var flute_timer = -1.0
var flute_stop_delay = 0.0
var flute_zones: Array = []
var flute_rules: Dictionary = {}
var knockout_phase = KnockoutPhase.FALL
var knockout_remaining = 0.0
# Optional port tuning. Disabled by default: use the original authored zones.
@export var chase_leash_distance = 0.0
@export_range(0.5,2.0,0.05) var chase_speed_multiplier = 1.0
@export_file("*.json") var rules_path = "res://assets/levels/lvl_01/data/sam.json"
@export_file("*.json") var audio_path = "res://assets/levels/lvl_01/data/ai_audio.json"

func _ready() -> void:
	super._ready()
	add_to_group("sam_guards")
	add_to_group("blast_targets")
	add_to_group("loud_noise_receivers")
	player = get_parent().get_node("Player")
	rules = JSON.parse_string(FileAccess.get_file_as_string(rules_path))
	sounds = JSON.parse_string(FileAccess.get_file_as_string(audio_path))
	_build_graph()
	floor_snap_length = .4
	audio = AudioStreamPlayer3D.new()
	audio.max_distance = 40
	add_child(audio)
	indicator = OriginalSamIndicator.new()
	indicator.guard = self
	add_child(indicator)
	player.respawned.connect(reset_guard)
	call_deferred("_remember_home")
	# Sam's own evaluator owns time and joint 9; do not let idle overwrite it.
	visual.idle_clip = ""
	visual.set_process(false)
	visual.sample_animation("head2",0)

func _remember_home() -> void:
	home = global_position
	home_yaw = rotation.y

static func contains(point: Vector3, boxes: Array, height: bool = true) -> bool:
	for box in boxes:
		var a = box["min"]
		var b = box["max"]
		var lo = GameSpace.original_point(Vector3(a[0],b[1],b[2]))
		var hi = GameSpace.original_point(Vector3(b[0],a[1],a[2]))
		if point.x >= lo.x and point.x <= hi.x and point.z >= lo.z and point.z <= hi.z and (not height or (point.y >= lo.y and point.y <= hi.y)): return true
	return false

func update_alert() -> void:
	var next = -1
	if state in [State.CHASE,State.CATCH]: next = 2
	elif contains(player.global_position,rules["green"]):
		next = 1 if contains(player.global_position,rules["orange"]) else 0
	if state in [State.STUNNED,State.HYPNOTIZED]: next = -1
	if alert_level != next:
		alert_level = next
		alert_changed.emit(next)

func can_detect_player() -> bool:
	if _player_unavailable() or outside_chase_leash(player.global_position): return false
	if player.hidden_from_observer(global_position): return false
	if forced_alert: return inside_hit_zone(player.global_position)
	if is_instance_valid(player.active_bush) and player.active_bush.hidden_from_sam():
		return global_position.distance_to(player.global_position) < 1.0 and inside_hit_zone(player.global_position)
	if alert_level != 1: return false
	if player.item_costume == "sheep": return false
	if not inside_hit_zone(player.global_position): return false
	var difference = player.global_position-global_position
	var close = Vector2(difference.x,difference.z).length() < 1.0
	var noisy = player.current_state in [player.WolfState.WALK,player.WolfState.RUN_START,player.WolfState.RUN,player.WolfState.RUN_AIR,player.WolfState.JUMP,player.WolfState.LAND] and player.velocity.length_squared() > .0025
	# DetectWolf: noise / <100 units / narrow head cone 0x71. Cover boxes
	# are authored visibility restrictions; generic occlusion rays are an adapter.
	var seen = absf(relative_angle) < 0x71*TAU/4096 and not contains(player.global_position,rules["hiding"])
	return close or noisy or (seen and _clear_line(player.global_position))

func _player_unavailable() -> bool:
	return player.cinematic_controls_locked or player.tutorial_movement_locked or player.current_state in [player.WolfState.PIT_FALL,player.WolfState.BLAST_DEATH,player.WolfState.SAM_DEATH] or player.restart_fade_remaining > 0

func inside_hit_zone(point: Vector3) -> bool:
	# Sam::PointInBoxListXYZ returns1 for a null list (e.g. level03).
	return rules.hit.is_empty() or contains(point,rules.hit)

func _clear_line(target: Vector3) -> bool:
	var query = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.7,target+Vector3.UP*.7)
	query.collision_mask = 1
	var excluded: Array[RID] = [get_rid(),player.get_rid()]
	for sheep in get_tree().get_nodes_in_group("grounded_npcs"):
		if sheep is CollisionObject3D: excluded.append(sheep.get_rid())
	query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _build_graph() -> void:
	var ids: Dictionary = {}
	for route in rules["routes"]:
		var previous = -1
		for p in route:
			var key = "%d:%d" % [p[0],p[2]]
			if not ids.has(key):
				ids[key] = ids.size()
				graph.add_point(ids[key],GameSpace.original_point(Vector3(p[0],p[1],p[2])))
			var index: int = ids[key]
			if previous >= 0 and previous != index and not graph.are_points_connected(previous,index): graph.connect_points(previous,index)
			previous = index

func _route(target: Vector3) -> void:
	path.clear()
	route_target = target
	if not force_nodes and _clear_move(global_position,target):
		path.append(target)
	elif graph.get_point_count() > 0:
		var start = _reachable_node(global_position)
		var end = _reachable_node(target,true)
		if start >= 0 and end >= 0:
			var excluded_nodes: Array[int] = []
			for index in graph.get_point_ids():
				if blocked_nodes.has(index) or not contains(graph.get_point_position(index),rules["authorized"],false):
					excluded_nodes.append(index)
					graph.set_point_disabled(index,true)
			path = graph.get_point_path(start,end)
			for index in excluded_nodes: graph.set_point_disabled(index,false)
			var end_ground = _ground(graph.get_point_position(end))
			if not path.is_empty() and end_ground != null and _clear_move(end_ground,target): path.append(target)
	repath = .35
	stall_time = 0
	stall_anchor = global_position
	force_nodes = false

func _navigation_exclusions() -> Array[RID]:
	var excluded: Array[RID] = [get_rid(),player.get_rid()]
	for actor in get_tree().get_nodes_in_group("grounded_npcs"):
		if actor is CollisionObject3D: excluded.append(actor.get_rid())
	return excluded

func _ground(point: Vector3) -> Variant:
	var query = PhysicsRayQueryParameters3D.create(point+Vector3.UP*3,point-Vector3.UP*30)
	query.exclude = _navigation_exclusions()
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	return null if hit.is_empty() else hit["position"]

func _clear_move(origin: Vector3, target: Vector3) -> bool:
	# Visibility alone does not prove a route fits Sam's collision body.
	var motion = target-origin
	var target_ground = _ground(target)
	if target_ground == null: return false
	motion.y = target_ground.y-origin.y
	var shape = CapsuleShape3D.new()
	shape.radius = .45
	shape.height = 1.72
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,origin+Vector3.UP*.95)
	query.motion = motion
	query.exclude = _navigation_exclusions()
	var fraction = get_world_3d().direct_space_state.cast_motion(query)
	if fraction[0] < .99: return false
	# Native REACHGOAL changes to node search when the ground drops >100u.
	var previous = origin.y
	var count = maxi(1,ceili(motion.length()/1.0))
	for i in range(1,count+1):
		var ground = _ground(origin+motion*(float(i)/count))
		if ground == null or absf(ground.y-previous) > 1.0: return false
		previous = ground.y
	return true

func _reachable_node(point: Vector3, allow_nearest: bool = false) -> int:
	var candidates: Array = Array(graph.get_point_ids())
	candidates.sort_custom(func(a,b): return graph.get_point_position(a).distance_squared_to(point) < graph.get_point_position(b).distance_squared_to(point))
	for index in candidates:
		if blocked_nodes.has(index) or not contains(graph.get_point_position(index),rules["authorized"],false): continue
		var position = graph.get_point_position(index)
		var ground = _ground(position)
		if ground == null: continue
		position.y = ground.y
		if _clear_move(point,position): return index
	if allow_nearest:
		for index in candidates:
			if not blocked_nodes.has(index) and contains(graph.get_point_position(index),rules["authorized"],false) and _ground(graph.get_point_position(index)) != null: return index
	return -1

func movement_speed() -> float:
	# Sam::SetState / SetGoalHome: level 01 has CHASE_CAMERA (0x10000),
	# not ALT_BEHAVIOUR (0x20000). It runs home at 1100u/s with RUN2.
	if state == State.CHASE: return (16.5 if (int(rules["mode"]) & 0x40000) else 11.0)*chase_speed_multiplier
	if state == State.INVESTIGATE: return 2.0
	var mode = int(rules["mode"])
	if mode & 0x20000:
		return 2.0 if absf(home.x-global_position.x)+absf(home.z-global_position.z) < 4 else 11.0
	return 2.0 if mode & 0x8000 else 11.0

func _enter(next: State, animation: String) -> void:
	if next in [State.GUARD,State.CHASE,State.RETURN_HOME,State.CATCH,State.STUNNED]: flute_timer = -1
	state = next
	state_elapsed = 0
	clip = animation
	clip_time = -0.001
	repath = 0
	path.clear()
	route_target = Vector3.INF
	stall_time = 0
	stall_anchor = global_position
	force_nodes = false
	blocked_nodes.clear()
	head_yaw = 0
	update_alert()

func reset_guard() -> void:
	flute_timer = -1; flute_stop_delay = 0
	knockout_phase = KnockoutPhase.FALL; knockout_remaining = 0
	global_position = home
	rotation.y = home_yaw
	velocity = Vector3.ZERO
	remove_collision_exception_with(player)
	head_phase = 0
	catch_punched = false
	forced_alert = false
	_set_burnt(false)
	if audio: audio.stop()
	_enter(State.GUARD,"head2")

func on_blast(_origin: Vector3) -> void:
	# Dynamite sends MSG_KILL/KILL_GENERIC (0): Sam is blackened, not KO.
	# KnockOut/DEATHDURATIONMS belongs to KILL_CRUSH, e.g. a falling rock.
	_set_burnt(true)

func on_rock_crush(_rock: CollisionObject3D) -> bool:
	# Sam::HandleMessage(KILL_CRUSH) -> KnockOut. DEATHDURATIONMS only
	# counts while SQUASH1 is lying, after SQUASH and before SQUASH2.
	if state==State.CATCH and not catch_punched:
		player.cinematic_controls_locked = false
		remove_collision_exception_with(player)
		player.set_state(player.WolfState.FALL)
	_enter(State.STUNNED,"squash")
	initialized = true
	knockout_phase = KnockoutPhase.FALL
	knockout_remaining = float(rules.knockout_seconds)
	velocity = Vector3.ZERO
	var ground = _ground(global_position)
	if ground!=null: global_position.y = ground.y+.001
	visual.sample_animation(clip,0)
	return true

func step_knockout(delta: float):
	match knockout_phase:
		KnockoutPhase.FALL:
			if clip_time>=float(visual.rig.animations.squash.duration):
				knockout_phase = KnockoutPhase.LYING; clip = "squash1"; clip_time = -.001
		KnockoutPhase.LYING:
			knockout_remaining -= delta
			if knockout_remaining<0:
				knockout_phase = KnockoutPhase.GET_UP; clip = "squash2"; clip_time = -.001
		KnockoutPhase.GET_UP:
			if clip_time>=float(visual.rig.animations.squash2.duration):
				# Native SetGoalWolf/SAMU_START_SEARCH: after fully getting up,
				# re-evaluate Ralph through the shared pursuit/zone logic.
				_enter(State.CHASE,"start")

func _set_burnt(value: bool) -> void:
	burnt = value
	for material in visual.legacy_skin.materials+indicator.portrait.legacy_skin.materials:
		material.set_shader_parameter("original_tint_amount",1.0 if value else 0.0)

func on_loud_noise(origin: Vector3, radius: float, source_class: int = -1) -> void:
	var difference = global_position-origin
	if Vector2(difference.x,difference.z).length() > radius or absf(difference.y) > radius or state in [State.CATCH,State.STUNNED]: return
	if source_class == 2:
		if contains(origin,rules["authorized"],false): forced_alert = true
		return
	if state != State.GUARD: return
	investigate_point = origin
	_enter(State.INVESTIGATE,"walk2")

func on_flute(origin: Vector3,zones: Array,configuration: Dictionary = {}) -> void:
	if not visual.rig.animations.has("hypnos1"): return
	# MSG_SAM_INVESTIGATE stores its sender and refreshes1000ms. The
	# native LOOKAFTER state consumes it; a chase/catch is never interrupted.
	flute_rules = configuration
	flute_timer = float(flute_rules.get("refresh_seconds",1.0)); investigate_point = origin; flute_zones = zones
	if state==State.GUARD and initialized:
		flute_stop_delay = 0
		_enter(State.HYPNOTIZED,"hypnos1")

func step_hypnosis(delta: float):
	if clip=="hypnos1":
		if clip_time>=float(visual.rig.animations.hypnos1.duration):
			clip = "hypnos2"; clip_time = -.001
		return
	if flute_timer<0:
		_enter(State.RETURN_HOME,"run2"); return
	flute_timer -= delta
	var toward = investigate_point-global_position; toward.y = 0
	if toward.length_squared()>.0001: rotation.y = atan2(toward.x,toward.z)
	var motion = toward.normalized()*float(flute_rules.get("speed",2.0))
	var stop = toward.length()<float(flute_rules.get("stop_distance",2.0)) or (not flute_zones.is_empty() and not contains(global_position+motion*delta,flute_zones,false))
	if stop:
		flute_stop_delay -= delta
		if flute_stop_delay<=0 and clip!="hypnos2": clip = "hypnos2"; clip_time = -.001
	else:
		flute_stop_delay = float(flute_rules.get("stop_delay_seconds",.2))
		if clip!="walk2": clip = "walk2"; clip_time = -.001
		velocity.x = motion.x; velocity.z = motion.z

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): return
	if player.cinematic_controls_locked and state != State.CATCH:
		# CIN00 locks Ralph before Sam's .44s START completes. Finish the
		# body pose and keep HEAD2 alive, without detection or navigation.
		if not initialized:
			state_elapsed += delta
			if state_elapsed >= float(visual.rig.animations.start.duration):
				initialized = true
				_enter(State.GUARD,"head2")
		if state == State.GUARD: advance_watch_head(delta)
		return
	state_elapsed += delta
	repath -= delta
	for index in blocked_nodes.keys():
		blocked_nodes[index] -= delta
		if blocked_nodes[index] <= 0: blocked_nodes.erase(index)
	var diff = player.global_position-global_position
	if state == State.GUARD:
		advance_watch_head(delta)
	else: head_yaw = 0
	# Sam::relAngleToWolf is in native coordinates; the reflected world
	# reverses the relative angle. Use the current sweep, not last frame's.
	relative_angle = wrapf(rotation.y-atan2(diff.x,diff.z)-head_yaw,-PI,PI)
	update_alert()
	velocity.x = 0
	velocity.z = 0
	if not initialized:
		if state_elapsed >= float(visual.rig["animations"]["start"]["duration"]):
			initialized = true
			_enter(State.GUARD,"head2")
	elif state == State.GUARD:
		if flute_timer>=0: _enter(State.HYPNOTIZED,"hypnos1")
		elif can_detect_player(): _enter(State.CHASE,"start")
	elif state == State.HYPNOTIZED:
		step_hypnosis(delta)
	elif state in [State.CHASE,State.RETURN_HOME,State.INVESTIGATE]:
		var target = player.global_position if state == State.CHASE else (home if state == State.RETURN_HOME else investigate_point)
		var boundary_stop = false
		if state == State.CHASE and (_player_unavailable() or outside_chase_leash(player.global_position) or outside_chase_leash(global_position) or (state_elapsed >= .2 and not inside_hit_zone(player.global_position))):
			_enter(State.RETURN_HOME,"run2")
			target = home
		if state == State.CHASE and not contains(target,rules["authorized"],false) and (int(rules["mode"]) & 0x1000) == 0:
			var direct = target-global_position
			direct.y = 0
			if not contains(global_position+direct.normalized()*movement_speed()*delta,rules["authorized"],false):
				_enter(State.RETURN_HOME,"run2")
				target = home
				boundary_stop = true
		var distance = Vector2(target.x-global_position.x,target.z-global_position.z).length()
		if state == State.CHASE and distance < 1.0 and absf(diff.y) < 1.0:
			_catch_player()
		elif state != State.CHASE and distance < .5:
			if state == State.RETURN_HOME:
				forced_alert = false
				rotation.y = home_yaw
				_enter(State.GUARD,"head2")
			elif state_elapsed > 5: _enter(State.RETURN_HOME,"run2")
		elif boundary_stop: pass
		else:
			if force_nodes or (repath <= 0 and (path.is_empty() or route_target.distance_to(target) > 1.0)): _route(target)
			while path.size() > 1 and Vector2(path[0].x-global_position.x,path[0].z-global_position.z).length() < .4: path.remove_at(0)
			if state == State.CHASE and path.size() == 1 and global_position.distance_to(path[0]) < .6 and not contains(target,rules["authorized"],false) and (int(rules["mode"]) & 0x1000) == 0:
				_enter(State.RETURN_HOME,"run2")
			if not path.is_empty():
				var direction = path[0]-global_position
				direction.y = 0
				direction = direction.normalized()
				rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.z),minf(1,8*delta))
				var speed = minf(movement_speed(),Vector2(path[0].x-global_position.x,path[0].z-global_position.z).length()/delta)
				if state == State.RETURN_HOME:
					var return_clip = "run2" if movement_speed() > 2.0 else "walk1"
					if clip != return_clip:
						clip = return_clip
						clip_time = -.001
				velocity.x = direction.x*speed
				velocity.z = direction.z*speed
				# Sam::UpdateState checks directEnd against its XZ authorized boxes.
				if state == State.CHASE and not contains(global_position+velocity*delta,rules["authorized"],false):
					velocity.x = 0
					velocity.z = 0
					if not contains(player.global_position,rules["authorized"],false) and (int(rules["mode"]) & 0x1000) == 0:
						_enter(State.RETURN_HOME,"run2")
					else: repath = 0
				if state == State.CHASE and state_elapsed >= float(visual.rig["animations"]["start"]["duration"]) and clip != "run1":
					clip = "run1"
					clip_time = -0.001
		if state == State.INVESTIGATE and can_detect_player(): _enter(State.CHASE,"start")
	elif state == State.STUNNED:
		step_knockout(delta)
	elif state == State.CATCH:
		if not catch_punched and state_elapsed >= float(visual.rig["animations"][clip]["duration"]):
			catch_punched = true
			# SAM_STT_CATCHDONE -> SAM_ANIM_CATCHDONE / WIN, cue77 at .94s.
			clip = "win"
			clip_time = -.001
			player.cinematic_controls_locked = false
			player.set_state(player.WolfState.SAM_DEATH)
	velocity.y = 0 if is_on_floor() else maxf(-20,velocity.y-29*delta)
	var requested_motion = Vector2(velocity.x,velocity.z).length_squared() > .01
	move_and_slide()
	if state in [State.CHASE,State.RETURN_HOME,State.INVESTIGATE] and requested_motion:
		stall_time += delta
		if Vector2(global_position.x-stall_anchor.x,global_position.z-stall_anchor.z).length() >= .1:
			stall_anchor = global_position
			stall_time = 0
		elif stall_time >= .25:
			# UpdateStallTracker -> SEARCHNEARESTNODE, retain collision and avoid
			# immediately choosing the same obstructed approach again.
			if not path.is_empty(): blocked_nodes[graph.get_closest_point(path[0])] = 2.0
			force_nodes = true

func _catch_player() -> void:
	player.interrupt_actions()
	if is_instance_valid(player.carried_sheep): player.carried_sheep.reset_to_home()
	player.cinematic_controls_locked = true
	player.velocity = Vector3.ZERO
	# MSG_WOLF_CAUGHT puts both actors at Sam's origin; opposite headings
	# line up the two authored grab/punch animation meshes.
	var difference = global_position-player.global_position
	player.skeleton.rotation.y = atan2(difference.x,difference.z)
	rotation.y = wrapf(player.skeleton.rotation.y+PI,-PI,PI)
	player.global_position = global_position
	add_collision_exception_with(player)
	player.play_anim("sam_caught")
	_enter(State.CATCH,"punch7")
	catch_punched = false

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if player.cinematic_controls_locked and initialized and state not in [State.GUARD,State.CATCH]: return
	var previous = clip_time
	clip_time += delta
	var duration = float(visual.rig["animations"][clip]["duration"])
	var looping = state!=State.CATCH and clip!="hypnos1" and initialized and (state!=State.STUNNED or knockout_phase==KnockoutPhase.LYING)
	visual.sample_animation(clip,clip_time,looping)
	if state == State.GUARD and visual.skeleton.get_bone_count() > 9:
		visual.skeleton.set_bone_pose_rotation(9,Quaternion(Vector3.UP,head_yaw))
		visual.legacy_skin.update_pose()
	for cue in visual.rig["animations"][clip]["sound_cues"]:
		if not looping and previous >= duration: continue
		var time = float(cue["time"])
		if looping:
			time += floor(maxf(0,previous)/duration)*duration
			if time <= previous: time += duration
		if time <= clip_time and sounds.has(str(int(cue["sound_id"]))):
			audio.stream = load(sounds[str(int(cue["sound_id"]))])
			audio.play()
	if state == State.CATCH and not catch_punched:
		for cue in player.run_data["animations"]["sam_caught"]["sound_cues"]:
			if float(cue["time"]) > previous and float(cue["time"]) <= clip_time:
				var sound = player.run_data["sounds"].get(str(int(cue["sound_id"])))
				if sound: player.play_animation_sfx(sound["path"])

func outside_chase_leash(point: Vector3) -> bool:
	return chase_leash_distance > 0 and Vector2(point.x-home.x,point.z-home.z).length() > chase_leash_distance

func advance_watch_head(delta: float):
	head_phase = fmod(head_phase+float(rules.head_speed)*floor(delta*1000/2)*TAU/4096,TAU)
	head_yaw = sin(head_phase)*deg_to_rad(float(rules.max_angle))
