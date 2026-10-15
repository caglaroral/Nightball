extends SceneTree
## Generates res://ui/theme.tres. Run:  godot --headless --path godot -s res://tools/build_theme.gd
## After that the theme can be fine-tuned in the Godot editor; rerunning this overwrites it.

const BG_SURFACE := Color("1a222b")
const BG_INSET := Color("10161b")
const TEXT := Color("eef2f5")
const MUTED := Color("8c98a2")
const ACCENT := Color("33c46c")
const ACCENT_DARK := Color("249752")
const RIM := Color(1, 1, 1, 0.12)

var _medium: FontFile
var _bold: FontFile
var _black: FontFile


func _initialize() -> void:
	_medium = load("res://assets/fonts/Inter-Medium.ttf")
	_bold = load("res://assets/fonts/Inter-Bold.ttf")
	_black = load("res://assets/fonts/InterDisplay-Black.ttf")

	var t := Theme.new()
	t.default_font = _medium
	t.default_font_size = 20

	_labels(t)
	_buttons(t)
	_panels(t)
	_line_edit(t)
	_scroll(t)

	var err := ResourceSaver.save(t, "res://ui/theme.tres")
	print("theme saved: ", error_string(err))
	quit(0 if err == OK else 1)


static func box(bg: Color, radius: int, shadow_alpha := 0.0, shadow_size := 0, shadow_y := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 12
	s.anti_aliasing = true
	s.anti_aliasing_size = 1.0
	if shadow_size > 0:
		s.shadow_color = Color(0, 0, 0, shadow_alpha)
		s.shadow_size = shadow_size
		s.shadow_offset = Vector2(0, shadow_y)
	return s


## Thin bright line along the top edge, as if lit from above.
static func rim(s: StyleBoxFlat, color: Color) -> StyleBoxFlat:
	s.border_color = color
	s.border_width_top = 1
	s.border_blend = true
	return s


static func margins(s: StyleBox, h: float, v: float) -> StyleBox:
	s.content_margin_left = h
	s.content_margin_right = h
	s.content_margin_top = v
	s.content_margin_bottom = v
	return s


func _labels(t: Theme) -> void:
	t.set_color("font_color", "Label", TEXT)

	t.add_type("TitleLabel")
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", _black)
	t.set_font_size("font_size", "TitleLabel", 96)
	t.set_color("font_shadow_color", "TitleLabel", Color(ACCENT, 0.35))
	t.set_constant("shadow_outline_size", "TitleLabel", 18)
	t.set_constant("shadow_offset_x", "TitleLabel", 0)
	t.set_constant("shadow_offset_y", "TitleLabel", 6)

	t.add_type("HeadingLabel")
	t.set_type_variation("HeadingLabel", "Label")
	t.set_font("font", "HeadingLabel", _bold)
	t.set_font_size("font_size", "HeadingLabel", 32)

	t.add_type("MutedLabel")
	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", MUTED)
	t.set_font_size("font_size", "MutedLabel", 18)

	t.add_type("ScoreLabel")
	t.set_type_variation("ScoreLabel", "Label")
	t.set_font("font", "ScoreLabel", _black)
	t.set_font_size("font_size", "ScoreLabel", 40)
	t.set_color("font_outline_color", "ScoreLabel", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "ScoreLabel", 6)

	t.add_type("BannerLabel")
	t.set_type_variation("BannerLabel", "Label")
	t.set_font("font", "BannerLabel", _black)
	t.set_font_size("font_size", "BannerLabel", 120)
	t.set_color("font_outline_color", "BannerLabel", Color(0, 0, 0, 0.75))
	t.set_constant("outline_size", "BannerLabel", 18)
	t.set_color("font_shadow_color", "BannerLabel", Color(0, 0, 0, 0.45))
	t.set_constant("shadow_offset_y", "BannerLabel", 10)
	t.set_constant("shadow_outline_size", "BannerLabel", 24)


func _button_states(t: Theme, type: String, normal: Color, hover: Color, pressed: Color, glow: Color) -> void:
	var n := rim(box(normal, 14, 0.35, 10, 4), RIM)
	var h := rim(box(hover, 14, 0.0, 18, 4), Color(1, 1, 1, 0.22))
	h.shadow_color = glow
	var p := box(pressed, 14, 0.3, 4, 1)
	var d := box(Color("232b32"), 14)
	var f := box(Color(0, 0, 0, 0), 16)
	f.draw_center = false
	f.set_border_width_all(2)
	f.border_color = Color(ACCENT, 0.9)
	f.set_expand_margin_all(3)
	for s in [n, h, p, d]:
		margins(s, 26, 14)
	t.set_stylebox("normal", type, n)
	t.set_stylebox("hover", type, h)
	t.set_stylebox("pressed", type, p)
	t.set_stylebox("hover_pressed", type, p)
	t.set_stylebox("disabled", type, d)
	t.set_stylebox("focus", type, f)


func _buttons(t: Theme) -> void:
	t.set_font("font", "Button", _bold)
	t.set_font_size("font_size", "Button", 22)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color(TEXT, 0.85))
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.6))
	_button_states(t, "Button", Color("2c3741"), Color("374552"), Color("232d36"), Color(0, 0, 0, 0.45))

	t.add_type("PrimaryButton")
	t.set_type_variation("PrimaryButton", "Button")
	_button_states(t, "PrimaryButton", Color("2ea860"), Color("38bd6d"), ACCENT_DARK, Color(ACCENT, 0.45))

	# Small flat button used in the match HUD.
	t.add_type("GhostButton")
	t.set_type_variation("GhostButton", "Button")
	var gn := margins(rim(box(Color(0.06, 0.08, 0.1, 0.55), 12), RIM), 18, 8)
	var gh := margins(rim(box(Color(0.12, 0.15, 0.18, 0.75), 12), Color(1, 1, 1, 0.2)), 18, 8)
	var gp := margins(box(Color(0.04, 0.05, 0.06, 0.8), 12), 18, 8)
	t.set_stylebox("normal", "GhostButton", gn)
	t.set_stylebox("hover", "GhostButton", gh)
	t.set_stylebox("pressed", "GhostButton", gp)
	t.set_stylebox("hover_pressed", "GhostButton", gp)
	t.set_font_size("font_size", "GhostButton", 18)

	# Rows in the room list.
	t.add_type("RowButton")
	t.set_type_variation("RowButton", "Button")
	var rn := margins(rim(box(Color("222c35"), 12, 0.25, 6, 2), RIM), 20, 16)
	var rh := margins(rim(box(Color("2b3843"), 12, 0.0, 14, 2), Color(1, 1, 1, 0.2)), 20, 16)
	(rh as StyleBoxFlat).shadow_color = Color(ACCENT, 0.3)
	var rp := margins(box(Color("1c242c"), 12), 20, 16)
	t.set_stylebox("normal", "RowButton", rn)
	t.set_stylebox("hover", "RowButton", rh)
	t.set_stylebox("pressed", "RowButton", rp)
	t.set_stylebox("hover_pressed", "RowButton", rp)
	t.set_font("font", "RowButton", _medium)
	t.set_font_size("font_size", "RowButton", 20)
	t.set_constant("h_separation", "RowButton", 12)


func _panels(t: Theme) -> void:
	var card := rim(box(Color(BG_SURFACE, 0.94), 22, 0.45, 28, 10), Color(1, 1, 1, 0.08))
	margins(card, 28, 24)
	t.set_stylebox("panel", "PanelContainer", card)
	t.set_stylebox("panel", "Panel", card)

	# Capsule used for the score and the clock.
	t.add_type("PillPanel")
	t.set_type_variation("PillPanel", "PanelContainer")
	var pill := rim(box(Color(0.05, 0.07, 0.09, 0.72), 999, 0.35, 14, 4), Color(1, 1, 1, 0.1))
	margins(pill, 26, 6)
	t.set_stylebox("panel", "PillPanel", pill)

	# Player entry inside a team card.
	t.add_type("PlayerChip")
	t.set_type_variation("PlayerChip", "PanelContainer")
	var chip := box(Color(1, 1, 1, 0.05), 10)
	margins(chip, 14, 8)
	t.set_stylebox("panel", "PlayerChip", chip)


func _line_edit(t: Theme) -> void:
	var normal := box(BG_INSET, 12)
	normal.set_border_width_all(1)
	normal.border_color = Color(1, 1, 1, 0.08)
	margins(normal, 16, 12)
	var focus := box(Color(0, 0, 0, 0), 14, 0.0, 10)
	focus.draw_center = false
	focus.set_border_width_all(2)
	focus.border_color = ACCENT
	focus.shadow_color = Color(ACCENT, 0.25)
	focus.set_expand_margin_all(1)
	t.set_stylebox("normal", "LineEdit", normal)
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_font_size("font_size", "LineEdit", 22)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.6))
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.35))


func _scroll(t: Theme) -> void:
	var grabber := box(Color(1, 1, 1, 0.18), 6)
	var grabber_hover := box(Color(1, 1, 1, 0.3), 6)
	var track := box(Color(0, 0, 0, 0), 6)
	margins(track, 4, 4)
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber_hover)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber_hover)
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
