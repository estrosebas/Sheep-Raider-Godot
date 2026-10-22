extends AnimatableBody3D
# RCarpetMobile: a button drives the native trajectory at +/-400 units/s.
# This adapter uses Godot platform velocity for characters and MovingSupport
# for placed items, so cargo receives each movement delta only once.
var definition: Dictionary
var visual: OriginalCinematicActor
var inputs: Dictionary = {}
var points: Array[Vector3] = []
var distance = 0.0
var length = 0.0
var audio: AudioStreamPlayer3D
var initialized = false

func _ready():
	sync_to_physics = false
	collision_layer = 3
	process_physics_priority = 50
	visual = load(definition.directory+"/worn.tscn").instantiate(); add_child(visual)
	for box in definition.boxes:
		if int(box.flags)&1: continue
		var lo = GameSpace.original_point(Vector3(box.min[0],box.max[1],box.max[2]))
		var hi = GameSpace.original_point(Vector3(box.max[0],box.min[1],box.min[2]))
		var shape = BoxShape3D.new(); shape.size = hi-lo
		var collider = CollisionShape3D.new(); collider.shape = shape; collider.position = (lo+hi)/2
		add_child(collider)
	for point in definition.trajectory:
		points.append(GameSpace.original_point(Vector3(point[0],point[1],point[2])))
	for i in range(1,points.size()): length += points[i-1].distance_to(points[i])
	audio = AudioStreamPlayer3D.new(); add_child(audio)
	var path: String = get_parent().asset_directory+"/audio/94.wav"
	if ResourceLoader.exists(path): audio.stream = load(path)
	add_to_group("moving_supports"); add_to_group("mobile_platforms")
	get_parent().player.respawned.connect(reset_to_home)
	call_deferred("initialize")

func initialize():
	visual.rotation = rotation; rotation = Vector3.ZERO
	reset_to_home(); initialized = true

func set_switch(sender: Node,on: bool): inputs[sender] = on

func surface_height(_point: Vector3) -> float:
	return global_position.y-float(definition.boxes[0].min[1])*.01

func set_distance(value: float):
	distance = clampf(value,0,length)
	var remaining = distance
	for i in range(1,points.size()):
		var segment = points[i-1].distance_to(points[i])
		if remaining<=segment or i==points.size()-1:
			global_position = points[i-1].lerp(points[i],minf(remaining/maxf(segment,.001),1))
			return
		remaining -= segment

func reset_to_home():
	inputs.clear(); set_distance(0)
	if audio: audio.stop()

func _physics_process(delta: float):
	if not initialized or inputs.is_empty(): return
	var target = length if inputs.values().has(true) else 0.0
	var next = move_toward(distance,target,float(definition.switch_speed)*float(definition.speed_ratio)*delta)
	var moving = not is_equal_approx(next,distance)
	set_distance(next)
	if moving and audio.stream and not audio.playing: audio.play()
	elif not moving: audio.stop()
