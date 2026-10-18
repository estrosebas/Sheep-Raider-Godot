extends Node
class_name TutorialProgress

const Space = preload("res://scripts/levels/game_space.gd")
signal checkpoint_reached(index: int)
var data: Dictionary
var player: CharacterBody3D
var reached: Dictionary = {}
var rocks: Dictionary = {}
var checkpoint_index = -1

static func contains(box: Dictionary, point: Vector3) -> bool:
	var a = box["min"]
	var b = box["max"]
	var lo = Space.original_point(Vector3(a[0],b[1],b[2]))
	var hi = Space.original_point(Vector3(b[0],a[1],a[2]))
	return point.x >= lo.x and point.x <= hi.x and point.y >= lo.y and point.y <= hi.y and point.z >= lo.z and point.z <= hi.z

static func center(box: Dictionary) -> Vector3:
	var a = box["min"]
	var b = box["max"]
	return Space.original_point(Vector3((a[0]+b[0])/2.0,(a[1]+b[1])/2.0,(a[2]+b[2])/2.0))

static func contains_xz(box: Dictionary, point: Vector3) -> bool:
	var a = box["min"]
	var b = box["max"]
	return point.x >= float(a[0])*0.01 and point.x <= float(b[0])*0.01 and point.z >= -float(b[2])*0.01 and point.z <= -float(a[2])*0.01

func _ready() -> void:
	player = get_parent().get_node("Player")
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_00/data/tutorial_progress.json"))
	var solids = get_parent().get_node("OriginalObjectCollisions")
	for record in data["falling_rocks"]:
		var body: StaticBody3D = solids.get_node("FallingRock_%d" % int(record["res"]))
		var mesh = MeshInstance3D.new()
		mesh.name = "OriginalRockVisual"
		mesh.mesh = load("res://assets/levels/lvl_00/falling_rock.tres")
		body.add_child(mesh)
		body.hide()
		for shape in body.get_children():
			if shape is CollisionShape3D:
				shape.disabled = true
		rocks[int(record["res"])] = {"body":body,"home":body.position,"trigger":int(record["activation"]["export"]),"active":false,"ticks":0,"elapsed":0.0}

func _physics_process(delta: float) -> void:
	if player.is_on_floor() and not player.cinematic_controls_locked and not player.tutorial_movement_locked:
		for checkpoint in data["checkpoints"]:
			if contains(checkpoint["trigger"],player.global_position) and checkpoint_index != int(checkpoint["index"]):
				activate_checkpoint(int(checkpoint["index"]))
	for rock in rocks.values():
		if not rock["active"] or rock["ticks"] >= 5:
			continue
		rock["elapsed"] += delta
		while rock["elapsed"] >= 0.04 and rock["ticks"] < 5:
			rock["elapsed"] -= 0.04
			rock["ticks"] += 1
			rock["body"].position.y -= 4.0
			if rock["ticks"] == 5:
				rock["body"].position = rock["home"]
				player.play_animation_sfx("res://assets/audio/sfx/falling_rock_impact.wav")

func activate_checkpoint(index: int) -> void:
	for checkpoint in data["checkpoints"]:
		if int(checkpoint["index"]) != index:
			continue
		checkpoint_index = index
		reached[index] = true
		player.checkpoint_position = center(checkpoint["destination"])
		player.checkpoint_camera_rotation = Vector3(0,-deg_to_rad(float(checkpoint["yaw"]))+PI,0)
		player.inventory.state.commit_at_checkpoint()
		for rock in rocks.values():
			if rock["trigger"] == int(checkpoint["trigger"]["export"]) and not rock["active"]:
				rock["active"] = true
				rock["body"].position = rock["home"]+Vector3.UP*20
				rock["body"].show()
				for shape in rock["body"].get_children():
					if shape is CollisionShape3D:
						shape.set_deferred("disabled",false)
		checkpoint_reached.emit(index)
		return
