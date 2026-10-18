extends Node3D

@onready var col_shape_node: CollisionShape3D = $Collision/CollisionShape3D
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var info_label: Label = $HUD/MarginContainer/VBoxContainer/InfoLabel
@onready var coords_label: Label = $HUD/MarginContainer/VBoxContainer/CoordsLabel
@onready var player: CharacterBody3D = $Player
@onready var scenery_node: MeshInstance3D = $Scenery

var entities_data: Array = []
var help_visible = false
const Catalog = preload("res://scripts/items/item_catalog.gd")
const Space = preload("res://scripts/levels/game_space.gd")
const Solids = preload("res://scripts/levels/original_solid_builder.gd")
const Intro = preload("res://scripts/cinematics/original_sequence.gd")
const CameraTraining = preload("res://scripts/cinematics/camera_training.gd")
const Progress = preload("res://scripts/levels/tutorial_progress.gd")

# Repository viewer uses nearest; original PC page flags request linear.
@export_enum("Visor del repositorio (Nearest)", "PC original (Linear)") var texture_profile: int = 0

func _ready() -> void:
	$HUD.hide()
	player.inventory.allow_world_placement = false
	# 1. Build Trimesh Collision directly from collision.obj
	var col_mesh = load("res://assets/levels/lvl_00/collision.obj")
	if col_mesh and col_shape_node:
		var shape = Space.mesh_from_export(col_mesh).create_trimesh_shape()
		col_shape_node.shape = shape
		print("[Level00] Static trimesh collision successfully initialized!")

	# 3. Play Background Music
	if bgm_player and not bgm_player.playing:
		# Original WAV has no loop marker; continue across both cinematics/voices.
		if bgm_player.stream is AudioStreamWAV:
			var music: AudioStreamWAV = bgm_player.stream.duplicate()
			music.loop_mode = AudioStreamWAV.LOOP_FORWARD
			music.loop_begin = 0
			music.loop_end = roundi(music.get_length()*music.mix_rate)
			bgm_player.stream = music
		bgm_player.play()

	# 4. Load Scenaric Entities info
	load_entities()
	var sky = preload("res://scripts/levels/original_sky.gd").new()
	sky.name = "OriginalSky"
	add_child(sky)
	var signs = preload("res://scripts/levels/original_signposts.gd").new()
	signs.name = "Signposts"
	add_child(signs)
	Solids.build(self,"res://assets/levels/lvl_00/data/solid_boxes.json",["Rock","seesaw","SensibleButton","FallingGate","Mailbox"])
	var puzzle = preload("res://scripts/levels/tutorial_puzzle.gd").new()
	puzzle.name = "TutorialPuzzle"
	add_child(puzzle)
	var progress = Progress.new()
	progress.name = "TutorialProgress"
	add_child(progress)
	# Match the source camera after the missing Z conversion is restored.
	player.camera_pivot.rotation.y = PI
	spawn_inventory_pickups()
	spawn_mailboxes()
	var finish = preload("res://scripts/levels/tutorial_finish.gd").new()
	finish.name = "TutorialFinish"
	add_child(finish)
	set_texture_profile(texture_profile)
	var intro = Intro.new()
	intro.name = "TutorialIntro"
	add_child(intro)
	intro.bind_player(player)
	var training = CameraTraining.new()
	training.name = "CameraTraining"
	add_child(training)
	var runner = OriginalRoadrunner.new()
	runner.name = "RoadrunnerRace"
	runner.player = player
	runner.definition = training.data["roadrunner"]
	add_child(runner)
	var saves = LevelCheckpointSave.new()
	saves.name = "CheckpointSave"
	add_child(saves)
	var pause_menu = OriginalPauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)

func spawn_inventory_pickups() -> void:
	# Per-level data defines available objects; no starter inventory is invented.
	for entity in entities_data:
		if int(entity["class_id"]) != 10:
			continue
		var pickup = Catalog.create_item(10, "lvl_00:%d" % int(entity["res"]))
		pickup.name = "Rocket_%d" % int(entity["res"])
		pickup.item_id = "lvl_00:%d" % int(entity["res"])
		pickup.class_id = int(entity["class_id"])
		pickup.item_label = "Cohete"
		pickup.preserve_source_pivot = true
		var pos = entity["pos"]
		pickup.position = Space.from_export(Vector3(pos[0], pos[1], pos[2]))
		# Shared RocketItem; the level changes only placement and designer properties.
		pickup.fuel_seconds = float(entity["props"]["0x0"])
		pickup.durability = float(entity["props"]["0x8"]) * 2.0 / 100.0
		add_child(pickup)

func spawn_mailboxes() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_00/puzzle/definitions.json"))
	var box_definition: Dictionary
	for definition in data["objects"]:
		if definition["class_name"] == "DeliveryBox": box_definition = definition
	for definition in data["objects"]:
		if definition["class_name"] != "Mailbox": continue
		var mailbox = preload("res://scripts/items/original_mailbox.gd").new()
		mailbox.name = "Mailbox_%d" % int(definition["res"])
		mailbox.definition = definition
		mailbox.box_definition = box_definition
		mailbox.sounds = data["sounds"]
		mailbox.position = Space.from_export(Vector3(definition["pos"][0],definition["pos"][1],definition["pos"][2]))
		mailbox.rotation.y = deg_to_rad(float(definition["rot_deg"][1]))
		for resource in definition["item_resources"]:
			var item = get_node_or_null("Rocket_%d" % int(resource))
			if item: mailbox.items.append(item)
		add_child(mailbox)
		player.respawned.connect(mailbox.rollback)
		get_node("TutorialProgress").checkpoint_reached.connect(func(_index): mailbox.commit())

func set_texture_profile(profile: int) -> void:
	texture_profile = clampi(profile, 0, 1)
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = node.mesh
		if mesh == null:
			continue
		for surface in range(mesh.get_surface_count()):
			var material = mesh.surface_get_material(surface)
			if material is ShaderMaterial:
				material.set_shader_parameter("use_linear_filter", texture_profile == 1)
	var profile_name = "PC original / Linear" if texture_profile == 1 else "Visor del repositorio / Nearest"
	info_label.text = "Nivel 0: Tutorial | Texturas: %s | F6: cambiar" % profile_name
	print("[Level00] Texture profile: ", profile_name)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("item_lab"):
		SaveFiles.remember_level_exit(self)
		get_tree().change_scene_to_file("res://scenes/testing/ItemLab.tscn")
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		set_texture_profile(1 - texture_profile)

func load_entities() -> void:
	var path = "res://assets/levels/lvl_00/data/entities.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json_text = file.get_as_text()
		var json = JSON.new()
		if json.parse(json_text) == OK:
			entities_data = json.data
			print("[Level00] Loaded ", entities_data.size(), " entities from entities.json")

func _process(_delta: float) -> void:
	if player and coords_label:
		var p = player.global_position
		coords_label.text = "Posición: X: %.2f | Y: %.2f | Z: %.2f | Velocidad: %.1f m/s" % [p.x, p.y, p.z, player.velocity.length()]
