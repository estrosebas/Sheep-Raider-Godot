extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	var level = load("res://scenes/levels/Level02.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.3).timeout
	var boundary = level.get_node("StartPassageBoundary")
	var player = level.player; player.set_physics_process(false); player.set_process(false)
	var rock = level.get_node("Rock_49"); rock.set_physics_process(false)
	check(boundary.get_child_count()==3 and (player.collision_mask&8)!=0,"Initial rock has two invisible sides and overhead boundary for Ralph")
	check((rock.collision_mask&8)==0 and (player.camera_pivot.collision_mask&8)==0,"Stone push axes and free camera ignore invisible boundaries")
	var center: Vector3 = boundary.global_position
	for offset in [Vector3(0,1,2),Vector3(0,1,-2),Vector3(0,3,0)]:
		var query = PhysicsRayQueryParameters3D.create(center+offset+Vector3.LEFT*2,center+offset+Vector3.RIGHT*2,8)
		check(not level.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Side/jump route is blocked at "+str(offset))
	var clear = PhysicsRayQueryParameters3D.create(center+Vector3(-2,.8,0),center+Vector3(2,.8,0),8)
	check(level.get_world_3d().direct_space_state.intersect_ray(clear).is_empty(),"Low central opening remains free for normal passage after pushing")
	player.global_position = center+Vector3(-1.25,0,0)
	var motion = Vector3(3,0,0)
	var collision = KinematicCollision3D.new()
	check(player.test_move(player.global_transform,motion,collision) and collision.get_collider()==rock,"Original stone physically blocks the centre before pushing")
	rock.global_position += Vector3(4,0,0)
	await physics_frame; await physics_frame
	check(not player.test_move(player.global_transform,motion),"Ralph's actual capsule crosses centre after stone is moved")
	player.global_position = center+Vector3(-1.25,2,2)
	check(player.test_move(player.global_transform,motion),"Ralph's actual capsule cannot jump past the lateral log")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Level02 initial rock / invisible bypass boundary: ",failures," failures"); quit(failures)
