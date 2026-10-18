extends CanvasLayer
class_name OriginalLevelDialogue
signal finished
var card: Control
var label: Label
var subtitle_canvas: OriginalSubtitleCanvas
var letterbox: OriginalLetterbox
var pages: Array[String] = []
var current_page = 0
var elapsed = 0.0
var voice: AudioStreamPlayer
var voiced = false
var page_durations = PackedFloat64Array()
var total_duration = 0.0
var timed = false
var completed = false
var automatic = false
var wait_for_voice = false

func _ready() -> void:
	layer = 40
	var root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	letterbox = OriginalLetterbox.new()
	root.add_child(letterbox)
	card = Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	root.add_child(card)
	letterbox.text_card = card
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color",Color.WHITE)
	label.add_theme_color_override("font_outline_color",Color.BLACK)
	label.add_theme_constant_override("outline_size",4)
	label.add_theme_font_size_override("font_size",36)
	OriginalGameFont.apply(label)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Keep the Label as the text/state holder; render original animated cells.
	label.hide()
	subtitle_canvas = OriginalSubtitleCanvas.new()
	subtitle_canvas.text_label = label
	card.add_child(subtitle_canvas)
	subtitle_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.hide()

static func clean(text: String) -> String:
	var regex = RegEx.new()
	text = text.replace("$B_SNEAK$",preload("res://scripts/input/platform_controls.gd").key_label("sneak")).replace("$B_ACTION$","E").replace("$B_JUMP$",GameLocalization.ui("Espacio"))
	text = text.replace("$B_RUN$",GameLocalization.ui("Shift varias veces")).replace("$B_SELECT$","Tab").replace("$B_QUICKINV$","Tab")
	regex.compile("\\$[^$]+\\$")
	return regex.sub(text,"",true).replace("\\n","\n").strip_edges()

func show_line(text: String, audio: AudioStreamPlayer = null, advance_automatically: bool = false) -> void:
	pages.clear()
	page_durations.clear()
	total_duration = 0
	completed = false
	automatic = advance_automatically
	wait_for_voice = false
	voice = audio
	voiced = audio != null and audio.stream != null
	# ScrollText_Run (text.cpp): $digits$ / $(digits)$ = page time * 100ms.
	var regex = RegEx.new()
	regex.compile("\\$\\(?([0-9]{1,5})\\)?\\$")
	var marks = regex.search_all(text)
	timed = not marks.is_empty()
	if timed:
		for i in range(marks.size()):
			var start = marks[i].get_end()
			var end = marks[i+1].get_start() if i+1 < marks.size() else text.length()
			pages.append(clean(text.substr(start,end-start)))
			var duration = float(marks[i].get_string(1))*.1
			page_durations.append(duration)
			total_duration += duration
	else:
		pages.append(clean(text))
	if pages.is_empty(): pages.append("")
	if automatic:
		# Adapted PC controls have no MLT timing tags. Keep their text readable
		# in the same two-line subtitle band, paced across the actual recording.
		if not timed:
			var duration = voice.stream.get_length() if voiced else maxf(3,clean(text).length()/14.0)
			page_durations.append(duration); total_duration = duration; timed = true
		var old_pages = pages.duplicate(); var old_times = page_durations.duplicate()
		pages.clear(); page_durations.clear()
		for i in range(old_pages.size()):
			var lines = OriginalTextBox.wrap_text(old_pages[i],29)
			var count = maxi(1,ceili(lines.size()/2.0))
			for part in range(count):
				pages.append("\n".join(lines.slice(part*2,mini(lines.size(),part*2+2))))
				page_durations.append(float(old_times[i])/count)
	current_page = 0
	elapsed = 0
	label.text = pages[0]
	letterbox.text_card = card
	card.show()

func close() -> void:
	card.hide()

func _process(delta: float) -> void:
	if not card.visible: return
	if wait_for_voice: return
	elapsed += delta
	if voiced:
		if voice.playing:
			elapsed = maxf(elapsed-delta,voice.get_playback_position()+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency())
	if timed:
		var end = 0.0
		for i in range(pages.size()):
			end += page_durations[i]
			current_page = i
			if elapsed < end: break
		label.text = pages[current_page]
		if elapsed >= total_duration and not completed and (not automatic or not voiced or not voice.playing):
			completed = true
			finished.emit()
