extends CanvasLayer
# Shared onboarding and H help for the studio, every level and touch devices.
const COPY = {
	"es":["CONTROLES", "W A S D: moverse\nRatón: cámara\nEspacio: saltar / doble salto\nShift: correr\nCtrl (C en web): sigilo\nTab: inventario · Flechas: elegir objeto\nE: interactuar · R: usar objeto\nEsc: pausa · F5: idioma\nH: mostrar u ocultar esta ayuda", "Palanca izquierda: moverse\nArrastra a la derecha: cámara\nToca los iconos para saltar, correr e interactuar.\nSigilo: un toque activa y otro desactiva.\nInventario: un toque abre y otro cierra.\nCon el inventario abierto, mueve la palanca\na los lados o toca las flechas para elegir.\n?: ayuda · Globo: idioma · Ⅱ: pausa", "Cerrar ayuda"],
	"en":["CONTROLS", "W A S D: move\nMouse: camera\nSpace: jump / double jump\nShift: run\nCtrl (C on web): sneak\nTab: inventory · Arrows: select item\nE: interact · R: use item\nEsc: pause · F5: language\nH: show or hide this help", "Left stick: move\nDrag on the right: camera\nTap the icons to jump, run and interact.\nSneak: tap to switch on or off.\nInventory: tap to open or close.\nWhile the inventory is open, move the stick\nleft/right or tap the arrows to select an item.\n?: help · Globe: language · Ⅱ: pause", "Close help"],
	"it":["COMANDI", "W A S D: muoversi\nMouse: telecamera\nSpazio: salto / doppio salto\nShift: correre\nCtrl (C sul web): furtività\nTab: inventario · Frecce: scegliere\nE: interagire · R: usare oggetto\nEsc: pausa · F5: lingua\nH: mostrare o nascondere questa guida", "Leva sinistra: muoversi\nTrascina a destra: telecamera\nTocca le icone per saltare, correre e interagire.\nFurtività: tocca per attivare o disattivare.\nInventario: tocca per aprire o chiudere.\nCon l’inventario aperto, muovi la leva\no tocca le frecce per scegliere un oggetto.\n?: guida · Globo: lingua · Ⅱ: pausa", "Chiudi guida"],
	"pt_BR":["CONTROLES", "W A S D: mover\nMouse: câmera\nEspaço: salto / salto duplo\nShift: correr\nCtrl (C na web): furtividade\nTab: inventário · Setas: escolher\nE: interagir · R: usar objeto\nEsc: pausa · F5: idioma\nH: mostrar ou ocultar esta ajuda", "Alavanca esquerda: mover\nArraste à direita: câmera\nToque nos ícones para saltar, correr e interagir.\nFurtividade: toque para ativar ou desativar.\nInventário: toque para abrir ou fechar.\nCom o inventário aberto, mova a alavanca\nou toque nas setas para escolher um objeto.\n?: ajuda · Globo: idioma · Ⅱ: pausa", "Fechar ajuda"]
}
var dialog: Control
var prior_pause = false
var prior_mouse = Input.MOUSE_MODE_VISIBLE
var config_path = ""
var automatic = true
var acknowledged = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 390
	add_to_group("first_run_help")
	if config_path.is_empty(): config_path = GameLocalization.config_path
	var settings = ConfigFile.new()
	if settings.load(config_path)==OK: acknowledged = bool(settings.get_value("onboarding","controls_seen",false))
	if DisplayServer.get_name()=="headless": automatic = false

func _process(_delta):
	if not automatic or acknowledged or is_instance_valid(dialog) or get_tree().paused: return
	var language = get_node_or_null("/root/LanguageMenu")
	if language and (language.transitioning or language.overlay): return
	var player = get_tree().get_first_node_in_group("player")
	if not player or player.cinematic_controls_locked or player.tutorial_movement_locked: return
	if not get_tree().get_nodes_in_group("update_launcher").is_empty(): return
	open_help()

func toggle():
	if is_instance_valid(dialog): close_help()
	elif get_tree().get_first_node_in_group("player"): open_help()

func open_help():
	if is_instance_valid(dialog): return
	prior_pause = get_tree().paused
	prior_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_to_group("update_launcher")
	var controls = get_node_or_null("/root/MobileControls")
	if controls: controls.release_all()
	var words: Array = COPY.get(GameLocalization.locale,COPY.en)
	dialog = ColorRect.new()
	dialog.color = Color(.015,.025,.05,.94)
	add_child(dialog); dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center = CenterContainer.new()
	dialog.add_child(center); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",16)
	center.add_child(box)
	var title = Label.new(); title.text = words[0]
	title.add_theme_font_size_override("font_size",30)
	box.add_child(title)
	var body = Label.new()
	body.text = words[2 if controls and controls.enabled else 1]
	body.add_theme_font_size_override("font_size",23)
	box.add_child(body)
	var close = Button.new(); close.text = words[3]
	close.custom_minimum_size.y = 58
	close.add_theme_font_size_override("font_size",23)
	close.pressed.connect(close_help)
	box.add_child(close); close.grab_focus()

func close_help():
	if not is_instance_valid(dialog): return
	acknowledged = true
	var settings = ConfigFile.new(); settings.load(config_path)
	settings.set_value("onboarding","controls_seen",true)
	settings.save(config_path)
	dialog.queue_free(); dialog = null
	remove_from_group("update_launcher")
	get_tree().paused = prior_pause
	Input.mouse_mode = prior_mouse
