extends RefCounted

# Archived comparison bench. Not created by the normal laboratory.
# Invoke setup(lab) explicitly to revisit the discarded versions.
static func setup(lab):
	if lab.has_node("BushVolume"): return
	var volume = preload("res://scripts/items/original_bush.gd").new()
	volume.name = "BushVolume"
	volume.volumetric = true
	volume.render_variant = 0
	volume.position = Vector3(9,0,16)
	lab.add_child(volume)
	lab.player.respawned.connect(volume.reset_to_home)
	lab.add_child(LabFloorLabel.create("CIERRE GEOMETRICO",Vector3(9,.035,18),25))
	# 1: both sides write depth, but overlapping corners remain visible.
	# 2: accepted solution; retained here for side-by-side comparison.
	# 3: alpha prepass preserves blending and visible overlapping layers.
	var labels = ["1: CAPA\nVISIBLE", "2: CARAS\nFRONTALES", "3: ALFA +\nPROFUNDIDAD"]
	for i in range(3):
		var bush = preload("res://scripts/items/original_bush.gd").new()
		bush.name = "BushRender_%d"%(i+1)
		bush.render_variant = i+1
		bush.position = Vector3(4+i*5,0,24)
		lab.add_child(bush)
		lab.player.respawned.connect(bush.reset_to_home)
		lab.add_child(LabFloorLabel.create(labels[i],Vector3(4+i*5,.035,26),23))
	# Billboard: rotates foliage toward the camera. Discarded because the
	# request was layer occlusion; it also exposes intersections with Ralph.
	var billboard = preload("res://scripts/items/original_bush.gd").new()
	billboard.name = "BushCamera"
	billboard.camera_facing = true
	billboard.render_variant = 0
	billboard.position = Vector3(14,0,16)
	lab.add_child(billboard)
	lab.player.respawned.connect(billboard.reset_to_home)
	lab.add_child(LabFloorLabel.create("BILLBOARD\nDESCARTADO",Vector3(14,.035,18),23))
