extends Control

# Mira central estilo Ace Combat: retículo fixo no meio da tela e caixa de
# marcação seguindo o Lips, ficando vermelha quando ele está sob a mira.

const COR_MIRA := Color(0.55, 1.0, 0.72, 0.9)
const COR_ALVO := Color(0.45, 0.95, 1.0, 0.85)
const COR_TRAVADO := Color(1.0, 0.28, 0.32, 0.95)
const RAIO_TRAVA := 78.0

var camera:Camera3D
var alvo:Node3D
var travado:bool = false
var distancia:float = 0.0
var piscar:float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta:float) -> void:
	piscar += delta
	queue_redraw()


func _draw() -> void:
	var centro := get_viewport_rect().size * 0.5
	_desenhar_reticulo(centro)
	if not is_instance_valid(camera) or not is_instance_valid(alvo):
		return
	var pos_alvo:Vector3 = alvo.global_position
	if camera.is_position_behind(pos_alvo):
		return
	var tela := camera.unproject_position(pos_alvo)
	distancia = camera.global_position.distance_to(pos_alvo)
	travado = tela.distance_to(centro) < RAIO_TRAVA
	_desenhar_caixa_alvo(tela, centro)


func _desenhar_reticulo(centro:Vector2) -> void:
	var cor := COR_TRAVADO if travado else COR_MIRA
	draw_arc(centro, 26.0, 0.0, TAU, 48, cor, 1.6, true)
	for angulo:float in [0.0, PI * 0.5, PI, PI * 1.5]:
		var dir:Vector2 = Vector2(cos(angulo), sin(angulo))
		draw_line(centro + dir * 16.0, centro + dir * 24.0, cor, 1.6, true)
	draw_circle(centro, 2.2, cor)
	# Cantos externos da mira
	var braco := 12.0
	var lado := 46.0
	for sx:float in [-1.0, 1.0]:
		for sy:float in [-1.0, 1.0]:
			var canto:Vector2 = centro + Vector2(sx * lado, sy * lado)
			draw_line(canto, canto - Vector2(sx * braco, 0.0), cor, 1.4, true)
			draw_line(canto, canto - Vector2(0.0, sy * braco), cor, 1.4, true)


func _desenhar_caixa_alvo(tela:Vector2, centro:Vector2) -> void:
	var cor := COR_TRAVADO if travado else COR_ALVO
	var meia := clampf(4200.0 / maxf(distancia, 20.0), 34.0, 150.0)
	var braco := meia * 0.38
	for sx:float in [-1.0, 1.0]:
		for sy:float in [-1.0, 1.0]:
			var canto:Vector2 = tela + Vector2(sx * meia, sy * meia)
			draw_line(canto, canto - Vector2(sx * braco, 0.0), cor, 2.4, true)
			draw_line(canto, canto - Vector2(0.0, sy * braco), cor, 2.4, true)
	if travado:
		var pulso := 0.5 + 0.5 * sin(piscar * 12.0)
		draw_arc(tela, meia * 0.5, 0.0, TAU, 32, Color(cor.r, cor.g, cor.b, 0.25 + pulso * 0.45), 2.0, true)
	else:
		draw_line(centro, tela, Color(cor.r, cor.g, cor.b, 0.18), 1.2, true)
	var fonte := ThemeDB.fallback_font
	var texto:String = "%d m" % int(distancia)
	draw_string(fonte, tela + Vector2(meia + 8.0, -meia + 14.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, cor)
	if travado:
		draw_string(fonte, tela + Vector2(meia + 8.0, -meia + 32.0), tr("AVIAO_HUD_TRAVADO"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, COR_TRAVADO)
