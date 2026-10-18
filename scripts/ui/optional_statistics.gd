extends CanvasLayer
# Loaded by the existing mutable LanguageMenu bridge: no new binary/autoload needed.
const ENDPOINT = "https://sheepraider.nooxtools.me/api/stats/events"
const PATH = "user://privacy.cfg"
const COPY = {
	"es":["Estadísticas opcionales", "¿Quieres ayudar a mejorar el juego? Si aceptas, enviaremos una vez por apertura la plataforma (PC, Android o web) y la versión. No enviamos nombres, partidas, IP ni identificadores del dispositivo en estas estadísticas. No contamos personas únicas. Puedes cambiar esta decisión en Pausa > Opciones > Privacidad. Rechazar no afecta al juego ni a sus actualizaciones.", "Aceptar", "Rechazar", "Privacidad"],
	"en":["Optional statistics", "Help improve the game? If you agree, each launch sends your platform (PC, Android or web) and game version. These statistics contain no names, saves, IP addresses or device IDs. We do not count unique people. Change your choice in Pause > Options > Privacy. Declining does not affect gameplay or updates.", "Accept", "Decline", "Privacy"],
	"it":["Statistiche facoltative", "Vuoi aiutarci a migliorare il gioco? Con il tuo consenso inviamo piattaforma (PC, Android o web) e versione una volta per avvio. Le statistiche non includono nomi, salvataggi, IP o identificativi del dispositivo. Non contiamo persone uniche. Puoi cambiare scelta in Pausa > Opzioni > Privacy. Rifiutare non modifica il gioco o gli aggiornamenti.", "Accetta", "Rifiuta", "Privacy"],
	"pt_BR":["Estatísticas opcionais", "Quer ajudar a melhorar o jogo? Ao aceitar, enviamos a plataforma (PC, Android ou web) e a versão uma vez por abertura. Estas estatísticas não incluem nomes, partidas, IP ou identificadores do dispositivo. Não contamos pessoas únicas. Altere em Pausa > Opções > Privacidade. Recusar não afeta o jogo nem suas atualizações.", "Aceitar", "Recusar", "Privacidade"]
}
var choice = "unknown"
var config_path = PATH
var endpoint = ENDPOINT
var session_sent = false
var dialog: Control
var request: HTTPRequest
var prior_pause = false
var prior_mouse = Input.MOUSE_MODE_VISIBLE

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 400
	add_to_group("optional_statistics")
	var settings = ConfigFile.new()
	if settings.load(config_path)==OK and settings.get_value("statistics","policy",0)==1:
		choice = str(settings.get_value("statistics","choice","unknown"))
	if choice not in ["accepted","declined"]: choice = "unknown"
	if choice=="accepted": call_deferred("send_session")

func words() -> Array:
	return COPY.get(GameLocalization.locale,COPY.en)

func open_if_needed():
	if choice=="unknown": open_preferences()

func open_preferences():
	if is_instance_valid(dialog): return
	prior_pause = get_tree().paused
	prior_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Shared touch controls must pass these native GUI buttons through untouched.
	add_to_group("update_launcher")
	dialog = ColorRect.new()
	dialog.color = Color(0.015,0.025,0.05,.94)
	add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center = CenterContainer.new()
	dialog.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box = VBoxContainer.new()
	box.custom_minimum_size.x = minf(680,get_viewport().get_visible_rect().size.x-48)
	box.add_theme_constant_override("separation",20)
	center.add_child(box)
	var title = Label.new()
	title.text = words()[0]
	title.add_theme_font_size_override("font_size",28)
	box.add_child(title)
	var body = Label.new()
	body.text = words()[1]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size",20)
	box.add_child(body)
	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation",20)
	box.add_child(buttons)
	for accepted in [true,false]:
		var button = Button.new()
		button.text = words()[2 if accepted else 3]
		button.custom_minimum_size = Vector2(150,56)
		button.pressed.connect(set_consent.bind(accepted))
		buttons.add_child(button)
	# No affirmative default: declining is the initial keyboard focus.
	buttons.get_child(1).grab_focus()

func set_consent(accepted: bool):
	choice = "accepted" if accepted else "declined"
	var settings = ConfigFile.new()
	settings.set_value("statistics","policy",1)
	settings.set_value("statistics","choice",choice)
	settings.save(config_path)
	if not accepted and is_instance_valid(request):
		request.cancel_request()
		request.queue_free()
		request = null
	if is_instance_valid(dialog):
		dialog.queue_free()
		dialog = null
		remove_from_group("update_launcher")
		get_tree().paused = prior_pause
		Input.mouse_mode = prior_mouse
	if accepted: send_session()

func send_session():
	if choice!="accepted" or session_sent: return
	# Editor runs and developer test scripts never inflate public counters.
	var local_test = OS.is_debug_build() and endpoint.begins_with("http://127.0.0.1:")
	if (OS.has_feature("editor") or DisplayServer.get_name()=="headless") and not local_test: return
	session_sent = true
	var platform = "web" if OS.has_feature("web") else ("android" if OS.has_feature("android") else "windows")
	var version = str(ProjectSettings.get_setting("application/config/version","unknown"))
	if FileAccess.file_exists("res://assets/updates/content_release.json"):
		var release = JSON.parse_string(FileAccess.get_file_as_string("res://assets/updates/content_release.json"))
		if release is Dictionary: version = str(release.get("version",version))
	request = HTTPRequest.new()
	request.timeout = 8
	add_child(request)
	request.request_completed.connect(func(_r,_c,_h,_b):
		if is_instance_valid(request): request.queue_free()
		request = null)
	var event = Crypto.new().generate_random_bytes(16).hex_encode()
	request.request(endpoint,["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify({"kind":"session","platform":platform,"version":version,"event":event,"consent":"v1"}))
