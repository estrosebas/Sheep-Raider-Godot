extends RefCounted
# Shared native cover adapter: locomotion never becomes WALK on a Ctrl exit.
var rock: OriginalHiddenRock
var elapsed = 0.0
var reentry_delay = 0.0
var face_normal = Vector3.ZERO
var entry_position = Vector3.ZERO
var anchor = Vector3.ZERO
var skeleton_home = Vector3.ZERO
var offset_active = false
var torso_vertices: Array = []
var contact_gap = .015
var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_cover_rules.json"))
func active() -> bool: return is_instance_valid(rock)
func hidden_from(actor,observer: Vector3) -> bool:
	return active() and actor.current_state in [actor.WolfState.COVER_ENTER,actor.WolfState.COVER_HIDDEN] and rock.accepts(actor,float(rules.gap_units)*float(rules.scale)) and rock.hides_from(actor,observer,face_normal)

func clear(actor):
	if offset_active and is_instance_valid(actor.skeleton): actor.skeleton.position = skeleton_home
	rock = null; elapsed = 0; face_normal = Vector3.ZERO; offset_active = false

func leave(actor):
	clear(actor); reentry_delay = .15
	actor.velocity.x = 0; actor.velocity.z = 0
	if actor.current_state in [actor.WolfState.COVER_ENTER,actor.WolfState.COVER_HIDDEN]: actor.set_state(actor.WolfState.SNEAK if Input.is_action_pressed("sneak") else actor.WolfState.IDLE)
func step(actor,delta: float) -> bool:
	if actor.launch_controls_locked: return false
	reentry_delay = maxf(0,reentry_delay-delta)
	var input = Input.get_vector("move_left","move_right","move_forward","move_backward")
	var forward = -actor.camera_pivot.global_basis.z; forward.y = 0; forward = forward.normalized()
	var right = actor.camera_pivot.global_basis.x; right.y = 0; right = right.normalized()
	var direction = (right*input.x-forward*input.y).normalized()
	var moving = input.length_squared()>.01
	var eligible = Input.is_action_pressed("sneak") and actor.is_on_floor() and not actor.inventory_controls_locked and not actor.cinematic_controls_locked and not actor.tutorial_movement_locked and actor.restart_fade_remaining<=0 and not actor.item_actions.busy and not is_instance_valid(actor.carried_sheep) and not is_instance_valid(actor.active_rocket) and not is_instance_valid(actor.active_bush) and actor.item_costume.is_empty()
	var gap = float(rules.gap_units)*float(rules.scale)
	var cosine = cos(float(rules.toward_side_angle_units)*TAU/4096)
	if active():
		if not eligible or not rock.accepts(actor,gap) or (moving and direction.dot(-face_normal)<cosine) or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("run"):
			leave(actor); return false
	else:
		if not eligible or reentry_delay>0 or actor.current_state not in [actor.WolfState.IDLE,actor.WolfState.WALK,actor.WolfState.SNEAK]: return false
		var closest = INF
		for candidate in actor.get_tree().get_nodes_in_group("rock_cover"):
			if candidate.get_world_3d()!=actor.get_world_3d() or not candidate.accepts(actor,gap): continue
			if moving and direction.dot(-candidate.side_normal(actor.global_position))<cosine: continue
			var distance = actor.global_position.distance_squared_to(candidate.global_position)
			if distance<closest: closest = distance; rock = candidate
		if not active(): return false
		face_normal = rock.side_normal(actor.global_position)
		entry_position = actor.global_position
		anchor = rock.cover_anchor(actor,face_normal)
		skeleton_home = actor.skeleton.position; offset_active = true
		elapsed = 0; actor.set_state(actor.WolfState.COVER_ENTER)
		actor.animation_player.advance(0); actor.apply_legacy_reaction_pose()
		actor.sneak_audio_player.stop()
		actor.velocity.x = 0; actor.velocity.z = 0
	var previous = elapsed; elapsed += delta
	if actor.current_state==actor.WolfState.COVER_ENTER:
		for cue in actor.run_data.animations.cover_enter.sound_cues:
			if float(cue.time)>previous and float(cue.time)<=elapsed:
				var sound = actor.run_data.sounds.get(str(int(cue.sound_id)),{})
				if sound.has("path"): actor.play_animation_sfx(sound.path)
	actor.skeleton.rotation.y = atan2(face_normal.x,face_normal.z)
	var duration = float(actor.run_data.animations.cover_enter.duration)
	var progress = clampf(elapsed/duration,0,1) if actor.current_state==actor.WolfState.COVER_ENTER else 1.0
	var wanted = entry_position.lerp(anchor,smoothstep(0,1,progress))
	actor.velocity = Vector3((wanted.x-actor.global_position.x)/delta,0 if actor.is_on_floor() else maxf(-20,actor.velocity.y-29*delta),(wanted.z-actor.global_position.z)/delta)
	actor.move_and_slide()
	if actor.current_state==actor.WolfState.COVER_ENTER and elapsed>=duration:
		if Vector2(anchor.x-actor.global_position.x,anchor.z-actor.global_position.z).length()>.03:
			leave(actor); return false # A real obstruction must not teleport Ralph.
		actor.set_state(actor.WolfState.COVER_HIDDEN); elapsed = 0
	update_pose_contact(actor,smoothstep(0,1,progress))
	return true

func update_pose_contact(actor,weight: float):
	if torso_vertices.is_empty():
		var model = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_data.json"))
		for surface in model.surfaces.values():
			for i in range(surface.verts.size()):
				var bone = int(surface.bones[i][0])
				if bone not in [2,3]: continue # Torso/back, not tail, ears or feet.
				var v = surface.verts[i]
				torso_vertices.append({"bone":bone,"point":Vector3(v[0],v[1],v[2])})
	var skin = actor.legacy_skin
	var back: Variant = null
	var minimum = INF
	for vertex in torso_vertices:
		var posed: Vector3 = skin.last_matrices[vertex.bone]*skin.inverse_rests[vertex.bone]*vertex.point
		var point: Vector3 = actor.global_position+actor.global_basis*skeleton_home+actor.skeleton.global_basis*posed
		var projection = point.dot(face_normal)
		if projection<minimum: minimum = projection; back = point
	if back==null: return
	var face = rock.visual_face_point(face_normal,back.y)
	if face==null: return
	var offset = clampf((face-back).dot(face_normal)+contact_gap,-.5,.5)*weight
	actor.skeleton.position = skeleton_home+actor.global_basis.inverse()*face_normal*offset
