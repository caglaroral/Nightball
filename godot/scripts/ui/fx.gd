class_name Fx
## Small UI motion helpers shared by the screens.


## Buttons grow slightly on hover and dip when pressed, with a click sound.
static func juice_buttons(root: Node) -> void:
	for node in root.find_children("*", "BaseButton", true, false):
		juice(node as BaseButton)


static func juice(button: BaseButton) -> void:
	if button.has_meta("juiced"):
		return
	button.set_meta("juiced", true)
	button.resized.connect(func(): button.pivot_offset = button.size / 2.0)
	button.pivot_offset = button.size / 2.0
	button.mouse_entered.connect(func(): _scale_to(button, 1.04, 0.12))
	button.mouse_exited.connect(func(): _scale_to(button, 1.0, 0.15))
	button.button_down.connect(func():
		_scale_to(button, 0.96, 0.06)
		Sfx.play("click", -6.0))
	button.button_up.connect(func(): _scale_to(button, 1.04 if button.is_hovered() else 1.0, 0.12))


static func _scale_to(control: Control, value: float, duration: float) -> void:
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2(value, value), duration) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fades and slides a screen's content in.
static func enter(control: Control) -> void:
	control.modulate.a = 0.0
	var start := control.position
	control.position = start + Vector2(0, 24)
	var tween := control.create_tween().set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "position", start, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
