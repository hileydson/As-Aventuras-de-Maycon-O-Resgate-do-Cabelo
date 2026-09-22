extends CanvasLayer

signal closed

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/TitleLabel
@onready var tab_container: TabContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer
@onready var aim_title: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Gameplay/VBoxContainer/AimAssistSection/AimTitle
@onready var aim_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Gameplay/VBoxContainer/AimAssistSection/HBoxContainer/AimSlider
@onready var aim_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Gameplay/VBoxContainer/AimAssistSection/HBoxContainer/AimValueLabel
@onready var aim_desc: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Gameplay/VBoxContainer/AimAssistSection/AimDesc
@onready var debug_title: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Debug/VBoxContainer/DebugTitle
@onready var debug_events_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Debug/VBoxContainer/ScrollContainer/DebugEventsContainer
@onready var btn_close: Button = $PanelContainer/MarginContainer/VBoxContainer/Footer/BtnClose

var _previous_focus_control: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	aim_slider.value_changed.connect(_on_aim_slider_value_changed)
	btn_close.pressed.connect(_on_close_pressed)
	update_language()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		fechar()

func abrir() -> void:
	_previous_focus_control = get_viewport().gui_get_focus_owner()
	update_language()
	setup_tabs()
	aim_slider.value = Global.aim_assist_strength
	_update_aim_label(Global.aim_assist_strength)
	if Global.show_debug_tab:
		_populate_debug_events()
	visible = true
	aim_slider.grab_focus()

func fechar() -> void:
	Global.save_settings()
	visible = false
	emit_signal("closed")
	if is_instance_valid(_previous_focus_control) and _previous_focus_control.is_inside_tree():
		_previous_focus_control.grab_focus()

func setup_tabs() -> void:
	var has_debug = Global.show_debug_tab
	if tab_container.get_tab_count() > 1:
		tab_container.set_tab_hidden(1, not has_debug)
	tab_container.current_tab = 0

func update_language() -> void:
	title_label.text = tr("SETTINGS_TITLE")
	tab_container.set_tab_title(0, tr("SETTINGS_GAMEPLAY"))
	if tab_container.get_tab_count() > 1:
		tab_container.set_tab_title(1, tr("SETTINGS_DEBUG"))
	aim_title.text = tr("SETTINGS_AIM_ASSIST")
	aim_desc.text = tr("SETTINGS_AIM_ASSIST_DESC")
	debug_title.text = tr("SETTINGS_GAME_EVENTS")
	btn_close.text = tr("SETTINGS_CLOSE")
	_update_aim_label(aim_slider.value)

func _update_aim_label(value: float) -> void:
	if value <= 0.001:
		aim_value_label.text = tr("SETTINGS_AIM_OFF")
	else:
		var pct = int(round(value * 100.0))
		aim_value_label.text = str(pct) + "%"

func _on_aim_slider_value_changed(val: float) -> void:
	Global.aim_assist_strength = val
	_update_aim_label(val)

func _populate_debug_events() -> void:
	for child in debug_events_container.get_children():
		child.queue_free()
	
	for event_name in Global.game_events.keys():
		var check = CheckBox.new()
		check.text = str(event_name)
		check.button_pressed = bool(Global.game_events.get(event_name, false))
		check.focus_mode = Control.FOCUS_ALL
		check.toggled.connect(func(pressed: bool):
			Global.game_events[event_name] = pressed
		)
		debug_events_container.add_child(check)

func _on_close_pressed() -> void:
	fechar()
