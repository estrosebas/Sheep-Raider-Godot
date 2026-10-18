extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr(message)
func touch(id: int,point: Vector2,pressed: bool):
	var event = InputEventScreenTouch.new(); event.index = id; event.position = root.get_final_transform()*point; event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func drag(id: int,point: Vector2,relative: Vector2):
	var event = InputEventScreenDrag.new(); event.index = id; event.position = root.get_final_transform()*point; event.relative = root.get_final_transform().basis_xform(relative)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run():
	SaveFiles.startup_offered=true; SaveFiles.pending={}; SaveFiles.directory="user://touch_test_%d"%Time.get_ticks_usec()
	GameLocalization.select("es",false)
	var controls = root.get_node("MobileControls")
	check(not controls.enabled,"Desktop has no touch overlay without opt-in")
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene=lab
	await create_timer(.4).timeout
	check(lab.get_node_or_null("LeafHeapExperiment_0")==null and lab.get_node_or_null("LeafMapFragment_0")==null,"Rejected leaf experiments removed from lab")
	check(lab.has_node("BullLeafHeap"),"Original leaf heap retained")
	controls.set_enabled(true); await create_timer(.06).timeout
	lab.player.set_physics_process(false)
	controls.update_layout()
	check(controls.button_icon("action")!=null and controls.button_icon("inventory")!=null,"Original hand and inventory cloud available")
	check(controls.button_icon("jump")!=null and controls.button_icon("run")!=null and controls.button_icon("sneak")!=null,"Selected jump/runv1/sneakv1 artwork available")
	check(not controls.buttons.has("use") and controls.button_icon("use")==null,"Empty hands hide Use and its touch target")
	var item=lab.get_node("Item_3")
	item.equip_to(lab.player); lab.player.inventory.equipped_node=item
	controls.update_layout()
	check(controls.buttons.has("use") and controls.button_icon("use")!=null,"Held lettuce shows Use with the item icon")
	item.store(); lab.player.inventory.equipped_node=null; controls.update_layout()
	check(not controls.buttons.has("use"),"Stowing the item hides Use again")
	check(controls.buttons.sneak.at.x>controls.safe.get_center().x,"Sneak button is on the right")
	touch(20,controls.buttons.sneak.at,true); touch(20,controls.buttons.sneak.at,false)
	check(controls.sneak_toggled and Input.is_action_pressed("sneak"),"One tap latches stealth after finger release")
	touch(21,controls.buttons.sneak.at,true); touch(21,controls.buttons.sneak.at,false)
	check(not controls.sneak_toggled and not Input.is_action_pressed("sneak"),"Second tap switches stealth off")
	var center = controls.joystick_center()
	touch(0,center,true); drag(0,center+Vector2(60,0)*controls.unit,Vector2(60,0)*controls.unit)
	check(Input.get_action_strength("move_right")>.4 and Input.get_action_strength("move_right")<1,"Joystick sends analog strength")
	touch(1,controls.buttons.jump.at,true)
	check(Input.is_action_pressed("jump") and Input.is_action_pressed("move_right"),"Multitouch permits jump while moving")
	touch(1,controls.buttons.jump.at,false)
	check(not Input.is_action_pressed("jump") and Input.is_action_pressed("move_right"),"Releasing jump keeps movement")
	var point = Vector2(controls.safe.end.x-400*controls.unit,controls.safe.position.y+250*controls.unit)
	var yaw = lab.player.camera_pivot.rotation.y
	touch(2,point,true); drag(2,point+Vector2(30,0),Vector2(30,0)); touch(2,point,false)
	check(not is_equal_approx(yaw,lab.player.camera_pivot.rotation.y),"Touch drag rotates gameplay camera")
	lab.player.cinematic_controls_locked=true
	yaw=lab.player.camera_pivot.rotation.y
	lab.player.rotate_view(Vector2(30,0))
	check(is_equal_approx(yaw,lab.player.camera_pivot.rotation.y),"Cinematic camera remains locked")
	lab.player.cinematic_controls_locked=false
	touch(0,center,false)
	check(not Input.is_action_pressed("move_right"),"Joystick release clears movement")
	# Inventory stays open after releasing the switch; a later tap closes it.
	lab.player.inventory.state.add({"id":"touch_lettuce","class_id":3,"label":"Lechuga"})
	lab.player.inventory.state.add({"id":"touch_dynamite","class_id":2,"label":"Dinamita"})
	touch(3,controls.buttons.inventory.at,true); await create_timer(.04).timeout
	touch(3,controls.buttons.inventory.at,false); await create_timer(.04).timeout
	check(lab.player.inventory.wheel_open and controls.context=="menu","Inventory opens and changes touch context")
	controls.update_layout()
	check(controls.buttons.has("inventory_prev") and controls.buttons.has("inventory_next"),"Open clouds show dedicated touch arrows")
	var before_arrow = lab.player.inventory.state.selected_class
	touch(14,controls.buttons.inventory_next.at,true)
	await create_timer(.04).timeout
	check(Input.is_action_pressed("move_right"),"Inventory arrow sends selection navigation")
	check(lab.player.inventory.state.selected_class!=before_arrow,"Touch arrow actually changes the selected cloud")
	touch(14,controls.buttons.inventory_next.at,false)
	controls.update_layout(); center=controls.joystick_center()
	touch(4,center,true); drag(4,center+Vector2(80,0)*controls.unit,Vector2(80,0)*controls.unit)
	check(Input.is_action_pressed("move_right"),"Inventory receives left/right navigation")
	touch(4,center,false)
	check(lab.player.inventory.wheel_open,"Finger release keeps inventory open")
	touch(3,controls.buttons.inventory.at,true); touch(3,controls.buttons.inventory.at,false); await create_timer(.04).timeout
	check(not lab.player.inventory.wheel_open,"Second inventory tap equips/closes")
	controls.update_layout()
	check(not controls.buttons.has("inventory_prev"),"Closed clouds hide touch arrows")
	# Exercise the original pause menu, including key-only row navigation.
	var pause = OriginalPauseMenu.new(); lab.add_child(pause); await create_timer(.04).timeout
	controls.update_layout(); touch(5,controls.buttons.pause.at,true); touch(5,controls.buttons.pause.at,false); await create_timer(.04).timeout
	check(pause.opened and paused,"Touch pause opens original menu")
	var selected = pause.selected; center=controls.joystick_center()
	touch(6,center,true); drag(6,center+Vector2(0,80)*controls.unit,Vector2(0,80)*controls.unit)
	check(pause.selected==posmod(selected+1,pause.rows.size()),"Joystick navigates pause rows")
	touch(6,center,false)
	touch(7,controls.buttons.pause.at,true); touch(7,controls.buttons.pause.at,false); await create_timer(.04).timeout
	check(not pause.opened and not paused,"Touch back resumes gameplay")
	# Language overlay pauses the same scene; turning does not save a locale.
	var language = root.get_node("LanguageMenu")
	controls.update_layout(); touch(9,controls.buttons.language.at,true); touch(9,controls.buttons.language.at,false)
	await create_timer(2.4).timeout
	check(language.overlay!=null and language.wheel!=null,"Touch opens original language wheel")
	if language.wheel:
		var choice = language.wheel.selected
		center=controls.joystick_center()
		touch(10,center,true); drag(10,center+Vector2(80,0)*controls.unit,Vector2(80,0)*controls.unit); touch(10,center,false)
		check(language.wheel.selected!=choice,"Touch joystick turns language wheel")
	controls.update_layout(); touch(11,controls.buttons.pause.at,true); touch(11,controls.buttons.pause.at,false)
	await create_timer(2.4).timeout
	check(language.overlay==null and current_scene==lab and not paused,"Touch back returns from language wheel to same scene")
	controls.update_layout(); touch(8,controls.buttons.run.at,true)
	check(Input.is_action_pressed("run"),"Run button remains held")
	controls._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	Input.flush_buffered_events()
	check(not Input.is_action_pressed("run") and controls.fingers.is_empty(),"Focus loss releases all fingers and keys")
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(1280,720); await create_timer(.04).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/mobile_controls.png")
	controls.set_enabled(false)
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream=null
	lab.queue_free(); await create_timer(.04).timeout
	print("Mobile controls / multitouch / camera / inventory / pause / focus / lab cleanup: ",failures," failures")
	quit(failures)
