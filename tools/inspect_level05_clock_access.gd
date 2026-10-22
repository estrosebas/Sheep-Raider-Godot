extends SceneTree
class EntryMarker extends Control:
	var camera: Camera3D
	func _draw():
		var p = camera.unproject_position(Vector3(1.6,8.8,-22))
		draw_arc(p,35,0,TAU,64,Color.BLACK,8,true)
		draw_arc(p,35,0,TAU,64,Color.YELLOW,4,true)
		var end = p+Vector2(115,-70)
		draw_line(p,end,Color.BLACK,7,true); draw_line(p,end,Color.YELLOW,3,true)
		draw_rect(Rect2(end-Vector2(5,27),Vector2(280,38)),Color(0,0,0,.85))
		draw_string(ThemeDB.fallback_font,end,"ENTRADA AL RELOJ",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.YELLOW)
func _init(): call_deferred("run")
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://clock_access_%d"%Time.get_ticks_usec()
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	var level = load("res://scenes/levels/Level05.tscn").instantiate(); root.add_child(level); current_scene = level
	for i in range(10): await physics_frame
	var cine = level.get_node("LevelCinematics")
	if cine.active_movie: cine.active_movie.finish_sequence(true)
	level.player.set_physics_process(false)
	cine.set_process(false)
	var clock = level.get_node("TimeKeeper_61").global_position
	var space = level.get_world_3d().direct_space_state
	# Sweep real CharacterBody trajectories; report first contact instead of
	# mistaking the upper ledge for entry into the chamber below it.
	var actor = level.player
	var elastic = level.get_node("elastic_86").controller
	elastic.set_physics_process(false)
	var a = level.get_node("ElasticTree_62"); var b = level.get_node("ElasticTree_67")
	elastic.tie_first(a,actor); elastic.tree_b = b; elastic.mode = "strung"
	var midpoint = (a.global_position+b.global_position)*.5
	for aim_x in [-4,0,2,4,6,8]:
		for distance in [32,36,40]:
			for height in [4,8,12]:
				var retreat = midpoint-Vector3(aim_x,0,-25); retreat = retreat.normalized()
				actor.global_position = midpoint+retreat*4.9+Vector3.UP*.001
				actor.velocity = Vector3.ZERO; actor.set_state(actor.WolfState.FALL)
				elastic.projection_distance = distance; elastic.projection_height = height
				elastic.start_launch(actor,(actor.global_position-(midpoint+Vector3.UP*.8))*2,1)
				for i in range(300):
					elastic._physics_process(1.0/60)
					if elastic.flight.is_empty(): break
				var end = actor.global_position
				for i in range(120):
					if actor.move_and_collide(Vector3.DOWN*.1): break
				print("SHOT x=",aim_x," D=",distance," H=",height," contact=",end," floor=",actor.global_position)
	for angle in range(0,360,15):
		var direction = Vector3(sin(deg_to_rad(angle)),0,cos(deg_to_rad(angle)))
		var origin = clock+Vector3.UP
		var query = PhysicsRayQueryParameters3D.create(origin,origin+direction*20,1)
		var hit = space.intersect_ray(query)
		print("EXIT ",angle," ",hit.get("position","open"))
	for z in range(-28,-14,2):
		for x in [2,4,6,8,10,12]:
			var point = Vector3(x,clock.y+1,z)
			var query = PhysicsRayQueryParameters3D.create(point+Vector3.UP*15,point-Vector3.UP*5,1)
			var hit = space.intersect_ray(query)
			print("SURFACE ",x," ",z," ",hit.get("position","open"))
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1280,720)
		var camera = Camera3D.new(); level.add_child(camera); camera.current = true; camera.fov = 65
		var views = [Vector3(0,0,-26),Vector3(4,0,-18),Vector3(4,13,-24),Vector3(15,18,0)]
		for index in range(views.size()):
			camera.global_position = views[index]; camera.look_at(clock+Vector3.UP)
			for i in range(5): await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://validation/level05_clock_access_%d.png"%index)
		var layer = CanvasLayer.new(); root.add_child(layer); layer.layer = 450
		var marker = EntryMarker.new(); layer.add_child(marker); marker.camera = camera; marker.queue_redraw()
		for i in range(5): await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level05_elastic_clock_entry.png")
		layer.queue_free()
	level.queue_free(); await process_frame; quit()
