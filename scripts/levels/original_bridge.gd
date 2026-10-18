extends Node3D
class_name OriginalBridge
var definition: Dictionary
@export var asset_directory = "res://assets/levels/lvl_01/models/10"
@export var audio_bank_path = "res://assets/levels/lvl_01/data/ai_audio.json"
var player: RalphController
var visual: OriginalCinematicActor
var state = "idle"
var elapsed = 0.0
var loops = 0
var frozen = false
var collider: CollisionShape3D
var peer: OriginalBridge
var sounds: Dictionary
var audio: AudioStreamPlayer3D
var camera: Camera3D
var saved_camera = Transform3D.IDENTITY
var saved_top_level = false
var last_cue_time = -.001
func _ready():
	add_to_group("original_bridges")
	player = get_parent().get_node("Player")
	visual = load(asset_directory+"/worn.tscn").instantiate()
	add_child(visual)
	var body = StaticBody3D.new()
	add_child(body)
	collider = CollisionShape3D.new()
	body.add_child(collider)
	sounds = JSON.parse_string(FileAccess.get_file_as_string(audio_bank_path))
	audio = AudioStreamPlayer3D.new()
	audio.max_distance = 30
	add_child(audio)
	player.respawned.connect(reset)
	reset()
	call_deferred("_find_peer")
func _find_peer():
	for bridge in get_tree().get_nodes_in_group("original_bridges"):
		if bridge != self and bridge.get_parent() == get_parent(): peer = bridge
func occupants() -> Array:
	var result: Array = []
	if OriginalSam.contains(player.global_position,definition.fall_zone): result.append(player)
	for sheep in get_tree().get_nodes_in_group("sheep_targets"):
		if sheep is OriginalSheep and not sheep.dead and sheep.get_world_3d() == get_world_3d() and OriginalSam.contains(sheep.goal_position(),definition.fall_zone): result.append(sheep)
	return result
func reset():
	_release()
	state = "idle"
	loops = 0
	elapsed = 0
	last_cue_time = -.001
	visual.sample_animation("pose1",0)
	collider.set_deferred("disabled",false)
	_update_collision()
func _release():
	if frozen:
		player.tutorial_movement_locked = false
		frozen = false
	if is_instance_valid(camera):
		camera.top_level = saved_top_level
		camera.transform = saved_camera
		camera = null
func _update_collision():
	var vertices = PackedVector3Array()
	for surface in visual.rig.surfaces.values():
		for i in range(surface.verts.size()):
			var v = surface.verts[i]
			var joint = int(surface.bones[i])
			vertices.append(visual.legacy_skin.last_matrices[joint]*visual.legacy_skin.inverse_rests[joint]*Vector3(v[0],v[1],v[2]))
	var shape = ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(vertices)
	collider.shape = shape
func _freeze(objects: Array):
	player.interrupt_actions()
	player.tutorial_movement_locked = true
	frozen = true
	var sheep: OriginalSheep
	for object in objects:
		if object is OriginalSheep: sheep = object
	if not sheep: return
	var distance = player.global_position.distance_to(sheep.goal_position())
	if distance <= 3: return
	camera = player.camera
	saved_top_level = camera.top_level
	saved_camera = camera.transform
	var midpoint = (player.global_position+sheep.goal_position())/2
	camera.top_level = true
	camera.global_position = midpoint+global_basis.x*maxf(6,distance)+Vector3.UP
	camera.look_at(midpoint)
func collapse():
	var objects = occupants()
	_release()
	for bridge in [self,peer]:
		if not is_instance_valid(bridge): continue
		bridge.state = "breaking"
		bridge.elapsed = 0
		bridge.last_cue_time = -.001
		bridge.collider.set_deferred("disabled",true)
	for object in objects:
		if object is OriginalSheep: object.lose("fall")
	if objects.has(player):
		player.tutorial_movement_locked = false
		player.set_state(player.WolfState.PIT_FALL)
func _physics_process(delta):
	if not definition.master: return
	if player.cinematic_controls_locked or player.restart_fade_remaining > 0: return
	var objects = occupants()
	if state in ["idle","creak"]:
		if objects.size() < 2:
			if state == "creak":
				_release()
				state = "idle"
				loops = 0
				visual.sample_animation("pose1",0)
				peer.visual.sample_animation("pose1",0)
				_update_collision()
				peer._update_collision()
			return
		if state == "idle":
			state = "creak"
			elapsed = 0
			last_cue_time = -.001
	var clip = "pose2" if state == "creak" else ("brake2" if state == "breaking" else "fbrake2")
	if state == "idle": return
	elapsed += delta
	for cue in visual.rig.animations[clip].sound_cues:
		if cue.time > last_cue_time and cue.time <= elapsed and sounds.has(str(int(cue.sound_id))):
			audio.stream = load(sounds[str(int(cue.sound_id))])
			audio.play()
	last_cue_time = elapsed
	visual.sample_animation(clip,elapsed)
	if peer: peer.visual.sample_animation(clip,elapsed)
	if state == "creak":
		_update_collision()
		if peer: peer._update_collision()
	if elapsed >= float(visual.rig.animations[clip].duration):
		if state == "creak":
			if loops == 6: _freeze(objects)
			if loops == 12: collapse()
			else: loops += 1
		elif state == "breaking":
			state = "broken"
			if peer: peer.state = "broken"
		elapsed = 0
		last_cue_time = -.001
