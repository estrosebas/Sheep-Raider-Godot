extends OriginalNpcConversation

# DaffyElf (class 55), daffyelf.cpp 0x4361bb–0x436892.
# The shared director owns the level-entry CIN1; this adapter owns Elf CIN2.
var movie: OriginalLevelSequence
var movies: Dictionary = {}
var calling: AudioStreamPlayer3D
var calling_started = false
var warmup = 0.0
var talk_elapsed = 0.0
var random = RandomNumberGenerator.new()

func _ready() -> void:
	data_path = "res://assets/levels/lvl_04/data/daffy.json"
	actor_prefix = "DaffyElf"
	intro_finished = false
	super._ready()
	random.randomize()
	daffy.idle("stand")
	movie = OriginalLevelSequence.new()
	movie.sequence_path = "res://assets/levels/lvl_04/cinematics/sequence_%d.json"%int(data.cine_id)
	movie.allow_skip = true
	movie.apply_empty_visibility_defaults = true
	add_child(movie)
	movie.bind_player(player)
	movies[int(data.cine_id)] = movie
	movie.finished.connect(_lesson_finished)
	calling = AudioStreamPlayer3D.new()
	var sounds: Dictionary = GameLocalization.load_data("res://assets/levels/lvl_04/data/ai_audio.json")
	var sound_path: String = sounds.get(str(int(data.calling_sound_id)),"")
	if not sound_path.is_empty(): calling.stream = load(sound_path)
	calling.unit_size = 6.0
	calling.max_distance = 20.0
	calling.volume_db = -6.0
	add_child(calling)
	# DaffyElf::WATCH starts37 once (soundHandle stays nonzero after it
	# ends). CINEMATIC/WAIT_CINE_BOX never start it; COME1 has no such cue.

func _process(delta: float) -> void:
	warmup += delta
	if active_movie:
		calling.stop()
		calling_started = false
		return
	global_position = daffy.global_position
	if speaking:
		calling.stop()
		calling_started = false
		talk_elapsed += delta
		var clip = daffy.animation_player.get_animation(daffy.idle_clip)
		if clip and talk_elapsed >= clip.length:
			talk_elapsed = 0.0
			daffy.idle(["talk1","talk2","talk4"][random.randi_range(0,2)])
		return
	if menu.visible:
		calling.stop()
		calling_started = false
		return
	if player.cinematic_controls_locked or player.restart_fade_remaining > 0:
		calling.stop()
		return
	var direction = player.global_position-daffy.global_position
	daffy.rotation.y = atan2(direction.x,direction.z)
	if not intro_finished:
		# The source tests CINEBOX in X/Z only, not the actor's height.
		if warmup > .25 and OriginalSam.contains(player.global_position,data.trigger,false):
			if movie.start_sequence(): active_movie = movie
	elif calling.stream and not calling_started:
		calling_started = true
		calling.play()

func _lesson_finished(_skipped: bool) -> void:
	active_movie = null
	intro_finished = true
	calling_started = false
	global_position = daffy.global_position
	daffy.idle("stand")

func can_interact(actor: RalphController) -> bool:
	return super.can_interact(actor) and actor.global_position.distance_to(daffy.global_position) < float(data.interaction_distance)

func say(answer: Dictionary, skippable: bool = true) -> void:
	calling.stop()
	calling_started = false
	talk_elapsed = 0.0
	super.say(answer,skippable)

func _voice_finished() -> void:
	super._voice_finished()
	calling_started = false
	daffy.idle("stand")

func on_blast(_point: Vector3) -> void:
	# DaffyElf::HandleMessage has no burnt-dialogue branch.
	pass

func capture_progress() -> Dictionary:
	return {"intro_finished":intro_finished}

func restore_progress(saved: Dictionary) -> void:
	calling.stop(); calling_started = false
	intro_finished = bool(saved.get("intro_finished",false))
	movie.played = intro_finished
	daffy.idle("stand")
