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

@onready var graphics3d_scroll: ScrollContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics3D/ScrollContainer
@onready var msaa3d_title: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics3D/ScrollContainer/VBox/Msaa3DSection/Msaa3DTitle
@onready var msaa3d_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics3D/ScrollContainer/VBox/Msaa3DSection/Msaa3DOption
@onready var msaa3d_desc: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics3D/ScrollContainer/VBox/Msaa3DSection/Msaa3DDesc
@onready var res_scale_title: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics3D/ScrollContainer/VBox/ResolutionScaleSection/ResolutionScaleTitle
@onready var res_scale_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics3D/ScrollContainer/VBox/ResolutionScaleSection/ResolutionScaleRow/ResolutionScaleSlider
@onready var res_scale_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics3D/ScrollContainer/VBox/ResolutionScaleSection/ResolutionScaleRow/ResolutionScaleValueLabel
@onready var res_scale_desc: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics3D/ScrollContainer/VBox/ResolutionScaleSection/ResolutionScaleDesc
@onready var glow_check: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics3D/ScrollContainer/VBox/GlowSection/GlowCheck
@onready var glow_desc: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics3D/ScrollContainer/VBox/GlowSection/GlowDesc
@onready var ssao_check: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics3D/ScrollContainer/VBox/SsaoSection/SsaoCheck
@onready var ssao_desc: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics3D/ScrollContainer/VBox/SsaoSection/SsaoDesc
@onready var shadow_title: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics3D/ScrollContainer/VBox/ShadowQualitySection/ShadowQualityTitle
@onready var shadow_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics3D/ScrollContainer/VBox/ShadowQualitySection/ShadowQualityOption
@onready var shadow_desc: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics3D/ScrollContainer/VBox/ShadowQualitySection/ShadowQualityDesc
@onready var btn_restore_3d: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics3D/ScrollContainer/VBox/RestoreRow/BtnRestore3D

@onready var msaa2d_title: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics2D/VBox/Msaa2DSection/Msaa2DTitle
@onready var msaa2d_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics2D/VBox/Msaa2DSection/Msaa2DOption
@onready var msaa2d_desc: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics2D/VBox/Msaa2DSection/Msaa2DDesc
@onready var texfilter_title: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics2D/VBox/TextureFilterSection/TextureFilterTitle
@onready var texfilter_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics2D/VBox/TextureFilterSection/TextureFilterOption
@onready var texfilter_desc: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics2D/VBox/TextureFilterSection/TextureFilterDesc
@onready var btn_restore_2d: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics2D/VBox/RestoreRow/BtnRestore2D

var _previous_focus_control: Control = null
var _last_focused_debug_check: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if scroll_container:
		scroll_container.follow_focus = true
	if graphics3d_scroll:
		graphics3d_scroll.follow_focus = true
	aim_slider.value_changed.connect(_on_aim_slider_value_changed)
	btn_close.pressed.connect(_on_close_pressed)
	tab_container.tab_changed.connect(_on_tab_changed)
	_connect_graphics_signals()
	update_language()

func _setup_graphics_options() -> void:
	msaa3d_option.clear()
	msaa3d_option.add_item(tr("SETTINGS_GFX_OFF"), 0)
	msaa3d_option.add_item("2x", 1)
	msaa3d_option.add_item("4x", 2)
	msaa3d_option.add_item("8x", 3)

	shadow_option.clear()
	shadow_option.add_item(tr("SETTINGS_GFX_SHADOW_LOW"), 0)
	shadow_option.add_item(tr("SETTINGS_GFX_SHADOW_MEDIUM"), 1)
	shadow_option.add_item(tr("SETTINGS_GFX_SHADOW_HIGH"), 2)

	msaa2d_option.clear()
	msaa2d_option.add_item(tr("SETTINGS_GFX_OFF"), 0)
	msaa2d_option.add_item("2x", 1)
	msaa2d_option.add_item("4x", 2)
	msaa2d_option.add_item("8x", 3)

	texfilter_option.clear()
	texfilter_option.add_item(tr("SETTINGS_GFX_FILTER_NEAREST"), 0)
	texfilter_option.add_item(tr("SETTINGS_GFX_FILTER_LINEAR"), 1)

func _connect_graphics_signals() -> void:
	msaa3d_option.item_selected.connect(func(idx:int): Global.apply_gfx_msaa_3d(idx))
	res_scale_slider.value_changed.connect(_on_res_scale_slider_changed)
	glow_check.toggled.connect(func(pressed:bool): Global.apply_gfx_glow_override(1 if pressed else 0))
	ssao_check.toggled.connect(func(pressed:bool): Global.apply_gfx_ssao_override(1 if pressed else 0))
	shadow_option.item_selected.connect(func(idx:int): Global.apply_gfx_shadow_atlas_size(Global.shadow_atlas_sizes[idx]))
	btn_restore_3d.pressed.connect(_on_btn_restore_3d_pressed)

	msaa2d_option.item_selected.connect(func(idx:int): Global.apply_gfx_msaa_2d(idx))
	texfilter_option.item_selected.connect(func(idx:int): Global.apply_gfx_texture_filter_2d(idx))
	btn_restore_2d.pressed.connect(_on_btn_restore_2d_pressed)

func _on_res_scale_slider_changed(value:float) -> void:
	Global.apply_gfx_resolution_scale(value)
	_update_res_scale_label(value)

func _update_res_scale_label(value:float) -> void:
	res_scale_value_label.text = str(int(round(value * 100.0))) + "%"

func _on_btn_restore_3d_pressed() -> void:
	Global.restore_graphics_defaults_3d()
	_refresh_graphics_3d_ui()

func _on_btn_restore_2d_pressed() -> void:
	Global.restore_graphics_defaults_2d()
	_refresh_graphics_2d_ui()

func _refresh_graphics_3d_ui() -> void:
	msaa3d_option.select(Global.gfx_msaa_3d)
	res_scale_slider.value = Global.gfx_resolution_scale
	_update_res_scale_label(Global.gfx_resolution_scale)
	var shadow_idx := Global.shadow_atlas_sizes.find(Global.gfx_shadow_atlas_size)
	shadow_option.select(shadow_idx if shadow_idx != -1 else 2)
	var env := Global.get_active_3d_environment()
	glow_check.button_pressed = (env.glow_enabled if env else false) if Global.gfx_glow_override == -1 else (Global.gfx_glow_override == 1)
	ssao_check.button_pressed = (env.ssao_enabled if env else false) if Global.gfx_ssao_override == -1 else (Global.gfx_ssao_override == 1)

func _refresh_graphics_2d_ui() -> void:
	msaa2d_option.select(Global.gfx_msaa_2d)
	texfilter_option.select(Global.gfx_texture_filter_2d)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed):
		get_viewport().set_input_as_handled()
		fechar()
		return

	# Troca de abas no controle / teclado (LB / RB, L1 / R1, PageUp / PageDown)
	if event.is_action_pressed("ui_page_up") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_SHOULDER and event.pressed):
		get_viewport().set_input_as_handled()
		_switch_tab_relative(-1)
		return
	elif event.is_action_pressed("ui_page_down") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_SHOULDER and event.pressed):
		get_viewport().set_input_as_handled()
		_switch_tab_relative(1)
		return

	# Rolagem manual suave com o analógico direito do controle
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y and absf(event.axis_value) > 0.2:
		var active_scroll := _get_active_scroll_container()
		if is_instance_valid(active_scroll):
			active_scroll.scroll_vertical += int(event.axis_value * 14.0)

func _get_active_scroll_container() -> ScrollContainer:
	if tab_container.current_tab == 1:
		return graphics3d_scroll
	if tab_container.current_tab == _debug_tab_index():
		return scroll_container
	return null

func _debug_tab_index() -> int:
	return tab_container.get_tab_count() - 1

func _get_visible_tab_indices() -> Array:
	var result: Array = []
	for i in range(tab_container.get_tab_count()):
		if not tab_container.is_tab_hidden(i):
			result.append(i)
	return result

func _switch_tab_relative(delta: int) -> void:
	var visible_tabs := _get_visible_tab_indices()
	if visible_tabs.size() <= 1:
		return
	var pos := visible_tabs.find(tab_container.current_tab)
	if pos == -1:
		pos = 0
	var new_pos := (pos + delta) % visible_tabs.size()
	if new_pos < 0:
		new_pos += visible_tabs.size()
	_switch_tab(visible_tabs[new_pos])

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
	var debug_idx = _debug_tab_index()
	if debug_idx > 0:
		tab_container.set_tab_hidden(debug_idx, not has_debug)
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
		msaa3d_option.grab_focus()
		btn_close.focus_neighbor_top = btn_restore_3d.get_path()
	elif tab_idx == 2:
		msaa2d_option.grab_focus()
		btn_close.focus_neighbor_top = btn_restore_2d.get_path()
	elif tab_idx == _debug_tab_index():
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
	tab_container.set_tab_title(1, tr("SETTINGS_GRAPHICS_3D"))
	tab_container.set_tab_title(2, tr("SETTINGS_GRAPHICS_2D"))
	var debug_idx := _debug_tab_index()
	if debug_idx > 0:
		tab_container.set_tab_title(debug_idx, tr("SETTINGS_DEBUG"))
	aim_title.text = tr("SETTINGS_AIM_ASSIST")
	aim_desc.text = tr("SETTINGS_AIM_ASSIST_DESC")
	debug_title.text = tr("SETTINGS_GAME_EVENTS")
	btn_close.text = tr("SETTINGS_CLOSE")
	_update_aim_label(aim_slider.value)

	msaa3d_title.text = tr("SETTINGS_GFX_MSAA_3D")
	msaa3d_desc.text = tr("SETTINGS_GFX_MSAA_3D_DESC")
	res_scale_title.text = tr("SETTINGS_GFX_RES_SCALE")
	res_scale_desc.text = tr("SETTINGS_GFX_RES_SCALE_DESC")
	glow_check.text = tr("SETTINGS_GFX_GLOW")
	glow_desc.text = tr("SETTINGS_GFX_GLOW_DESC")
	ssao_check.text = tr("SETTINGS_GFX_SSAO")
	ssao_desc.text = tr("SETTINGS_GFX_SSAO_DESC")
	shadow_title.text = tr("SETTINGS_GFX_SHADOW")
	shadow_desc.text = tr("SETTINGS_GFX_SHADOW_DESC")
	btn_restore_3d.text = tr("SETTINGS_GFX_RESTORE")

	msaa2d_title.text = tr("SETTINGS_GFX_MSAA_2D")
	msaa2d_desc.text = tr("SETTINGS_GFX_MSAA_2D_DESC")
	texfilter_title.text = tr("SETTINGS_GFX_TEXTURE_FILTER")
	texfilter_desc.text = tr("SETTINGS_GFX_TEXTURE_FILTER_DESC")
	btn_restore_2d.text = tr("SETTINGS_GFX_RESTORE")

	_setup_graphics_options()
	_refresh_graphics_3d_ui()
	_refresh_graphics_2d_ui()

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

	var dungeon_invincible_check = CheckBox.new()
	dungeon_invincible_check.text = "🛡 " + tr("SETTINGS_DEBUG_DUNGEON_INVINCIBLE")
	dungeon_invincible_check.tooltip_text = tr("SETTINGS_DEBUG_DUNGEON_INVINCIBLE_DESC")
	dungeon_invincible_check.button_pressed = Global.debug_dungeon_invincible
	dungeon_invincible_check.focus_mode = Control.FOCUS_ALL
	dungeon_invincible_check.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	dungeon_invincible_check.add_theme_color_override("font_hover_color", Color(0.68, 0.94, 1.0))
	dungeon_invincible_check.add_theme_color_override("font_focus_color", Color(0.68, 0.94, 1.0))
	dungeon_invincible_check.toggled.connect(func(pressed: bool):
		Global.debug_dungeon_invincible = pressed
	)
	debug_events_container.add_child(dungeon_invincible_check)
	checks.append(dungeon_invincible_check)

	# Botão para resetar eventos do calabouço no save slot atual
	var reset_dungeon_btn = Button.new()
	reset_dungeon_btn.text = "🔄 " + tr("SETTINGS_DEBUG_RESET_DUNGEON")
	reset_dungeon_btn.tooltip_text = tr("SETTINGS_DEBUG_RESET_DUNGEON_DESC")
	reset_dungeon_btn.focus_mode = Control.FOCUS_ALL
	reset_dungeon_btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	reset_dungeon_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.7, 0.7))
	reset_dungeon_btn.pressed.connect(func():
		Global.reset_dungeon_events(true)
		_populate_debug_events()
	)
	debug_events_container.add_child(reset_dungeon_btn)
	checks.append(reset_dungeon_btn)

	var sep = HSeparator.new()
	debug_events_container.add_child(sep)

	# 2. Eventos da história / game_events (organizados: calabouço primeiro destacados, depois gerais)
	var dungeon_keys: Array[String] = []
	var other_keys: Array[String] = []
	for k in Global.game_events.keys():
		if str(k).begins_with("dungeon_") or k == "axe_taken":
			dungeon_keys.append(str(k))
		else:
			other_keys.append(str(k))

	var dungeon_label = Label.new()
	dungeon_label.text = "🏰 " + tr("SETTINGS_DEBUG_DUNGEON_SECTION")
	dungeon_label.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0))
	debug_events_container.add_child(dungeon_label)

	for event_name in dungeon_keys:
		var check = CheckBox.new()
		check.text = str(event_name)
		check.button_pressed = bool(Global.game_events.get(event_name, false))
		check.focus_mode = Control.FOCUS_ALL
		check.add_theme_color_override("font_color", Color(0.8, 0.88, 1.0))
		check.toggled.connect(func(pressed: bool):
			Global.game_events[event_name] = pressed
			if event_name == "axe_taken" or event_name == "dungeon_axe_taken":
				Global.maycon_itens["axe"] = pressed
			Global.save_to_player_savegame()
			Global.save_settings()
		)
		debug_events_container.add_child(check)
		checks.append(check)

	var sep2 = HSeparator.new()
	debug_events_container.add_child(sep2)

	var story_label = Label.new()
	story_label.text = "📜 " + tr("SETTINGS_DEBUG_STORY_SECTION")
	story_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.55))
	debug_events_container.add_child(story_label)

	for event_name in other_keys:
		var check = CheckBox.new()
		check.text = str(event_name)
		check.button_pressed = bool(Global.game_events.get(event_name, false))
		check.focus_mode = Control.FOCUS_ALL
		check.toggled.connect(func(pressed: bool):
			Global.game_events[event_name] = pressed
			Global.save_to_player_savegame()
			Global.save_settings()
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
