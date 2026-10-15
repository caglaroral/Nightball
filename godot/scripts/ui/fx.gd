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


## Phones do not move the app when the on-screen keyboard opens, so a text field can end up
## underneath it. Call every frame: slides content (anchored to the full screen) up until the
## focused text field sits just above the keyboard, and back down when it closes.
static func follow_keyboard(content: Control, delta: float) -> void:
	# Desktop has no on-screen keyboard (and asking for its height logs a warning).
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	var keyboard_px := DisplayServer.virtual_keyboard_get_height()
	# Nothing to undo; also leaves the screen's slide-in animation alone.
	if keyboard_px <= 0 and content.position.y >= -0.5:
		return
	var focus := content.get_viewport().gui_get_focus_owner()
	var target := 0.0
	if keyboard_px > 0 and focus is LineEdit and content.is_ancestor_of(focus):
		var view_height := content.get_viewport_rect().size.y
		var units_per_px := view_height / float(DisplayServer.window_get_size().y)
		var keyboard_top := view_height - keyboard_px * units_per_px
		var field_bottom := focus.get_global_rect().end.y - content.position.y
		target = minf(0.0, keyboard_top - 20.0 - field_bottom)
	content.position.y = lerpf(content.position.y, target, 1.0 - exp(-14.0 * delta))


## Fades and slides a screen's content in.
static func enter(control: Control) -> void:
	control.modulate.a = 0.0
	var start := control.position
	control.position = start + Vector2(0, 24)
	var tween := control.create_tween().set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "position", start, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
