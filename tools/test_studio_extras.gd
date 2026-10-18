extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.directory = "user://studio_extras_test_%d"%Time.get_ticks_usec()
	SaveFiles.studio_initialized = true; SaveFiles.startup_offered = true
	SaveFiles.pending = {}; SaveFiles.resume_checkpoint = {}
	OriginalProgress.restore({}); GameLocalization.select("es",false)
	OriginalProgress.award_clock("lvl_01"); OriginalProgress.award_clock("lvl_02")
	var level = load(SaveFiles.STUDIO_SCENE).instantiate(); root.add_child(level); current_scene = level
	await create_timer(.6).timeout
	var bonus = level.get_node("Bonuses"); var player = level.player
	var pedestal = level.get_node("BonusManager_13"); var memory = level.get_node("MCardManager_48")
	check(pedestal.visual.idle_clip=="stand" and memory.visual.idle_clip=="stand","Original ACBONUS1/AMEMORY1 pedestals animate at native positions")
	player.global_position = pedestal.global_position+Vector3(2,0,2)
	check(not pedestal.can_interact(player),"Manhattan300 range does not become a larger radial range")
	player.global_position = pedestal.global_position+Vector3.LEFT
	player.set_state(player.WolfState.IDLE)
	check(pedestal.interact(player) and bonus.opened and paused,"E on bonus pedestal opens its modal menu")
	check(bonus.source.entries.size()==8 and bonus.source.entries[0].images.size()==25 and bonus.source.entries[5].images.size()==8,"Native pack directory imports all gallery entries")
	bonus.activate(); check(bonus.page=="confirm","Locked bonus requires original purchase prompt")
	bonus.activate(); check(bonus.page=="bought" and OriginalProgress.bonus_points==1 and OriginalProgress.bonus_unlocked(0),"Purchase spends native price and persists flag")
	bonus.activate(); bonus.activate()
	check(bonus.page=="images" and bonus.picture!=null,"Purchased gallery opens its original JPEG")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900); await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/studio_bonus_gallery.png")
	bonus.page = "list"; bonus.selected = 1
	bonus.activate(); bonus.activate()
	check(bonus.page=="insufficient" and OriginalProgress.bonus_points==1 and not OriginalProgress.bonus_unlocked(1),"Insufficient points cannot unlock or subtract balance")
	bonus.page = "list"; bonus.selected = 0
	if DisplayServer.get_name()!="headless":
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/studio_bonus_menu.png")
	bonus.close_menu()
	var record = SaveFiles.read_slot(0)
	check(not paused and not record.is_empty() and int(record.progress.bonus_flags)==1 and int(record.progress.bonus_points)==1,"Purchase autosave uses separate automatic slot")
	OriginalProgress.restore(record.progress)
	check(OriginalProgress.bonus_unlocked(0) and not OriginalProgress.award_clock("lvl_01") and OriginalProgress.bonus_points==1,"Reload preserves spending without rewarding the same clock again")
	var legacy = record.progress.duplicate(); legacy.erase("bonus_flags"); OriginalProgress.restore(legacy)
	check(OriginalProgress.bonus_flags==0 and OriginalProgress.bonus_points==1,"Older slots without purchase flags remain valid")
	OriginalProgress.restore(record.progress)
	for language in ["en","pt_BR","it","es"]:
		GameLocalization.select(language,false)
		check(not bonus.native_text(25).is_empty() and not bonus.native_text(4).is_empty(),"Original bonus text localization: "+language)
	player.global_position = memory.global_position+Vector3.LEFT; player.set_state(player.WolfState.IDLE)
	check(memory.interact(player) and level.get_node("PauseMenu").page=="save","Memory-card pedestal uses real save slots")
	level.get_node("PauseMenu").activate("slot_1")
	check(not SaveFiles.read_slot(1).is_empty() and int(SaveFiles.read_slot(1).progress.bonus_flags)==1,"Memory-card manual slot includes unlocked extras")
	level.get_node("PauseMenu").close_menu()
	if DisplayServer.get_name()!="headless":
		var camera = Camera3D.new(); level.add_child(camera); camera.position = Vector3(18,5,-5); camera.look_at(Vector3(14,1,-14)); camera.current = true
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/studio_pedestals.png")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Studio native pedestals /110 JPEGs / eight extras / purchase / save / localization: ",failures," failures")
	quit(failures)
