extends StaticBody3D
# TriggedStone class52: native TIMER, FALL1/EXPLOD1 and world CRASHINGZONE.
enum State { REST, ARMED, FALL, SETTLE }
var definition: Dictionary
var sounds: Dictionary = {}
var visual: OriginalCinematicActor
var player: RalphController
var state = State.REST
var timer = 0.0
var triggered = false
var clip = "stand1"
var previous_time = -.001
var camera_shot: Node3D
var audio: AudioStreamPlayer3D
var shapes: Array[CollisionShape3D] = []
var victims: Dictionary = {}

func _ready():
	player = get_parent().get_node("Player")
	visual = load(definition.directory+"/worn.tscn").instantiate()
	add_child(visual)
	# This native mesh has separate, reverse-wound fracture interiors at the
	# exact same positions as its exterior. Two-sided drawing hides the rock
	# texture behind the dark interior polygons (60 overlapping pairs in04).
	for material in visual.legacy_skin.materials:
		if material.shader.resource_path=="res://shaders/retro_opaque.gdshader":
			material.shader = preload("res://shaders/retro_opaque_single_sided.gdshader")
	visual.sample_animation("stand1",0)
	update_visual_bounds()
	for box in definition.get("boxes",[]):
		if int(box.flags)&1: continue
		var lo = GameSpace.original_point(Vector3(box.min[0],box.max[1],box.max[2]))
		var hi = GameSpace.original_point(Vector3(box.max[0],box.min[1],box.min[2]))
		var shape = BoxShape3D.new(); shape.size = hi-lo
		var collision = CollisionShape3D.new(); collision.shape = shape; collision.position = (lo+hi)/2
		add_child(collision); shapes.append(collision)
	audio = AudioStreamPlayer3D.new(); add_child(audio); audio.max_distance = 60
	player.respawned.connect(reset_to_home)
	add_to_group("triggered_stones")

func set_switch(sender: Node,on: bool):
	if not on:
		triggered = false
		close_camera()
		return
	if state != State.REST or triggered: return
	triggered = true; state = State.ARMED; timer = 0
	var occupants: Array = sender.get("occupants") if sender.get("occupants") is Array else []
	if occupants.has(player) and definition.get("camera") is Dictionary:
		camera_shot = preload("res://scripts/cinematics/original_launch_camera.gd").new()
		camera_shot.definition = definition.camera; camera_shot.player = player; camera_shot.no_freeze = true
		add_child(camera_shot)

func start_clip(next: String,next_state: State):
	clip = next; state = next_state; timer = 0; previous_time = -.001
	visual.sample_animation(clip,0)
	update_visual_bounds()

func _physics_process(delta: float):
	if state == State.REST: return
	timer += delta
	if state == State.ARMED:
		if timer > float(definition.trigger_delay_ms)*.001:
			victims.clear()
			for shape in shapes: shape.set_deferred("disabled",true)
			start_clip("fall1",State.FALL)
		return
	visual.sample_animation(clip,timer)
	update_visual_bounds()
	for cue in visual.rig.animations[clip].get("sound_cues",[]):
		var identity = str(int(cue.sound_id))
		if float(cue.time)>previous_time and float(cue.time)<=timer and sounds.has(identity):
			audio.stream = load(sounds[identity]); audio.play()
	previous_time = timer
	var duration = float(visual.rig.animations[clip].duration)
	if state == State.FALL and timer > duration*float(definition.crush_fraction): crush_victims()
	if timer < duration: return
	if state == State.FALL: start_clip("explod1",State.SETTLE)
	elif state == State.SETTLE:
		close_camera()
		start_clip("stand1",State.REST)
		for shape in shapes: shape.set_deferred("disabled",false)

func crush_victims():
	var candidates: Array = [player]
	candidates.append_array(get_tree().get_nodes_in_group("sam_guards"))
	candidates.append_array(get_tree().get_nodes_in_group("sheep_targets"))
	for actor in candidates:
		if not is_instance_valid(actor) or actor.get_parent()!=get_parent(): continue
		# Native CrushVictims refreshes Sam's KnockOut on every crushing frame
		# until FALL1 finishes. Ralph/sheep use idempotent death handlers.
		if victims.has(actor.get_instance_id()) and not actor is OriginalSam: continue
		if not OriginalSam.contains(actor.global_position,definition.crush_zones): continue
		victims[actor.get_instance_id()] = true
		if actor is RalphController: actor.on_rock_crush(self)
		elif actor is OriginalSheep: actor.lose("crush")
		elif actor is OriginalSam: actor.on_rock_crush(self)

func bottom() -> float:
	# Ralph's shared squash state snaps beneath its killer; this stone's
	# animated mesh rolls to the authored world zone, away from its origin.
	return -float(definition.crush_zones[0].max[1])*.01 if not definition.crush_zones.is_empty() else global_position.y

func update_visual_bounds():
	# Shader skinning moves the falling stone/fragments beyond the generic
	# +/-4m box. Bound the actual current pose, retaining all native geometry
	# and preventing camera culling at impact or while EXPLOD1 scatters it.
	var palette: Array[Transform3D] = []
	var skin = visual.legacy_skin
	for bone in range(skin.last_matrices.size()):
		palette.append(skin.last_matrices[bone]*skin.inverse_rests[bone])
	var bounds = AABB(); var first = true
	for surface in visual.rig.surfaces.values():
		for i in range(surface.verts.size()):
			var v = surface.verts[i]
			var point: Vector3 = palette[int(surface.bones[i])]*Vector3(v[0],v[1],v[2])
			if first: bounds = AABB(point,Vector3.ZERO); first = false
			else: bounds = bounds.expand(point)
	visual.skeleton.get_node("Visual").custom_aabb = bounds.grow(.02)

func close_camera():
	if is_instance_valid(camera_shot): camera_shot.close()
	camera_shot = null

func reset_to_home():
	close_camera(); triggered = false; victims.clear(); audio.stop()
	start_clip("stand1",State.REST)
	for shape in shapes: shape.set_deferred("disabled",false)
