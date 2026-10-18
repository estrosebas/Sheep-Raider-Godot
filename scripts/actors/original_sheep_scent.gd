extends RefCounted
# Sheep states 8/9/10: STAND2 turn, SMEL1 sniff, WALK2 hopping approach.
var target: PerfumeItem
var phase = ""
var elapsed = 0.0

func enter(actor, next: String):
	phase = next; elapsed = 0
	actor.visual.idle_speed = randi_range(12 if phase == "walk" else 16,20)/16.0
	actor.visual.idle({"turn":"stand2","sniff":"smel1","walk":"walk2"}[phase])

func reset(actor):
	if phase.is_empty(): return
	target = null; phase = ""; elapsed = 0
	actor.flock_phase = "idle"
	actor.flock_target = null
	actor.flock_timer = 0
	actor.visual.idle_speed = 1
	actor.visual.idle(actor.idle_animation)

func step(actor, perfume: PerfumeItem,delta: float) -> bool:
	if not is_instance_valid(perfume): reset(actor); return false
	if target != perfume:
		target = perfume; enter(actor,"turn")
	actor.flock_phase = "scent_"+phase
	actor.sheep_audio.stop() # Perfume is never an eating target.
	elapsed += delta
	var direction: Vector3 = target.scent_position()-actor.global_position; direction.y = 0
	actor.rotation.y = lerp_angle(actor.rotation.y,atan2(direction.x,direction.z),minf(1,TAU*delta))
	var can_smell = target.can_smell_from(actor.global_position)
	if can_smell: target.report_sheep(actor)
	var clip: String = actor.visual.idle_clip
	var duration = float(actor.visual.rig.animations[clip].duration)/actor.visual.idle_speed
	if phase == "turn" and elapsed >= duration: enter(actor,"sniff")
	elif phase == "sniff" and elapsed >= duration and can_smell and direction.length() > .8: enter(actor,"walk")
	elif phase == "walk" and (not can_smell or direction.length() <= .8): enter(actor,"sniff")
	var motion = direction.normalized()*2.5 if phase == "walk" and direction.length() > .8 else Vector3.ZERO
	actor.velocity.x = motion.x; actor.velocity.z = motion.z
	actor.velocity.y = 0 if actor.is_on_floor() else maxf(-20,actor.velocity.y-29*delta)
	actor.move_and_slide()
	if actor.is_on_floor(): actor.last_floor_y = actor.global_position.y
	return true
