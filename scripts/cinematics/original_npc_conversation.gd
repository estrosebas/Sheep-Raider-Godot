extends Node3D
class_name OriginalNpcConversation
var player: RalphController
var daffy: OriginalCinematicActor
var data: Dictionary
var active_movie: OriginalLevelSequence
var voice: AudioStreamPlayer
var dialogue: OriginalLevelDialogue
var menu: CanvasLayer
var menu_label: Label
var menu_frame: OriginalTextBox
var selected = 0
var speaking = false
var intro_finished = true
var burnt = false
var burnt_line_said = false
var speech_skippable = true
@export_file("*.json") var data_path = "res://assets/levels/lvl_01/data/daffy.json"
@export var actor_prefix = "DaffyLevel01"

func _ready() -> void:
	player = get_parent().get_node("Player")
	data = GameLocalization.load_data(data_path)
	daffy = get_parent().get_node("%s_%d" % [actor_prefix,int(data["resource"])])
	daffy.idle("stand1")
	add_to_group("world_interactables")
	global_position = daffy.global_position
	voice = AudioStreamPlayer.new()
	add_child(voice)
	dialogue = OriginalLevelDialogue.new()
	add_child(dialogue)
	menu = CanvasLayer.new()
	menu.layer = 45
	add_child(menu)
	menu_label = Label.new()
	menu.add_child(menu_label)
	menu_label.hide()
	menu_frame = OriginalTextBox.new()
	menu_frame.text_label = menu_label
	menu.add_child(menu_frame)
	menu_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.hide()
	voice.finished.connect(_on_voice_finished)
	dialogue.finished.connect(_voice_finished)
	add_to_group("blast_targets")
	player.respawned.connect(reset_burnt)

func can_interact(actor: RalphController) -> bool:
	return actor == player and intro_finished and not active_movie and not speaking and not menu.visible and actor.can_use_item() and actor.global_position.distance_to(daffy.global_position) < 2.0

func interact(actor: RalphController) -> bool:
	if not can_interact(actor): return false
	actor.interrupt_actions()
	actor.cinematic_controls_locked = true
	if burnt and not burnt_line_said:
		burnt_line_said = true
		say(data["burnt"],actor_prefix != "DaffyLevel01")
	else:
		selected = 0
		_show_menu()
	return true

func _show_menu() -> void:
	var choices: Array = []
	for answer in data["answers"]: choices.append(answer["choice"])
	menu_frame.set_choices(data["question"],choices,selected,GameLocalization.ui("E: elegir · Escape: volver"))
	menu.show()

func _process(_delta: float) -> void:
	if speaking:
		daffy.idle_clip = "talk1" if voice.playing else "stand1"
	elif not active_movie:
		var diff = player.global_position-daffy.global_position
		daffy.rotation.y = atan2(diff.x,diff.z)
		global_position = daffy.global_position

func _voice_finished() -> void:
	voice.stop()
	speaking = false
	dialogue.close()
	daffy.idle("stand1")
	player.cinematic_controls_locked = false

func _on_voice_finished() -> void:
	# Dialogue_Say ends when ScrollText_Run ends, including silent timed pages.
	if not dialogue.timed: _voice_finished()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if menu.visible:
		if event.physical_keycode in [KEY_UP,KEY_W,KEY_DOWN,KEY_S]:
			selected = posmod(selected+(-1 if event.physical_keycode in [KEY_UP,KEY_W] else 1),data["answers"].size())
			_show_menu()
		elif event.physical_keycode in [KEY_ENTER,KEY_E]:
			menu.hide()
			var answer = data["answers"][selected]
			say(answer)
		elif event.physical_keycode == KEY_ESCAPE:
			menu.hide()
			player.cinematic_controls_locked = false
		get_viewport().set_input_as_handled()
	elif speaking and speech_skippable and event.physical_keycode == KEY_E:
		voice.stop()
		_voice_finished()
		get_viewport().set_input_as_handled()

func say(answer: Dictionary, skippable: bool = true) -> void:
	speech_skippable = skippable
	voice.stream = load(answer["voice_path"])
	voice.play()
	speaking = true
	daffy.idle("talk1")
	dialogue.show_line(answer["text"],voice)

func on_blast(_point: Vector3) -> void:
	burnt = true
	OriginalBurntTint.apply(daffy.legacy_skin,true)

func reset_burnt() -> void:
	burnt = false
	burnt_line_said = false
	OriginalBurntTint.apply(daffy.legacy_skin,false)

func _exit_tree() -> void:
	if is_instance_valid(player) and (speaking or (is_instance_valid(menu) and menu.visible)): player.cinematic_controls_locked = false

func reload_localization():
	var speech_index = selected
	var is_burnt = false
	if speaking and voice.stream:
		is_burnt = voice.stream.resource_path == data.burnt.voice_path
		for i in range(data.answers.size()):
			if voice.stream.resource_path == data.answers[i].voice_path: speech_index = i
	var position = voice.get_playback_position()
	data = GameLocalization.load_data(data_path)
	if menu.visible: _show_menu()
	if speaking:
		var answer = data.burnt if is_burnt else data.answers[speech_index]
		voice.stream = load(answer.voice_path)
		voice.play(minf(position,maxf(0,voice.stream.get_length()-.01)))
		dialogue.show_line(answer.text,voice)
