extends RefCounted
class_name OriginalLettuceGuidance
# Salad::MSG_QUERY_NEAREST_TARGET: XZ radius 600, Y +/-150,
# sheep score distance squared; other salads distance squared + 360000.
static func query(item: LettuceItem, point: Vector3, wanted: int = 0) -> Dictionary:
	var nearest: Node3D
	var best = INF
	var distance = 0.0
	for candidate in item.get_tree().get_nodes_in_group("sheep_targets")+item.get_tree().get_nodes_in_group("sheep_attractors"):
		if candidate == item or candidate.get_world_3d() != item.get_world_3d(): continue
		if candidate is OriginalSheep:
			if wanted == 3: continue
			if candidate.dead or candidate.carried_by or candidate.sleepy or (candidate.flock and candidate.flock.restricted(candidate)): continue
		elif candidate is LettuceItem:
			if wanted == 11: continue
			if not candidate.available or candidate.holder or candidate.respawn_time > 0: continue
		else: continue
		var difference = candidate.global_position-point
		if absf(difference.y) > 1.5: continue
		var d = Vector2(difference.x,difference.z).length()
		if d > 6: continue
		var score = d*d+(36 if candidate is LettuceItem else 0)
		if score < best:
			best = score
			nearest = candidate
			distance = d
	if not nearest: return {}
	return {"target":nearest,"distance":distance,"value":int(distance*65535/6),"sheep":nearest is OriginalSheep,"near_limit":distance >= 5.4}
