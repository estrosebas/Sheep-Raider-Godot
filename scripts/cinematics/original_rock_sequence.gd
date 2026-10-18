extends OriginalLevelSequence
# Rock::StartLvl03Cinematic uses CINE_NO_WOLF_FREEZE and the two native CINs.
var rock: Node3D
var rolling_basis = Basis.IDENTITY
var last_rock_position: Vector3
var released_camera = false
var roll_sound: AudioStreamPlayer3D

func _ready():
	allow_skip = false # CINE_NO_WOLF_FREEZE also bypasses native movie skip input.
	preserve_player_state = true # Ending this gameplay shot cannot reset a crush death.
	super._ready()

func start_sequence(replay: bool = false) -> bool:
	# Mailbox containers are created after the cinematic manager's _ready.
	world_actors.clear()
	for child in get_parent().get_parent().get_children():
		if not child is Node3D or not child.has_meta("original_resource"): continue
		for key in data.actors:
			if int(data.actors[key].resource)==int(child.get_meta("original_resource")): world_actors[key] = child
	if not super.start_sequence(replay): return false
	player.cinematic_controls_locked = false
	player.set_physics_process(saved_physics)
	player.visible = was_player_visible
	player.inventory.wheel.visible = was_wheel_visible
	framing.hide() # Gameplay camera shot, not a dialogue cutscene.
	for actor in world_actors.values():
		actor.movie_active = true
	rolling_basis = rock.roll
	last_rock_position = actors["1:55"].global_position
	if not rock.sound_path.is_empty():
		roll_sound = AudioStreamPlayer3D.new(); add_child(roll_sound)
		var stream: AudioStreamWAV = load(rock.sound_path).duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD; stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
		roll_sound.stream = stream; roll_sound.max_distance = 50; roll_sound.global_position = rock.global_position; roll_sound.play()
	released_camera = false
	return true

func _process(delta: float):
	if not playing: return
	if not released_camera and not rock.definition.get("cine_camera_box",[]).is_empty() and not TutorialProgress.contains_xz(rock.definition.cine_camera_box[0],player.global_position):
		player.camera.current = true; released_camera = true
	super._process(delta)
	if not playing: return
	if is_instance_valid(roll_sound):
		roll_sound.global_position = actors["1:55"].global_position
		if elapsed>3: roll_sound.stop()
	var visual = actors["1:55"]
	var displacement = visual.global_position-last_rock_position
	if displacement.length()>.00001:
		var axis = displacement.cross(Vector3.UP)
		if axis.length()>.00001: rolling_basis = Basis(axis.normalized(),-displacement.length()/rock.radius)*rolling_basis
	last_rock_position = visual.global_position
	visual.get_child(0).basis = rolling_basis
	# Keep real solids at CIN positions while their duplicate art is shown.
	for key in world_actors:
		world_actors[key].global_transform = actors[key].global_transform
	rock.crush_objects_below(rock.global_position,rock.global_position) # Native LVL03_CINE also checks beneath the rock.

func finish_sequence(skipped: bool):
	if not playing: return
	if is_instance_valid(roll_sound): roll_sound.stop(); roll_sound.queue_free()
	var position_before = player.global_position
	var state_before = player.current_state
	super.finish_sequence(skipped)
	player.global_position = position_before
	player.set_state(state_before)
	for actor in world_actors.values():
		actor.movie_active = false
		if actor is OriginalDeliveryBox: actor.begin_fall()
	rock.roll = rolling_basis; rock.visual.basis = rolling_basis
	rock.stop_push(false); rock.seesaw_support = null; rock.fall_time = 0; rock.velocity = Vector3.ZERO
