extends Node3D
class_name ImportedLevel
const LOGIC_CLASSES = [19,25,32,70,74,106,137,176,184]

@export var asset_directory = "res://assets/levels/lvl_01"
@export var foundation_mode = false
var manifest: Dictionary
var entities: Array
var texture_profile = 0
var help_visible = false
@onready var player: RalphController = $Player

func _ready() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string(asset_directory+"/data/manifest.json"))
	entities = JSON.parse_string(FileAccess.get_file_as_string(asset_directory+"/data/entities.json"))
	# Persist terrain in the scene so the editor can display it without running
	# the gameplay importer. Other imported scenes can still create it on load.
	var scenery = get_node_or_null("Scenery") as MeshInstance3D
	if scenery == null:
		scenery = MeshInstance3D.new()
		scenery.name = "Scenery"
		scenery.mesh = load(asset_directory+"/scenery.tres")
		add_child(scenery)
	var sky = preload("res://scripts/levels/original_sky.gd").new()
	sky.mesh_path = asset_directory+"/sky.tres"
	sky.name = "OriginalSky"
	add_child(sky)
	if foundation_mode:
		preload("res://scripts/levels/imported_level_foundation.gd").new().setup(self)
		return
	OriginalSolidBuilder.build(self,asset_directory+"/data/solid_boxes.json",["Mailbox","Rocks","Telescope","SignPostSimple","Salad","bridge","TimeKeeper"])
	var mechanics = JSON.parse_string(FileAccess.get_file_as_string(asset_directory+"/data/mechanics.json"))
	var notes = GameLocalization.load_data(asset_directory+"/data/notes.json")
	var solids = JSON.parse_string(FileAccess.get_file_as_string(asset_directory+"/data/solid_boxes.json"))
	var delivered: Dictionary = {}
	for entity in entities:
		var definition = manifest["models"].get(str(int(entity["model_res"])))
		var kind = int(entity["class_id"])
		# Goal::PostLoadInit hides its trigger model; it was a floating white blob.
		if definition == null or kind in LOGIC_CLASSES or kind in [0,4,23,160]: continue # Logical managers have no world rendering; Bird starts hidden.
		var actor: Node3D
		match kind:
			6:
				actor = OriginalBridge.new()
				actor.asset_directory = definition.directory
				actor.audio_bank_path = asset_directory+"/data/ai_audio.json"
				for bridge in JSON.parse_string(FileAccess.get_file_as_string(asset_directory+"/data/bridges.json")):
					if int(bridge.res) == int(entity.res): actor.definition = bridge
			11:
				actor = OriginalSheep.new()
				actor.definition = entity
				actor.visual_scene = definition["directory"]+"/worn.tscn"
				actor.idle_animation = "stand3"
			1:
				actor = OriginalSam.new()
				actor.definition = entity
				actor.visual_scene = definition["directory"]+"/worn.tscn"
				actor.idle = "head2"
			2,3:
				actor = ItemCatalog.create_item(kind,"lvl_01:%d" % int(entity["res"]))
				actor.preserve_source_pivot = true
				if kind == 3: actor.original_scene = definition["directory"]+"/worn.tscn"
				if kind == 2: actor.fuse_seconds = float(entity["props"]["0x0"])*.001
				delivered[int(entity["res"])] = actor
			78:
				actor = OriginalWorldNote.new()
				actor.visual_scene = definition["directory"]+"/worn.tscn"
				actor.text = str(notes[str(int(entity["res"]))])
				delivered[int(entity["res"])] = actor
			13:
				actor = OriginalBreakableRocks.new()
				for box in solids:
					if int(box["res"]) == int(entity["res"]): actor.definition = box
			38:
				actor = OriginalTimeKeeper.new()
				actor.asset_directory = definition["directory"]
				actor.level_id = manifest["level"]
				actor.sound_bank_path = asset_directory+"/data/ai_audio.json"
			28:
				actor = OriginalTelescope.new()
				actor.definition = mechanics["telescope"]
			_:
				actor = load(definition["directory"]+"/worn.tscn").instantiate()
		actor.name = "%s_%d" % [entity["class_name"],int(entity["res"])]
		actor.set_meta("original_resource",int(entity["res"]))
		actor.set_meta("original_class",entity["class_name"])
		add_child(actor)
		var p = entity["pos"]
		actor.global_position = GameSpace.from_export(Vector3(p[0],p[1],p[2]))
		var r = entity["rot"]
		actor.rotation = Vector3(float(r[0]),-float(r[1]),-float(r[2]))*TAU/4096.0
		if actor is GameItem:
			actor.home_position = actor.global_position
		if actor is OriginalSheep: player.respawned.connect(actor.reset_to_home)
		if actor is OriginalCinematicActor:
			var idle: String = definition["idle"]
			if idle.begins_with("stand") or idle == "default": actor.idle(idle)
			elif not idle.is_empty(): actor.sample_animation(idle,0)
			if kind == 38:
				actor.idle("clock1") # TimeKeeper::TK_AVAILABLE, not collected CLOCK3.
				call_deferred("_snap_preview_to_ground",actor)
	var mailbox = OriginalMailbox.new()
	mailbox.name = "Mailbox_61"
	mailbox.definition = mechanics["mailbox"]
	mailbox.box_definition = mechanics["box"]
	mailbox.sounds = mechanics["sounds"]
	var mail_position = mechanics["mailbox"]["pos"]
	mailbox.position = GameSpace.from_export(Vector3(mail_position[0],mail_position[1],mail_position[2]))
	for resource in mechanics["mailbox"]["item_resources"]:
		if delivered.has(int(resource)): mailbox.items.append(delivered[int(resource)])
	add_child(mailbox)
	player.respawned.connect(mailbox.rollback)
	var p = manifest["spawn"]["pos"]
	player.global_position = GameSpace.from_export(Vector3(p[0],p[1],p[2]))
	player.skeleton.rotation.y = -float(manifest["spawn"]["rot"][1])*TAU/4096
	player.camera_pivot.rotation.y = PI
	player.safe_position = player.global_position
	var fall_zones_path = asset_directory+"/data/fall_zones.json"
	if FileAccess.file_exists(fall_zones_path):
		for definition in JSON.parse_string(FileAccess.get_file_as_string(fall_zones_path)):
			var zone = OriginalFallZone.new()
			zone.name = definition["name"]
			zone.player = player
			zone.minimum = Vector2(definition["min_xz"][0],definition["min_xz"][1])
			zone.maximum = Vector2(definition["max_xz"][0],definition["max_xz"][1])
			zone.fall_height = float(definition["fall_height"])
			zone.use_jump_reach = bool(definition.get("use_jump_reach",false))
			zone.minimum_origin_y = float(definition.get("minimum_origin_y",0))
			add_child(zone)
	$HUD.hide()
	set_texture_profile(0)
	var scrolling = OriginalTextureScroll.new()
	scrolling.name = "TextureScroll"
	add_child(scrolling)
	var menu = OriginalPauseMenu.new()
	menu.name = "PauseMenu"
	add_child(menu)
	var flock = OriginalFlock.new()
	flock.name = "Flock"
	add_child(flock)
	var checkpoints = OriginalCheckpointManager.new()
	checkpoints.name = "Checkpoints"
	add_child(checkpoints)
	var daffy_lessons = OriginalLevel01Daffy.new()
	daffy_lessons.name = "DaffyLessons"
	add_child(daffy_lessons)
	var porky_lessons = OriginalLevel01Porky.new()
	porky_lessons.name = "PorkyLessons"
	add_child(porky_lessons)
	var checkpoint_save = ImportedCheckpointSave.new()
	checkpoint_save.name = "CheckpointSave"
	add_child(checkpoint_save)
	for definition in JSON.parse_string(FileAccess.get_file_as_string(asset_directory+"/data/goals.json")):
		var goal = OriginalLevelGoal.new()
		goal.name = "Goal_%d"%int(definition.res)
		goal.definition = definition
		goal.level_id = str(manifest.level)
		add_child(goal)
	var music: AudioStreamWAV = load("res://assets/audio/music/trip_v1.wav").duplicate()
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.loop_begin = 0
	music.loop_end = roundi(music.get_length()*music.mix_rate)
	$BGMPlayer.stream = music
	$BGMPlayer.volume_db = -12
	$BGMPlayer.play()
	print("[",manifest["level"],"] Original scenery / ",entities.size()," objects / ",manifest["collision_triangles"]," collision triangles")

func set_texture_profile(profile: int) -> void:
	texture_profile = clampi(profile,0,1)
	for node in find_children("*","MeshInstance3D",true,false):
		if node.mesh == null: continue
		for i in range(node.mesh.get_surface_count()):
			var material = node.mesh.surface_get_material(i)
			if material is ShaderMaterial: material.set_shader_parameter("use_linear_filter",texture_profile == 1)

func _snap_preview_to_ground(actor: Node3D) -> void:
	var query = PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*3,actor.global_position-Vector3.UP*30)
	var exclusions: Array[RID] = [player.get_rid()]
	for npc in get_tree().get_nodes_in_group("grounded_npcs"): exclusions.append(npc.get_rid())
	query.exclude = exclusions
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): actor.global_position.y = hit["position"].y

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_H:
			help_visible = not help_visible
			$HUD.visible = help_visible
			player.inventory.wheel.set_help_visible(help_visible)
		elif event.physical_keycode == KEY_F6: set_texture_profile(1-texture_profile)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("item_lab") and not event.is_echo():
		SaveFiles.remember_level_exit(self)
		get_tree().change_scene_to_file("res://scenes/testing/ItemLab.tscn")
