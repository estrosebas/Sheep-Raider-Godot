extends SceneTree
func _init(): call_deferred("run")
func run():
	SaveFiles.startup_offered=true; SaveFiles.pending={}; SaveFiles.directory="user://stone_capture_%d"%Time.get_ticks_usec()
	GameLocalization.select("es",false)
	var level=load("res://scenes/levels/Level04.tscn").instantiate(); root.add_child(level); current_scene=level
	await create_timer(.6).timeout
	for movie in level.get_node("LevelCinematics").movies.values():
		if movie.playing: movie.finish_sequence(true)
	level.get_node("LevelCinematics").set_process(false); level.get_node("DaffyLessons").set_process(false)
	level.player.set_physics_process(false); level.player.cinematic_controls_locked=false
	level.player.restart_fade_remaining=0; level.player.restart_fade.set_amount(0)
	await process_frame; await process_frame
	var stone=level.get_node("TriggedStone_65"); stone.set_physics_process(false)
	var args=OS.get_cmdline_user_args()
	var mode=args[0] if not args.is_empty() else "disabled"
	if mode!="disabled":
		for material in stone.visual.legacy_skin.materials:
			var shader=Shader.new(); shader.code=material.shader.code.replace("cull_disabled","cull_"+mode).replace("cull_back","cull_"+mode).replace('#include "','#include "res://shaders/')
			material.shader=shader
	var sam=level.get_node("Sam_42"); sam.set_physics_process(false); sam.set_process(false)
	sam.global_position=Vector3(36.97,.34,-31.9); sam.rotation.y=0; sam.visual.sample_animation("head2",0)
	var camera=Camera3D.new(); level.add_child(camera); camera.current=true
	camera.position=GameSpace.original_point(Vector3(4117,-345,3810)); camera.look_at(Vector3(36.97,1.2,-31.5))
	root.size=Vector2i(1280,720)
	for key in ["rest","fall","impact","settle"]:
		var clip="stand1" if key=="rest" else "explod1" if key=="settle" else "fall1"
		var time=0.0 if key=="rest" else .50 if key=="fall" else .85 if key=="impact" else .15
		stone.visual.sample_animation(clip,time)
		stone.update_visual_bounds()
		if key in ["impact","settle"]: sam.visual.sample_animation("squash",.25)
		var skin=stone.visual.legacy_skin; var bounds=AABB(); var first=true
		for surface in stone.visual.rig.surfaces.values():
			for i in range(surface.verts.size()):
				var v=surface.verts[i]; var bone=int(surface.bones[i])
				var point=skin.last_matrices[bone]*skin.inverse_rests[bone]*Vector3(v[0],v[1],v[2])
				if first: bounds=AABB(point,Vector3.ZERO); first=false
				else: bounds=bounds.expand(point)
		print(key," animated mesh bounds ",bounds," custom ",stone.visual.skeleton.get_node("Visual").custom_aabb)
		if DisplayServer.get_name()!="headless":
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://validation/level04_stone_%s_%s.png"%[mode,key])
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream=null
	level.queue_free(); await process_frame; quit()
