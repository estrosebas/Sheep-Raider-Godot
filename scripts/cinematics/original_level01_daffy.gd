extends OriginalNpcConversation
class_name OriginalLevel01Daffy
var movies: Dictionary = {}
var warmup = 0.0

func _ready() -> void:
	intro_finished = false
	super._ready()
	for identity in [0,2,3,4]:
		var movie = OriginalLevelSequence.new()
		movie.sequence_path = "res://assets/levels/lvl_01/cinematics/sequence_%d.json" % identity
		movie.allow_skip = true
		add_child(movie)
		movie.bind_player(player)
		movie.finished.connect(_finished.bind(identity))
		movies[identity] = movie

func start_movie(identity: int) -> bool:
	if active_movie or player.cinematic_controls_locked: return false
	var movie: OriginalLevelSequence = movies[identity]
	if not movie.start_sequence(): return false
	active_movie = movie
	return true

func _finished(_skipped: bool, identity: int) -> void:
	active_movie = null
	var movie = movies[identity]
	var next = OriginalCameraCatalog.next_sequence(movie.sequence_path)
	if not next.is_empty():
		call_deferred("start_movie",int(next.cine_id))
	elif movie.camera_kind=="intro_cinematic" and movie.camera_descriptor.get("trigger","")=="level_entry":
		intro_finished = true
		global_position = daffy.global_position
		daffy.idle("stand1")


func _process(delta: float) -> void:
	if player.restart_fade_remaining > 0: return
	warmup += delta
	if warmup > .2 and not movies[0].played and not active_movie and movies[0].inside_trigger(player.global_position): start_movie(0)
	super._process(delta)
