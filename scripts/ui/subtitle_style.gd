extends RefCounted
class_name SubtitleStyle

# Shared original bitmap typeface and tint for tutorial/subtitle labels.
static func apply(label: Label) -> void:
	OriginalGameFont.apply(label)
