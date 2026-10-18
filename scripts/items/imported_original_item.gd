extends GameItem
# Importable native item before its exclusive usage mechanic is ported.
@export_file("*.tscn") var original_scene
@export var source_level = "lvl_03"
var original_visual: OriginalCinematicActor
func _ready():
	super._ready()
	original_visual = load(original_scene).instantiate(); add_child(original_visual)
	original_visual.idle("objet" if original_visual.rig.animations.has("objet") else "stand")
	icon_path = "res://assets/ui/inventory/icon_%d.png"%class_id
	reload_localization()
func reload_localization():
	var help = GameLocalization.text(source_level,class_id+1,0)
	item_label = help.split(":")[0].capitalize()
