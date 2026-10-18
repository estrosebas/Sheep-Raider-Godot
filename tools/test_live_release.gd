# Run with the Godot console tool and an isolated --updates-test-config.
# Release templates use the project's main scene; --script is an editor/tool flag.
# This probe performs no gameplay/save writes.
extends SceneTree
func _init(): call_deferred("run")
func run():
	var client=root.get_node("ContentUpdates")
	var started=Time.get_ticks_msec()
	var result=await client.check_update()
	var ok=result.state=="current" and client.current_sequence()==1 and client.offered.is_empty()
	print("Godot / public HTTPS / signed manifest / bundled sequence: ","PASS" if ok else "FAIL", " ",result," elapsed_ms=",Time.get_ticks_msec()-started)
	quit(0 if ok else 1)
