extends CharacterBody3D

var definition: Dictionary
var visual: OriginalCinematicActor
var broken_visual: OriginalCinematicActor
var home = Vector3.ZERO
var carried_by: RalphController
var carry_controller: OriginalSheepCarry
var carry_heading = 0.0
var catapult_motion_owner: Node3D
var shattered = false
var shatter_time = 0.0
var thrown = false
var floor_shape: CollisionShape3D
var sounds: Dictionary = {}
var audio: AudioStreamPlayer3D

func _ready():
	add_to_group("world_interactables")
	add_to_group("carryable_rocks")
	add_to_group("grounded_npcs")
	set_meta("original_class","SmallRock")
	set_meta("original_weight",120)
	set_meta("original_resource",int(definition.res))
	visual = load(definition.directory+"/worn.tscn").instantiate(); add_child(visual); visual.idle("stand")
	broken_visual = load("res://assets/effects/small_rock_break/worn.tscn").instantiate(); add_child(broken_visual); broken_visual.hide()
	audio = AudioStreamPlayer3D.new(); add_child(audio)
	# Native SmallRock: .8m diameter, .9m tall cone, weight120.
	floor_shape = CollisionShape3D.new(); floor_shape.name = "CollisionShape3D"
	var box = definition.boxes[0]
	var shape = ConvexPolygonShape3D.new()
	var lo = GameSpace.original_point(Vector3(box.min[0],box.max[1],box.max[2]))
	var hi = GameSpace.original_point(Vector3(box.max[0],box.min[1],box.min[2]))
	var centre = (lo+hi)*.5
	var points = PackedVector3Array([Vector3(centre.x,hi.y,centre.z)])
	for i in range(16): points.append(Vector3(centre.x+cos(i*TAU/16)*(hi.x-lo.x)*.5,lo.y,centre.z+sin(i*TAU/16)*(hi.z-lo.z)*.5))
	shape.points = points; floor_shape.shape = shape; add_child(floor_shape)
	call_deferred("remember_home")
	var actor = get_tree().get_first_node_in_group("player")
	if actor: actor.respawned.connect(return_home)
	process_priority = 110
	process_physics_priority = 100

func remember_home():
	var query = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,global_position-Vector3.UP*5)
	query.exclude = [get_rid()]; query.collision_mask = 1
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): global_position.y = hit.position.y+.005
	home = global_position

func action_label(actor) -> String:
	return GameLocalization.text("lvl_01",0,0x36 if carried_by==actor else 0x29)

func can_interact(actor: RalphController) -> bool:
	if shattered or is_instance_valid(catapult_motion_owner) or not actor.can_use_item(): return false
	if carried_by==actor: return actor.is_on_floor()
	if carried_by or actor.carried_sheep or actor.carried_object or actor.inventory.equipped_node: return false
	var offset = global_position-actor.global_position
	return actor.is_on_floor() and Vector2(offset.x,offset.z).length()<=1.25 and absf(offset.y)<=.9

func interact(actor: RalphController) -> bool:
	if not can_interact(actor): return false
	if carried_by==actor:
		return actor.item_actions.begin([
			{"clip":"sheep_drop","exit":func():
				var placement = placement_from(actor)
				if placement.is_empty(): actor.item_actions.stages[1] = {"clip":"placement_refused"}; return
				drop_at(placement.position)}, {"clip":"sheep_drop_end"}])
	return actor.item_actions.begin([
		{"clip":"sheep_lift","enter":func(): actor.item_actions.face(global_position),"exit":func():
			carry_heading = rotation.y-actor.skeleton.rotation.y
			carried_by = actor; actor.carried_object = self; carry_controller = OriginalSheepCarry.new()
			add_collision_exception_with(actor); floor_shape.set_deferred("disabled",true)}, {"clip":"sheep_lift_end"}])

func placement_from(actor: RalphController) -> Dictionary:
	# Wolf::CanPutDownHeldObj(false) leaves the object at (10,-70,-92),
	# not snapped onto the floor. SmallRock then falls onto the button/bucket.
	var point = actor.global_position+Vector3.UP*.7+actor.item_facing()*.92+actor.skeleton.global_basis.x*.1
	var excluded: Array[RID] = [actor.get_rid(),get_rid()]
	for other in get_tree().get_nodes_in_group("grounded_npcs"):
		if other is CollisionObject3D and not excluded.has(other.get_rid()): excluded.append(other.get_rid())
	var space = get_world_3d().direct_space_state
	var ray = PhysicsRayQueryParameters3D.create(point,point-Vector3.UP*30)
	ray.collision_mask = 1; ray.exclude = excluded
	var ground = space.intersect_ray(ray)
	if ground.is_empty() or ground.position.y>point.y: return {}
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = floor_shape.shape; query.collision_mask = 1; query.exclude = excluded; query.margin = .001
	for i in range(8):
		var sample = point.lerp(actor.global_position,float(i)/8)
		query.transform = Transform3D(Basis.IDENTITY,sample+floor_shape.position)
		if not space.intersect_shape(query,1).is_empty(): return {}
	return {"position":point,"support":ground.collider}

func drop_at(point: Vector3):
	if carried_by:
		var actor = carried_by
		rotation = Vector3(0,actor.skeleton.rotation.y+carry_heading,0)
		scale = Vector3.ONE
		actor.carried_object = null; remove_collision_exception_with(actor)
		carried_by = null; carry_controller = null
	global_position = point; velocity = Vector3.ZERO
	floor_shape.set_deferred("disabled",false)
	thrown = true

func move_carrier(delta):
	if not carry_controller: carry_controller = OriginalSheepCarry.new()
	carry_controller.step(self,delta)

func _process(delta):
	if carried_by:
		var hand = carried_by.skeleton.global_transform*carried_by.legacy_skin.last_matrices[18]
		var root_pose = carried_by.skeleton.global_transform*carried_by.legacy_skin.last_matrices[0]
		var orientation = root_pose.basis*GameSpace.EXPORT_TO_GODOT
		global_transform = Transform3D(orientation.rotated(orientation.y.normalized(),carry_heading),hand.origin+orientation*Vector3(.1,0,0))
	if shattered:
		var previous_time = shatter_time
		shatter_time += delta
		broken_visual.sample_animation("break",shatter_time)
		for cue in broken_visual.rig.animations["break"].sound_cues:
			if float(cue.time)>previous_time and float(cue.time)<=shatter_time and sounds.has(str(int(cue.sound_id))):
				audio.stream = load(sounds[str(int(cue.sound_id))]); audio.play()
		if shatter_time>=float(broken_visual.rig.animations["break"].duration): return_home()

func _physics_process(delta):
	if carried_by or shattered or is_instance_valid(catapult_motion_owner): return
	velocity.y = 0 if is_on_floor() else maxf(-10,velocity.y-15*delta)
	move_and_slide()
	if global_position.y<home.y-20: return_home()
	for provider in get_tree().get_nodes_in_group("water_regions"):
		if provider.get_parent()==get_parent() and not provider.water_at(global_position+Vector3.UP*.8).is_empty(): return_home(); return
	if thrown:
		for zone in get_tree().get_nodes_in_group("original_fall_zones"):
			if zone.get_parent()==get_parent() and global_position.x>=zone.minimum.x and global_position.x<=zone.maximum.x and global_position.z>=zone.minimum.y and global_position.z<=zone.maximum.y and global_position.y<zone.fall_height:
				return_home(); return

func landed(impact: bool):
	catapult_motion_owner = null; thrown = true; velocity = Vector3.ZERO
	if not impact: return
	shattered = true; shatter_time = 0
	visual.hide(); broken_visual.show(); floor_shape.set_deferred("disabled",true)
	broken_visual.sample_animation("break",0)
	for target in get_tree().get_nodes_in_group("sam_guards"):
		var offset = target.global_position-global_position
		if absf(offset.y)<=1.0 and Vector2(offset.x,offset.z).length()<=2.0: target.on_rock_crush(self)

func return_home():
	if carried_by: drop_at(home)
	catapult_motion_owner = null; shattered = false; thrown = false
	global_position = home; rotation = Vector3.ZERO; velocity = Vector3.ZERO
	visual.show(); visual.idle("stand"); broken_visual.hide()
	floor_shape.set_deferred("disabled",false)
