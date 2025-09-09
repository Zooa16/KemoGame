extends CanvasLayer

@onready var black_screen: ColorRect = $ColorRect
@onready var label: Label = $Label

func show_role(role: String, duration: float = 6) -> void:
	# Apply role name
	label.text = role

	# Apply color if exists in Global
	if Global.role_colors.has(role):
		label.modulate = Global.role_colors[role]
	else:
		label.modulate = Color.WHITE

	# Start fully transparent
	label.modulate.a = 0.0

	# Tween sequence
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	
	tween.tween_interval(1.0)
	tween.tween_property(label, "modulate:a", 1.0, 6.0)

	# Stay visible (duration - fade parts - delay)
	var visible_time = max(0, duration - 1.0 - 6.0 - 1.0) # leave room for fade in/out
	tween.tween_interval(visible_time)

	# Fade out over 1s
	tween.tween_property(label, "modulate:a", 0.0, 1.0)

	# Remove scene after done
	tween.tween_callback(func(): queue_free())
