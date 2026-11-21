class_name Hud
extends CanvasLayer
## HUD + title / pause / win overlays. Bilingual text uses a system CJK font fallback.

var _fireflies: Label
var _deaths: Label
var _time: Label
var _overlay: PanelContainer
var _title: Label
var _body: Label
var _toast: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 28
	bar.offset_top = 18
	bar.offset_right = -28
	bar.add_theme_constant_override("separation", 36)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var icon := TextureRect.new()
	icon.texture = load("res://art/final/objects/firefly1.png")
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bar.add_child(icon)
	_fireflies = _label(bar, "0 / 0", 34)
	_deaths = _label(bar, "", 28)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_time = _label(bar, "0:00.0", 28)

	_toast = _label(root, "", 30)
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 90
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0

	_overlay = PanelContainer.new()
	_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.07, 0.18, 0.88)
	style.border_color = Color(1.0, 0.75, 0.35, 0.9)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(36)
	_overlay.add_theme_stylebox_override("panel", style)
	root.add_child(_overlay)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_overlay.add_child(vb)
	_title = _label(vb, "", 64)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	_body = _label(vb, "", 26)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _make_theme() -> Theme:
	var th := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei UI", "Microsoft JhengHei",
		"Noto Sans CJK TC", "PingFang TC", "Noto Sans", "Sans-Serif"])
	font.font_weight = 700
	th.default_font = font
	return th


func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.16))
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func set_stats(fireflies: int, total: int, deaths: int, seconds: float) -> void:
	_fireflies.text = "%d / %d" % [fireflies, total]
	_deaths.text = "✕ %d" % deaths if deaths > 0 else ""
	_time.text = format_time(seconds)


static func format_time(seconds: float) -> String:
	return "%d:%04.1f" % [int(seconds) / 60, fmod(seconds, 60.0)]


func show_overlay(title: String, body: String) -> void:
	_title.text = title
	_body.text = body
	_overlay.visible = true


func hide_overlay() -> void:
	_overlay.visible = false


func toast(text: String) -> void:
	_toast.text = text
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
