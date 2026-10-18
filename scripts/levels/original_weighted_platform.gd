extends AnimatableBody3D
class_name OriginalWeightedPlatform
# WoodenPlatForm: empty / sheep / wolf-or-rock choose three heights;
# the linked SecretDoor travels in the opposite vertical direction.
var definition: Dictionary
var home_y = 0.0
var heavy_y = 0.0
var speed = 0.0
var visual: Node3D
var door: Node3D
var door_collision: Node3D
var last_load = 0

func _ready():
	sync_to_physics = false
	home_y = float(definition.pos[1])
	var raw = int(definition.props["0x10"])
	if raw>2147483647: raw-=4294967296
	heavy_y = raw*.01; speed = float(definition.props["0x14"])*.3
	visual = load(definition.directory+"/worn.tscn").instantiate(); add_child(visual)
	for box in definition.boxes:
		var lo = GameSpace.original_point(Vector3(box.min[0],box.max[1],box.max[2]))
		var hi = GameSpace.original_point(Vector3(box.max[0],box.min[1],box.min[2]))
		var shape = BoxShape3D.new(); shape.size = hi-lo
		var collision = CollisionShape3D.new(); collision.shape = shape; collision.position = (lo+hi)/2
		add_child(collision)
	add_to_group("weighted_platforms")
	call_deferred("link_door")

func link_door():
	for child in get_parent().get_children():
		if child is Node3D and int(child.get_meta("original_resource",-1))==int(definition.door_resource): door = child; break
	var collisions = get_parent().get_node("OriginalObjectCollisions")
	for child in collisions.get_children():
		if int(child.get_meta("original_resource",-1))==int(definition.door_resource): door_collision = child; break

func surface_height() -> float:
	return global_position.y-float(definition.boxes[0].min[1])*.01

func load_at(actor: Node3D) -> int:
	if actor is OriginalSheep and (actor.dead or actor.carried_by): return 0
	if actor is RalphController and actor.current_state in [actor.WolfState.PIT_FALL,actor.WolfState.SAM_DEATH,actor.WolfState.BLAST_DEATH]: return 0
	var box = definition.boxes[0]
	var difference = actor.global_position-global_position
	var extent = .35 if actor is OriginalSheep or actor is RalphController else float(actor.radius)
	var feet: float = actor.global_position.y if actor is OriginalSheep or actor is RalphController else actor.global_position.y-extent
	if difference.x+extent<float(box.min[0])*.01 or difference.x-extent>float(box.max[0])*.01: return 0
	if difference.z+extent<-float(box.max[2])*.01 or difference.z-extent>-float(box.min[2])*.01: return 0
	if absf(feet-surface_height())>.15 or actor.velocity.y>.5: return 0
	return 1 if actor is OriginalSheep else 2

func set_height(value: float):
	var delta_y = value-position.y
	position.y = value
	if is_instance_valid(door): door.position.y -= delta_y
	if is_instance_valid(door_collision): door_collision.position.y -= delta_y

func _physics_process(delta: float):
	var candidates = get_tree().get_nodes_in_group("player")+get_tree().get_nodes_in_group("sheep_targets")+get_tree().get_nodes_in_group("pushable_rocks")
	var carried: Array = []; last_load = 0
	for actor in candidates:
		if actor.get_parent()!=get_parent(): continue
		var weight = load_at(actor)
		if weight>0: carried.append(actor); last_load = maxi(last_load,weight)
	var target = home_y if last_load==0 else (home_y+heavy_y)/2 if last_load==1 else heavy_y
	var next = move_toward(position.y,target,speed*delta)
	var step = next-position.y
	set_height(next)
	# Native CarryObjects translates cargo before its next movement update.
	for actor in carried:
		# CharacterBody3D carries floor velocity during move_and_slide. Applying
		# the same delta here too would move a rock twice and lose its load.
		if not actor.is_physics_processing(): actor.global_position.y += step
