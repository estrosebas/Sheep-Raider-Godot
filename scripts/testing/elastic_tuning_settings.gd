extends RefCounted

# Development tuning is separate from checkpoint/progress and language config.
static var path = "user://elastic_tuning.cfg"

static func identity(controller: Node) -> String:
	return str(controller.item.source_level) if controller.item else "lvl_03"

static func apply_saved(controller: Node):
	var config = ConfigFile.new()
	if config.load(path)!=OK: return
	controller.apply_tuning(config.get_value(identity(controller),"values",{}))

static func save_values(controller: Node,values: Dictionary) -> Error:
	var config = ConfigFile.new(); config.load(path)
	config.set_value(identity(controller),"values",values)
	return config.save(path)

static func native_values(controller: Node) -> Dictionary:
	var props: Dictionary = controller.definition.get("props",{})
	return {"max_length":float(props.get("0xc",1150))*.01,
		"two_anchor_max_length":float(props.get("0xc",1150))*.01,
		"projection_distance":float(props.get("0x0",5000))*.01,
		"projection_height":float(props.get("0x4",500))*.01,
		"projection_speed":float(props.get("0x10",2000))*.01,
		"full_charge_threshold":1.0,"minimum_launch_charge":0.0,
		"automatic_launch_hold":1.0,"return_speed":6.14,"spring_strength":1.0}

static func level_values(controller: Node) -> Dictionary:
	var values = native_values(controller)
	var fields = {"projection_distance":"distance","projection_height":"height","projection_speed":"speed"}
	for key in values:
		var source_key = fields.get(key,key)
		if controller.definition.has(source_key): values[key] = controller.definition[source_key]
	return values
