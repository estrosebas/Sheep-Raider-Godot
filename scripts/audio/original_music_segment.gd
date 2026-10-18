extends AudioStreamPlayer
class_name OriginalMusicSegment

signal selection_changed(track: Dictionary)
var selected: Dictionary = {}

# Sample boundaries keep loops exact without a frame-driven seek at end_time.
# start_time/end_time allow future multi-song files to share one source WAV.
func play_segment(track: Dictionary) -> bool:
	var path = str(track.get("path",""))
	if not ResourceLoader.exists(path): return false
	var wav: AudioStreamWAV = load(path).duplicate()
	if wav == null: return false
	var start = float(track.get("start_time",0))
	var end = float(track.get("end_time",wav.get_length()))
	var loop_start = float(track.get("loop_start",start))
	if start < 0 or loop_start < start or end <= loop_start or end > wav.get_length()+.0001:
		return false
	var begin_sample = roundi(loop_start*wav.mix_rate)
	var end_sample = roundi(end*wav.mix_rate)
	# Exact native sample indices are valid only at the original sample rate.
	if int(track.get("sample_rate",0)) == wav.mix_rate:
		begin_sample = int(track.get("loop_start_sample",begin_sample))
		end_sample = int(track.get("end_sample",end_sample))
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = begin_sample
	wav.loop_end = end_sample
	stream = wav
	selected = track.duplicate(true)
	play(start)
	selection_changed.emit(selected)
	return true

func stop_selection() -> void:
	stop()
	selected = {}
	selection_changed.emit(selected)
