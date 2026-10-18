extends Node
# Stable bootstrap: deliberately no gameplay class names, preloads or assets.
signal status_changed(message: String)
var config: Dictionary = {}
var platform_id = ""
var storage = "user://updates"
var active: Dictionary = {}
var offered: Dictionary = {}
var mounted = false
var recovery_message = ""
var state = "idle"
var last_error = ""
var request_node: HTTPRequest
var expected_bytes = 0
var test_mode = false

func _init():
	config = read_json("res://config/updates.json")
	# Test overrides are available only in editor/debug runtimes, never release.
	if OS.is_debug_build():
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--updates-test-config="):
				config.merge(read_json(argument.trim_prefix("--updates-test-config=")),true)
				test_mode = true
	storage = str(config.get("storage","user://updates"))
	platform_id = "android-arm64" if OS.has_feature("android") else "windows-x86_64" if OS.has_feature("windows") else "unsupported"
	if test_mode: platform_id = str(config.get("platform_override",platform_id))
	if not supported(): return
	DirAccess.make_dir_recursive_absolute(storage)
	_mount_installed()

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func supported() -> bool:
	return not OS.has_feature("web") and platform_id!="unsupported" and bool(config.get("enabled",false)) and (not OS.has_feature("editor") or test_mode or "--enable-updates" in OS.get_cmdline_user_args())

func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func atomic_json(path: String,value: Dictionary) -> bool:
	var file = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(value)); file.flush(); file.close()
	# POSIX rename replaces; Windows needs the old small pointer removed first.
	# The previous signed pointer remains independently recoverable.
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path)!=OK: return false
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func hash_file(path: String) -> String:
	var file = FileAccess.open(path,FileAccess.READ)
	if not file: return ""
	var hash = HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	while file.get_position()<file.get_length():
		hash.update(file.get_buffer(mini(1048576,file.get_length()-file.get_position())))
	return hash.finish().hex_encode()

func engine_version() -> String:
	var version = Engine.get_version_info()
	return "%d.%d.%d"%[version.major,version.minor,version.patch]

func safe_relative(value: String) -> bool:
	if value.is_empty() or value.begins_with("/") or value.contains("..") or value.contains(":"): return false
	var pattern = RegEx.new(); pattern.compile("^[A-Za-z0-9_./-]+$")
	return pattern.search(value)!=null

func validate_envelope(envelope: Dictionary) -> Dictionary:
	last_error = ""
	if envelope.get("key_id","")!=config.get("key_id","") or not envelope.get("payload_base64") is String or not envelope.get("signature_base64") is String:
		last_error = "manifest_format"; return {}
	var bytes = Marshalls.base64_to_raw(envelope.payload_base64)
	var signature = Marshalls.base64_to_raw(envelope.signature_base64)
	if bytes.is_empty() or bytes.size()>262144 or signature.is_empty():
		last_error = "manifest_format"; return {}
	var key = CryptoKey.new()
	if key.load(str(config.get("public_key","")),true)!=OK:
		last_error = "public_key"; return {}
	var hash = HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	if not Crypto.new().verify(HashingContext.HASH_SHA256,hash.finish(),signature,key):
		last_error = "signature"; return {}
	var value = JSON.parse_string(bytes.get_string_from_utf8())
	if not value is Dictionary:
		last_error = "manifest_format"; return {}
	if value.get("schema_version")!=1 or value.get("product_id")!=config.get("product_id") or value.get("platform")!=platform_id or value.get("channel")!=config.get("channel"):
		last_error = "manifest_identity"; return {}
	if value.get("bootstrap_abi")!=config.get("bootstrap_abi") or value.get("engine_version")!=engine_version():
		last_error = "bootstrap_required"; return {}
	if not (value.get("sequence") is float or value.get("sequence") is int) or int(value.sequence)<1 or float(value.sequence)!=int(value.sequence) or int(value.sequence)>2147483647:
		last_error = "manifest_format"; return {}
	if not value.get("content_version") is String or value.content_version.is_empty() or value.content_version.length()>64 or not value.get("package") is Dictionary:
		last_error = "manifest_format"; return {}
	var pack: Dictionary = value.package
	if not pack.get("path") is String or not safe_relative(pack.path) or not pack.path.begins_with("releases/") or not pack.path.ends_with(".zip"):
		last_error = "package_path"; return {}
	if not (pack.get("bytes") is float or pack.get("bytes") is int) or int(pack.bytes)<=0 or float(pack.bytes)!=int(pack.bytes) or int(pack.bytes)>int(config.max_package_bytes):
		last_error = "package_size"; return {}
	var regex = RegEx.new(); regex.compile("^[a-f0-9]{64}$")
	if not pack.get("sha256") is String or not regex.search(pack.sha256):
		last_error = "package_hash"; return {}
	return value

func package_file(payload: Dictionary) -> String:
	return storage.path_join("content-%d.zip"%int(payload.sequence))

func verify_package(path: String,payload: Dictionary) -> bool:
	var file = FileAccess.open(path,FileAccess.READ)
	if not file or file.get_length()!=int(payload.package.bytes): last_error="package_size"; return false
	file.close()
	if hash_file(path)!=payload.package.sha256: last_error="package_hash"; return false
	var zip = ZIPReader.new()
	if zip.open(path)!=OK: last_error="package_zip"; return false
	for entry in zip.get_files():
		if entry.begins_with("/") or entry.contains("..") or entry.contains("\\") or entry in ["project.binary","project.godot"] or entry.begins_with("scripts/updates/") or entry.begins_with("config/") or entry=="scenes/startup/UpdateGate.tscn":
			zip.close(); last_error="protected_path"; return false
	var marker = JSON.parse_string(zip.read_file("assets/updates/content_release.json").get_string_from_utf8())
	zip.close()
	if not marker is Dictionary or int(marker.get("sequence",0))!=int(payload.sequence) or marker.get("platform")!=platform_id or marker.get("product_id")!=config.product_id:
		last_error="package_marker"; return false
	return true

func _mount_installed():
	var envelope = read_json(storage.path_join("active.json"))
	var trial = read_json(storage.path_join("trial.json"))
	var payload = validate_envelope(envelope) if not envelope.is_empty() else {}
	# A newer installer already contains these resources. Never mount an older
	# cached patch over it or download the installer's own baseline again.
	if not payload.is_empty() and int(payload.sequence)<=int(config.get("bundled_sequence",0)): return
	if not trial.is_empty() and int(trial.get("sequence",0))!=int(payload.get("sequence",0)):
		# A failed pointer write must not treat the previous version as a trial.
		DirAccess.remove_absolute(storage.path_join("trial.json")); trial={}
	if not trial.is_empty() and bool(trial.get("started",false)):
		# No successful startup handshake: next launch restores the previous pack.
		envelope = read_json(storage.path_join("previous.json")); payload = validate_envelope(envelope) if not envelope.is_empty() else {}
		atomic_json(storage.path_join("active.json"),envelope)
		DirAccess.remove_absolute(storage.path_join("trial.json"))
		trial={}
		recovery_message="rollback"
	if not payload.is_empty() and int(payload.sequence)<=int(config.get("bundled_sequence",0)): return
	if payload.is_empty() or not verify_package(package_file(payload),payload):
		var previous = read_json(storage.path_join("previous.json"))
		var older = validate_envelope(previous) if not previous.is_empty() else {}
		if older.is_empty() or int(older.sequence)<=int(config.get("bundled_sequence",0)) or not verify_package(package_file(older),older): return
		envelope=previous; payload=older; recovery_message="rollback"
		atomic_json(storage.path_join("active.json"),envelope)
	if not trial.is_empty() and recovery_message.is_empty():
		atomic_json(storage.path_join("trial.json"),{"sequence":int(payload.sequence),"started":true})
	if ProjectSettings.load_resource_pack(package_file(payload),true): active=payload; mounted=true
	else: recovery_message="mount_failed"

func confirm_boot():
	if mounted and FileAccess.file_exists(storage.path_join("trial.json")):
		DirAccess.remove_absolute(storage.path_join("trial.json"))
	if mounted:
		var keep=[int(active.get("sequence",0))]
		var previous=validate_envelope(read_json(storage.path_join("previous.json")))
		if not previous.is_empty(): keep.append(int(previous.sequence))
		var names=RegEx.new(); names.compile("^content-([0-9]+)\\.zip$")
		# Delete only updater-owned files in this directory, never save files.
		for file in DirAccess.get_files_at(storage):
			var match_name=names.search(file)
			if match_name and int(match_name.get_string(1)) not in keep:
				DirAccess.remove_absolute(storage.path_join(file))

func current_sequence() -> int: return maxi(int(config.get("bundled_sequence",0)),int(active.get("sequence",0)))

func _new_request(timeout: float) -> HTTPRequest:
	var request = HTTPRequest.new(); request.timeout=timeout; request.max_redirects=0; request.accept_gzip=false
	request.use_threads=true; add_child(request); request_node=request
	return request

func _status(next: String): state=next; status_changed.emit(next)

func base_url() -> String:
	var base = str(config.base_url)
	if base.begins_with("https://") and base.ends_with("/"): return base
	if test_mode and base.begins_with("http://127.0.0.1:") and base.ends_with("/"): return base
	return ""

func check_update() -> Dictionary:
	offered={}
	if not supported(): return {"state":"disabled"}
	if base_url().is_empty(): return {"state":"unavailable","error":"base_url"}
	_status("checking")
	var request = _new_request(float(config.manifest_timeout)); request.body_size_limit=524288
	var url = base_url()+str(config.channel)+"/"+platform_id+"/manifest.json"
	if request.request(url,["Accept: application/json","Cache-Control: no-cache"])!=OK:
		request.queue_free(); _status("unavailable"); return {"state":state,"error":"request"}
	var result = await request.request_completed
	request.queue_free()
	if result[0]!=HTTPRequest.RESULT_SUCCESS or int(result[1])!=200:
		_status("unavailable"); return {"state":state,"error":"http","http_status":result[1],"http_result":result[0]}
	var envelope = JSON.parse_string(result[3].get_string_from_utf8())
	var payload = validate_envelope(envelope) if envelope is Dictionary else {}
	if payload.is_empty():
		_status("incompatible" if last_error=="bootstrap_required" else "unavailable"); return {"state":state,"error":last_error}
	if int(payload.sequence)<=current_sequence(): _status("current"); return {"state":state}
	offered={"envelope":envelope,"payload":payload}
	_status("available"); return {"state":state,"version":payload.content_version,"bytes":payload.package.bytes}

func download_update() -> Dictionary:
	if offered.is_empty(): return {"state":"unavailable","error":"no_offer"}
	var payload: Dictionary = offered.payload
	var temporary = storage.path_join("download.part")
	_status("downloading"); expected_bytes=int(payload.package.bytes)
	var request = _new_request(float(config.download_timeout)); request.download_file=temporary
	request.body_size_limit=expected_bytes
	if request.request(base_url()+payload.package.path)!=OK:
		request.queue_free(); _status("unavailable"); return {"state":state,"error":"request"}
	var result = await request.request_completed
	request.queue_free()
	if result[0]!=HTTPRequest.RESULT_SUCCESS or int(result[1])!=200:
		DirAccess.remove_absolute(temporary); _status("unavailable"); return {"state":state,"error":"download"}
	_status("verifying")
	await get_tree().process_frame
	# No partial archive is ever mounted, and saved games are never overwritten.
	if not verify_package(temporary,payload):
		DirAccess.remove_absolute(temporary); _status("unavailable"); return {"state":state,"error":last_error}
	var destination = package_file(payload)
	if FileAccess.file_exists(destination): DirAccess.remove_absolute(destination)
	if DirAccess.rename_absolute(temporary,destination)!=OK: _status("unavailable"); return {"state":state,"error":"disk"}
	var previous = read_json(storage.path_join("active.json"))
	if not atomic_json(storage.path_join("previous.json"),previous) or not atomic_json(storage.path_join("trial.json"),{"sequence":int(payload.sequence),"started":false}) or not atomic_json(storage.path_join("active.json"),offered.envelope):
		_status("unavailable"); return {"state":state,"error":"disk"}
	_status("restart_required"); return {"state":state,"version":payload.content_version}

func progress() -> float:
	if state!="downloading" or not is_instance_valid(request_node) or expected_bytes<=0: return 0
	return clampf(float(request_node.get_downloaded_bytes())/expected_bytes,0,1)

func restart():
	if OS.has_feature("windows"):
		var args: Array = OS.get_cmdline_user_args().duplicate()
		OS.create_instance(args)
	get_tree().quit()
