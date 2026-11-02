extends Node
# Native PRINTSBOX and sheet6; permanent ring of128 prints, alternating frames.
var data: Dictionary
var player: RalphController
var prints: Array[Sprite3D] = []
var distance = 0.0
var previous = Vector3.ZERO
var cursor = 0
func _ready():
	player = get_parent().player; previous = player.global_position
func _physics_process(_delta: float):
	var current = player.global_position
	var moved = Vector2(current.x-previous.x,current.z-previous.z).length(); previous = current
	if player.cinematic_controls_locked or not player.is_on_floor() or player.item_costume=="sheep" or player.current_state in [player.WolfState.PIT_FALL,player.WolfState.SAM_DEATH,player.WolfState.BLAST_DEATH] or not OriginalSam.contains(current,data.print_zones): distance = 0; return
	if moved>3: distance = 0; return
	# Do not draw on props inside a print volume; native RECENT_OBJECT_CONTACT.
	var query = PhysicsRayQueryParameters3D.create(current+Vector3.UP*.1,current-Vector3.UP*.3,1)
	query.exclude = [player.get_rid()]
	var hit = player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider!=get_parent().get_node("Collision") or hit.normal.y<.91: distance = 0; return
	distance += moved
	if distance>=1.5:
		distance = fmod(distance,1.5); stamp(hit.position,player.item_facing(),hit.normal)
func stamp(point: Vector3,facing: Vector3,normal = Vector3.UP):
	var print: Sprite3D
	if prints.size()<128:
		print = Sprite3D.new(); print.shaded = false; print.double_sided = true
		print.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; print.no_depth_test = false
		get_parent().add_child(print); prints.append(print)
	else: print = prints[cursor%128]
	print.texture = load(data.sprites.prints[cursor%data.sprites.prints.size()])
	print.pixel_size = .6/print.texture.get_width()
	var right = facing.cross(normal).normalized()
	if right.is_zero_approx(): right = Vector3.RIGHT
	print.global_transform = Transform3D(Basis(right,right.cross(normal).normalized(),normal),point+normal*.015)
	cursor += 1
