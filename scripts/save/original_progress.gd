extends RefCounted
class_name OriginalProgress

# Progress::AwardTimeKeeper: one bit per level, one bonus (two in Lvl-16).
# Runtime survives death/scene changes; manual slots and victory autosave persist it.
const TOTAL_SHEEP = 17
static var completed_levels: Dictionary = {}
static var completion_unsaved = false
static var clocks: Array[String] = []
static var bonus_count = 0
static var bonus_points = 0
static var timekeeper_unsaved = false
static var bonus_flags = 0
static var bonus_unsaved = false

static func bonus_unlocked(index: int) -> bool:
	return index in range(8) and bool(bonus_flags & (1<<index))

static func buy_bonus(index: int,price: int) -> bool:
	if index not in range(8) or price<=0 or bonus_unlocked(index) or bonus_points<price: return false
	bonus_points -= price
	bonus_flags |= 1<<index
	bonus_unsaved = true
	return true

static func has_clock(level: String) -> bool: return clocks.has(level)

static func award_clock(level: String) -> bool:
	if has_clock(level): return false
	clocks.append(level)
	var amount = 2 if level == "lvl_16" else 1
	bonus_count += amount
	bonus_points += amount
	timekeeper_unsaved = true
	return true

static func snapshot() -> Dictionary:
	return {"clocks":clocks.duplicate(),"bonus_count":bonus_count,"bonus_points":bonus_points,"bonus_flags":bonus_flags,"completed_levels":completed_levels.duplicate(),"sheep_extracted":extracted_sheep_count()}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or not value.get("clocks") is Array: return false
	for level in value["clocks"]:
		if not level is String or not level.begins_with("lvl_"): return false
	var completed = value.get("completed_levels",{})
	if not completed is Dictionary: return false
	var flags = value.get("bonus_flags",0)
	if not flags is int and not flags is float: return false
	if not is_finite(float(flags)) or float(flags)!=int(flags) or int(flags)<0 or int(flags)>255: return false
	for level in completed:
		if not valid_level(level) or not completed[level] is bool: return false
	return (value.get("bonus_count") is float or value.get("bonus_count") is int) and (value.get("bonus_points") is float or value.get("bonus_points") is int)

static func restore(value: Dictionary) -> void:
	completed_levels.clear()
	completion_unsaved = false
	clocks.clear()
	bonus_count = 0
	bonus_points = 0
	bonus_flags = 0; bonus_unsaved = false
	if valid(value):
		for level in value["clocks"]:
			if not clocks.has(level): clocks.append(level)
		completed_levels = value.get("completed_levels",{}).duplicate()
		bonus_count = maxi(0,int(value["bonus_count"]))
		bonus_points = maxi(0,int(value["bonus_points"]))
		bonus_flags = int(value.get("bonus_flags",0))
	timekeeper_unsaved = false

static func valid_level(level: String) -> bool:
	for i in range(18):
		if level == "lvl_%02d" % i: return true
	return false

static func is_completed(level: String) -> bool:
	return completed_levels.get(level,false)

static func is_level_unlocked(level: String) -> bool:
	if not valid_level(level): return false
	var index = int(level.trim_prefix("lvl_"))
	# The introductory tutorial is optional; the first regular level is open.
	# Completed levels remain replayable, including older saves which only
	# contain that level's completion flag.
	return index <= 1 or is_completed(level) or is_completed("lvl_%02d"%(index-1))

static func complete_level(level: String) -> bool:
	if not valid_level(level) or is_completed(level): return false
	completed_levels[level] = true
	completion_unsaved = true
	return true

static func extracted_sheep_count() -> int:
	# Progress::sheepToCatch starts at0x11. Scene level17 is the ending.
	var count = 0
	for i in range(TOTAL_SHEEP):
		if is_completed("lvl_%02d" % i): count += 1
	return count

static func remaining_sheep_count() -> int:
	return TOTAL_SHEEP-extracted_sheep_count()
