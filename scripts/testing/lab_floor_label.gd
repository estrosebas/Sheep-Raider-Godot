extends RefCounted
class_name LabFloorLabel

static func create(text: String, point: Vector3, font_size: int = 48) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.position = point
	label.rotation.x = -PI/2
	label.font = load(OriginalGameFont.PATH)
	label.font_size = font_size
	label.pixel_size = .016
	label.modulate = Color(2,1.7,.44,1)
	label.outline_modulate = Color.BLACK
	label.outline_size = 8
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return label
