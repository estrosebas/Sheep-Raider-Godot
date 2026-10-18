extends RefCounted
class_name OriginalRalphIdle

# Wolf::g_wolfIdleAnims / ScnControllable::NextIdleAnim.
const VARIANTS = ["idle_stand1","idle_stand2","idle_stand3","idle_stand5"]
const LOOP_RANGES = [Vector2i(1,2),Vector2i(5,6),Vector2i(5,6),Vector2i(1,1)]
var clip = ""
var base_clip = "idle"
var elapsed = 0.0
var loops_remaining = 0

func reset(actor: RalphController) -> void:
	base_clip = base_for(actor)
	clip = base_clip
	elapsed = 0
	loops_remaining = randi_range(0,4) if base_clip=="held_item_idle" else randi_range(3,5)
	actor.play_anim(clip)

func base_for(actor: RalphController) -> String:
	var item = actor.inventory.equipped_node if actor.inventory else null
	if item is GameItem and item.holder==actor and actor.item_costume.is_empty():
		return "rocket_idle" if item.class_id==10 else "held_item_idle"
	return "idle"

func step(actor: RalphController, delta: float) -> void:
	if actor.animation_player.current_animation != clip or clip.is_empty() or base_clip!=base_for(actor): reset(actor)
	var previous = elapsed
	elapsed += delta
	var duration = actor.animation_player.get_animation(clip).length
	play_cues(actor,previous,minf(elapsed,duration))
	if elapsed < duration: return
	elapsed = fmod(elapsed,duration)
	if base_clip=="rocket_idle": return # Wolf::IdleAnimStep leaves ROCKET1 looping.
	if loops_remaining > 0:
		loops_remaining -= 1
		play_cues(actor,-.001,elapsed)
		return
	if base_clip=="held_item_idle":
		# Holding ordinary objects uses STAND10 for Rand_Bounded(5) loops,
		# then one STAND9 fidget. Empty-handed variants must never take over.
		var item = actor.inventory.equipped_node
		clip = ("flute_fidget" if item is FluteItem else "held_item_fidget") if clip==base_clip else base_clip
		loops_remaining = randi_range(0,4) if clip==base_clip else 0
	elif clip == "idle":
		var index = randi_range(0,VARIANTS.size()-1)
		clip = VARIANTS[index]
		loops_remaining = randi_range(LOOP_RANGES[index].x,LOOP_RANGES[index].y)-1
	else:
		clip = "idle"
		loops_remaining = randi_range(3,5)-1
	elapsed = 0
	actor.play_anim(clip)
	play_cues(actor,-.001,0)

func play_cues(actor: RalphController, previous: float, time: float) -> void:
	for cue in actor.run_data.animations[clip].sound_cues:
		if float(cue.time) > previous and float(cue.time) <= time:
			var sound = actor.run_data.sounds.get(str(int(cue.sound_id)))
			if sound: actor.play_animation_sfx(sound.path)
