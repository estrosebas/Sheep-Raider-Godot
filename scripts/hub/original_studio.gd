extends Node3D

const BASE = "res://assets/levels/scene"
@export var asset_directory = BASE
var player: RalphController
var texture_profile = 0
var help_visible = false
var entities: Array
var source: Dictionary
var panel: OriginalCinematicActor
var crowd: Array[OriginalCinematicActor] = []
var world_doors: Dictionary = {}
var returned_sheep: Dictionary = {}
var observed_progress: Dictionary = {}
var observed_unsaved = false

func _ready():
	var restored = SaveFiles.initialize_studio()
	player = $Player
	entities = JSON.parse_string(FileAccess.get_file_as_string(BASE+"/data/entities.json"))
	source = JSON.parse_string(FileAccess.get_file_as_string(BASE+"/data/studio.json"))
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(BASE+"/data/manifest.json"))
	for entry in entities:
		if int(entry.class_id) not in [148,155,169,170,195]: continue
		if int(entry.class_id) == 170:
			var identity = "lvl_%02d"%int(entry.props["0x4"])
			if not SaveFiles.scene_for_level(identity).is_empty():
				add_level_door(identity,entry)
				continue
		var actor = load(manifest.models[str(int(entry.model_res))].directory+"/worn.tscn").instantiate() as OriginalCinematicActor
		actor.name = "%s_%d"%[entry.class_name,int(entry.res)]
		add_child(actor)
		actor.position = GameSpace.from_export(Vector3(entry.pos[0],entry.pos[1],entry.pos[2]))
		actor.rotation = Vector3(entry.rot[0],-entry.rot[1],-entry.rot[2])*TAU/4096
		match int(entry.class_id):
			148:
				panel = actor
				for material in panel.legacy_skin.materials: material.shader = load("res://shaders/studio_counter.gdshader")
			155: actor.idle("stand")
			169: actor.sample_animation("close1",0); world_doors[str(int(entry.res))] = actor
			170: actor.sample_animation("close2",0)
			195:
				actor.idle("stand1" if randi_range(0,1)==0 else "stand2")
				actor.idle_time = randf()*float(actor.rig.animations[actor.idle_clip].duration)
				crowd.append(actor)
	# Native passage gates are independently removed with their world collider.
	OriginalSolidBuilder.build(self,BASE+"/data/solid_boxes.json",["DoorWorld"])
	for key in world_doors:
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(BASE+"/data/solid_boxes.json"))
		var row = rows.filter(func(value): return str(int(value.res))==key)[0]
		var root = OriginalSolidBuilder.build(self,"",[],[row])
		root.name = "GateCollision_"+key
		# World doors have two directional boxes; the source picks only one.
		var body = root.get_child(0)
		var chosen = 1 if absf(world_doors[key].rotation.y)>.01 else 0
		for i in range(body.get_child_count()): body.get_child(i).disabled = i != chosen
	add_level_door("lvl_00",{"res":0,"pos":[-8.5,.13,17.5],"rot":[0,0,0]})
	var portal = LabLevelDoor.new()
	portal.name = "LaboratoryDoor"; portal.level_label = GameLocalization.ui("Laboratorio")
	portal.level_scene = "res://scenes/testing/ItemLab.tscn"; portal.position = Vector3(8,.13,-13)
	add_child(portal)
	# The original studio has no top-left progress/action legend.
	player.get_node("ActionPrompt").hide()
	var door_status = preload("res://scripts/hub/studio_door_status.gd").new()
	door_status.name = "DoorStatus"; add_child(door_status)
	player.safe_position = player.global_position
	player.checkpoint_position = player.global_position
	var checkpoint = preload("res://scripts/hub/studio_checkpoint_save.gd").new()
	checkpoint.name = "CheckpointSave"; add_child(checkpoint)
	var pause = OriginalPauseMenu.new(); pause.name = "PauseMenu"; add_child(pause)
	var extras = preload("res://scripts/hub/studio_bonus_menu.gd").new(); extras.name = "Bonuses"; add_child(extras)
	for entry in extras.source.pedestals:
		var pedestal = preload("res://scripts/hub/studio_pedestal.gd").new()
		pedestal.definition = entry; pedestal.name = "%s_%d"%[entry.class_name,int(entry.res)]
		add_child(pedestal)
		pedestal.position = GameSpace.from_export(Vector3(entry.pos[0],entry.pos[1],entry.pos[2]))
		pedestal.rotation = Vector3(entry.rot[0],-entry.rot[1],-entry.rot[2])*TAU/4096
	$HUD.hide()
	var music: AudioStreamWAV = load("res://assets/audio/music/jungle_v1.wav").duplicate()
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD; music.loop_end = roundi(music.get_length()*music.mix_rate)
	$BGMPlayer.stream = music; $BGMPlayer.play()
	refresh_progress()
	# Keep the native arrival position, even for a save made while in a level.
	# A studio save may restore a safely grounded position inside this same map.
	if not restored.is_empty() and restored.level == "studio":
		var point = SaveFiles.to_vector(restored.checkpoint.position)
		var ray = PhysicsRayQueryParameters3D.create(point+Vector3.UP*1,point-Vector3.UP*3,1)
		ray.exclude = [player.get_rid()]
		var hit = get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			player.global_position = hit.position+Vector3.UP*.01
			player.skeleton.rotation.y = restored.checkpoint.facing
			player.camera_pivot.rotation = SaveFiles.to_vector(restored.checkpoint.camera)
	set_texture_profile(0)

func add_level_door(identity: String,entry: Dictionary):
	var door = LabLevelDoor.new()
	door.name = "LevelDoor_"+identity.trim_prefix("lvl_")
	door.level_scene = SaveFiles.scene_for_level(identity)
	door.level_label = GameLocalization.ui("Nivel %02d")%int(identity.trim_prefix("lvl_"))
	door.resume_saved_checkpoint = true
	door.sequential_progress = true
	add_child(door)
	door.position = GameSpace.from_export(Vector3(entry.pos[0],entry.pos[1],entry.pos[2]))
	door.rotation.y = -float(entry.rot[1])*TAU/4096

func refresh_progress():
	observed_progress = OriginalProgress.completed_levels.duplicate()
	observed_unsaved = OriginalProgress.completion_unsaved or OriginalProgress.timekeeper_unsaved
	panel.idle_clip = ""
	panel.sample_animation(source.counter_animation_ids[str(OriginalProgress.remaining_sheep_count())],0)
	var index = 0
	for number in range(OriginalProgress.TOTAL_SHEEP):
		var identity = "lvl_%02d"%number
		if not OriginalProgress.is_completed(identity):
			if returned_sheep.has(identity): returned_sheep[identity].queue_free(); returned_sheep.erase(identity)
			continue
		if not returned_sheep.has(identity):
			var sheep = load(BASE+"/models/4/worn.tscn").instantiate() as OriginalCinematicActor
			sheep.name = "ReturnedSheep_%02d"%number; sheep.set_meta("source_level",identity)
			add_child(sheep); returned_sheep[identity] = sheep
			sheep.idle("stand3"); sheep.idle_speed = randf_range(.75,1.25)
			sheep.idle_time = randf()*float(sheep.rig.animations.stand3.duration)
		var sheep: OriginalCinematicActor = returned_sheep[identity]
		# Keep the recovered flock inside the native counter's collection pen,
		# leaving Ralph's arrival spot and Lucas unobstructed.
		var pen = source.sheep_collection_box
		sheep.position = Vector3(float(pen.min[0])*.01+.8+(index%4)*1.4,0,-float(pen.max[2])*.01+.6+int(index/4)*1.0)
		sheep.rotation.y = -1308*TAU/4096
		index += 1
	for key in world_doors:
		var opened = OriginalProgress.is_completed(source.world_door_levels[key])
		world_doors[key].visible = not opened
		var body = get_node("GateCollision_"+key).get_child(0)
		var chosen = 1 if absf(world_doors[key].rotation.y)>.01 else 0
		for i in range(body.get_child_count()): body.get_child(i).set_deferred("disabled",opened or i!=chosen)
	get_node("CheckpointSave").capture_checkpoint()

func reload_localization():
	refresh_progress()
	get_node("LaboratoryDoor").level_label = GameLocalization.ui("Laboratorio")
	for i in range(18):
		var door = get_node_or_null("LevelDoor_%02d"%i)
		if not door: continue
		door.level_label = GameLocalization.ui("Nivel %02d")%i

func _process(delta):
	if observed_progress != OriginalProgress.completed_levels or observed_unsaved != (OriginalProgress.completion_unsaved or OriginalProgress.timekeeper_unsaved): refresh_progress()

func set_texture_profile(value: int):
	texture_profile = clampi(value,0,1)
	for node in find_children("*","MeshInstance3D",true,false):
		if not node.mesh: continue
		for i in range(node.mesh.get_surface_count()):
			var material = node.mesh.surface_get_material(i)
			if material is ShaderMaterial: material.set_shader_parameter("use_linear_filter",texture_profile==1)

func _unhandled_input(event):
	if event.is_action_pressed("item_lab") and not event.is_echo(): get_tree().change_scene_to_file("res://scenes/testing/ItemLab.tscn")
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_H:
		help_visible = not help_visible; $HUD.visible = help_visible
		player.inventory.wheel.set_help_visible(help_visible)
