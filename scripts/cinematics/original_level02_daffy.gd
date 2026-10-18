extends OriginalNpcConversation

# Adapter of DaffyLevel02::Update/DetectWolf. Native CIN01/02 and MLT48
# supply the presentation; only input bindings and engine coordinates differ.
var movies: Dictionary = {}
var introduction_seen = false
var challenge_won = false
var game_armed = false
var game_running = false
var asking_to_practice = false
var pending_phase = -1
var current_phase = -1
var head_phase = 0.0
var head_yaw = 0.0
var home_yaw = 0.0
var start_timer = 0.0
var start_timeout = 7.0
var start_nag_given = false
var warmup = 0.0
@export_range(0.0,5.0,.1) var intro_clearance = 2.0
var indicator: CanvasLayer
var portrait: OriginalCinematicActor
var portrait_frame: TextureRect
@export var start_preview_distance = 1.5
@export_dir var level_directory = "res://assets/levels/lvl_02"
var source_level = "lvl_02"

func _ready():
	data_path = level_directory+"/data/daffy.json"
	source_level = level_directory.get_file()
	actor_prefix = "DaffyLevel02"
	intro_finished = false
	super._ready()
	if source_level=="lvl_02": data.burnt = GameLocalization.load_data("res://assets/levels/lvl_01/data/daffy.json").burnt
	daffy.idle("stand1a")
	home_yaw = daffy.rotation.y
	for identity in data.cine_ids:
		var movie = OriginalLevelSequence.new()
		movie.sequence_path = level_directory+"/cinematics/sequence_%d.json"%int(identity)
		movie.allow_skip = true
		movie.apply_empty_visibility_defaults = true
		add_child(movie)
		movie.bind_player(player)
		movie.finished.connect(_movie_finished.bind(int(identity)))
		movies[int(identity)] = movie
	_build_indicator()
	player.respawned.connect(_reset_challenge)
	daffy.hide()
	_apply_tutorial_props()

func contains(point: Vector3, boxes: Array, xz_only: bool = true) -> bool:
	for box in boxes:
		var a = box.min; var b = box.max
		var lo = GameSpace.original_point(Vector3(a[0],b[1],b[2]))
		var hi = GameSpace.original_point(Vector3(b[0],a[1],a[2]))
		if point.x >= lo.x and point.x <= hi.x and point.z >= lo.z and point.z <= hi.z and (xz_only or (point.y >= lo.y and point.y <= hi.y)): return true
	return false

func near_start(point: Vector3) -> bool:
	# Manual-camera adaptation: show the guard sweep before entering the line.
	# This preview never arms detection or changes the native start/goal boxes.
	for box in data.start:
		var x = clampf(point.x,float(box.min[0])*.01,float(box.max[0])*.01)
		var z = clampf(point.z,-float(box.max[2])*.01,-float(box.min[2])*.01)
		if Vector2(point.x-x,point.z-z).length() <= start_preview_distance: return true
	return false

func start_movie(identity: int) -> bool:
	if active_movie or player.cinematic_controls_locked: return false
	var movie: OriginalLevelSequence = movies[identity]
	if not movie.start_sequence(): return false
	active_movie = movie
	return true

func _movie_finished(_skipped: bool, identity: int):
	active_movie = null
	global_position = daffy.global_position
	daffy.idle("stand1a")
	daffy.show()
	_apply_tutorial_props()
	if identity == int(data.cine_ids[0]):
		introduction_seen = true
		call_deferred("_ask_to_practice")
	else:
		intro_finished = true
		game_armed = true
		head_phase = 0
		current_phase = -1
		_apply_tutorial_props()
		if data.get("post_rules_reminder",false): call_deferred("_say_phase",8,21)

func _apply_tutorial_props():
	# Resource 90 is Lucas's demonstration bush puppet, not a usable bush.
	# It exists only in the CIN. 86/87 are the animated white start/goal lines.
	var puppet = get_parent().get_node_or_null("MiscStatic_90") if source_level=="lvl_02" else null
	if puppet: puppet.hide()
	for resource in data.get("line_resources",[86,87]):
		var line = get_parent().get_node_or_null("MiscStatic_%d"%resource)
		if line:
			line.idle_clip = ""
			line.sample_animation("action03" if intro_finished else "action00",999)
			if intro_finished: _restore_cine_pose(line,resource,int(data.cine_ids[1]))

func _restore_cine_pose(actor: Node3D, resource: int, identity: int):
	for track in movies[identity].data.tracks:
		if int(track.selector) != 2 or int(track.index) != resource: continue
		for record in track.records:
			if record.keys.is_empty(): continue
			var values = record.keys[-1].value
			if int(record.opcode) == 1: actor.global_position = GameSpace.original_point(Vector3(values[0],values[1],values[2]))
			elif int(record.opcode) == 2: actor.rotation = Vector3(values[0],-values[1],-values[2])*TAU/4096

func can_interact(actor: RalphController) -> bool:
	return actor == player and introduction_seen and not game_running and not active_movie and not speaking and not menu.visible and actor.can_use_item() and actor.global_position.distance_to(daffy.global_position) < 2.0

func interact(actor: RalphController) -> bool:
	if not can_interact(actor): return false
	_freeze_player()
	if burnt and not burnt_line_said:
		burnt_line_said = true
		current_phase = -1
		say(data.burnt)
	elif challenge_won:
		asking_to_practice = false
		selected = 0
		_show_menu()
	else: _ask_to_practice()
	return true

func _freeze_player():
	# MSG_FREEZE preserves the disguise during feedback. interrupt_actions()
	# normally removes a bush, which would make retrying this lesson impossible.
	var bush = player.active_bush
	player.active_bush = null
	player.interrupt_actions()
	player.active_bush = bush
	player.cinematic_controls_locked = true

func _ask_to_practice():
	if not is_inside_tree(): return
	_freeze_player()
	asking_to_practice = true
	selected = 0
	_show_menu()

func _show_menu():
	if not asking_to_practice:
		super._show_menu()
		return
	menu_frame.set_choices(GameLocalization.text(source_level,48,int(data.text_base)+2),[GameLocalization.ui("Sí"),GameLocalization.ui("No")],selected,GameLocalization.ui("E: elegir · Escape: volver"))
	menu.show()

func _input(event: InputEvent):
	if not menu.visible or not asking_to_practice:
		super._input(event)
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode in [KEY_UP,KEY_W,KEY_DOWN,KEY_S]:
		selected = 1-selected
		_show_menu()
	elif event.physical_keycode in [KEY_ENTER,KEY_E,KEY_ESCAPE]:
		var accepted = selected == 0 and event.physical_keycode != KEY_ESCAPE
		menu.hide()
		asking_to_practice = false
		player.cinematic_controls_locked = false
		if accepted:
			if not intro_finished: call_deferred("start_movie",int(data.cine_ids[1]))
			else:
				game_armed = true
				_say_phase(8,21)
	get_viewport().set_input_as_handled()

func _say_phase(phase: int, voice_id: int):
	voice_id = int(data.get("phase_voices",{}).get(str(phase),voice_id))
	current_phase = phase
	_freeze_player()
	if phase == 7:
		daffy.idle("ok1")
		pending_phase = 7
	else: pending_phase = -1
	say({"text":GameLocalization.text(source_level,48,int(data.text_base)+phase),"voice_path":GameLocalization.voice_path(voice_id)})
	if phase == 7: daffy.idle("ok1")

func _voice_finished():
	super._voice_finished()
	daffy.idle("stand1a")
	if current_phase == 7:
		challenge_won = true
		game_armed = false
		game_running = false
		daffy.rotation.y = home_yaw
	elif current_phase in [3,4,5,6]:
		game_running = false
		game_armed = true
		start_timer = 0
		head_phase = 0
	current_phase = -1
	pending_phase = -1

func _process(delta: float):
	warmup += delta
	if not is_instance_valid(player): return
	var past_clearance = player.global_position.x > 6.5+intro_clearance if source_level=="lvl_02" else true
	var after_rock = source_level=="lvl_02" and past_clearance and player.global_position.x < 20 and player.global_position.z < -40 and player.global_position.z > -54.3 and absf(player.global_position.y) < 2
	var finishing_push = is_instance_valid(player.push_target) or player.tutorial_movement_locked
	if warmup > .25 and not introduction_seen and not active_movie and not player.cinematic_controls_locked and not finishing_push and past_clearance and (contains(player.global_position,data.trigger) or after_rock):
		start_movie(int(data.cine_ids[0]))
	var preview = intro_finished and not challenge_won and game_armed and near_start(player.global_position)
	indicator.visible = (game_running or preview) and not speaking and not menu.visible and not player.cinematic_controls_locked
	if active_movie: return
	global_position = daffy.global_position
	if speaking:
		if pending_phase != 7: daffy.idle_clip = "talk1" if voice.playing else "stand1a"
		return
	if menu.visible: return
	if player.cinematic_controls_locked or player.current_state in [player.WolfState.PIT_FALL,player.WolfState.BLAST_DEATH,player.WolfState.SAM_DEATH]: return
	if not game_running and not preview:
		var diff = player.global_position-daffy.global_position
		daffy.rotation.y = atan2(diff.x,diff.z)
	if not intro_finished or challenge_won: return
	var point = player.global_position
	if game_armed and contains(point,data.start):
		game_running = true
		game_armed = false
		start_timer = 0
		daffy.rotation.y = home_yaw
	if not game_running:
		if preview:
			daffy.rotation.y = home_yaw
			_watch_head(delta)
		return
	if contains(point,data.goal):
		game_running = false
		_say_phase(7,20)
		return
	if not contains(point,data.activation):
		game_running = false
		game_armed = false
		head_phase = 0
		return
	# Advance even while waiting on the start line; keep the same phase on exit.
	_watch_head(delta)
	if contains(point,data.start):
		start_timer += delta
		if not start_nag_given and start_timer > start_timeout:
			start_nag_given = true
			_say_phase(9,22)
		return
	start_nag_given = false
	start_timer = 0
	var detected = detect_player()
	if detected > 0:
		game_running = false
		start_timeout = 3.0 if detected in [4,5] else 7.0
		_say_phase(detected,13+detected)

func _watch_head(delta: float):
	# UpdateHeadSweep: +dtMs/2 native angle units, +/-70 degrees.
	head_phase = fmod(head_phase+delta*.5*1000*TAU/4096,TAU)
	head_yaw = sin(head_phase)*deg_to_rad(70)
	daffy.idle_clip = "" # Native guard freezes the idle body during the exercise.
	daffy.sample_animation("stand1a",0)
	if daffy.skeleton.get_bone_count() > 4:
		daffy.skeleton.set_bone_pose_rotation(4,Quaternion(Vector3.UP,head_yaw))
		daffy.legacy_skin.update_pose()
	# DrawAlertIcon rotates the head relative to Ralph, not to world north.
	# Showing only head_yaw made a side-on wolf see a misleading frontal HUD.
	portrait.rotation.y = relative_view_angle()
	var size = get_viewport().get_visible_rect().size
	var scale = size.y/240.0
	portrait_frame.position = Vector2(size.x-size.x/8,55*scale)-portrait_frame.size/2

func head_forward() -> Vector3:
	# The native head override is local to joint4. Parent pose rotations and
	# export reflections also turn the visible head; home_yaw-head_yaw alone
	# can disagree with its actual beak direction in the rendered pose.
	var direction = Vector3(0,0,1)
	if daffy.legacy_skin.last_matrices.size()>4:
		direction = daffy.global_basis*daffy.legacy_skin.last_matrices[4].basis*Vector3.FORWARD
	direction.y = 0
	return direction.normalized()

func relative_view_angle() -> float:
	var direction = head_forward()
	var diff = player.global_position-daffy.global_position
	return wrapf(atan2(direction.x,direction.z)-atan2(diff.x,diff.z),-PI,PI)

func detect_player() -> int:
	# Native noise test precedes the very narrow 56/4096 head beam.
	if not contains(player.global_position,data.activation,false): return 0
	if player.hidden_from_observer(daffy.global_position): return 0
	var moving = Vector2(player.velocity.x,player.velocity.z).length() > .05
	var noisy = moving and player.current_state in [player.WolfState.WALK,player.WolfState.RUN_START,player.WolfState.RUN,player.WolfState.RUN_AIR,player.WolfState.JUMP,player.WolfState.LAND]
	if noisy: return 3
	var angle = relative_view_angle()
	if absf(angle) >= 56*TAU/4096: return 0
	if data.get("variant","")=="hidden_rocks":
		# The original asks Wolf::IS_VISIBLE against rock cover; use the
		# observer's line to Ralph with the imported solid rock geometry.
		if player.current_state==player.WolfState.SNEAK:
			var ray = PhysicsRayQueryParameters3D.create(daffy.global_position+Vector3.UP*.7,player.global_position+Vector3.UP*.7,1)
			ray.exclude = [player.get_rid()]
			if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return 0
		return 6
	if not is_instance_valid(player.active_bush): return 6
	# Native visible = not sneaking; moving disguised and sneaking has its own line.
	if player.current_state != player.WolfState.SNEAK and moving: return 5
	if moving: return 4
	return 0

func _build_indicator():
	indicator = CanvasLayer.new(); indicator.layer = 20; add_child(indicator); indicator.hide()
	var viewport = SubViewport.new(); viewport.size = Vector2i(140,120); viewport.transparent_bg = true; viewport.own_world_3d = true
	indicator.add_child(viewport)
	portrait = load(data.head_directory+"/worn.tscn").instantiate(); viewport.add_child(portrait)
	portrait.sample_animation("default",0)
	var camera = Camera3D.new(); viewport.add_child(camera)
	camera.position = Vector3(0,.245,1.4); camera.look_at(Vector3(0,.245,0)); camera.fov = 25; camera.current = true
	portrait_frame = TextureRect.new(); indicator.add_child(portrait_frame)
	portrait_frame.texture = load("res://assets/levels/lvl_01/sam_head/border.png")
	portrait_frame.self_modulate = OriginalSamIndicator.source_color(1)
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.size = Vector2(70,40)*get_viewport().get_visible_rect().size.y/240.0
	var image = TextureRect.new(); portrait_frame.add_child(image); image.texture = viewport.get_texture()
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE; image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _reset_challenge():
	voice.stop(); speaking = false; dialogue.close(); menu.hide(); asking_to_practice = false
	game_running = false; game_armed = intro_finished and not challenge_won
	start_timer = 0; head_phase = 0; current_phase = -1
	daffy.rotation.y = home_yaw; daffy.idle("stand1a")

func capture_progress() -> Dictionary:
	return {"introduction_seen":introduction_seen,"intro_finished":intro_finished,"challenge_won":challenge_won}

func restore_progress(saved: Dictionary):
	introduction_seen = saved.get("introduction_seen",false)
	intro_finished = saved.get("intro_finished",false)
	challenge_won = saved.get("challenge_won",false)
	for identity in movies: movies[identity].played = introduction_seen if identity == int(data.cine_ids[0]) else intro_finished
	_reset_challenge()
	daffy.visible = introduction_seen
	if introduction_seen: _restore_cine_pose(daffy,int(data.resource),int(data.cine_ids[1] if intro_finished else data.cine_ids[0]))
	_apply_tutorial_props()

func reload_localization():
	var phase = current_phase
	if phase < 0:
		var burnt_speech = speaking and voice.stream and voice.stream.resource_path == data.burnt.voice_path
		super.reload_localization()
		if source_level=="lvl_02": data.burnt = GameLocalization.load_data("res://assets/levels/lvl_01/data/daffy.json").burnt
		if burnt_speech:
			voice.stream = load(data.burnt.voice_path)
			voice.play()
			dialogue.show_line(data.burnt.text,voice)
		return
	data = GameLocalization.load_data(data_path)
	var time = voice.get_playback_position()
	var identity = int(data.get("phase_voices",{}).get(str(phase),13+phase if phase in [3,4,5,6] else {7:20,8:21,9:22}[phase]))
	voice.stream = load(GameLocalization.voice_path(identity))
	voice.play(minf(time,maxf(0,voice.stream.get_length()-.01)))
	dialogue.show_line(GameLocalization.text(source_level,48,int(data.text_base)+phase),voice)
