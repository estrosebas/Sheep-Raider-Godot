extends GameItem
class_name OriginalElasticItem

@export_file("*.tscn") var original_scene = "res://assets/levels/lvl_03/models/21/worn.tscn"
var source_level = "lvl_03"
var elastic_definition: Dictionary = {}
var original_visual: OriginalCinematicActor
var controller: Node3D

func _init(): class_id = 42

func _ready():
	super._ready()
	if visual: visual.hide()
	original_visual = load(original_scene).instantiate(); add_child(original_visual)
	original_visual.idle("stand")
	icon_path = "res://assets/ui/inventory/icon_42.png"
	controller = preload("res://scripts/items/original_elastic_controller.gd").new()
	controller.name = "ElasticController"; controller.item = self
	controller.definition = elastic_definition
	add_child(controller)
	reload_localization()

func _update_held_position():
	if holder is RalphController:
		global_transform = holder.skeleton.global_transform*holder.legacy_skin.last_matrices[18]
		global_basis *= GameSpace.EXPORT_TO_GODOT
	else: super._update_held_position()

func use_item(actor: Node3D) -> Dictionary:
	for tree in get_tree().get_nodes_in_group("elastic_trees"):
		if tree.get_world_3d()==get_world_3d() and tree.nearby(actor):
			return {"success":controller.tree_action(tree,actor),"consumed":false}
	return {"success":false,"consumed":false}

func store():
	if controller and controller.mode!="item": return
	super.store()

func restore():
	if controller: controller.reset_item()
	super.restore()
	if original_visual: original_visual.show()

func reload_localization():
	item_label = GameLocalization.text(source_level,43,0).split(":")[0].capitalize()
