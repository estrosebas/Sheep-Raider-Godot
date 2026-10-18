extends RefCounted

# Data-driven foundation for subsequent maps; level-specific sequences are
# added separately, rather than copying the level-01 lessons and identities.
func setup(level: ImportedLevel) -> void:
	var base = level.asset_directory
	var runtime = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/runtime.json"))
	var balance = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/port_balance.json")) if FileAccess.file_exists(base+"/data/port_balance.json") else {}
	var interactions = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/interactions.json")) if FileAccess.file_exists(base+"/data/interactions.json") else {}
	var switches = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/switches.json")) if FileAccess.file_exists(base+"/data/switches.json") else {}
	var wildlife = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/wildlife.json")) if FileAccess.file_exists(base+"/data/wildlife.json") else {}
	var sharks = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/sharks.json")) if FileAccess.file_exists(base+"/data/sharks.json") else {}
	var rafts = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/rafts.json")) if FileAccess.file_exists(base+"/data/rafts.json") else {}
	var excluded = ["Mailbox","Salad","SignPostSimple","Rock","Bush","seesaw"] if not interactions.is_empty() else ["Mailbox","Salad","SignPostSimple"]
	if not switches.is_empty(): excluded.append_array(["SensibleButton","Wooden Lift","WoodenPlatForm","FallingGate"])
	excluded.append_array(["Rocks","box","HiddenRocks","TimeKeeper","Flute","TriggedStone","bull","HeapOfLeaf","Leaf","Shark"])
	if not rafts.is_empty(): excluded.append("Raft")
	OriginalSolidBuilder.build(level,base+"/data/solid_boxes.json",excluded)
	var delivered = {}
	var elastic = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/elastic.json")) if FileAccess.file_exists(base+"/data/elastic.json") else {}
	for entity in level.entities:
		var kind = int(entity.class_id)
		if kind in [0,4,14,23,160,161] or kind in ImportedLevel.LOGIC_CLASSES: continue
		var definition = level.manifest.models.get(str(int(entity.model_res)))
		if definition == null: continue
		var actor: Node3D
		match kind:
			53:
				if rafts.is_empty():
					actor = load(definition.directory+"/worn.tscn").instantiate()
				else:
					actor = preload("res://scripts/levels/original_raft.gd").new()
					for raft in rafts.get("rafts",[]):
						if int(raft.res)==int(entity.res): actor.definition = raft
			50:
				actor = preload("res://scripts/actors/original_shark.gd").new()
				for shark in sharks.get("sharks",[]):
					if int(shark.res)==int(entity.res): actor.definition = shark
				actor.sounds = sharks.get("sounds",{})
			43:
				actor = preload("res://scripts/actors/original_bull.gd").new()
				for bull in wildlife.get("bulls",[]):
					if int(bull.res)==int(entity.res): actor.definition = bull
				actor.sounds = wildlife.get("sounds",{})
			54,191:
				actor = preload("res://scripts/levels/original_leaf_zone.gd").new()
				for leaf in wildlife.get("leaf_zones",[])+wildlife.get("leaves",[]):
					if int(leaf.res)==int(entity.res): actor.definition = leaf
				actor.sounds = wildlife.get("sounds",{})
			52:
				actor = preload("res://scripts/levels/original_triggered_stone.gd").new()
				for stone in switches.get("triggered_stones",[]):
					if int(stone.res)==int(entity.res): actor.definition = stone
				actor.sounds = runtime.sounds
			35:
				actor = OriginalHiddenRock.new(); actor.visual_scene = definition.directory+"/worn.tscn"
				for record in JSON.parse_string(FileAccess.get_file_as_string(base+"/data/solid_boxes.json")):
					if int(record.res)==int(entity.res): actor.definition = record
			13:
				actor = OriginalBreakableRocks.new(); actor.visual_scene = definition.directory+"/worn.tscn"
				for record in JSON.parse_string(FileAccess.get_file_as_string(base+"/data/solid_boxes.json")):
					if int(record.res)==int(entity.res): actor.definition = record
			26:
				actor = preload("res://scripts/levels/original_falling_gate.gd").new()
				for gate in switches.get("gates",[]):
					if int(gate.res)==int(entity.res): actor.definition = gate
				actor.sounds = runtime.sounds
			40:
				actor = OriginalWeightedPlatform.new()
				for platform in switches.get("weighted_platforms",[]):
					if int(platform.res)==int(entity.res): actor.definition = platform
			24:
				actor = OriginalPressureButton.new()
				for button in switches.get("buttons",[]):
					if int(button.res) == int(entity.res): actor.definition = button
				actor.sound_path = base+"/audio/54.wav"
			36:
				actor = OriginalWoodenLift.new()
				for lift in switches.get("lifts",[]):
					if int(lift.res) == int(entity.res): actor.definition = lift
				actor.sound_path = base+"/audio/94.wav"
			16:
				actor = preload("res://scripts/items/original_pushable_rock.gd").new()
				for rock in interactions.get("rocks",[]):
					if int(rock.res) == int(entity.res): actor.definition = rock
				actor.visual_scene = definition.directory+"/worn.tscn"
				actor.sound_path = runtime.sounds.get("262","")
				actor.impact_sound_path = runtime.sounds.get("68","")
			48:
				actor = preload("res://scripts/items/original_bush.gd").new()
			1:
				actor = OriginalSam.new()
				actor.definition = entity
				actor.visual_scene = definition.directory+"/worn.tscn"
				actor.rules_path = base+"/data/sam.json"
				actor.audio_path = base+"/data/ai_audio.json"
				actor.chase_speed_multiplier = float(balance.get("sam_chase_speed_multiplier",1.0))
			11:
				actor = OriginalSheep.new()
				actor.definition = entity
				actor.visual_scene = definition.directory+"/worn.tscn"
				actor.idle_animation = "stand3"
			2,3,7,10,39:
				actor = ItemCatalog.create_item(kind,"%s:%d"%[level.manifest.level,int(entity.res)])
				if kind == 3:
					actor.original_scene = definition.directory+"/worn.tscn"
					actor.preserve_source_pivot = true
				if kind==10:
					actor.original_scene = definition.directory+"/worn.tscn"
					var environment = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/environment.json"))
					var regions = environment.get("fly_boxes",[])
					if not regions.is_empty():
						var box = regions[0]
						var lo = GameSpace.original_point(Vector3(box.min[0],box.max[1],box.max[2])); var hi = GameSpace.original_point(Vector3(box.max[0],box.min[1],box.min[2]))
						actor.flight_bounds = AABB(lo,hi-lo); actor.has_flight_bounds = true
				if kind==2:
					actor.original_scene = definition.directory+"/worn.tscn"
					actor.fuse_seconds = float(entity.props.get("0x0",5000))*.001
				delivered[int(entity.res)] = actor
			42:
				actor = ItemCatalog.create_item(kind,"%s:%d"%[level.manifest.level,int(entity.res)])
				actor.original_scene = definition.directory+"/worn.tscn"; actor.source_level = level.manifest.level
				for record in elastic.get("items",[]):
					if int(record.res)==int(entity.res):
						actor.elastic_definition = record.duplicate(true)
						actor.elastic_definition.merge(balance.get("elastic",{}),true)
				actor.elastic_definition["stretch_sound"] = base+"/audio/284.wav"
				actor.elastic_definition["snap_sound"] = base+"/audio/235.wav"
				delivered[int(entity.res)] = actor
			41:
				actor = ItemCatalog.create_item(kind,"%s:%d"%[level.manifest.level,int(entity.res)])
				actor.original_scene = definition.directory+"/worn.tscn"
				actor.source_level = level.manifest.level
				delivered[int(entity.res)] = actor
			45:
				actor = OriginalElasticTree.new(); actor.visual_scene = definition.directory+"/worn.tscn"
				for record in elastic.get("trees",[]):
					if int(record.res)==int(entity.res): actor.definition = record
			38:
				actor = OriginalTimeKeeper.new()
				actor.asset_directory = definition.directory
				actor.level_id = level.manifest.level
				actor.sound_bank_path = base+"/data/ai_audio.json"
			78:
				actor = OriginalWorldNote.new()
				actor.visual_scene = definition.directory+"/worn.tscn"
				actor.source_level = level.manifest.level
				actor.native_text_index = int(entity.props["0x8"])
				actor.text = GameLocalization.text(level.manifest.level,79,actor.native_text_index)
			_:
				actor = load(definition.directory+"/worn.tscn").instantiate()
		actor.name = "%s_%d"%[entity.class_name,int(entity.res)]
		actor.set_meta("original_resource",int(entity.res))
		actor.set_meta("original_class",entity.class_name)
		level.add_child(actor)
		actor.position = GameSpace.from_export(Vector3(entity.pos[0],entity.pos[1],entity.pos[2]))
		actor.rotation = Vector3(entity.rot[0],-entity.rot[1],-entity.rot[2])*TAU/4096
		if actor is GameItem: actor.home_position = actor.global_position
		if actor is OriginalSheep: level.player.respawned.connect(actor.reset_to_home)
		if kind in [16,48]: level.player.respawned.connect(actor.reset_to_home)
		if actor is OriginalCinematicActor and not str(definition.idle).is_empty():
			# Decorative actors use an authored rest pose, not the first action
			# (e.g. the bull's attack) in an alphabetically extracted animation bank.
			var idle = "sleep1" if kind==43 and actor.rig.animations.has("sleep1") else str(definition.idle)
			actor.idle(idle)
	for definition in runtime.mailboxes:
		var mailbox = OriginalMailbox.new()
		mailbox.name = "Mailbox_%d"%int(definition.res)
		mailbox.definition = definition
		mailbox.box_definition = runtime.box
		mailbox.sounds = runtime.sounds
		mailbox.position = GameSpace.from_export(Vector3(definition.pos[0],definition.pos[1],definition.pos[2]))
		for resource in definition.item_resources:
			if delivered.has(int(resource)): mailbox.items.append(delivered[int(resource)])
		level.add_child(mailbox)
		# Native solid boxes are translated world boxes; only the artwork rotates.
		mailbox.visual.rotation.y = -float(definition.rot[1])*TAU/4096
		level.player.respawned.connect(mailbox.rollback)
	var spawn = level.manifest.spawn
	if balance.has("clock_collision_region"):
		var region = balance.clock_collision_region
		preload("res://scripts/levels/original_visual_collision.gd").setup(level,
			AABB(Vector3(region.min[0],region.min[1],region.min[2]),Vector3(region.size[0],region.size[1],region.size[2])),false)
	level.player.position = GameSpace.from_export(Vector3(spawn.pos[0],spawn.pos[1],spawn.pos[2]))
	level.player.skeleton.rotation.y = -float(spawn.rot[1])*TAU/4096
	level.player.camera_pivot.rotation.y = level.player.skeleton.rotation.y+PI
	level.player.safe_position = level.player.global_position
	level.get_node("HUD").hide()
	level.set_texture_profile(0)
	if level.manifest.level == "lvl_02":
		preload("res://scripts/levels/original_visual_collision.gd").setup(level,AABB(Vector3(-22,-3,-58),Vector3(32,14,28)))
		var passage = preload("res://scripts/levels/level02_start_passage.gd").new()
		passage.name = "StartPassageBoundary"
		level.add_child(passage)
	var flock = OriginalFlock.new()
	flock.name = "Flock"
	level.add_child(flock)
	var checkpoints = OriginalCheckpointManager.new()
	checkpoints.name = "Checkpoints"
	level.add_child(checkpoints)
	var menu = OriginalPauseMenu.new()
	menu.name = "PauseMenu"
	level.add_child(menu)
	if level.manifest.level in ["lvl_02","lvl_03"]:
		var lessons = preload("res://scripts/cinematics/original_level02_daffy.gd").new()
		lessons.level_directory = base
		lessons.name = "DaffyLessons"
		level.add_child(lessons)
	if level.manifest.level == "lvl_04":
		var lessons = preload("res://scripts/cinematics/level04_cinematics.gd").new()
		lessons.name = "DaffyLessons"
		level.add_child(lessons)
	if FileAccess.file_exists(base+"/data/environment.json"):
		var environment = preload("res://scripts/levels/original_level_environment.gd").new()
		environment.name = "LevelEnvironment"
		level.add_child(environment)
	if FileAccess.file_exists(base+"/data/cinematic_triggers.json"):
		var cinematics = preload("res://scripts/cinematics/imported_level_cinematics.gd").new()
		cinematics.name = "LevelCinematics"; level.add_child(cinematics)
	var save = ImportedCheckpointSave.new()
	save.name = "CheckpointSave"
	level.add_child(save)
	for definition in JSON.parse_string(FileAccess.get_file_as_string(base+"/data/goals.json")):
		var goal = OriginalLevelGoal.new()
		goal.name = "Goal_%d"%int(definition.res)
		goal.definition = definition
		goal.level_id = level.manifest.level
		level.add_child(goal)
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/music/catalog.json"))
	var index = int(str(level.manifest.level).trim_prefix("lvl_"))
	for track in catalog.tracks:
		if not track.levels.any(func(value): return int(value) == index): continue
		var wav: AudioStreamWAV = load(track.path).duplicate()
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = int(track.start_sample)
		wav.loop_end = int(track.end_sample)
		level.get_node("BGMPlayer").stream = wav
		level.get_node("BGMPlayer").volume_db = -12
		level.get_node("BGMPlayer").play(track.start_time)
		break
	print("[",level.manifest.level,"] Native foundation: ",level.entities.size()," entities / ",level.manifest.collision_triangles," collision triangles")
