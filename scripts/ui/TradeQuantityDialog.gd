extends Control

signal trade_confirmed(action_type: String, item_id: String, amount: int)

var _overlay: ColorRect
var _panel: Panel
var _title_label: Label
var _summary_label: Label
var _spin_box: SpinBox
var _total_label: Label
var _confirm_button: Button
var _cancel_button: Button

var _action_type: String = ""
var _item_id: String = ""
var _unit_price: int = 0
var _max_amount: int = 1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		hide_dialog()


func is_open() -> bool:
	return visible


func open_dialog(action_type: String, item_id: String, max_amount: int, unit_price: int) -> void:
	_action_type = action_type
	_item_id = item_id
	_unit_price = unit_price
	_max_amount = max(max_amount, 1)
	_title_label.text = "卖出物品" if action_type == "sell" else "购买物品"
	_summary_label.text = "%s\n单价：%d 金币\n可选数量：1 - %d" % [
		ItemDatabase.get_display_name(item_id),
		unit_price,
		_max_amount
	]
	_spin_box.min_value = 1
	_spin_box.max_value = _max_amount
	_spin_box.step = 1
	_spin_box.value = 1
	_confirm_button.text = "确认卖出" if action_type == "sell" else "确认购买"
	_update_total_label(1.0)
	visible = true
	_spin_box.grab_focus()


func hide_dialog() -> void:
	visible = false


func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	_panel = Panel.new()
	_panel.size = Vector2(360, 240)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.98, 0.94, 0.84, 0.98)
	panel_style.border_color = Color(0.60, 0.42, 0.22, 0.95)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	_title_label = Label.new()
	_title_label.position = Vector2(20, 18)
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.27, 0.17, 0.09))
	_panel.add_child(_title_label)

	_summary_label = Label.new()
	_summary_label.position = Vector2(20, 56)
	_summary_label.size = Vector2(320, 74)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_font_size_override("font_size", 16)
	_summary_label.add_theme_color_override("font_color", Color(0.32, 0.21, 0.11))
	_panel.add_child(_summary_label)

	_spin_box = SpinBox.new()
	_spin_box.position = Vector2(20, 138)
	_spin_box.size = Vector2(120, 30)
	_spin_box.value_changed.connect(_update_total_label)
	_panel.add_child(_spin_box)

	_total_label = Label.new()
	_total_label.position = Vector2(156, 140)
	_total_label.size = Vector2(184, 28)
	_total_label.add_theme_font_size_override("font_size", 16)
	_total_label.add_theme_color_override("font_color", Color(0.45, 0.27, 0.11))
	_panel.add_child(_total_label)

	_confirm_button = Button.new()
	_confirm_button.position = Vector2(20, 186)
	_confirm_button.size = Vector2(150, 34)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_panel.add_child(_confirm_button)

	_cancel_button = Button.new()
	_cancel_button.position = Vector2(190, 186)
	_cancel_button.size = Vector2(150, 34)
	_cancel_button.text = "取消"
	_cancel_button.pressed.connect(hide_dialog)
	_panel.add_child(_cancel_button)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_panel.position = (get_viewport_rect().size - _panel.size) * 0.5


func _update_total_label(value: float) -> void:
	var amount := int(round(value))
	_total_label.text = "总价：%d 金币" % (_unit_price * amount)


func _on_confirm_pressed() -> void:
	var amount := int(round(_spin_box.value))
	trade_confirmed.emit(_action_type, _item_id, amount)
	hide_dialog()
