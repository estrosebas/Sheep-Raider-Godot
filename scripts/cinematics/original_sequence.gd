extends Node3D
class_name OriginalSequence

const Space = preload("res://scripts/levels/game_space.gd")
signal started
signal finished(skipped: bool)
@export var sequence_path = "res://assets/cinematics/tutorial_intro/sequence.json"
@export var allow_skip = false # CIN 1 has CINE_NO_INPUT; opt in for development.
@export var apply_empty_visibility_defaults = false
@export_enum("automatic","intro_cinematic","camera_animation","tutorial_cinematic","interaction_camera","camera_focus","death_camera","menu_camera") var camera_kind = "automatic"
@export_enum("automatic","none","iris") var return_transition = "automatic"
var camera_descriptor: Dictionary
var catalog_kind = true
var catalog_transition = true
var data: Dictionary
var actors: Dictionary = {}
var player: CharacterBody3D
var camera: Camera3D
var playing = false
var played = false
var elapsed = 0.0
var sound_events: Array[Dictionary] = []
var sound_players: Array[AudioStreamPlayer3D] = []
var hidden_nodes: Array[Node3D] = []
var was_player_visible = true
var was_wheel_visible = true
var saved_physics = true
var saved_camera_current: Camera3D
var saved_hud_visible = true
var framing: CanvasLayer
var voice_player: AudioStreamPlayer
var persistent_platforms: Dictionary = {}
var saved_player_position: Vector3
var sound_reuse_cursor = 0
const MAX_CINEMATIC_SOUNDS = 8

class OriginalFraming extends Control:
	func _draw() -> void:
		var width = maxf(0,(size.x-size.y*4.0/3)/2)
		draw_rect(Rect2(0,0,width,size.y),Color.BLACK)
		draw_rect(Rect2(size.x-width,0,width,size.y),Color.BLACK)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

func _ready() -> void:
	catalog_kind = camera_kind=="automatic"
	catalog_transition = return_transition=="automatic"
	camera_descriptor = OriginalCameraCatalog.sequence(sequence_path)
	if camera_kind=="automatic": camera_kind = camera_descriptor.get("kind","camera_animation")
	if return_transition=="automatic": return_transition = camera_descriptor.get("return_transition","none")
	data = GameLocalization.load_data(sequence_path)
	camera = Camera3D.new()
	camera.name = "OriginalCinematicCamera"
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)
	framing = CanvasLayer.new()
	framing.layer = 30
	add_child(framing)
	var mask = OriginalFraming.new()
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	framing.add_child(mask)
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	framing.hide()
	voice_player = AudioStreamPlayer.new()
	add_child(voice_player)
	for key in data["actors"]:
		var definition = data["actors"][key]
		var actor = load(definition["directory"]+"/worn.tscn").instantiate()
		actor.name = definition["name"]
		add_child(actor)
		actor.hide()
		actors[key] = actor
	_build_sound_events()

func bind_player(actor: CharacterBody3D) -> void:
	player = actor

func inside_trigger(point: Vector3) -> bool:
	var trigger = data["trigger"]
	var a = trigger["min"]
	var b = trigger["max"]
	var lo = Space.original_point(Vector3(a[0],b[1],b[2]))
	var hi = Space.original_point(Vector3(b[0],a[1],a[2]))
	return point.x >= lo.x and point.x <= hi.x and point.y >= lo.y and point.y <= hi.y and point.z >= lo.z and point.z <= hi.z

func start_sequence(replay: bool = false) -> bool:
	if playing or (played and not replay) or not is_instance_valid(player):
		return false
	# Opening the entry/respawn iris needs Ralph's physics updates. Starting
	# a movie here disables that physics and leaves the circle stuck mid-open.
	if player.restart_fade_remaining > 0: return false
	if player.current_state == player.WolfState.PIT_FALL:
		return false
	playing = true
	played = true
	elapsed = 0
	saved_player_position = player.global_position
	saved_camera_current = get_viewport().get_camera_3d()
	saved_physics = player.is_physics_processing()
	was_player_visible = player.visible
	was_wheel_visible = player.inventory.wheel.visible
	player.interrupt_actions()
	player.cinematic_controls_locked = true
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.stop_loop_sfx()
	player.sneak_audio_player.stop()
	player.run_dust.clear()
	player.hide()
	player.inventory.wheel.hide()
	hidden_nodes.clear()
	var daffy = get_parent().get_node_or_null("DaffyDuck")
	if daffy and daffy.visible:
		hidden_nodes.append(daffy)
		daffy.hide()
	var hud = get_parent().get_node_or_null("HUD")
	if hud:
		saved_hud_visible = hud.visible
		hud.hide()
	camera.current = true
	framing.show()
	for node in actors.values():
		node.idle_clip = ""
	sample(0)
	_dispatch_sounds(-0.001,0)
	started.emit()
	if data.has("voice_path"):
		voice_player.stream = load(data["voice_path"])
		# Localized recordings differ in length; hold the final pose until speech ends.
		data["duration"] = maxf(float(data["duration"]),voice_player.stream.get_length())
		voice_player.play()
	return true

func switch_sequence(path: String) -> void:
	assert(not playing)
	sequence_path = path
	camera_descriptor = OriginalCameraCatalog.sequence(path)
	if catalog_kind: camera_kind = camera_descriptor.get("kind","camera_animation")
	if catalog_transition: return_transition = camera_descriptor.get("return_transition","none")
	data = GameLocalization.load_data(path)
	sound_events.clear()
	_build_sound_events()

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if not playing:
		if not played and not player.tutorial_movement_locked and inside_trigger(player.global_position):
			start_sequence()
		return
	var previous = elapsed
	elapsed = minf(elapsed+delta,float(data["duration"]))
	sample(elapsed)
	_dispatch_sounds(previous,elapsed)
	if elapsed >= float(data["duration"]):
		finish_sequence(false)

func _unhandled_input(event: InputEvent) -> void:
	if playing and allow_skip and (event.is_action_pressed("cancel") or event.is_action_pressed("action")) and not event.is_echo():
		finish_sequence(true)
		get_viewport().set_input_as_handled()

func sample(time: float) -> void:
	for track in data["tracks"]:
		var key = "%d:%d" % [int(track["selector"]),int(track["index"])]
		var is_camera = int(track["selector"]) == 0
		var actor: Node3D = camera if is_camera else actors[key]
		var shown = true
		for record in track["records"]:
			var keys: Array = record["keys"]
			if keys.is_empty():
				# NotifyActors still applies an empty visibility stream's
				# initial state (notably the hidden tutorial smoke prop).
				if apply_empty_visibility_defaults and int(record.opcode) in [4,5]: shown = int(record.opcode) == 4
				continue
			var index = 0
			for i in range(keys.size()):
				if float(keys[i]["time"]) <= time:
					index = i
			var current = keys[index]
			var next = keys[mini(index+1,keys.size()-1)]
			var amount = 0.0
			if int(current["mode"]) == 2 and float(next["time"]) > float(current["time"]):
				amount = clampf((time-float(current["time"]))/float(next["time"]-current["time"]),0,1)
			var op = int(record["opcode"])
			if op == 1:
				var a = _vector(current["value"])
				var b = _vector(next["value"])
				actor.global_position = Space.original_point(a.lerp(b,amount))
			elif op == 2:
				var a = _vector(current["value"])*TAU/4096
				var b = _vector(next["value"])*TAU/4096
				var r = Vector3(lerp_angle(a.x,b.x,amount),lerp_angle(a.y,b.y,amount),lerp_angle(a.z,b.z,amount))
				actor.rotation = Vector3(-r.x,r.y,-r.z) if is_camera else Vector3(r.x,-r.y,-r.z)
			elif op == 3 and not is_camera:
				var value = int(current["value"][0]) & 65535
				var clip = data["actors"][key]["animation_ids"][str(value&0x7fff)]
				# Cine::OpStartAnim calls PlayAnim(id, 1, 0): every authored
				# animation repeats until the next opcode, including Lucas TIPTOE.
				actor.sample_animation(clip,maxf(0,time-float(current["time"])),true)
			elif op in [4,5]:
				shown = op == 4 # NotifyActors' initial visibility before first key.
				if time >= float(keys[0]["time"]):
					shown = bool(index%2) if op == 4 else not bool(index%2)
			elif op == 6 and is_camera:
				# Camera_StartScripted: focal = virtual width * scale >> 10.
				var focal = floorf(512.0*lerpf(float(current["value"][0]),float(next["value"][0]),amount)/1024.0)
				# Preserve the original 4:3 framing instead of cropping vertically
				# on a 16:9 monitor; side masks retain the authored horizontal view.
				camera.fov = rad_to_deg(2*atan(256/maxf(1,focal)/(4.0/3)))
		if not is_camera:
			actor.movie_visibility(shown)

func _vector(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

func _build_sound_events() -> void:
	for track in data["tracks"]:
		if int(track["selector"]) == 0:
			continue
		var key = "%d:%d" % [int(track["selector"]),int(track["index"])]
		for record in track["records"]:
			if int(record["opcode"]) != 3:
				continue
			var keys: Array = record["keys"]
			for index in range(keys.size()):
				var frame = keys[index]
				var next_time = float(keys[index+1]["time"]) if index+1 < keys.size() else float(data["duration"])+0.01
				var clip = data["actors"][key]["animation_ids"][str(int(frame["value"][0])&0x7fff)]
				var source = actors[key].rig["animations"][clip]
				for cycle in range(ceili((next_time-float(frame["time"]))/maxf(.001,float(source["duration"])))):
					for cue in source["sound_cues"]:
						var cue_time = float(frame["time"])+cycle*float(source["duration"])+float(cue["time"])
						if cue_time < next_time and cue_time <= float(data["duration"]):
							sound_events.append({"time":cue_time,"actor":key,"id":int(cue["sound_id"])})

func _dispatch_sounds(previous: float, time: float) -> void:
	for cue in sound_events:
		if float(cue["time"]) <= previous or float(cue["time"]) > time:
			continue
		var path = data["sounds"][str(cue["id"])]
		var sound: AudioStreamPlayer3D = null
		var already_playing = false
		for existing in sound_players:
			if existing.playing and existing.get_meta("cue_actor","") == cue["actor"] and existing.get_meta("cue_id",-1) == cue["id"]:
				already_playing = true
				break
			if not existing.playing:
				sound = existing
		if already_playing: continue
		if sound == null and sound_players.size() >= MAX_CINEMATIC_SOUNDS:
			sound = sound_players[sound_reuse_cursor]
			sound_reuse_cursor = (sound_reuse_cursor+1)%MAX_CINEMATIC_SOUNDS
			sound.stop()
		if sound == null:
			sound = AudioStreamPlayer3D.new()
			sound.max_distance = 50
			add_child(sound)
			sound_players.append(sound)
		sound.set_meta("cue_actor",cue["actor"])
		sound.set_meta("cue_id",cue["id"])
		sound.global_position = actors[cue["actor"]].global_position
		sound.stream = load(path)
		sound.play()

func finish_sequence(skipped: bool) -> void:
	if not playing:
		return
	# Source flags do not restore actor positions: finish in the last authored pose.
	sample(float(data["duration"]))
	var actor: Node3D = actors["2:52"]
	var moves_player = false
	for track in data["tracks"]:
		if int(track["selector"]) == 2 and int(track["index"]) == 52:
			moves_player = true
		if int(track["selector"]) == 3:
			var key = "3:%d" % int(track["index"])
			persistent_platforms[key] = actors[key].visible
	player.global_position = actor.global_position if moves_player else saved_player_position
	if moves_player:
		player.skeleton.rotation.y = actor.rotation.y
	player.cinematic_controls_locked = false
	player.visible = was_player_visible
	player.inventory.wheel.visible = was_wheel_visible
	player.set_state(player.WolfState.IDLE)
	player.set_physics_process(saved_physics)
	player.safe_position = player.global_position
	if is_instance_valid(saved_camera_current):
		saved_camera_current.current = true
	else:
		player.camera.current = true
	var daffy = get_parent().get_node_or_null("DaffyDuck")
	if daffy:
		daffy.global_position = actors["2:56"].global_position
		daffy.rotation.y = actors["2:56"].rotation.y
	for node in hidden_nodes:
		if is_instance_valid(node) and node != daffy:
			node.show()
	for key in actors:
		actors[key].movie_visibility(bool(persistent_platforms.get(key,false)))
	# Keep the real animated Lucas after the intro, rather than a rigid duplicate.
	actors["2:56"].show()
	actors["2:56"].idle("stand1")
	for sound in sound_players:
		sound.stop()
	voice_player.stop()
	var hud = get_parent().get_node_or_null("HUD")
	if hud:
		hud.visible = saved_hud_visible
	playing = false
	framing.hide()
	apply_return_transition()
	finished.emit(skipped)

func apply_return_transition():
	OriginalCameraCatalog.apply_return(player,return_transition)

func reload_localization():
	var position = voice_player.get_playback_position()
	var updated = GameLocalization.load_data(sequence_path)
	# Level00's follow voice is assigned by CameraTraining, outside sequence.json.
	if data.has("voice_path") and not updated.has("voice_path"):
		var filename = str(data.voice_path).get_file()
		for path in GameLocalization.manifest.languages[GameLocalization.locale].voices.values():
			if str(path).get_file() == filename: updated["voice_path"] = path; break
	data = updated
	if playing and data.has("voice_path"):
		voice_player.stream = load(data.voice_path)
		data["duration"] = maxf(float(data.duration),voice_player.stream.get_length())
		voice_player.play(minf(position,maxf(0,voice_player.stream.get_length()-.01)))
