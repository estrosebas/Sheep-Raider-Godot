extends Node3D

const Catalog = preload("res://scripts/items/item_catalog.gd")
const MagneticTarget = preload("res://scripts/items/magnetic_target.gd")
const SheepReceiver = preload("res://scripts/items/original_sheep.gd")
@onready var player = $Player

func _ready() -> void:
	$HUD.hide()
	player.inventory.allow_world_placement = true
	for i in range(6):
		var door = LabLevelDoor.new()
		var identity = "%02d" % i
		door.name = "LevelDoor_"+identity
		door.level_label = "Nivel "+identity
		door.level_scene = "res://scenes/levels/Level%s.tscn" % identity
		door.position = Vector3(20,0,4+i*8)
		door.rotation.y = PI/2
		add_child(door)
		var name_on_floor = LabFloorLabel.create("NIVEL "+identity,Vector3(16,.035,4+i*8))
		name_on_floor.name = "DoorFloorLabel_"+identity
		add_child(name_on_floor)
	var index = 0
	for kind in [66, 80, 125, 3, 39, 7, 10, 2, 41]:
		var item = Catalog.create_item(kind, "lab:%d" % kind)
		if kind == 3: item.original_scene = "res://assets/levels/lvl_01/models/5/worn.tscn"
		item.name = "Item_%d" % kind
		item.position = Vector3(-6 + index * 2.0, 0.02, -3.0)
		add_child(item)
		index += 1
	var mechanics = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_01/data/mechanics.json"))
	var telescope = OriginalTelescope.new()
	telescope.name = "Telescope"
	telescope.definition = mechanics["telescope"].duplicate(true)
	telescope.definition["normal_box"] = null
	telescope.definition["reverse_box"] = null
	telescope.position = Vector3(7,0,-7)
	add_child(telescope)
	var rocks = OriginalBreakableRocks.new()
	rocks.name = "BlastRocks"
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_01/data/solid_boxes.json")):
		if entry["class_name"] == "Rocks": rocks.definition = entry
	rocks.position = Vector3(-3,0,-12)
	add_child(rocks)
	for i in range(3):
		var target = MagneticTarget.new()
		target.name = "Metal_%d" % i
		target.position = Vector3(-6.0 + i * 0.9, 0.5, -6.0)
		var mesh = MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.mesh.size = Vector3.ONE * 0.6
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.55, 0.68, 0.78)
		mesh.material_override = material
		target.add_child(mesh)
		var collision = CollisionShape3D.new()
		collision.shape = BoxShape3D.new()
		collision.shape.size = Vector3.ONE * 0.6
		target.add_child(collision)
		add_child(target)
	var sheep = SheepReceiver.new()
	sheep.name = "Sheep"
	sheep.visual_scene = "res://assets/levels/lvl_02/models/6/worn.tscn"
	sheep.position = Vector3(3.0, 0.05, -7.0)
	add_child(sheep)
	player.respawned.connect(sheep.reset_to_home)
	setup_lettuce_area()
	setup_music_area()
	setup_push_and_bush()
	setup_bull_leaf_heap()
	# TODO(level04 foliage): revisit rear-face overlap and native leaf-sheet
	# geometry. A–G lab experiments were rejected as flat; keep the original
	# BullLeafHeap reference above. Archived experiments explain each approach.
	setup_rock_cover()
	setup_elastic_area()
	var studio = LabLevelDoor.new()
	studio.name = "StudioDoor"; studio.level_label = GameLocalization.ui("Plató")
	studio.level_scene = SaveFiles.STUDIO_SCENE; studio.position = Vector3(20,0,-4); studio.rotation.y = PI/2
	add_child(studio)
	add_child(LabFloorLabel.create(GameLocalization.ui("Plató").to_upper(),Vector3(16,.035,-4),30))
	var ghost = Node3D.new()
	ghost.name = "GhostTarget"
	ghost.set_script(load("res://scripts/testing/ghost_item_fixture.gd"))
	ghost.position = Vector3(0.0, 0.0, -6.0)
	add_child(ghost)

func setup_lettuce_area() -> void:
	add_child(LabFloorLabel.create("LECHUGAS Y OVEJA\nE: COGER / R: COLOCAR",Vector3(20,.035,-8),36))
	var sheep = SheepReceiver.new()
	sheep.name = "LettuceSheep"
	sheep.visual_scene = "res://assets/levels/lvl_02/models/6/worn.tscn"
	sheep.position = Vector3(14,.05,-14)
	add_child(sheep)
	player.respawned.connect(sheep.reset_to_home)

	# Supply plants outside the sheep's six-metre attraction radius.
	# Pick them up, then place a trail near the sheep to test following/eating.
	for i in range(6):
		var item = Catalog.create_item(3,"lab:lettuce:%d" % i)
		item.name = "LettuceSupply_%d" % i
		item.original_scene = "res://assets/levels/lvl_01/models/5/worn.tscn"
		item.position = Vector3(24+(i%3)*2,.02,-13-int(i/3)*2)
		add_child(item)

func setup_elastic_area():
	# Same controllers/assets as Level03; two anchors and a separate 14m yo-yo ledge.
	for entry in [["ElasticTree_A",Vector3(-20,0,-24),201],["ElasticTree_B",Vector3(-12,0,-24),202],
		["ElasticTree_Yoyo",Vector3(-32,14,-20),203]]:
		var tree = OriginalElasticTree.new(); tree.name = entry[0]; tree.position = entry[1]
		tree.set_meta("original_resource",entry[2]); tree.pull_up_point = entry[1]+Vector3(1,0,1)
		if int(entry[2])==203: tree.pull_up_point.y += 1.8 # Authored cosine peak above the landing platform.
		add_child(tree)
		# The map normally supplies these native model collision boxes.
		var trunk = StaticBody3D.new(); tree.add_child(trunk)
		var shape = CollisionShape3D.new(); shape.shape = CylinderShape3D.new()
		shape.shape.radius = .28; shape.shape.height = 2; shape.position.y = 1
		trunk.add_child(shape)
	for entry in [["Elastic",Vector3(-21,0,-26)],["ElasticYoyo",Vector3(-31,14,-19)]]:
		var elastic = Catalog.create_item(42,"lab:"+entry[0]); elastic.name = entry[0]
		var profile = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_03/data/port_balance.json"))
		elastic.elastic_definition = profile.get("elastic",{}).duplicate(true)
		elastic.position = entry[1]; add_child(elastic)
	var sheep = SheepReceiver.new(); sheep.name = "ElasticSheep"
	sheep.visual_scene = "res://assets/levels/lvl_02/models/6/worn.tscn"
	sheep.position = Vector3(-15.2,.02,-20); add_child(sheep)
	player.respawned.connect(sheep.reset_to_home)
	add_child(LabFloorLabel.create("ELASTICO\nE: ENGANCHAR / TIRAR / SOLTAR\nENTRE DOS ARBOLES: ESTIRAR Y SALTAR",Vector3(-16,.035,-28),28))
	add_child(LabFloorLabel.create("YO-YO\nSUBE, ENGANCHA Y SALTA DEL BORDE",Vector3(-32,.035,6),28))
	for i in range(14): elastic_step(Vector3(-32,float(i)+.5,3-float(i)*1.5),Vector3(3,1,1.5))
	elastic_step(Vector3(-32,13.5,-20),Vector3(6,1,6))

func elastic_step(point: Vector3,dimensions: Vector3):
	var body = StaticBody3D.new(); body.position = point
	var shape = CollisionShape3D.new(); shape.shape = BoxShape3D.new(); shape.shape.size = dimensions
	body.add_child(shape)
	var mesh = MeshInstance3D.new(); mesh.mesh = BoxMesh.new(); mesh.mesh.size = dimensions
	var paint = StandardMaterial3D.new(); paint.albedo_color = Color(.38,.27,.16)
	mesh.material_override = paint; body.add_child(mesh); add_child(body)

func setup_push_and_bush():
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_02/data/interactions.json"))
	var rock = preload("res://scripts/items/original_pushable_rock.gd").new()
	rock.name = "PushableRock"
	rock.definition = data.rocks[2].duplicate(true)
	rock.definition.push_zones = []
	rock.definition.props["0x8"] = 1
	rock.definition.props["0x2c"] = 1
	rock.visual_scene = "res://assets/levels/lvl_02/models/20/worn.tscn"
	rock.sound_path = "res://assets/levels/lvl_02/audio/262.wav"
	rock.position = Vector3(-4,.9,16)
	add_child(rock)
	player.respawned.connect(rock.reset_to_home)
	var bush = preload("res://scripts/items/original_bush.gd").new()
	bush.name = "Bush"
	bush.position = Vector3(5,0,16)
	add_child(bush)
	player.respawned.connect(bush.reset_to_home)
	add_child(LabFloorLabel.create("ARBUSTO\nCARAS FRONTALES",Vector3(5,.035,18),25))
	add_child(LabFloorLabel.create("E: ARBUSTO\nMANTEN E: EMPUJAR",Vector3(1,.035,19),30))
	# Discarded variants remain in this archive, disabled during normal play:
	# preload("res://scripts/testing/experiments/bush_render_experiments.gd").setup(self)

func setup_bull_leaf_heap():
	# Complete native leaf-heap component, unchanged scale/UV/geometry.
	# The bush's backface patch was rejected for this open terrain geometry.
	# Keep a two-sided native reference here; new experiments live further back.
	var base = "res://assets/levels/lvl_04"
	var metadata = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/foliage.json"))
	var heap = load(base+"/foliage/leaf_heap.tscn").instantiate()
	heap.name = "BullLeafHeap"; heap.position = Vector3(1,0,-27)
	heap.mesh = preload("res://scripts/testing/experiments/leaf_heap_experiments.gd").original_reference(heap.mesh)
	add_child(heap)
	preload("res://scripts/testing/experiments/leaf_heap_experiments.gd").add_top_collision(heap,heap.mesh)
	var source_origin = GameSpace.from_export(Vector3(metadata.source_origin[0],metadata.source_origin[1],metadata.source_origin[2]))
	var offset: Vector3 = heap.position-source_origin
	var native_offset = Vector3(offset.x,-offset.y,-offset.z)*100
	var wildlife = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/wildlife.json"))
	for source in wildlife.leaf_zones:
		if int(source.res)!=int(metadata.sample_leaf_zone): continue
		var definition = source.duplicate(true)
		for point in definition.polygon:
			for axis in range(3): point[axis] += native_offset[axis]
		for box in definition.zone:
			for axis in range(3):
				box.min[axis] += native_offset[axis]; box.max[axis] += native_offset[axis]
		var noise = preload("res://scripts/levels/original_leaf_zone.gd").new()
		noise.name = "BullLeafHeapNoise"; noise.definition = definition; noise.sounds = wildlife.sounds
		noise.position = GameSpace.from_export(Vector3(source.pos[0],source.pos[1],source.pos[2]))+offset
		add_child(noise)
		break
	add_child(LabFloorLabel.create("HOJARASCA DEL TORO\nREFERENCIA ORIGINAL / VER PRUEBAS AL FONDO",Vector3(1,.035,-15),22))

func setup_music_area() -> void:
	var music = OriginalMusicSegment.new()
	music.name = "MusicPreview"
	music.volume_db = -10
	add_child(music)
	add_child(LabFloorLabel.create("MUSICA\nPISA UN BOTON",Vector3(-18,.035,-1),40))
	var tracks = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/music/catalog.json"))["tracks"].duplicate(true)
	tracks.append({})
	for i in range(tracks.size()):
		var pad = LabMusicPad.new()
		pad.name = "MusicPad_%02d" % i
		pad.music = music
		pad.track = tracks[i]
		pad.position = Vector3(-24+(i%3)*6,0,4+int(i/3)*4)
		add_child(pad)

func setup_rock_cover():
	var records = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_03/data/solid_boxes.json"))
	var source = records.filter(func(value): return value.class_name=="HiddenRocks")[0]
	for i in range(2):
		var rock = OriginalHiddenRock.new(); rock.definition = source.duplicate(true)
		rock.definition.res = -100-i; rock.name = "CoverRock_%d"%i
		rock.visual_scene = "res://assets/levels/lvl_03/models/13/worn.tscn"
		rock.position = Vector3(12+i*4,0,16)
		add_child(rock)
	add_child(LabFloorLabel.create("ROCAS DE COBERTURA\n%s: SIGILO / ACERCATE A LA ROCA"%preload("res://scripts/input/platform_controls.gd").key_label("sneak").to_upper(),Vector3(14,.035,20),25))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		$HUD.visible = not $HUD.visible
	if event.is_action_pressed("item_lab"):
		get_tree().change_scene_to_file(SaveFiles.STUDIO_SCENE)

func _process(_delta: float) -> void:
	var suffix = ""
	if is_instance_valid(player.active_rocket):
		suffix = " · Cohete: %.1f s / daño %.0f%%" % [player.active_rocket.fuel, (1.0-player.active_rocket.health/player.active_rocket.durability)*100]
	$HUD/Label.text = "LABORATORIO · Puertas Nivel 00 / Nivel 01 / Nivel 02 / Nivel 03 / Nivel 04: E para entrar\nE: recoger/usar · R: usar o colocar equipado · Tab + A/D: inventario\nCohete: W baja / S sube · A/D girar · Shift impulsar · E/R bajar" + suffix
