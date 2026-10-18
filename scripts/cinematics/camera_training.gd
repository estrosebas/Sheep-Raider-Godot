extends Node
class_name DaffyCameraTraining

const Space = preload("res://scripts/levels/game_space.gd")
const Probe = preload("res://scripts/player/camera_focus_probe.gd")
const ProgressRules = preload("res://scripts/levels/tutorial_progress.gd")
signal completed
enum Phase { WAIT_INTRO, FOLLOW, DIALOGUE, MOVING, LOOK, COMPLETE, WAIT_STAGE, DEMO }
@export var enabled = true
@export var continue_after_camera = true
var phase = Phase.WAIT_INTRO
var data: Dictionary
var director: Node3D
var actor: Node3D
var player: CharacterBody3D
var probe: Node
var focus_area: Area3D
var voice: AudioStreamPlayer
var ui: CanvasLayer
var card: Control
var instruction_card: Control
var dialogue: OriginalLevelDialogue
var body: Label
var hint: Label
var crosshair: FocusCrosshair
var letterbox: OriginalLetterbox
var voice_pending = false
var step_index = 0
var pending_dialogue = 0
var dialogue_time = 0.0
var animation_time = 0.0
var move_index = 0
var move_time = 0.0
var move_start: Vector3
var target: Vector3
var points: Array[Vector3] = []
var completion_time = 0.0
var saved_camera_offset = 0.0
var dialogue_pages: Array[String] = []
var page_index = 0
var retrying_race = false
var race_armed = false
var race_active = false
var race_finished = false
var race_time = 0.0
var race_start_position = Vector3.ZERO
var jump_phase = 0
var cue_clip = ""
var cue_time = -0.001
var race_label: Label
var flight_joke = false

class FocusCrosshair extends Control:
	var progress = 0.0
	func _draw() -> void:
		var center = size/2
		draw_circle(center,2,Color.WHITE)
		if progress > 0:
			draw_arc(center,14,-PI/2,-PI/2+TAU*clampf(progress,0,1),32,Color(1,0.85,0.3),3,true)

func _ready() -> void:
	data = GameLocalization.load_data("res://assets/cinematics/camera_training/lessons.json")
	director = get_parent().get_node("TutorialIntro")
	player = get_parent().get_node("Player")
	actor = director.actors["2:56"]
	player.respawned.connect(_on_player_respawn)
	director.finished.connect(_intro_finished)
	voice = AudioStreamPlayer.new()
	add_child(voice)
	probe = Probe.new()
	add_child(probe)
	probe.expected_target = actor
	probe.required_seconds = data["focus_seconds"]
	probe.exclude.append(player.get_rid())
	focus_area = Area3D.new()
	focus_area.name = "CameraFocusTarget"
	focus_area.collision_layer = 256
	focus_area.collision_mask = 0
	focus_area.set_meta("camera_focus_target",actor)
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.7
	shape.height = 2.2
	collision.shape = shape
	collision.position.y = 1.1
	focus_area.add_child(collision)
	actor.add_child(focus_area)
	_build_ui()

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 40
	add_child(ui)
	letterbox = OriginalLetterbox.new()
	ui.add_child(letterbox)
	card = PanelContainer.new()
	letterbox.text_card = card
	ui.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_left = 60
	card.offset_right = -60
	card.offset_top = -230
	card.offset_bottom = -30
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel",style)
	var column = VBoxContainer.new()
	card.add_child(column)
	var name_label = Label.new()
	name_label.text = "LUCAS"
	name_label.hide() # Dialogue_Show prints the spoken text, without a speaker header.
	name_label.add_theme_font_size_override("font_size",26)
	SubtitleStyle.apply(name_label)
	column.add_child(name_label)
	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size",26)
	SubtitleStyle.apply(body)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	body.hide()
	var subtitle_canvas = OriginalSubtitleCanvas.new()
	subtitle_canvas.text_label = body
	subtitle_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(subtitle_canvas)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size",20)
	SubtitleStyle.apply(hint)
	column.add_child(hint)
	crosshair = FocusCrosshair.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crosshair.hide()
	card.hide()
	instruction_card = card
	dialogue = OriginalLevelDialogue.new()
	add_child(dialogue)
	# One shared pair of bars also frames the short camera-focus instructions.
	letterbox.queue_free()
	letterbox = dialogue.letterbox
	letterbox.reparent(ui)
	ui.move_child(letterbox,0)
	letterbox.text_card = instruction_card
	dialogue.finished.connect(_spoken_line_finished)
	race_label = Label.new()
	race_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	race_label.add_theme_font_size_override("font_size",30)
	ui.add_child(race_label)
	race_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	race_label.offset_top = 100
	race_label.hide()

func _intro_finished(_skipped: bool) -> void:
	if not enabled:
		return
	if phase == Phase.WAIT_INTRO and int(director.data["cine_id"]) == 1:
		phase = Phase.FOLLOW
		director.switch_sequence("res://assets/cinematics/tutorial_intro/follow_sequence.json")
		director.data["voice_path"] = data["voices"]["80"]["path"]
		director.allow_skip = true
		director.start_sequence(true)
		_present_line(data["follow_text"],director.voice_player)
	elif phase == Phase.FOLLOW and int(director.data["cine_id"]) == 5:
		player.tutorial_movement_locked = true
		saved_camera_offset = player.camera.h_offset
		player.camera.h_offset = 0.8
		player.capture_mouse(true)
		_show_dialogue(0)
	elif phase == Phase.DEMO and int(director.data["cine_id"]) == 3:
		phase = Phase.DIALOGUE
		player.tutorial_movement_locked = true
		actor.idle_clip = ""
		dialogue_time = 0
		_update_page()
		if dialogue.completed: call_deferred("_spoken_line_finished")

func _clean(text: String) -> String:
	return OriginalLevelDialogue.clean(text)

func _show_dialogue(index: int) -> void:
	phase = Phase.DIALOGUE
	player.interrupt_actions()
	player.tutorial_movement_locked = true
	step_index = index
	dialogue_time = 0
	animation_time = 0
	actor.idle_clip = ""
	_face_player()
	probe.reset()
	crosshair.hide()
	var slot = data["slots"][index]
	voice.stop()
	voice.stream = null
	voice_pending = false
	# Voice 91 explicitly orders internal view; don't replay a contradictory
	# instruction after replacing it with the third-person camera mechanic.
	if index != 2 and int(slot["voice_id"]) != 0:
		voice.stream = load(data["voices"][str(int(slot["voice_id"]))]["path"])
		voice_pending = true
	_present_line(lesson_text(index),voice if voice_pending else null)

func _set_pages(text: String) -> void:
	_present_line(text,voice if voice.stream else null)

func _present_line(text: String,audio: AudioStreamPlayer):
	instruction_card.hide()
	dialogue.show_line(text,audio,true)
	dialogue.wait_for_voice = voice_pending
	card = dialogue.card
	dialogue_pages.assign(dialogue.pages)
	_update_page()

func _update_page() -> void:
	page_index = dialogue.current_page
	body.text = dialogue.label.text
	hint.text = ""

func _spoken_line_finished():
	if enabled and phase == Phase.DIALOGUE: _begin_move()

func _unhandled_input(event: InputEvent) -> void:
	if enabled and phase == Phase.DIALOGUE and dialogue_time > 0.4 and event.is_action_pressed("action") and not event.is_echo():
		# Optional skip; ordinary progression now follows the spoken line.
		_begin_move()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not enabled:
		return
	# Dialogue_StartVoice waits until Letterbox_Update reaches LETTERBOX_OPEN.
	if voice_pending and phase in [Phase.DIALOGUE,Phase.DEMO] and letterbox.timer_ms >= 1500:
		voice_pending = false
		voice.play()
		dialogue.wait_for_voice = false
	if phase in [Phase.FOLLOW,Phase.DIALOGUE,Phase.DEMO]: _update_page()
	if race_active:
		race_time = maxf(0,race_time-delta)
		race_label.text = GameLocalization.ui("Carrera · %.1f s") % race_time
		if race_time <= 0:
			_race_failed()
	if phase == Phase.DIALOGUE:
		dialogue_time += delta
		animation_time += delta
		var clip = "talk1" if voice.playing or (step_index == 2 and dialogue_time < 2) else "stand1a"
		if flight_joke and animation_time < float(actor.rig["animations"]["joke"]["duration"]):
			clip = "joke"
		actor.sample_animation(clip,animation_time,true)
	elif phase == Phase.MOVING:
		_step_move(delta)
	elif phase == Phase.COMPLETE:
		completion_time += delta
		if completion_time > 4:
			card.hide()

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	if race_active and ProgressRules.contains(data["race"]["finish"],player.global_position):
		race_active = false
		race_finished = true
		race_label.hide()
		_show_dialogue(13)
	if step_index >= 11 and step_index <= 13 and not race_active and not race_finished and phase != Phase.DIALOGUE:
		if not race_armed and ProgressRules.contains_xz(data["race"]["start"],player.global_position):
			race_armed = true
			race_start_position = player.global_position
		elif race_armed:
			race_active = true
			race_time = float(data["race"]["duration"])
			race_label.show()
	if phase == Phase.WAIT_STAGE:
		var box = data["slots"][step_index]["box"]
		if box != null and player.active_rocket == null and ProgressRules.contains(box,player.global_position):
			_stage_reached()
		return
	if phase != Phase.LOOK:
		return
	probe.camera = get_viewport().get_camera_3d()
	if probe.evaluate(delta):
		_show_dialogue(pending_dialogue)
	else:
		crosshair.progress = probe.focus_seconds/probe.required_seconds
		crosshair.queue_redraw()

func _begin_move() -> void:
	voice.stop()
	voice_pending = false
	flight_joke = false
	card.hide()
	dialogue.close()
	card = instruction_card
	letterbox.text_card = instruction_card
	if retrying_race:
		retrying_race = false
		_show_dialogue(11)
		return
	if step_index >= 4:
		player.tutorial_movement_locked = false
	if step_index >= data["slots"].size():
		phase = Phase.COMPLETE
		actor.idle("stand1")
		return
	phase = Phase.MOVING
	actor.idle_clip = ""
	points.clear()
	for point in data["slots"][step_index]["points"]:
		points.append(Space.original_point(Vector3(point[0],point[1],point[2])))
	move_index = 0
	cue_clip = ""
	if int(data["slots"][step_index]["gait"]) in [3,4]:
		actor.global_position = points[-1]
		_snap_to_ground()
		_move_finished()
	else:
		_next_move_point()

func _next_move_point() -> void:
	while move_index < points.size():
		target = points[move_index]
		var distance = Vector2(target.x-actor.global_position.x,target.z-actor.global_position.z).length()
		if distance >= 0.5:
			move_start = actor.global_position
			move_time = 0
			jump_phase = 0
			var heading = atan2(target.x-move_start.x,target.z-move_start.z)
			actor.rotation.y = heading+PI/2 if step_index < 3 else heading
			var gait = int(data["slots"][step_index]["gait"])%10
			actor.sample_animation("hide2" if step_index < 3 else ("walk1" if gait in [0,1] else "jump3"),0)
			return
		actor.global_position = target
		_snap_to_ground()
		move_index += 1
	_move_finished()

func _step_move(delta: float) -> void:
	if step_index >= 3:
		_step_platform_move(delta)
		return
	var old_time = move_time
	move_time += delta
	var duration = float(actor.rig["animations"]["hide2"]["duration"])
	actor.sample_animation("hide2",move_time)
	# Early MoveTo jumps hold X/Z, interpolate Y, then warp to the path node.
	actor.global_position.y = lerpf(move_start.y,target.y,clampf(move_time/duration,0,1))
	for cue in actor.rig["animations"]["hide2"]["sound_cues"]:
		if cue["time"] >= old_time and cue["time"] < move_time:
			player.play_animation_sfx(director.data["sounds"][str(int(cue["sound_id"]))])
	if move_time >= duration:
		actor.global_position = target
		_snap_to_ground()
		move_index += 1
		_next_move_point()

func _snap_to_ground() -> void:
	var ray = PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*2,actor.global_position-Vector3.UP*4)
	ray.exclude = [player.get_rid()]
	var hit = actor.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit["normal"].y > 0.5:
		actor.global_position.y = hit["position"].y

func _move_finished() -> void:
	_face_player()
	actor.idle("stand1")
	if step_index == 0:
		_show_dialogue(1)
	elif step_index in [1,2]:
		phase = Phase.LOOK
		pending_dialogue = step_index+1
		probe.reset()
		crosshair.progress = 0
		crosshair.show()
		body.text = GameLocalization.ui("Busca a Lucas arriba.") if step_index == 2 else GameLocalization.ui("Lucas está detrás de ti. Gira la cámara para encontrarlo.")
		hint.text = GameLocalization.ui("Apúntale con el centro de la cámara durante un segundo.")
		card.show()
	elif step_index == 3:
		phase = Phase.COMPLETE
		player.tutorial_movement_locked = false
		player.camera.h_offset = saved_camera_offset
		crosshair.hide()
		body.text = GameLocalization.ui("¡Muy bien! Ya puedes mirar a tu alrededor.")
		hint.text = GameLocalization.ui("WASD: moverte · Espacio: saltar · Ratón: cámara")
		card.show()
		completed.emit()
		if continue_after_camera:
			_enter_stage(4)
	else:
		_enter_stage(step_index+1)

func _enter_stage(index: int) -> void:
	step_index = index
	phase = Phase.WAIT_STAGE
	player.tutorial_movement_locked = false
	card.hide()
	actor.idle("stand1")
	if index >= data["slots"].size():
		phase = Phase.COMPLETE
		return
	if data["slots"][index]["box"] == null:
		_stage_reached()

func _stage_reached() -> void:
	var text = _clean(data["slots"][step_index]["original_text"])
	if text.is_empty():
		_begin_move()
	else:
		_show_dialogue(step_index)
		if step_index == 14:
			phase = Phase.DEMO
			director.switch_sequence("res://assets/cinematics/tutorial_intro/platform_sequence.json")
			director.allow_skip = true
			director.start_sequence(true)

func _step_platform_move(delta: float) -> void:
	var gait = int(data["slots"][step_index]["gait"])%10
	if gait in [0,1]:
		move_time += delta
		actor.global_position = actor.global_position.move_toward(target,6*delta)
		var direction = target-actor.global_position
		actor.rotation.y = atan2(direction.x,direction.z)
		actor.sample_animation("walk1",move_time,true)
		if actor.global_position.distance_to(target) < 0.5:
			actor.global_position = target
			_snap_to_ground()
			move_index += 1
			_next_move_point()
		return
	move_time += delta
	var clip = ["jump3","jump4","jump5","jump6"][jump_phase]
	actor.sample_animation(clip,move_time)
	if jump_phase == 0:
		if move_time >= float(actor.rig["animations"]["jump3"]["duration"]):
			jump_phase = 1
			move_time = 0
	elif jump_phase in [1,2]:
		var fraction = clampf(move_time/0.4,0,1)
		actor.global_position = move_start.lerp(target,fraction)+Vector3.UP*sin(fraction*PI)
		if fraction > 0.5:
			jump_phase = 2
		if fraction >= 1:
			actor.global_position = target
			_snap_to_ground()
			if move_index+1 < points.size():
				move_index += 1
				_next_move_point()
			else:
				jump_phase = 3
				move_time = 0
	else:
		if move_time >= float(actor.rig["animations"]["jump6"]["duration"]):
			move_index += 1
			_next_move_point()

func _race_failed() -> void:
	race_active = false
	race_armed = false
	race_label.hide()
	player.respawn_at_checkpoint()
	_show_retry()

func _show_retry() -> void:
	actor.global_position = Space.original_point(_point(data["slots"][11]["points"][0]))
	_show_dialogue(11)
	voice.stream = load(data["voices"]["82"]["path"])
	voice_pending = true
	_set_pages(data["race"]["retry_text"])
	retrying_race = true

func _on_player_respawn() -> void:
	if not enabled:
		return
	if race_active:
		race_active = false
		race_armed = false
		race_label.hide()
		_show_retry()
	elif step_index == 9:
		actor.global_position = Space.original_point(_point(data["slots"][8]["points"][-1]))
		_show_dialogue(9)
		voice.stream = load(data["voices"][str(int(data["flight_joke"]["voice_id"]))]["path"])
		voice_pending = false
		voice.play()
		_set_pages(data["flight_joke"]["text"])
		flight_joke = true

func _point(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

func _face_player() -> void:
	var direction = player.global_position-actor.global_position
	actor.rotation.y = atan2(direction.x,direction.z)

func reload_localization():
	data = GameLocalization.load_data("res://assets/cinematics/camera_training/lessons.json")
	if phase in [Phase.DIALOGUE,Phase.DEMO] and step_index >= 0:
		var text = lesson_text(step_index)
		var identity = int(data.slots[step_index].voice_id)
		if step_index==2: identity = 0
		if retrying_race: identity = 82; text = data.race.retry_text
		if flight_joke: identity = int(data.flight_joke.voice_id); text = data.flight_joke.text
		var position = voice.get_playback_position() if voice.playing else dialogue.elapsed
		var playing_before = voice.playing
		if identity != 0:
			voice.stream = load(GameLocalization.voice_path(identity))
			if playing_before: voice.play(minf(position,maxf(0,voice.stream.get_length()-.01)))
		_present_line(text,voice if identity!=0 else null)
		if not voice_pending:
			dialogue.elapsed = minf(position,dialogue.total_duration)
			dialogue._process(0)
			_update_page()

func lesson_text(index: int) -> String:
	var text = data["slots"][index]["original_text"]
	# Adapt the two control instructions, preserving the original lesson order.
	if index == 1:
		text = GameLocalization.ui("PSSST. Estoy detrás de ti.\nGira la cámara con el ratón hasta encontrarme.")
	elif index == 2:
		text = GameLocalization.ui("Ahora me esconderé aquí.\nMira hacia arriba y mantenme en el centro de la cámara un segundo.")
	elif index == 16:
		text = GameLocalization.ui("Para conseguir un objeto debes encargarlo abriendo un buzón.\nAcércate, mira hacia él y pulsa E para solicitar el envío.\nLa caja caerá y se abrirá al tocar el suelo.\nRecoge el objeto con E para guardarlo en tu inventario.")
	elif index == 17:
		text = GameLocalization.ui("Recoge el cohete con E y guárdalo en tu inventario.\nMantén Tab para mostrar tus objetos.\nSelecciona con A y D y suelta Tab para equiparlo.\nEl cohete se coloca en tu espalda; pulsa E o R para despegar.\nAhora regresa y utiliza el cohete para volar hasta la META.")
	return text
