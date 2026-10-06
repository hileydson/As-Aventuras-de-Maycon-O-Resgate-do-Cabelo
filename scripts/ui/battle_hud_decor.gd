extends Node

# Moldura escura do HUD das fases 3D a pé (primeira batalha e caminho das pedras).
# Os retângulos estão em coordenadas de tela (1152x648) e são convertidos para o
# espaço local de cada HUD, para o desenho envolver os ícones certinho. O HUD de
# corrida troca de ícone conforme o dispositivo, então a moldura o acompanha.
const STAMINA_BAR = preload("res://scripts/ui/stamina_bar.gd")

const GUN_PANEL_RECT := Rect2(1047.0, 542.0, 88.0, 103.0)
const LIFE_PANEL_RECT := Rect2(0.0, 597.0, 235.5, 47.0)
const RUN_PANEL_KBM_RECT := Rect2(40.0, 566.0, 62.0, 39.0)
const RUN_PANEL_PAD_RECT := Rect2(0.0, 562.0, 51.0, 44.0)
const STAMINA_BAR_SIZE := Vector2(84.0, 7.0)
const STAMINA_BAR_GAP := 8.0

const GUN_ACCENT := Color(1.0, 0.48, 0.68)
const LIFE_ACCENT := Color(0.31, 0.67, 0.8)
const RUN_ACCENT := Color(0.55, 0.92, 0.72)

var player:Node = null
var run_panel:PanelContainer
var stamina_bar:Control

func _ready() -> void:
	var hud:Node = player.get_node_or_null("hud_canvas") if is_instance_valid(player) else null
	if not is_instance_valid(hud):
		queue_free()
		return
	var gun_controls := hud.get_node_or_null("control_gun") as CanvasItem
	if is_instance_valid(gun_controls):
		var gun_panel := _add_panel(gun_controls, "GunHudBackdrop", GUN_PANEL_RECT, GUN_ACCENT)
		gun_controls.move_child(gun_panel, 0)
	var life_hud := hud.get_node_or_null("maycon_hp") as CanvasItem
	if is_instance_valid(life_hud):
		run_panel = _add_panel(life_hud, "RunHudBackdrop", _run_panel_rect(), RUN_ACCENT)
		life_hud.move_child(run_panel, 0)
		var life_panel := _add_panel(life_hud, "LifeHudBackdrop", LIFE_PANEL_RECT, LIFE_ACCENT)
		life_hud.move_child(life_panel, 1)
		stamina_bar = STAMINA_BAR.new()
		stamina_bar.name = "StaminaBar"
		stamina_bar.player = player
		stamina_bar.accent = RUN_ACCENT
		life_hud.add_child(stamina_bar)
		life_hud.move_child(stamina_bar, 2)
		_place_stamina_bar(life_hud)
	Global.input_hints.device_changed.connect(_on_device_changed)

func _on_device_changed() -> void:
	if not is_instance_valid(run_panel):
		return
	var life_hud := run_panel.get_parent() as CanvasItem
	_apply_rect(run_panel, life_hud, _run_panel_rect())
	_place_stamina_bar(life_hud)

func _run_panel_rect() -> Rect2:
	return RUN_PANEL_PAD_RECT if Global.input_hints.is_gamepad() else RUN_PANEL_KBM_RECT

func _place_stamina_bar(life_hud:CanvasItem) -> void:
	if not is_instance_valid(stamina_bar):
		return
	var base := _run_panel_rect()
	_apply_rect(stamina_bar, life_hud, Rect2(
		Vector2(base.end.x + STAMINA_BAR_GAP, base.position.y + (base.size.y - STAMINA_BAR_SIZE.y) * 0.5),
		STAMINA_BAR_SIZE
	))

static func _add_panel(parent:CanvasItem, panel_name:String, screen_rect:Rect2, accent:Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.02, 0.035, 0.84)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.65)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	style.shadow_size = 6
	style.shadow_offset = Vector2(2.0, 3.0)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	_apply_rect(panel, parent, screen_rect)
	return panel

static func _apply_rect(control:Control, parent:CanvasItem, screen_rect:Rect2) -> void:
	var local := to_local_rect(parent, screen_rect)
	control.position = local.position
	control.size = local.size

# Converte um retângulo de tela para o espaço local do HUD, que tem posição e
# escala próprias dentro do hud_canvas.
static func to_local_rect(parent:CanvasItem, screen_rect:Rect2) -> Rect2:
	var inverse := parent.get_global_transform().affine_inverse()
	var start:Vector2 = inverse * screen_rect.position
	var finish:Vector2 = inverse * screen_rect.end
	return Rect2(start, finish - start)
