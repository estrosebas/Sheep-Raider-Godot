extends Node3D
# Native CinematicsManager activation boxes; tutorial movies are owned by Lucas.
var movies: Dictionary = {}
var triggers: Array
var active_movie: OriginalLevelSequence
var player: RalphController
var intro_finished = false
var warmup = 0.0
var intro_id = -1
func _ready():
	player = get_parent().get_node("Player")
	var base: String = get_parent().asset_directory
	triggers = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/cinematic_triggers.json"))
	var imported = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/import_audit.json"))
	intro_id = int(imported.get("intro_cine_id",2))
	for audit in imported.sequences:
		var identity = int(audit.cine_id)
		# JSON numbers are floats; Array.has uses strict Variant types.
		if imported.get("tutorial_cine_ids",[0,3]).any(func(value): return int(value)==identity): continue
		var movie = preload("res://scripts/cinematics/original_rock_sequence.gd").new() if identity in [1,4] and imported.level=="lvl_03" else OriginalLevelSequence.new()
		movie.sequence_path = base+"/cinematics/sequence_%d.json"%identity
		movie.allow_skip = true; movie.apply_empty_visibility_defaults = true
		add_child(movie); movie.bind_player(player); movies[identity] = movie
		movie.finished.connect(_finished.bind(identity))
func start_movie(identity: int) -> bool:
	if active_movie or not movies.has(identity) or player.cinematic_controls_locked: return false
	if not movies[identity].start_sequence(): return false
	active_movie = movies[identity]; return true
func start_rock_movie(identity: int,rock: Node3D) -> bool:
	if active_movie or not movies.has(identity): return false
	var movie = movies[identity]
	movie.rock = rock
	if not movie.start_sequence(true): return false
	active_movie = movie
	rock.box_delivered = false
	return true
func _finished(_skipped: bool,identity: int):
	active_movie = null
	if identity==intro_id: intro_finished = true
func _process(delta):
	warmup += delta
	if warmup<.25 or active_movie or player.restart_fade_remaining>0 or player.cinematic_controls_locked or player.item_actions.busy: return
	for trigger in triggers:
		var identity = int(trigger.cine_id)
		if movies[identity].played: continue
		if OriginalSam.contains(player.global_position,trigger.activation): start_movie(identity); return
func capture_progress() -> Dictionary:
	var played: Array = []
	for identity in movies: if movies[identity].played: played.append(identity)
	return {"played":played,"intro_finished":intro_finished}
func restore_progress(saved: Dictionary):
	for identity in movies: movies[identity].played = saved.get("played",[]).has(identity) or identity==intro_id
	intro_finished = true
