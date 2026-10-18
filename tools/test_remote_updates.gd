extends SceneTree
var failures=0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr(message)
func run():
	var client=root.get_node("ContentUpdates")
	var mode="download"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe="): mode=arg.trim_prefix("--probe=")
	if mode in ["mounted","confirmed","rollback"]:
		if mode=="rollback":
			check(not client.mounted and client.recovery_message=="rollback","Unconfirmed first boot restores built-in game")
		else:
			check(client.mounted and client.current_sequence()==1,"Signed package mounted on cold launch")
			check(root.get_node("LanguageMenu").get("update_fixture_marker")=="service_from_pack","Service compiled from pack before game preloads")
			check(FileAccess.get_file_as_string("res://assets/update_fixture.json").contains("downloaded-from-server"),"Downloaded resource resolves")
			var lab=load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene=lab
			check(lab.get_node("Player").get("update_fixture_marker")=="controller_from_pack","Globally named RalphController uses updated script")
			for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop();node.stream=null
			lab.queue_free(); await process_frame
			if mode=="confirmed": client.confirm_boot()
		print("Update cold launch ",mode,": ",failures," failures"); quit(failures); return
	var result=await client.check_update()
	print("Check result: ",result)
	var fixture=str(client.config.base_url)
	if mode=="current":
		check(result.state=="current" and client.offered.is_empty(),"Confirmed installed content is not downloaded again")
	elif fixture.contains("bad-signature"):
		check(result.state=="unavailable" and result.error=="signature","Invalid signature rejected before download")
	elif fixture.contains("incompatible"):
		check(result.state=="incompatible","ABI mismatch requests binary update")
	elif fixture.contains("traversal") or fixture.contains("wrong-platform"):
		check(result.state=="unavailable" and client.offered.is_empty(),"Invalid identity/path rejected")
	elif fixture.contains("html-error") or fixture.contains("missing") or fixture.contains("timeout") or fixture.contains("4938"):
		check(result.state=="unavailable","HTTP failure/timeout keeps installed content")
	else:
		check(result.state=="available","Signed remote manifest accepted")
		if result.state=="available":
			var installed=await client.download_update()
			if fixture.contains("bad-hash"):
				check(installed.state=="unavailable" and installed.error=="package_hash" and not FileAccess.file_exists(client.storage.path_join("active.json")),"Corrupt package never activated")
			else:
				check(installed.state=="restart_required" and FileAccess.file_exists(client.storage.path_join("active.json")),"Verified download staged")
				check(not FileAccess.file_exists("res://assets/update_fixture.json"),"Current process does not hot-replace its resource graph")
	print("Remote HTTP updates ",fixture,": ",failures," failures");quit(failures)
