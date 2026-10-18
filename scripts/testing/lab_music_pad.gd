extends Area3D
class_name LabMusicPad

var music: OriginalMusicSegment
var track: Dictionary = {}
var material: StandardMaterial3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(3.8,.8,2.5)
	shape.position.y = .4
	add_child(shape)
	var tile = MeshInstance3D.new()
	tile.mesh = BoxMesh.new()
	tile.mesh.size = Vector3(4,.035,2.7)
	tile.position.y = .018
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tile.material_override = material
	add_child(tile)
	var text = "DETENER" if track.is_empty() else str(track.title).replace("_","\n").to_upper()
	text = text.replace("JUNGLERHODES01","JUNGLE\nRHODES01").replace("JUNGLETUTORIAL","JUNGLE\nTUTORIAL")
	var label = LabFloorLabel.create(text,Vector3(0,.055,0),30)
	var width = 1.0
	for line in text.split("\n"):
		width = maxf(width,label.font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size).x)
	label.pixel_size = minf(label.pixel_size,3.6/width)
	add_child(label)
	body_entered.connect(_on_body_entered)
	music.selection_changed.connect(_update_selection)
	_update_selection(music.selected)

func _on_body_entered(body: Node3D) -> void:
	if not body is RalphController or not body.can_use_item(): return
	if track.is_empty(): music.stop_selection()
	else: music.play_segment(track)

func _update_selection(selected: Dictionary) -> void:
	var active = selected.get("id","") == track.get("id","")
	material.albedo_color = Color(.18,.55,.3) if active else Color(.08,.13,.2)
