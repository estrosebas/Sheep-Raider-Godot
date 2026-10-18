extends Node3D
# Port-only invisible boundary around the initial rock. Layer 8 affects Ralph
# but not the manual camera or the pushable stone's two authored axes.
@export var opening_width = 2.1
@export var opening_height = 2.2
@export var wall_depth = .6
@export var side_extent = 13.0
@export var wall_height = 10.0

func _ready():
	var player = get_parent().player
	var rock = get_parent().get_node("Rock_49")
	position = GameSpace.from_export(Vector3(rock.definition.pos[0],0,rock.definition.pos[2]))
	player.collision_mask |= 8
	add_wall("LeftBypass",Vector3(0,wall_height/2,-opening_width/2-side_extent/2),Vector3(wall_depth,wall_height,side_extent))
	add_wall("RightBypass",Vector3(0,wall_height/2,opening_width/2+side_extent/2),Vector3(wall_depth,wall_height,side_extent))
	add_wall("OverRock",Vector3(0,(opening_height+wall_height)/2,0),Vector3(wall_depth,wall_height-opening_height,opening_width))

func add_wall(label: String,point: Vector3,extent: Vector3):
	var body = StaticBody3D.new(); body.name = label
	body.collision_layer = 8; body.collision_mask = 0
	body.set_meta("run_impact_exempt",true)
	var shape = BoxShape3D.new(); shape.size = extent
	var collider = CollisionShape3D.new(); collider.shape = shape
	body.add_child(collider); add_child(body); body.position = point
