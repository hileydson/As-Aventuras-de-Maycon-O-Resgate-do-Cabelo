extends CanvasLayer

signal special_activated

var active:bool = false
var time_left:float = 0.0
var total_time:float = 10.0

var overlay_control:Control
var badge_panel:PanelContainer
var title_label:Label
var time_label:Label
var particles:Array[Dictionary] = []
var badge_style:StyleBoxFlat

var special_prompt_panel:PanelContainer
var special_prompt_style:StyleBoxFlat
var special_icon:TextureRect
var special_prompt_label:Label
var special_ready:bool = false

const COLORS := [
	Color("ffd700"), # Gold
	Color("ff2d75"), # Neon Pink
	Color("00f0ff"), # Cyan
	Color("39ff14"), # Lime
	Color("b026ff"), # Purple
	Color("ff7700")  # Orange
]

func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_ui()

func _build_ui() -> void:
	overlay_control = Control.new()
	overlay_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_control.draw.connect(_on_overlay_draw)
	add_child(overlay_control)

	# 10-Second Countdown Badge (Top Center)
	badge_panel = PanelContainer.new()
	badge_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	badge_panel.position = Vector2(-110.0, 18.0)
	badge_panel.custom_minimum_size = Vector2(220.0, 68.0)
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.08, 0.12, 0.22, 0.88)
	badge_style.border_color = Color(0.18, 0.85, 1.0, 0.95)
	badge_style.set_border_width_all(3)
	badge_style.set_corner_radius_all(18)
	badge_style.shadow_color = Color(0.05, 0.5, 0.9, 0.45)
	badge_style.shadow_size = 14
	badge_style.set_content_margin_all(8)
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	add_child(badge_panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 1)
	badge_panel.add_child(column)

	title_label = Label.new()
	title_label.text = "✦ " + tr("PLATFORM_INVINCIBLE_TITLE") + " ✦"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color("ffe082"))
	column.add_child(title_label)

	time_label = Label.new()
	time_label.text = "10.0s"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 24)
	time_label.add_theme_color_override("font_color", Color("ffffff"))
	column.add_child(time_label)

	badge_panel.visible = false

	# Pulsing Button Y Special Prompt (Bottom Center)
	special_prompt_panel = PanelContainer.new()
	special_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	special_prompt_panel.position = Vector2(-130.0, -82.0)
	special_prompt_panel.custom_minimum_size = Vector2(260.0, 56.0)
	special_prompt_panel.pivot_offset = Vector2(130.0, 28.0)
	special_prompt_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	special_prompt_style = StyleBoxFlat.new()
	special_prompt_style.bg_color = Color(0.08, 0.12, 0.22, 0.94)
	special_prompt_style.border_color = Color("ffd700")
	special_prompt_style.set_border_width_all(3)
	special_prompt_style.set_corner_radius_all(20)
	special_prompt_style.shadow_color = Color(0.9, 0.65, 0.1, 0.5)
	special_prompt_style.shadow_size = 16
	special_prompt_style.set_content_margin_all(8)
	special_prompt_panel.add_theme_stylebox_override("panel", special_prompt_style)
	special_prompt_panel.gui_input.connect(_on_special_prompt_gui_input)
	add_child(special_prompt_panel)

	var prompt_row := HBoxContainer.new()
	prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt_row.add_theme_constant_override("separation", 10)
	prompt_row.mouse_filter = Control.MOUSE_FILTER_PASS
	special_prompt_panel.add_child(prompt_row)

	special_icon = TextureRect.new()
	special_icon.texture = load("res://assets/novas_imagens/buttons/360_Y.png")
	special_icon.custom_minimum_size = Vector2(36.0, 36.0)
	special_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	special_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	special_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_row.add_child(special_icon)

	special_prompt_label = Label.new()
	special_prompt_label.text = tr("PLATFORM_SPECIAL_PROMPT")
	special_prompt_label.add_theme_font_size_override("font_size", 14)
	special_prompt_label.add_theme_color_override("font_color", Color("fff6d0"))
	special_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_row.add_child(special_prompt_label)

	special_prompt_panel.visible = false

func _on_special_prompt_gui_input(event:InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		special_activated.emit()

func set_special_prompt_visible(visible_val:bool) -> void:
	special_ready = visible_val
	if not is_instance_valid(special_prompt_panel):
		return
	if visible_val:
		special_prompt_panel.visible = true
		special_prompt_panel.scale = Vector2(0.3, 0.3)
		var tween := create_tween().bind_node(special_prompt_panel)
		tween.tween_property(special_prompt_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		if special_prompt_panel.visible:
			var tween := create_tween().bind_node(special_prompt_panel)
			tween.tween_property(special_prompt_panel, "scale", Vector2(0.3, 0.3), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_callback(func(): special_prompt_panel.visible = false)

func start_invincibility(duration:float = 10.0) -> void:
	set_special_prompt_visible(false)
	active = true
	time_left = duration
	total_time = duration
	badge_panel.visible = true
	badge_panel.scale = Vector2(0.5, 0.5)
	badge_panel.pivot_offset = badge_panel.custom_minimum_size * 0.5
	var tween := create_tween().bind_node(badge_panel)
	tween.tween_property(badge_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func stop_invincibility() -> void:
	if not active and not badge_panel.visible:
		return
	active = false
	time_left = 0.0
	var tween := create_tween().bind_node(badge_panel)
	tween.tween_property(badge_panel, "scale", Vector2(0.4, 0.4), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): badge_panel.visible = false)

func _process(delta:float) -> void:
	if special_prompt_panel.visible:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.007) * 0.08
		special_prompt_panel.scale = Vector2(pulse, pulse)
		var glow := absf(sin(Time.get_ticks_msec() * 0.005))
		special_prompt_style.border_color = Color("ffd700").lerp(Color("00f0ff"), glow)
		special_prompt_style.shadow_color = Color(0.9, 0.7, 0.1, 0.3 + glow * 0.35)

	if active:
		time_left = maxf(time_left - delta, 0.0)
		time_label.text = "%.1f s" % time_left
		if time_left <= 3.0:
			var flash:float = absf(sin(time_left * 12.0))
			badge_style.border_color = Color("ff3366").lerp(Color("ffe082"), flash)
			time_label.add_theme_color_override("font_color", Color("ffdddd").lerp(Color("ff4466"), flash))
			badge_panel.scale = Vector2.ONE * (1.0 + flash * 0.06)
		else:
			var glow:float = absf(sin(Time.get_ticks_msec() * 0.006))
			badge_style.border_color = Color("00e5ff").lerp(Color("ffdf00"), glow * 0.5)
			time_label.add_theme_color_override("font_color", Color.WHITE)
			badge_panel.scale = Vector2.ONE

		_spawn_edge_particles()
		if time_left <= 0.0:
			stop_invincibility()

	_update_particles(delta)
	if active or particles.size() > 0:
		overlay_control.queue_redraw()

func _spawn_edge_particles() -> void:
	var vp_size := overlay_control.get_viewport_rect().size
	var spawn_count := 8
	for i in range(spawn_count):
		var edge := randi() % 4
		var pos := Vector2.ZERO
		var vel := Vector2.ZERO
		match edge:
			0: # Top
				pos = Vector2(randf_range(0.0, vp_size.x), randf_range(0.0, 6.0))
				vel = Vector2(randf_range(-40.0, 40.0), randf_range(90.0, 200.0))
			1: # Bottom
				pos = Vector2(randf_range(0.0, vp_size.x), vp_size.y - randf_range(0.0, 6.0))
				vel = Vector2(randf_range(-40.0, 40.0), -randf_range(90.0, 200.0))
			2: # Left
				pos = Vector2(randf_range(0.0, 6.0), randf_range(0.0, vp_size.y))
				vel = Vector2(randf_range(90.0, 200.0), randf_range(-40.0, 40.0))
			3: # Right
				pos = Vector2(vp_size.x - randf_range(0.0, 6.0), randf_range(0.0, vp_size.y))
				vel = Vector2(-randf_range(90.0, 200.0), randf_range(-40.0, 40.0))

		var life := randf_range(0.45, 0.78)
		particles.append({
			"pos": pos,
			"vel": vel,
			"color": COLORS[randi() % COLORS.size()],
			"radius": randf_range(3.2, 6.5),
			"life": life,
			"max_life": life,
			"is_star": randf() < 0.45
		})

func _update_particles(delta:float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p:Dictionary = particles[i]
		p["life"] = float(p.life) - delta
		p["pos"] = Vector2(p.pos) + Vector2(p.vel) * delta
		p["vel"] = Vector2(p.vel) * (1.0 - delta * 3.4)
		if float(p.life) <= 0.0:
			particles.remove_at(i)

func _on_overlay_draw() -> void:
	var vp_size := overlay_control.get_viewport_rect().size
	if active:
		# Subtle rainbow border glow
		var hue := fmod(Time.get_ticks_msec() * 0.0008, 1.0)
		var border_col := Color.from_hsv(hue, 0.75, 1.0, 0.18)
		var margin := 16.0
		overlay_control.draw_rect(Rect2(0.0, 0.0, vp_size.x, margin), border_col)
		overlay_control.draw_rect(Rect2(0.0, vp_size.y - margin, vp_size.x, margin), border_col)
		overlay_control.draw_rect(Rect2(0.0, margin, margin, vp_size.y - margin * 2.0), border_col)
		overlay_control.draw_rect(Rect2(vp_size.x - margin, margin, margin, vp_size.y - margin * 2.0), border_col)

	for p in particles:
		var alpha := clampf(float(p.life) / float(p.max_life), 0.0, 1.0)
		var col:Color = p.color
		col.a = alpha * 0.92
		var pos:Vector2 = p.pos
		var rad:float = float(p.radius) * (0.5 + alpha * 0.5)
		if bool(p.is_star):
			# 4-point star sparkle
			var pts := PackedVector2Array([
				pos + Vector2(0.0, -rad * 1.5),
				pos + Vector2(rad * 0.35, -rad * 0.35),
				pos + Vector2(rad * 1.5, 0.0),
				pos + Vector2(rad * 0.35, rad * 0.35),
				pos + Vector2(0.0, rad * 1.5),
				pos + Vector2(-rad * 0.35, rad * 0.35),
				pos + Vector2(-rad * 1.5, 0.0),
				pos + Vector2(-rad * 0.35, -rad * 0.35)
			])
			overlay_control.draw_colored_polygon(pts, col)
			overlay_control.draw_circle(pos, rad * 0.3, Color(1.0, 1.0, 1.0, alpha))
		else:
			overlay_control.draw_circle(pos, rad, col)
			overlay_control.draw_circle(pos, rad * 0.45, Color(1.0, 1.0, 1.0, alpha * 0.9))
