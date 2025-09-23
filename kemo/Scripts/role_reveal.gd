extends CanvasLayer

signal role_reveal_finished

@onready var black_screen: ColorRect = $ColorRect
@onready var label: Label = $Label
@onready var leader_label: Label = $LeaderLabel

func show_role(role: String, is_leader: bool, duration: float = 6) -> void:
	# --- Hidden Role (always shown to local player) ---
	label.text = "You are the " + role
	
	if Global.role_colors.has(role):
		label.modulate = Global.role_colors[role]
	else:
		label.modulate = Color.WHITE
	
	# --- Leader Role (only if this player is the Leader) ---
	if is_leader:
		leader_label.text = "You are the Leader"
		leader_label.modulate = Global.role_colors.get("Leader", Color(1, 1, 0))
		leader_label.visible = true
	else:
		leader_label.visible = false

	# --- Start with black screen and invisible text ---
	black_screen.modulate.a = 1.0
	label.modulate.a = 0.0
	leader_label.modulate.a = 0.0

	# --- Tween animation ---
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 1. Hold black for 1s
	tween.tween_interval(1.0)

	# 2. Fade in role label
	tween.tween_property(label, "modulate:a", 1.0, 1.0)

	# 3. If Leader, fade in LeaderLabel at the same time
	if is_leader:
		tween.parallel().tween_property(leader_label, "modulate:a", 1.0, 1.0)

	# 4. Stay visible for the rest of the duration
	var visible_time = max(0, duration - 3.0)
	tween.tween_interval(visible_time)

	# 5. Fade out both labels + black screen
	tween.parallel().tween_property(black_screen, "modulate:a", 0.0, 3.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 3.0)
	if is_leader:
		tween.parallel().tween_property(leader_label, "modulate:a", 0.0, 3.0)

	# 6. Cleanup
	await tween.finished
	emit_signal("role_reveal_finished")
	queue_free()
