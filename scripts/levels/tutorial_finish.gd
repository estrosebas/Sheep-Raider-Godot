extends Node3D
class_name TutorialFinish

signal level_completed
var player: RalphController
var sheep: OriginalSheep
var goal: Dictionary
var bounds: AABB
var radius: float
var completed = false
var completion: Node

func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_00/puzzle/definitions.json"))
	player = get_parent().get_node("Player")
	var flight: Dictionary = data["fly_box"]
	var lo = GameSpace.original_point(Vector3(flight["min"][0],flight["max"][1],flight["max"][2]))
	var hi = GameSpace.original_point(Vector3(flight["max"][0],flight["min"][1],flight["min"][2]))
	var rocket = get_parent().get_node("Rocket_77")
	rocket.flight_bounds = AABB(lo,hi-lo)
	rocket.has_flight_bounds = true
	# Replace the ungrounded static preview with the original animated sheep.
	get_parent().get_node("Sheep").hide()
	sheep = OriginalSheep.new()
	sheep.name = "Sheep"
	sheep.definition = data["sheep"]
	var p = data["sheep"]["pos"]
	sheep.position = GameSpace.from_export(Vector3(p[0],p[1],p[2]))
	sheep.rotation.y = deg_to_rad(float(data["sheep"]["rot_deg"][1]))
	add_child(sheep)
	player.respawned.connect(sheep.reset_to_home)
	goal = data["goal"]
	p = goal["pos"]
	var origin = GameSpace.from_export(Vector3(p[0],p[1],p[2]))
	var box = goal["box"]
	lo = GameSpace.original_point(Vector3(box["min"][0],box["max"][1],box["max"][2]))+origin
	hi = GameSpace.original_point(Vector3(box["max"][0],box["min"][1],box["min"][2]))+origin
	bounds = AABB(lo,hi-lo)
	radius = floorf(float(box["max"][0])*90/128)*.01

func qualifies(point: Vector3, require_box: bool) -> bool:
	var p = goal["pos"]
	var origin = GameSpace.from_export(Vector3(p[0],p[1],p[2]))
	return point.y >= bounds.position.y and point.y <= bounds.end.y and Vector2(point.x-origin.x,point.z-origin.z).length_squared() <= radius*radius and (not require_box or (point.x >= bounds.position.x and point.x <= bounds.end.x and point.z >= bounds.position.z and point.z <= bounds.end.z))

func _physics_process(_delta: float) -> void:
	if completed or player.cinematic_controls_locked or player.tutorial_movement_locked: return
	if qualifies(player.global_position,true) and qualifies(sheep.goal_position(),false):
		completed = true
		get_parent().get_node("CameraTraining").voice.stop()
		get_parent().get_node("CameraTraining").card.hide()
		completion = preload("res://scripts/levels/original_level_completion.gd").new()
		get_parent().add_child(completion)
		completion.begin("lvl_00",sheep)
		level_completed.emit()
