extends Node3D
class_name OriginalElasticTree

# ElasticTree::MSG_ELASTICTREE_GET_INFO. The destination is BOX.min, not its centre.
var definition: Dictionary = {}
var visual_scene = "res://assets/levels/lvl_03/models/10/worn.tscn"
var pull_up_point = Vector3.ZERO
var restriction = 0

func _ready():
	add_to_group("elastic_trees")
	add_to_group("world_interactables")
	add_child(load(visual_scene).instantiate())
	if definition.has("pull_up_point"):
		var p = definition.pull_up_point
		pull_up_point = GameSpace.original_point(Vector3(p[0],p[1],p[2]))
	restriction = int(definition.get("restriction",0))

func anchor() -> Vector3: return global_position+Vector3.UP*.8

func nearby(actor: Node3D) -> bool:
	var d = actor.global_position-global_position
	return absf(d.y)<=1.28 and Vector2(d.x,d.z).length_squared()<=.8*.8

func relevant(actor: RalphController):
	if actor.inventory.equipped_node is OriginalElasticItem: return actor.inventory.equipped_node.controller
	for controller in get_tree().get_nodes_in_group("elastic_controllers"):
		if controller.get_world_3d()==get_world_3d() and controller.accepts_tree(self,actor): return controller
	return null

func can_interact(actor: RalphController) -> bool:
	return not is_instance_valid(actor.carried_sheep) and nearby(actor) and relevant(actor)!=null

func interact(actor: RalphController) -> bool:
	var controller = relevant(actor)
	return controller.tree_action(self,actor) if controller else false

func action_label(actor: RalphController) -> String:
	var controller = relevant(actor)
	return GameLocalization.text("lvl_03",0,58 if controller and controller.has_anchor(self) else 54)
