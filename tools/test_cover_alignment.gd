extends SceneTree
var failures=0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr(message)
func stop_audio(scene):
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop();node.stream=null
func run():
	SaveFiles.startup_offered=true; SaveFiles.pending={}; SaveFiles.directory="user://cover_alignment_test_%d"%Time.get_ticks_usec()
	GameLocalization.select("es",false)
	var lab=load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene=lab
	await create_timer(.4).timeout
	var actor=lab.player; var rock=lab.get_node("CoverRock_0")
	var neutral:Vector3=actor.skeleton.position
	var radius=float(actor.get_node("CollisionShape3D").shape.radius)
	for normal in [Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT]:
		Input.action_release("sneak"); actor.interrupt_actions()
		var tangent=normal.cross(Vector3.UP)
		var local=rock.bounds.get_center()
		if absf(normal.x)>.5: local.x=(rock.bounds.end.x if normal.x>0 else rock.bounds.position.x)+normal.x*(radius+.065)
		else: local.z=(rock.bounds.end.z if normal.z>0 else rock.bounds.position.z)+normal.z*(radius+.065)
		actor.global_position=rock.global_position+local+tangent*.75; actor.global_position.y=.02
		actor.camera_pivot.rotation=Vector3.ZERO
		await create_timer(.18).timeout
		var start:Vector3=actor.global_position
		Input.action_press("sneak")
		await create_timer(.3).timeout
		check(actor.current_state==actor.WolfState.COVER_ENTER and actor.rock_cover.face_normal==normal,"Corner entry locks the approached face throughout HIDE1")
		var center:Vector3=rock.global_position+rock.bounds.get_center()
		var initial=absf((start-center).dot(tangent))
		var partial=absf((actor.global_position-center).dot(tangent))
		check(partial<initial-.05 and partial>.15,"HIDE1 moves gradually toward face centre without teleporting")
		await create_timer(.8).timeout
		check(actor.current_state==actor.WolfState.COVER_HIDDEN and absf((actor.global_position-center).dot(tangent))<.02,"Hidden pose ends at the centre of all four native rock faces")
		var plane=rock.bounds.end.x if normal.x>0 else rock.bounds.position.x if normal.x<0 else rock.bounds.end.z if normal.z>0 else rock.bounds.position.z
		var coordinate=(actor.global_position-rock.global_position).x if absf(normal.x)>.5 else (actor.global_position-rock.global_position).z
		var clearance=absf(coordinate-plane)-radius
		check(clearance>=-.001 and clearance<.03 and is_equal_approx(actor.get_node("CollisionShape3D").shape.radius,radius),"Real capsule remains outside the solid face at contact, with its normal dimensions")
		check(actor.rock_cover.offset_active and not actor.skeleton.position.is_equal_approx(neutral),"Cover back contact adapts the visual pose to the actual sloping rock artwork")
		check(actor.hidden_from_observer(center-normal*3) and not actor.hidden_from_observer(center+normal*3),"Locked face retains correct observer visibility after centring")
		if DisplayServer.get_name()!="headless" and normal==Vector3.BACK:
			root.size=Vector2i(1280,720)
			var camera=Camera3D.new(); lab.add_child(camera); camera.current=true
			camera.position=rock.global_position+Vector3(2.3,1.6,3.5);camera.look_at(rock.global_position+Vector3.UP*.5)
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://validation/rock_cover_corner_centered.png")
			camera.queue_free();actor.camera.make_current()
		Input.action_release("sneak"); await create_timer(.08).timeout
		check(not actor.rock_cover.active() and actor.skeleton.position.is_equal_approx(neutral),"Releasing sneak restores the unshifted model without changing collision")
	# Scripted interruptions must also restore a partially applied contact offset.
	actor.global_position=rock.global_position+Vector3(.6,.02,1.0)
	await create_timer(.2).timeout; Input.action_press("sneak"); await create_timer(.4).timeout
	actor.interrupt_actions()
	check(not actor.rock_cover.active() and actor.skeleton.position.is_equal_approx(neutral),"Dialogue/death/item cancellation clears cover alignment during entry")
	Input.action_release("sneak")
	# A real external obstacle blocks centring; cover must cancel, not cross it.
	var blocker=StaticBody3D.new();var collision=CollisionShape3D.new();var box=BoxShape3D.new()
	box.size=Vector3(.25,1.5,.5);collision.shape=box;blocker.add_child(collision)
	blocker.position=rock.global_position+Vector3(rock.bounds.get_center().x,.75,rock.bounds.end.z+radius+.01);lab.add_child(blocker)
	actor.global_position=rock.global_position+Vector3(.78,.02,rock.bounds.end.z+radius+.065)
	await create_timer(.2).timeout;Input.action_press("sneak");await create_timer(1.06).timeout
	check(not actor.rock_cover.active() and actor.skeleton.position.is_equal_approx(neutral),"A blocked face centre cancels cover instead of teleporting through an obstruction")
	Input.action_release("sneak");stop_audio(lab);lab.queue_free();await process_frame
	print("Cover alignment / four corners / centred hidden pose / real collision / interruption cleanup: ",failures," failures")
	quit(failures)
