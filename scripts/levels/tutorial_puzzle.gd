extends Node3D
class_name TutorialPuzzle

var data: Dictionary
var player: RalphController
var seesaws: Array = []
var rocks: Array = []
var button: OriginalCinematicActor
var gate: OriginalCinematicActor
var gate_body: StaticBody3D
var gate_shape: CollisionShape3D
var button_definition: Dictionary
var gate_definition: Dictionary
var pressed = false
var gate_open = false
var gate_time = 0.0
var gate_clip = "closed"
var gate_previous_time = -0.001
var sound: AudioStreamPlayer3D
var wolf_arc: Dictionary = {}
var launch_camera: Camera3D
var saved_camera: Camera3D
var was_locked = false

func _ready() -> void:
	process_physics_priority = -50
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_00/puzzle/definitions.json"))
	player = get_parent().get_node("Player")
	for definition in data["objects"]:
		if definition["class_name"] not in ["seesaw","Rock","SensibleButton","FallingGate"]: continue
		var node: Node3D
		match definition["class_name"]:
			"seesaw":
				node = OriginalSeesaw.new()
				node.definition = definition
				seesaws.append(node)
			"Rock":
				node = OriginalRock.new()
				node.definition = definition
				rocks.append(node)
			_:
				node = load(definition["directory"]+"/worn.tscn").instantiate()
				if definition["class_name"] == "SensibleButton":
					button = node
					button_definition = definition
				else:
					gate = node
					gate_definition = definition
		node.name = "%s_%d" % [definition["class_name"],int(definition["res"])]
		node.position = GameSpace.from_export(Vector3(definition["pos"][0],definition["pos"][1],definition["pos"][2]))
		if definition["class_name"] == "FallingGate": node.rotation.y = deg_to_rad(float(definition["rot_deg"][1]))
		add_child(node)
	button.sample_animation("off",0)
	gate.sample_animation("closed",0)
	gate_body = StaticBody3D.new()
	gate_body.name = "GateCollision"
	gate_body.position = gate.position
	add_child(gate_body)
	var box = gate_definition["boxes"][0]
	var lo = OriginalSeesaw.source_point([box["min"][0],box["max"][1],box["max"][2]])
	var hi = OriginalSeesaw.source_point([box["max"][0],box["min"][1],box["min"][2]])
	gate_shape = CollisionShape3D.new()
	gate_shape.position = (lo+hi)/2
	var shape = BoxShape3D.new()
	shape.size = hi-lo
	gate_shape.shape = shape
	gate_body.add_child(gate_shape)
	gate_body.set_meta("original_class","FallingGate")
	gate_body.set_meta("original_solid_top",hi.y)
	sound = AudioStreamPlayer3D.new()
	add_child(sound)
	launch_camera = Camera3D.new()
	add_child(launch_camera)
	player.respawned.connect(_respawn)

func player_launching() -> bool:
	return not wolf_arc.is_empty()

func launch(actor: Node3D,points: Array) -> void:
	if actor is OriginalRock:
		actor.launch(points)
	elif actor == player and wolf_arc.is_empty():
		was_locked = player.tutorial_movement_locked
		player.interrupt_actions()
		player.tutorial_movement_locked = true
		player.play_anim("jump")
		wolf_arc = {"time":0.0,"start":player.global_position,"middle":OriginalSeesaw.source_point(points[1]),"end":OriginalSeesaw.source_point(points[2])}
		for seesaw in seesaws:
			for side in range(2):
				if seesaw.definition["trajectories"][side] == points and seesaw.definition["cameras"][side] != null:
					_start_camera(seesaw.definition["cameras"][side])

func _start_camera(record: Dictionary) -> void:
	saved_camera = get_viewport().get_camera_3d()
	launch_camera.global_position = OriginalSeesaw.source_point(record["eye"])
	var r = record["rotation"]
	launch_camera.rotation = Vector3(-r[0],r[1],-r[2])*TAU/4096
	launch_camera.fov = rad_to_deg(2*atan(384.0/float(record["focal"])))
	launch_camera.current = true

func _physics_process(delta: float) -> void:
	var director = get_parent().get_node_or_null("TutorialIntro")
	if director and director.playing: return
	if player_launching():
		wolf_arc["time"] = minf(float(wolf_arc["time"])+delta/1.024,1)
		var target = OriginalSeesaw.arc_point(wolf_arc["start"],wolf_arc["middle"],wolf_arc["end"],wolf_arc["time"])
		var motion = target-player.global_position
		var contact = player.move_and_collide(motion)
		player.velocity = Vector3.ZERO
		# Source launches resolve collisions along the arc: the landing platform
		# can intercept the descending path BEFORE the authored endpoint.
		var intercepted = contact != null and wolf_arc["time"] > .1 and (motion.y < 0 or absf(contact.get_normal().y) < .5)
		if wolf_arc["time"] >= 1 or intercepted:
			wolf_arc.clear()
			player.tutorial_movement_locked = was_locked
			player.set_state(player.WolfState.FALL)
			if is_instance_valid(saved_camera): saved_camera.current = true
			saved_camera = null
	for rock in rocks: rock.step(delta)
	for seesaw in seesaws: seesaw.step(delta,player,rocks,self)
	_update_button()
	_update_gate(delta)

func _update_button() -> void:
	var box = button_definition["boxes"][0]
	var lo = OriginalSeesaw.source_point([box["min"][0],box["max"][1],box["max"][2]])+button.global_position
	var hi = OriginalSeesaw.source_point([box["max"][0],box["min"][1],box["min"][2]])+button.global_position
	var occupied = false
	for actor in [player]+rocks:
		var extent = actor.half_size if actor is OriginalRock else Vector3(.3,.8,.3)
		var p = actor.global_position+(actor.local_center if actor is OriginalRock else Vector3.UP*.8)
		if p.x+extent.x >= lo.x and p.x-extent.x <= hi.x and p.y+extent.y >= lo.y and p.y-extent.y <= hi.y and p.z+extent.z >= lo.z and p.z-extent.z <= hi.z:
			occupied = true
	if occupied != pressed:
		pressed = occupied
		button.sample_animation("on" if pressed else "off",0)
		sound.global_position = button.global_position
		sound.stream = load(data["sounds"]["54"])
		sound.play()
		gate_open = pressed
		if not button_definition["target_resources"].any(func(resource): return int(resource) == int(gate_definition["res"])): return
		gate_clip = "mv_open" if gate_open else "mv_close"
		gate_time = 0
		gate_previous_time = -.001
		gate.show()
		# Opening releases collision at the end; closing restores it immediately.
		if not gate_open: gate_shape.set_deferred("disabled",false)

func _update_gate(delta: float) -> void:
	gate_time += delta
	gate.sample_animation(gate_clip,gate_time)
	for cue in gate.rig["animations"][gate_clip]["sound_cues"]:
		if cue["time"] > gate_previous_time and cue["time"] <= gate_time:
			var s = AudioStreamPlayer3D.new()
			add_child(s)
			s.global_position = gate.global_position
			s.stream = load(data["sounds"][str(int(cue["sound_id"]))])
			s.finished.connect(s.queue_free)
			s.play()
	gate_previous_time = gate_time
	if gate_clip.begins_with("mv_") and gate_time >= float(gate.rig["animations"][gate_clip]["duration"]):
		gate_shape.set_deferred("disabled",gate_open)
		gate.visible = not gate_open
		gate_clip = "open" if gate_open else "closed"
		gate_time = 0
		gate_previous_time = -.001

func _respawn() -> void:
	if player_launching(): player.tutorial_movement_locked = was_locked
	wolf_arc.clear()
	if is_instance_valid(saved_camera): saved_camera.current = true
	saved_camera = null
	for rock in rocks:
		if rock.reset_on_death: rock.reset_rock()
