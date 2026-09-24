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
@onready var scroll_container: ScrollContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Debug/VBoxContainer/ScrollContainer
@onready var debug_events_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Debug/VBoxContainer/ScrollContainer/DebugEventsContainer
@onready var btn_close: Button = $PanelContainer/MarginContainer/VBoxContainer/Footer/BtnClose

var _previous_focus_control: Control = null
var _last_focused_debug_check: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if scroll_container:
		scroll_container.follow_focus = true
	aim_slider.value_changed.connect(_on_aim_slider_value_changed)
	btn_close.pressed.connect(_on_close_pressed)
	tab_container.tab_changed.connect(_on_tab_changed)
	update_language()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		fechar()
		return

	# Troca de abas no controle / teclado (LB / RB, L1 / R1, PageUp / PageDown)
	if tab_container.get_tab_count() > 1 and Global.show_debug_tab:
		if event.is_action_pressed("ui_page_up") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_SHOULDER and event.pressed):
			get_viewport().set_input_as_handled()
			_switch_tab(0)
			return
		elif event.is_action_pressed("ui_page_down") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_SHOULDER and event.pressed):
			get_viewport().set_input_as_handled()
			_switch_tab(1)
			return

	# Rolagem manual suave com o analógico direito do controle
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y and absf(event.axis_value) > 0.2:
		if tab_container.current_tab == 1 and is_instance_valid(scroll_container):
			scroll_container.scroll_vertical += int(event.axis_value * 14.0)

func abrir() -> void:
	_previous_focus_control = get_viewport().gui_get_focus_owner()
	update_language()
	setup_tabs()
	aim_slider.value = Global.aim_assist_strength
	_update_aim_label(Global.aim_assist_strength)
	if Global.show_debug_tab:
		_populate_debug_events()
	visible = true
	_on_tab_changed(tab_container.current_tab)

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

func _switch_tab(idx: int) -> void:
	if tab_container.current_tab != idx:
		tab_container.current_tab = idx
		_on_tab_changed(idx)

func _on_tab_changed(tab_idx: int) -> void:
	if tab_idx == 0:
		aim_slider.grab_focus()
		btn_close.focus_neighbor_top = aim_slider.get_path()
	elif tab_idx == 1:
		btn_close.focus_neighbor_top = NodePath("")
		if is_instance_valid(_last_focused_debug_check) and _last_focused_debug_check.is_inside_tree():
			_last_focused_debug_check.grab_focus()
		elif debug_events_container.get_child_count() > 0:
			var first = debug_events_container.get_child(0) as Control
			if is_instance_valid(first):
				first.grab_focus()
		
		if debug_events_container.get_child_count() > 0:
			var last = debug_events_container.get_child(debug_events_container.get_child_count() - 1) as Control
			if is_instance_valid(last):
				btn_close.focus_neighbor_top = last.get_path()

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
	for event_name in Global.game_events_default.keys():
		if !Global.game_events.has(event_name):
			Global.game_events[event_name] = Global.game_events_default[event_name]
	
	var checks: Array[CheckBox] = []

	# 1. Opção especial de teste: Desativar batalhas / Derrota instantânea ao encostar
	var battle_check = CheckBox.new()
	battle_check.text = "⚡ " + tr("SETTINGS_DEBUG_NO_BATTLES")
	battle_check.tooltip_text = tr("SETTINGS_DEBUG_NO_BATTLES_DESC")
	battle_check.button_pressed = Global.debug_disable_battles
	battle_check.focus_mode = Control.FOCUS_ALL
	battle_check.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	battle_check.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.55))
	battle_check.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.55))
	battle_check.toggled.connect(func(pressed: bool):
		Global.debug_disable_battles = pressed
	)
	debug_events_container.add_child(battle_check)
	checks.append(battle_check)

	var sep = HSeparator.new()
	debug_events_container.add_child(sep)

	# 2. Eventos da história / game_events
	for event_name in Global.game_events.keys():
		var check = CheckBox.new()
		check.text = str(event_name)
		check.button_pressed = bool(Global.game_events.get(event_name, false))
		check.focus_mode = Control.FOCUS_ALL
		check.toggled.connect(func(pressed: bool):
			Global.game_events[event_name] = pressed
		)
		debug_events_container.add_child(check)
		checks.append(check)

	# Encadeamento de foco vertical explícito para navegação fluida no controle
	for i in range(checks.size()):
		var check = checks[i]
		if i > 0:
			check.focus_neighbor_top = checks[i - 1].get_path()
		else:
			check.focus_neighbor_top = check.get_path()
		
		if i < checks.size() - 1:
			check.focus_neighbor_bottom = checks[i + 1].get_path()
		else:
			check.focus_neighbor_bottom = btn_close.get_path()
		
		check.focus_neighbor_left = check.get_path()
		check.focus_neighbor_right = check.get_path()

		# Esquerda no controle volta para a aba Gameplay
		check.gui_input.connect(func(ev: InputEvent):
			if ev.is_action_pressed("ui_left"):
				get_viewport().set_input_as_handled()
				_switch_tab(0)
		)

		check.focus_entered.connect(func():
			_last_focused_debug_check = check
			_scroll_to_control(check)
		)

	if checks.size() > 0:
		btn_close.focus_neighbor_top = checks[checks.size() - 1].get_path()

func _scroll_to_control(ctrl: Control) -> void:
	if not is_instance_valid(scroll_container) or not is_instance_valid(ctrl):
		return
	_do_scroll_to_control.call_deferred(ctrl)

func _do_scroll_to_control(ctrl: Control) -> void:
	if not is_instance_valid(scroll_container) or not is_instance_valid(ctrl):
		return
	
	scroll_container.ensure_control_visible(ctrl)
	
	var ctrl_rect: Rect2 = ctrl.get_global_rect()
	var scroll_rect: Rect2 = scroll_container.get_global_rect()
	
	if ctrl_rect.position.y < scroll_rect.position.y + 6.0:
		var diff: float = (scroll_rect.position.y + 6.0) - ctrl_rect.position.y
		scroll_container.scroll_vertical = maxi(0, scroll_container.scroll_vertical - int(diff) - 8)
	elif ctrl_rect.end.y > scroll_rect.end.y - 6.0:
		var diff: float = ctrl_rect.end.y - (scroll_rect.end.y - 6.0)
		scroll_container.scroll_vertical = scroll_container.scroll_vertical + int(diff) + 8

func _on_close_pressed() -> void:
	fechar()
