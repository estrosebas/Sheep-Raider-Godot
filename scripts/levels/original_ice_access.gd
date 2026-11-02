extends Node
# The native Ralph solid is36cm wide; the general port capsule is70cm.
# Use native width in the tight spaces next to ice cubes, retaining terrain.
var player: RalphController
var capsule: CapsuleShape3D
var original_radius = .35
var prior_slide = 0.0
var prior_block = true
var applied = false
func _ready():
	player = get_parent().player
	var shape = player.get_node("CollisionShape3D")
	shape.shape = shape.shape.duplicate(); capsule = shape.shape
	original_radius = capsule.radius
	prior_slide = player.wall_min_slide_angle; prior_block = player.floor_block_on_wall
	process_physics_priority = -100
func _physics_process(_delta):
	var close = false
	for cube in get_tree().get_nodes_in_group("ice_cubes"):
		if cube.get_world_3d()!=player.get_world_3d(): continue
		var p = player.global_position-cube.global_position
		if absf(p.y)<1.2 and Vector2(p.x,p.z).length()<3.2: close = true; break
	if close:
		capsule.radius = .18
		player.wall_min_slide_angle = 0; player.floor_block_on_wall = false
		applied = true
	else: restore()
func restore():
	if not applied: return
	capsule.radius = original_radius
	player.wall_min_slide_angle = prior_slide; player.floor_block_on_wall = prior_block
	applied = false
func _exit_tree():
	if is_instance_valid(player): restore()
