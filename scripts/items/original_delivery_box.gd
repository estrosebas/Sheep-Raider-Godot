extends CharacterBody3D
class_name OriginalDeliveryBox

# box::Update: constant 800 units/s; OPEN1 on landing, then remove container.
signal released(item: GameItem)
var item: GameItem
var definition: Dictionary
var sounds: Dictionary
var visual: OriginalCinematicActor
var state = "fall"
var elapsed = 0.0
var previous = -0.001
var held_for_rock = false
var movie_active = false

func _ready() -> void:
	visual = load(definition["directory"]+"/worn.tscn").instantiate()
	add_child(visual)
	visual.sample_animation("stand0",0)
	var shape = CollisionShape3D.new()
	var source = definition["boxes"][0]
	var lo = GameSpace.original_point(Vector3(source["min"][0],source["max"][1],source["max"][2]))
	var hi = GameSpace.original_point(Vector3(source["max"][0],source["min"][1],source["min"][2]))
	var box = BoxShape3D.new()
	box.size = hi-lo
	shape.shape = box
	shape.position = (lo+hi)/2
	add_child(shape)
	# Resolve delivery against world terrain/structures; never obstruct Ralph.
	set_collision_layer_value(1,false)
	var player = get_tree().get_first_node_in_group("player")
	if player is PhysicsBody3D: add_collision_exception_with(player)
	if held_for_rock:
		add_to_group("seesaw_boxes")
		set_collision_layer_value(1,true)

func _physics_process(delta: float) -> void:
	if movie_active: return
	if state == "fall":
		var hit = move_and_collide(Vector3.DOWN*8*delta)
		if hit and hit.get_normal().y > 0.5:
			if held_for_rock:
				# Native IN_CINE_BOX containers stay closed on the seesaw until
				# the rock cinematic launches them. Delivery still falls at 800/s.
				state = "sealed"
				return
			state = "open"
			item.global_position = global_position+Vector3.UP*0.02
			item.home_position = item.global_position
			item.available = true
			item.show()
			item.hint.visible = false
			released.emit(item)
	if state == "open":
		elapsed += delta
		visual.sample_animation("open1",elapsed)
		for cue in visual.rig["animations"]["open1"]["sound_cues"]:
			if float(cue["time"]) > previous and float(cue["time"]) <= elapsed:
				var path = sounds.get(str(int(cue["sound_id"])))
				if path: item.play_item_sound(path)
		previous = elapsed
		if elapsed >= float(visual.rig["animations"]["open1"]["duration"]): queue_free()

func begin_fall():
	held_for_rock = false
	state = "fall"; elapsed = 0; previous = -.001
	set_collision_layer_value(1,false)

func reset_delivery():
	state = "sealed" if held_for_rock else "fall"
	elapsed = 0; previous = -.001
	visual.sample_animation("stand0",0)

func bottom() -> float: return global_position.y
