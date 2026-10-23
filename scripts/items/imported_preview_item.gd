extends GameItem
# Import-stage adapter: delivery/pickup/inventory work; the item's exclusive
# effect is intentionally absent until its native controller is implemented.
var original_scene = ""
var original_visual: OriginalCinematicActor
var source_level = ""
var native_text_list = 0
func _ready():
	super._ready()
	set_meta("prototype_only",true)
	reload_localization()
	var icon = "res://assets/ui/inventory/icon_%d.png"%class_id
	if ResourceLoader.exists(icon): icon_path = icon
	original_visual = load(original_scene).instantiate(); add_child(original_visual)
	original_visual.sample_animation("objet",0)
func reload_localization():
	item_label = GameLocalization.text(source_level,native_text_list,0).split("\n")[0].trim_suffix(":")
func equip_to(actor: Node3D):
	super.equip_to(actor)
	original_visual.sample_animation("link",0)
func restore():
	super.restore()
	original_visual.sample_animation("objet",0)
func _update_held_position():
	if holder is RalphController:
		global_transform = holder.skeleton.global_transform*holder.legacy_skin.last_matrices[18]
		global_basis *= GameSpace.EXPORT_TO_GODOT
	else: super._update_held_position()
