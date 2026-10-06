extends Control

# Barra sutil da estamina de corrida: aparece quando o jogador gasta e some
# sozinha, com fade out, depois de um tempo cheia e parada.
const FADE_IN_SPEED:float = 7.0
const FADE_OUT_SPEED:float = 1.8
const FULL_HOLD_SECONDS:float = 1.4

var player:Node = null
var accent:Color = Color(0.55, 0.92, 0.72)
var fill_ratio:float = 1.0
var full_seconds:float = FULL_HOLD_SECONDS

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0

func _process(delta:float) -> void:
	if not is_instance_valid(player):
		return
	var maximo:float = maxf(1.0, float(player.estamina_maxima))
	var alvo:float = clampf(float(player.estamina_atual) / maximo, 0.0, 1.0)
	if alvo >= 0.999:
		full_seconds += delta
	else:
		full_seconds = 0.0
	var desejado:float = 0.0 if full_seconds >= FULL_HOLD_SECONDS else 1.0
	var velocidade:float = FADE_IN_SPEED if desejado > modulate.a else FADE_OUT_SPEED
	var alpha:float = move_toward(modulate.a, desejado, delta * velocidade)
	if is_equal_approx(alpha, modulate.a) and is_equal_approx(alvo, fill_ratio):
		return
	modulate.a = alpha
	fill_ratio = alvo
	queue_redraw()

func _draw() -> void:
	if modulate.a <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var raio:int = int(size.y * 0.5)
	var trilho := StyleBoxFlat.new()
	trilho.bg_color = Color(0.012, 0.02, 0.035, 0.78)
	trilho.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	trilho.set_border_width_all(1)
	trilho.set_corner_radius_all(raio)
	draw_style_box(trilho, Rect2(Vector2.ZERO, size))
	if fill_ratio <= 0.0:
		return
	var esgotado:bool = is_instance_valid(player) and not bool(player.pode_correr)
	var preenchido := StyleBoxFlat.new()
	preenchido.bg_color = Color(0.95, 0.42, 0.38) if esgotado else accent
	preenchido.set_corner_radius_all(raio)
	var interno := Vector2(size.x - 4.0, size.y - 4.0)
	draw_style_box(preenchido, Rect2(Vector2(2.0, 2.0), Vector2(maxf(interno.x * fill_ratio, interno.y), interno.y)))
