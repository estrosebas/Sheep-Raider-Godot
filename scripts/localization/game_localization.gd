extends RefCounted
class_name GameLocalization

# Shared scene/assets; only text and voice directories depend on locale.
const MANIFEST = "res://assets/localization/manifest.json"
static var locale = "es"
static var config_path = "user://language.cfg"
static var initialized = false
static var language_selected = false
static var manifest: Dictionary = {}
static var banks: Dictionary = {}
static var ui_strings: Dictionary = {}
static var loading_enabled = true
static var loading_style = "classic"

static func ensure() -> void:
	if initialized: return
	initialized = true
	language_selected = false
	manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	ui_strings = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/ui.json"))
	var settings = ConfigFile.new()
	if settings.load(config_path) == OK:
		var saved = str(settings.get_value("language","locale",""))
		if manifest.languages.has(saved):
			locale = saved
			language_selected = true
		loading_enabled = bool(settings.get_value("loading","enabled",true))
		loading_style = str(settings.get_value("loading","style","classic"))
		if loading_style not in ["classic","modern"]: loading_style = "classic"
	TranslationServer.set_locale(locale)

static func select(code: String, persist: bool = true) -> bool:
	ensure()
	if not manifest.languages.has(code): return false
	locale = code
	banks.clear()
	TranslationServer.set_locale(code)
	if persist:
		var settings = ConfigFile.new()
		settings.load(config_path) # Preserve other options stored beside language.
		settings.set_value("language","locale",locale)
		var saved = settings.save(config_path) == OK
		if saved: language_selected = true
		return saved
	return true

static func save_loading(enabled: bool,style: String) -> bool:
	ensure()
	loading_enabled = enabled; loading_style = style if style in ["classic","modern"] else "classic"
	var settings = ConfigFile.new(); settings.load(config_path)
	settings.set_value("loading","enabled",loading_enabled)
	settings.set_value("loading","style",loading_style)
	return settings.save(config_path)==OK

static func resolve(path: String) -> String:
	ensure()
	var variants: Dictionary = manifest.files.get(path,{})
	var candidate: String = variants.get(locale,variants.get(manifest.fallback,path))
	return candidate if FileAccess.file_exists(candidate) else path

static func load_data(path: String) -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string(resolve(path)))
	return value if value is Dictionary else {}

static func text(level: String, list_id: int, index: int) -> String:
	ensure()
	var variants: Dictionary = manifest.levels.get(level,{})
	var path: String = variants.get(locale,variants.get(manifest.fallback,""))
	if path.is_empty(): return ""
	if not banks.has(path): banks[path] = JSON.parse_string(FileAccess.get_file_as_string(path))
	var lists: Array = banks[path].lists
	if list_id < 0 or list_id >= lists.size() or index < 0 or index >= lists[list_id].size(): return ""
	return lists[list_id][index]

static func voice_path(identity: int) -> String:
	ensure()
	var path: String = manifest.languages[locale].voices.get(str(identity),"")
	# Imported WAVs are remapped resources inside the exported pack.
	if ResourceLoader.exists(path): return path
	return manifest.languages[manifest.fallback].voices.get(str(identity),"")

static func ui(message: String) -> String:
	ensure()
	return ui_strings.get(locale,{}).get(message,message)
