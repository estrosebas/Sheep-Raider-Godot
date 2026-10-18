extends OriginalSequence
class_name OriginalLevelSequence
var world_actors: Dictionary = {}
var dialogue: OriginalLevelDialogue
var preserve_player_state = false
var voice_completed = false

func _ready() -> void:
	super._ready()
	dialogue = OriginalLevelDialogue.new()
	add_child(dialogue)
	voice_player.finished.connect(func(): voice_completed = true)
	for child in get_parent().get_parent().get_children():
		if not child is Node3D or not child.has_meta("original_resource"): continue
		for key in data["actors"]:
			if int(data["actors"][key]["resource"]) == int(child.get_meta("original_resource")): world_actors[key] = child

func start_sequence(replay: bool = false) -> bool:
	if player.cinematic_controls_locked: return false
	for key in world_actors:
		# Tracks which only change animation/visibility retain native placement.
		actors[key].global_transform = world_actors[key].global_transform
	if not super.start_sequence(replay): return false
	if not data.tracks.any(func(track): return int(track.selector)==0):
		if is_instance_valid(saved_camera_current): saved_camera_current.current = true
		framing.hide()
	voice_completed = false
	for key in world_actors:
		if world_actors[key].visible:
			hidden_nodes.append(world_actors[key])
			world_actors[key].hide()
	var hud = get_parent().get_parent().get_node_or_null("HUD")
	if hud:
		saved_hud_visible = hud.visible
		hud.hide()
	if data.has("text"): dialogue.show_line(data["text"],voice_player)
	return true

func _process(delta: float) -> void:
	if not playing: return
	var previous = elapsed
	if data.has("voice_path") and not voice_completed:
		# Loading/stalls must not advance the actors ahead of the spoken audio.
		# Account for the mixed block and device output latency, including pause.
		if voice_player.playing:
			var audible = voice_player.get_playback_position()+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency()
			elapsed = minf(float(data["duration"]),maxf(previous,audible))
	elif voice_completed:
		elapsed = minf(float(data["duration"]),maxf(previous,voice_player.stream.get_length())+delta)
	else: elapsed = minf(float(data["duration"]),elapsed+delta)
	sample(elapsed)
	_dispatch_sounds(previous,elapsed)
	if elapsed >= float(data["duration"]): finish_sequence(false)

func finish_sequence(skipped: bool) -> void:
	if not playing: return
	sample(float(data["duration"]))
	# Resource 42 is Ralph only in Lvl-01; subsequent WARs use other ids.
	var ralph: Node3D
	for key in data.actors:
		if int(data.actors[key].model) == 0:
			ralph = actors[key]
			break
	if ralph:
		player.global_position = ralph.global_position
		player.skeleton.rotation.y = ralph.rotation.y
	else: player.global_position = saved_player_position
	for key in world_actors:
		var original: Node3D = world_actors[key]
		original.global_position = actors[key].global_position
		original.rotation = actors[key].rotation
	for node in hidden_nodes:
		if is_instance_valid(node): node.show()
	hidden_nodes.clear()
	for actor in actors.values(): actor.hide()
	player.cinematic_controls_locked = false
	player.visible = was_player_visible
	player.inventory.wheel.visible = was_wheel_visible
	if not preserve_player_state: player.set_state(player.WolfState.IDLE)
	player.set_physics_process(saved_physics)
	if is_instance_valid(saved_camera_current): saved_camera_current.current = true
	else: player.camera.current = true
	var hud = get_parent().get_parent().get_node_or_null("HUD")
	if hud: hud.visible = saved_hud_visible
	for sound in sound_players: sound.stop()
	voice_player.stop()
	dialogue.close()
	playing = false
	framing.hide()
	apply_return_transition()
	finished.emit(skipped)

func reload_localization():
	super.reload_localization()
	if playing and data.has("text"): dialogue.show_line(data.text,voice_player)
