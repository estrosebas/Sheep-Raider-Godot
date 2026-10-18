extends RefCounted
class_name ItemCatalog

const CLASSES = {
	2: preload("res://scripts/items/dynamite_item.gd"),
	3: preload("res://scripts/items/lettuce_item.gd"),
	7: preload("res://scripts/items/fan_item.gd"),
	10: preload("res://scripts/items/rocket_item.gd"),
	39: preload("res://scripts/items/perfume_item.gd"),
	41: preload("res://scripts/items/flute_item.gd"),
	42: preload("res://scripts/items/original_elastic_item.gd"),
	66: preload("res://scripts/items/magnet_item.gd"),
	80: preload("res://scripts/items/sheep_costume_item.gd"),
	125: preload("res://scripts/items/ghost_costume_item.gd")
}

static func create_item(kind: int, id: String = "") -> GameItem:
	if not CLASSES.has(kind):
		return null
	var item: GameItem = CLASSES[kind].new()
	item.class_id = kind
	item.item_id = id
	return item

static func definition(kind: int) -> Dictionary:
	var definitions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/definitions.json"))
	return definitions.get(str(kind), {}).duplicate(true)
