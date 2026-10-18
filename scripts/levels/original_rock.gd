extends CharacterBody3D
class_name OriginalRock

var definition: Dictionary
var visual: Node3D
var half_size: Vector3
var local_center: Vector3
var fall_time = 0.0
var previous_fall_speed = 0.0
var landed_speed = 0.0
var arc: Dictionary = {}
var initial_position: Vector3
var reset_on_death = false

func _ready() -> void:
	set_physics_process(false) # Puzzle manager coordinates contacts and launches.
	var box = definition["boxes"][-1]
	var a = box["min"]
	var b = box["max"]
	var lo = GameSpace.original_point(Vector3(a[0],b[1],b[2]))
	var hi = GameSpace.original_point(Vector3(b[0],a[1],a[2]))
	half_size = (hi-lo)/2
	local_center = (hi+lo)/2
	var collision = CollisionShape3D.new()
	# Source COLLBOX_ELLIPSOID, both tutorial rocks have spherical bounds.
	var sphere = SphereShape3D.new()
	sphere.radius = maxf(half_size.x,half_size.z)
	collision.shape = sphere
	collision.position = local_center
	add_child(collision)
	visual = load(definition["directory"]+"/worn.tscn").instantiate()
	add_child(visual)
	# Static actor's optional movie collider stays disabled; this body owns physics.
	initial_position = global_position
	reset_on_death = bool(definition["props"]["0x2c"])
	set_meta("original_class","Rock")
	set_meta("original_resource",int(definition["res"]))
	set_meta("original_solid_top",local_center.y+half_size.y)

func bottom() -> float:
	return global_position.y+local_center.y-half_size.y

func step(delta: float) -> void:
	landed_speed = 0
	if not arc.is_empty():
		arc["time"] = minf(float(arc["time"])+delta/1.024,1.0)
		var target = OriginalSeesaw.arc_point(arc["start"],arc["middle"],arc["end"],arc["time"])
		# Rock::Update preserves authored horizontal travel and resolves vertical contact.
		velocity = (target-global_position)/delta
		move_and_slide()
		if float(arc["time"]) >= 1.0:
			arc.clear()
			fall_time = 0
		return
	fall_time += delta
	previous_fall_speed = clampf(fall_time*40.0,2.0,30.0)
	velocity.y = -previous_fall_speed
	velocity.x = move_toward(velocity.x,0,20*delta)
	velocity.z = move_toward(velocity.z,0,20*delta)
	var was_grounded = is_on_floor()
	var stationary_xz = Vector2(global_position.x,global_position.z)
	move_and_slide()
	if is_on_floor():
		# Rock::FALL applies vertical gravity only. Godot's moving-platform velocity
		# must not make a resting stone creep off the seesaw before the puzzle.
		global_position.x = stationary_xz.x
		global_position.z = stationary_xz.y
		if not was_grounded: landed_speed = previous_fall_speed
		fall_time = 0

func launch(points: Array) -> void:
	arc = {"time":0.0,"start":global_position,"middle":OriginalSeesaw.source_point(points[1]),"end":OriginalSeesaw.source_point(points[2])}
	velocity = Vector3.ZERO

func reset_rock() -> void:
	arc.clear()
	global_position = initial_position
	velocity = Vector3.ZERO
	fall_time = 0
