extends RefCounted

# Port of progress_inventory.cpp. Identifiers/data only; no scene or input.
signal changed
signal selection_changed(class_id: int)
signal rolled_back(items: Array)
const NONE = 0xffff
const CLASS_COUNT = 200
var items: Dictionary = {}
var selected_class: int = NONE
var wheel_side: int = 0

func add(item: Dictionary) -> bool:
	var id = str(item.get("id", ""))
	var kind = int(item.get("class_id", NONE))
	if id.is_empty() or kind < 0 or kind >= CLASS_COUNT or items.has(id):
		return false
	items[id] = item.duplicate(true)
	changed.emit()
	return true

func remove(id: String) -> bool:
	if not items.has(id):
		return false
	var kind = int(items[id]["class_id"])
	items.erase(id)
	if selected_class == kind and count_class(kind) == 0:
		clear_selection()
	changed.emit()
	return true

func count_class(kind: int) -> int:
	var count = 0
	for item in items.values():
		if int(item["class_id"]) == kind:
			count += 1
	return count

func next_class(kind: int) -> int:
	for candidate in range(0 if kind == NONE else kind + 1, CLASS_COUNT):
		if count_class(candidate) > 0:
			return candidate
	return NONE

func prev_class(kind: int) -> int:
	# Original empty-hands reverse scan ends at class 1.
	for candidate in range(CLASS_COUNT - 1 if kind == NONE else kind - 1, 0 if kind == NONE else -1, -1):
		if count_class(candidate) > 0:
			return candidate
	return NONE

func select_class(kind: int) -> void:
	selected_class = kind if count_class(kind) > 0 else NONE
	selection_changed.emit(selected_class)

func clear_selection() -> void:
	select_class(NONE)

func get_selected_object() -> Dictionary:
	return get_class_object(selected_class)

func get_class_object(kind: int) -> Dictionary:
	# Original lists push pickups to the front.
	var keys = items.keys()
	keys.reverse()
	for id in keys:
		if int(items[id]["class_id"]) == kind:
			return items[id].duplicate(true)
	return {}

func select_next() -> void:
	var next = next_class(selected_class)
	if next != selected_class:
		if next_class(next) == selected_class:
			if selected_class != NONE:
				wheel_side = 0
				selected_class = next
			elif wheel_side != 0:
				wheel_side = 0
				selected_class = next
			else:
				wheel_side = 1
		else:
			selected_class = next
		selection_changed.emit(selected_class)

func select_prev() -> void:
	var prev = prev_class(selected_class)
	if prev != selected_class:
		if prev_class(prev) == selected_class:
			if selected_class != NONE:
				wheel_side = 1
				selected_class = prev
			elif wheel_side != 0:
				wheel_side = 0
			else:
				selected_class = prev
		else:
			selected_class = prev
		selection_changed.emit(selected_class)

func commit_at_checkpoint() -> void:
	for id in items:
		items[id]["kept"] = true

func drop_uncommitted() -> Array:
	var dropped: Array = []
	for id in items.keys():
		if not bool(items[id].get("kept", false)):
			dropped.append(items[id].duplicate(true))
			remove(id)
	rolled_back.emit(dropped)
	return dropped

func reset() -> void:
	items.clear()
	wheel_side = 0
	clear_selection()
	changed.emit()
