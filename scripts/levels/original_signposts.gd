extends Node3D
class_name OriginalSignposts

const Space = preload("res://scripts/levels/game_space.gd")
@export_file("*.json") var definitions_path = "res://assets/levels/lvl_00/data/sky_signs.json"
@export var player_path: NodePath = NodePath("../Player")
var signs: Array = []
var read_count = 0
var player: RalphController
var active_sign: Dictionary = {}
var read_variants: Dictionary = {}
var ui: CanvasLayer
var panel: VBoxContainer
var body: Label
var hint: Label
var prompt: Label
var trap_time = -1.0
var trap_released = false
var wolf_restored = false
var trap_camera: Camera3D
var anvil: OriginalCinematicActor
var wolf: OriginalCinematicActor
var sound: AudioStreamPlayer3D
var cues: Array = []
var was_player_visible = true
var saved_camera: Camera3D
var sound_paths: Dictionary
var text_box: OriginalTextBox

func _ready() -> void:
	player = get_node(player_path)
	signs = GameLocalization.load_data(definitions_path)["signs"]
	add_to_group("world_interactables")
	ui = CanvasLayer.new()
	ui.layer = 41
	add_child(ui)
	panel = VBoxContainer.new()
	ui.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size",27)
	SubtitleStyle.apply(body)
	panel.add_child(body)
	hint = Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",22)
	SubtitleStyle.apply(hint)
	panel.add_child(hint)
	body.hide()
	hint.hide()
	text_box = OriginalTextBox.new()
	text_box.text_label = body
	# A separate full-screen canvas follows panel visibility; the VBox remains
	# the text/state holder so existing sign interactions keep their interface.
	ui.add_child(text_box)
	text_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_box.hide()
	panel.hide()
	prompt = Label.new()
	ui.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -180
	prompt.offset_right = 180
	prompt.offset_top = -70
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SubtitleStyle.apply(prompt)
	prompt.text = "E · Leer cartel"
	prompt.hide()
	trap_camera = Camera3D.new()
	add_child(trap_camera)
	for actor_name in ["anvil","ralph"]:
		var actor = load("res://assets/cinematics/tutorial_intro/"+actor_name+"/worn.tscn").instantiate()
		add_child(actor)
		actor.hide()
		if actor_name == "anvil": anvil = actor
		else: wolf = actor
	sound = AudioStreamPlayer3D.new()
	sound.max_distance = 50
	add_child(sound)
	sound_paths = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cinematics/tutorial_intro/sequence.json"))["sounds"]

func nearest_sign(actor: Node3D) -> Dictionary:
	if actor.get_world_3d() != get_world_3d(): return {}
	var best = INF
	var result: Dictionary = {}
	for sign in signs:
		var p = sign["position"]
		var offset = actor.global_position-Space.from_export(Vector3(p[0],p[1],p[2]))
		# SignPost::MSG_QUERY_ACTION uses Manhattan XZ, without facing/Y checks.
		var distance = absf(offset.x)+absf(offset.z)
		if distance < float(sign["distance"]) and distance < best:
			best = distance
			result = sign
	return result

func can_interact(actor: Node3D) -> bool:
	return active_sign.is_empty() and actor.can_use_item() and not actor.inventory_controls_locked and actor.active_rocket == null and not nearest_sign(actor).is_empty()

func interact(actor: Node3D) -> bool:
	if not can_interact(actor): return false
	active_sign = nearest_sign(actor)
	var identity = int(active_sign["res"])
	if not read_variants.has(identity):
		read_variants[identity] = read_count
		read_count += 1
	var index = int(active_sign["text_index"])+int(read_variants[identity])
	# The original question variant is deliberately adapted to a warning:
	# all signs are read-only and cannot launch a repeated anvil decision.
	if int(read_variants[identity]) == 1: index = int(active_sign["text_index"])
	index = clampi(index,0,active_sign["texts"].size()-1)
	body.text = str(active_sign["texts"][index]).strip_edges()
	_update_hint()
	player.interrupt_actions()
	player.tutorial_movement_locked = true
	panel.show()
	text_box.show()
	prompt.hide()
	return true

func _update_hint() -> void:
	hint.text = "E · Cerrar"

func _input(event: InputEvent) -> void:
	if active_sign.is_empty(): return
	if trap_time >= 0 and not trap_released:
		if event is InputEventKey: get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("cancel"):
		close_sign()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("action") and not event.is_echo():
		close_sign()
		get_viewport().set_input_as_handled()

func close_sign() -> void:
	active_sign = {}
	panel.hide()
	text_box.hide()
	player.tutorial_movement_locked = false

func start_anvil() -> void:
	if trap_time >= 0 or active_sign.is_empty(): return
	player.interrupt_actions()
	panel.hide()
	text_box.hide()
	trap_time = 0
	trap_released = false
	wolf_restored = false
	was_player_visible = player.visible
	player.hide()
	saved_camera = get_viewport().get_camera_3d()
	var camera_data = active_sign["camera"]
	var eye = camera_data["eye"]
	var rot = camera_data["rotation"]
	trap_camera.global_position = Space.original_point(Vector3(eye[0],eye[1],eye[2]))
	trap_camera.rotation = Vector3(-float(rot[0]),float(rot[1]),-float(rot[2]))*TAU/4096.0
	trap_camera.fov = rad_to_deg(2*atan(384.0/(2*float(camera_data["focal"])*0.5)))
	trap_camera.current = true
	for actor in [anvil,wolf]:
		actor.global_position = player.global_position
		actor.rotation.y = player.skeleton.global_rotation.y
		actor.show()
	cues.clear()
	for actor in [anvil,wolf]:
		for cue in actor.rig["animations"]["anvil1"]["sound_cues"]:
			cues.append(cue)
	_step_trap(-0.001,0)

func _process(delta: float) -> void:
	if trap_time >= 0:
		var previous = trap_time
		trap_time += delta
		_step_trap(previous,trap_time)
	else:
		prompt.visible = false

func _step_trap(previous: float, time: float) -> void:
	var drop = float(anvil.rig["animations"]["anvil1"]["duration"])
	var hold = float(anvil.rig["animations"]["anvil2"]["duration"])
	anvil.sample_animation("anvil1" if time < drop else "anvil2",time if time < drop else time-drop)
	wolf.sample_animation("anvil1",time)
	if time >= float(wolf.rig["animations"]["anvil1"]["duration"]) and not wolf_restored:
		wolf_restored = true
		wolf.hide()
		player.visible = was_player_visible
	for cue in cues:
		if float(cue["time"]) > previous and float(cue["time"]) <= time and sound_paths.has(str(int(cue["sound_id"]))):
			sound.global_position = player.global_position
			sound.stream = load(sound_paths[str(int(cue["sound_id"]))])
			sound.play()
	# Anvil::Update releases its camera after 2000 ms while ANVIL2 keeps playing.
	if time >= drop+2 and not trap_released:
		trap_released = true
		if is_instance_valid(saved_camera): saved_camera.current = true
		# Never re-open the former Yes/No prompt while ANVIL2 is finishing.
	if time >= drop+hold:
		trap_time = -1
		anvil.hide()
		close_sign()

func reload_localization():
	signs = GameLocalization.load_data(definitions_path).signs
	if not active_sign.is_empty():
		for sign in signs:
			if sign["res"] == active_sign["res"]:
				active_sign = sign
				var identity = int(active_sign["res"])
				var index = int(active_sign.text_index)+int(read_variants.get(identity,0))
				if int(read_variants.get(identity,0)) == 1: index = int(active_sign.text_index)
				body.text = str(active_sign.texts[clampi(index,0,active_sign.texts.size()-1)]).strip_edges()
				break
	_update_hint()
