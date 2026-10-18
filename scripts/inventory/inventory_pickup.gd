extends Node3D

@export var item_id = ""
@export_range(0, 199) var class_id = 10
@export var item_label = "Cohete"
@export_file("*.png", "*.svg") var icon_path = ""
@export var kept = false
var available = true

func _ready() -> void:
	add_to_group("inventory_pickups")
	if item_id.is_empty():
		item_id = str(get_path())

func collect(inventory: Node) -> bool:
	if not available:
		return false
	if not inventory.add_item({"id": item_id, "class_id": class_id,
		"label": item_label, "icon": icon_path, "kept": kept}, self):
		return false
	available = false
	hide()
	return true

func restore() -> void:
	available = true
	show()
