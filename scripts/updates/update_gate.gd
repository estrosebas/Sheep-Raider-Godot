extends Control
# Stable launcher UI; avoid gameplay references until the early pack is mounted.
var updater: Node
var status: Label
var details: Label
var bar: ProgressBar
var primary: Button
var play: Button
var result: Dictionary = {}
var entering = false
var language = "es"
const WORDS = {
	"es":{"checking":"Buscando actualizaciones…","available":"Actualización disponible","downloading":"Descargando…","verifying":"Verificando archivos…","restart_required":"Actualización instalada. Reinicia para aplicarla.","unavailable":"No se pudo consultar o verificar la actualización. Puedes jugar con tu versión actual.","incompatible":"Esta actualización necesita una nueva versión base del juego.","play":"Jugar","download":"Descargar actualización","restart":"Reiniciar juego","close":"Cerrar y volver a abrir","title":"SHEEP RAIDER","rollback":"Se recuperó la versión anterior."},
	"en":{"checking":"Checking for updates…","available":"Update available","downloading":"Downloading…","verifying":"Verifying files…","restart_required":"Update installed. Restart to apply.","unavailable":"Update unavailable or invalid. You can play your current version.","incompatible":"This update requires a newer game installation.","play":"Play","download":"Download update","restart":"Restart game","close":"Close and reopen","title":"SHEEP RAIDER","rollback":"Previous version restored."},
}

func word(key: String) -> String: return WORDS.get(language,WORDS.es).get(key,key)

func _ready():
	add_to_group("update_launcher")
	updater=get_node("/root/ContentUpdates")
	var saved=ConfigFile.new()
	if saved.load("user://language.cfg")==OK: language=str(saved.get_value("language","locale","es"))
	if not updater.supported(): call_deferred("enter_game"); return
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var background=ColorRect.new(); background.color=Color(.025,.035,.07); background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(background); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin=MarginContainer.new(); add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,36)
	var center=CenterContainer.new(); margin.add_child(center)
	var box=VBoxContainer.new(); box.custom_minimum_size=Vector2(600,0); box.add_theme_constant_override("separation",22); center.add_child(box)
	box.add_theme_font_size_override("font_size",26)
	var title=Label.new(); title.text=word("title"); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",42); box.add_child(title)
	status=Label.new(); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; box.add_child(status)
	details=Label.new(); details.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; box.add_child(details)
	bar=ProgressBar.new(); bar.max_value=1; bar.custom_minimum_size.y=24; box.add_child(bar); bar.hide()
	primary=Button.new(); primary.custom_minimum_size.y=64; primary.pressed.connect(activate); box.add_child(primary); primary.hide()
	play=Button.new(); play.custom_minimum_size.y=64; play.text=word("play"); play.pressed.connect(enter_game); box.add_child(play)
	updater.status_changed.connect(show_status)
	show_status("checking")
	result=await updater.check_update()
	if not is_inside_tree() or entering: return
	if result.state in ["disabled","current"]: enter_game(); return
	show_status(result.state)
	if result.state=="available":
		details.text="%s · %.1f MB"%[result.version,float(result.bytes)/1048576.0]
		primary.text=word("download"); primary.show()
	elif not updater.recovery_message.is_empty(): details.text=word("rollback")

func show_status(value: String):
	if not status: return
	status.text=word(value)
	bar.visible=value in ["downloading","verifying"]

func activate():
	if updater.state=="restart_required": updater.restart(); return
	primary.hide(); play.disabled=true
	result=await updater.download_update()
	play.disabled=false
	show_status(result.state)
	if result.state=="restart_required":
		primary.text=word("restart" if OS.has_feature("windows") else "close"); primary.show()
		# Current process keeps its old resource graph. Only a cold launch mounts
		# the downloaded pack, preventing mixed versions of preloaded scripts.
		play.hide()

func _process(_delta):
	if bar and updater: bar.value=updater.progress()

func enter_game():
	if entering: return
	entering=true
	if is_instance_valid(updater.request_node) and updater.state=="checking": updater.request_node.cancel_request()
	var scene=load(str(updater.config.get("game_scene","res://scenes/startup/LanguageWheel.tscn"))) as PackedScene
	if not scene:
		entering=false
		if status: status.text="No se pudo iniciar. Cierra y vuelve a abrir para recuperar la versión anterior."
		return
	var instance=scene.instantiate()
	get_tree().root.add_child(instance); get_tree().current_scene=instance
	# The language wheel has completed _ready. Confirm only its real startup.
	if instance.get("wheel")!=null: updater.confirm_boot()
	queue_free()
