extends Node3D
class_name OriginalMailbox

# Mailbox::PostLoadInit / HandleMessage / Deliver / Rollback.
signal delivered
var definition: Dictionary
var box_definition: Dictionary
var sounds: Dictionary
var items: Array[GameItem] = []
var spawn_positions: Array[Vector3] = []
var boxes: Array[OriginalDeliveryBox] = []
var opened = false
var committed = false
var visual: OriginalCinematicActor
var hint: Label3D
var delivery_camera: Camera3D
var previous_camera: Camera3D
var animation_time = 0.0
var previous_time = -0.001
var sound_players: Array[AudioStreamPlayer3D] = []

func _ready() -> void:
	add_to_group("world_interactables")
	visual = load(definition["directory"]+"/worn.tscn").instantiate()
	add_child(visual)
	visual.idle("stand1")
	for item in items:
		spawn_positions.append(item.global_position)
		item.delivery_mailbox = self
		item.available = false
		item.hide()
	# PostLoadInit snaps the source scenery origin to terrain.
	var ray = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*3,global_position-Vector3.UP*10)
	var hit = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): global_position.y = hit["position"].y
	for box in definition["boxes"]:
		if int(box["flags"]) & 1: continue
		var body = StaticBody3D.new()
		var shape = CollisionShape3D.new()
		var lo = GameSpace.original_point(Vector3(box["min"][0],box["max"][1],box["max"][2]))
		var hi = GameSpace.original_point(Vector3(box["max"][0],box["min"][1],box["min"][2]))
		var geometry = BoxShape3D.new()
		geometry.size = hi-lo
		shape.shape = geometry
		shape.position = (lo+hi)/2
		body.add_child(shape)
		add_child(body)
	hint = Label3D.new()
	hint.text = "E · Solicitar envío"
	hint.position.y = 1.8
	hint.font_size = 36
	hint.pixel_size = 0.005
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(hint)
	hint.hide()
	delivery_camera = Camera3D.new()
	add_child(delivery_camera)

func can_interact(actor: Node3D) -> bool:
	if opened or not actor.can_use_item() or not actor.is_on_floor(): return false
	# ScanInteractables: solid model box gap <=60, vertical overlap, +/-1024 angle.
	var p = to_local(actor.global_position)
	var direction = global_position-actor.global_position
	direction.y = 0
	if direction.length() > 0.01 and actor.item_facing().dot(direction.normalized()) < 0: return false
	for box in definition["boxes"]:
		if int(box["flags"]) & 1: continue
		var lo = GameSpace.original_point(Vector3(box["min"][0],box["max"][1],box["max"][2]))
		var hi = GameSpace.original_point(Vector3(box["max"][0],box["min"][1],box["min"][2]))
		var gap = Vector2(maxf(maxf(lo.x-p.x,p.x-hi.x)-0.3,0),maxf(maxf(lo.z-p.z,p.z-hi.z)-0.3,0)).length()
		if gap <= 0.6 and p.y <= hi.y and p.y+1.7 >= lo.y: return true
	return false

func interact(actor: Node3D) -> bool:
	if not can_interact(actor): return false
	return actor.item_actions.begin([
		{"clip":"mailbox_hit","enter":func(): actor.item_actions.face(global_position),"exit":func(): _deliver(actor)},
		{"clip":"mailbox_end"},
		{"clip":"idle","duration":maxf(0,float(definition["props"]["0x34"])*0.001-0.31),"exit":_release_camera}],_release_camera)

func _deliver(actor: RalphController) -> void:
	opened = true
	visual.idle_clip = ""
	animation_time = 0
	previous_time = -0.001
	play_sound(sounds["251"],0.75)
	previous_camera = get_viewport().get_camera_3d()
	var record = definition.get("camera")
	if record != null:
		delivery_camera.global_position = GameSpace.original_point(Vector3(record["eye"][0],record["eye"][1],record["eye"][2]))
		var r = record["rotation"]
		delivery_camera.global_rotation = Vector3(-r[0],r[1],-r[2])*TAU/4096
		delivery_camera.fov = rad_to_deg(2*atan(384.0/float(record["focal"])))
		delivery_camera.current = true
	for index in range(items.size()):
		var box = OriginalDeliveryBox.new()
		box.item = items[index]
		var placed: Array = definition.get("placed_boxes",[])
		box.definition = placed[index] if index<placed.size() else box_definition
		box.held_for_rock = int(definition.get("rock_resource",-1))>=0
		if index<placed.size():
			box.set_meta("original_resource",int(placed[index].res))
			box.name = "DeliveryBox_%d"%int(placed[index].res)
		box.sounds = sounds
		get_parent().add_child(box)
		# Mailbox::Deliver positions authored boxes at their CONTENT's origin,
		# then sends MSG_USE (BOX_ST_FALL), even when linked to the rock puzzle.
		box.global_position = spawn_positions[index]
		box.add_collision_exception_with(actor)
		boxes.append(box)
	var resource = int(definition.get("rock_resource",-1))
	if resource>=0:
		for rock in get_tree().get_nodes_in_group("pushable_rocks"):
			if int(rock.get_meta("original_resource",-1))==resource: rock.box_delivered = true
	delivered.emit()

func _release_camera() -> void:
	if delivery_camera.current and is_instance_valid(previous_camera): previous_camera.current = true
	previous_camera = null

func commit() -> void:
	if opened: committed = true

func restore_containers(records: Array):
	for box in boxes:
		if is_instance_valid(box): box.queue_free()
	boxes.clear()
	for record in records:
		var placed: Array = definition.get("placed_boxes",[])
		for index in range(placed.size()):
			if int(placed[index].res)!=int(record.resource): continue
			var box = OriginalDeliveryBox.new()
			box.name = "DeliveryBox_%d"%int(record.resource)
			box.set_meta("original_resource",int(record.resource))
			box.item = items[index]; box.definition = placed[index]; box.sounds = sounds
			box.held_for_rock = bool(record.held)
			get_parent().add_child(box)
			box.global_position = SaveFiles.to_vector(record.position); box.state = str(record.state)
			boxes.append(box)

func rollback() -> void:
	if not opened or committed: return
	# Rock::StartLvl03Cinematic sets GF_CINE_SURVIVES_RESTART. Its actor
	# containers must survive a player death until their native flight ends.
	for box in boxes:
		if is_instance_valid(box) and box.movie_active: return
	_release_camera()
	for box in boxes:
		if is_instance_valid(box): box.queue_free()
	boxes.clear()
	for rock in get_tree().get_nodes_in_group("pushable_rocks"):
		if int(rock.get_meta("original_resource",-1))==int(definition.get("rock_resource",-1)): rock.box_delivered = false
	for item in items:
		item.store()
		item.available = false
	opened = false
	animation_time = 0
	visual.idle("stand1")

func _process(delta: float) -> void:
	var actor = get_parent().get_node_or_null("Player")
	hint.visible = false
	if not opened: return
	animation_time += delta
	visual.sample_animation("letter1",animation_time,false)
	for cue in visual.rig["animations"]["letter1"]["sound_cues"]:
		var t: float = cue["time"]
		if t > previous_time and t <= animation_time:
			var path = sounds.get(str(int(cue["sound_id"])))
			if path: play_sound(path)
	previous_time = animation_time

func play_sound(path: String, pitch: float = 1.0) -> void:
	var sound = AudioStreamPlayer3D.new()
	sound.stream = load(path)
	sound.pitch_scale = pitch
	sound.max_distance = 40
	add_child(sound)
	sound_players.append(sound)
	sound.finished.connect(func():
		sound_players.erase(sound)
		sound.queue_free())
	sound.play()
