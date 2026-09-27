extends Node3D

# Cutscene entre a fase do Super Maycon Brother e o interior do avião:
# Maycon cai do buraco da seta em câmera lenta enquanto o avião vem chegando.
# As câmeras alternam entre o avião e o Maycon, cada corte mais rápido que o
# anterior, até que a câmera lenta acaba e o fade out cobre a batida dos dois.

const PROXIMA_CENA = "res://scenes/3D/aviao_interior.tscn"

# Duração de cada corte de câmera, sempre menor que o anterior (12,4s no total)
const CORTES := [2.30, 1.95, 1.60, 1.30, 1.05, 0.85, 0.68, 0.54, 0.42, 0.33, 0.26, 0.21, 0.17, 0.14]
const FATOR_SLOW_MOTION := 0.26
const DURACAO_FADE_IN := 1.4
const DURACAO_RETOMADA := 1.15   # tempo em que o slow motion volta ao normal
const DURACAO_FADE_OUT := 0.6
const TEMPO_MUNDO_TOTAL := 4.1   # segundos "reais" da queda, esticados pelo slow motion

# Pontos inicial e final de cada personagem no espaço do mundo
const MAYCON_INICIO := Vector3(0.9, 232.0, -6.5)
const MAYCON_FIM := Vector3(0.35, 2.15, -1.2)
const AVIAO_INICIO := Vector3(0.0, 0.0, 620.0)
const AVIAO_FIM := Vector3(0.0, 0.0, 0.0)

# Enquadramentos do avião: deslocamento da câmera e ponto observado (relativos ao avião)
const ENQUADRAMENTOS_AVIAO := [
	{"offset": Vector3(15.0, -2.6, 15.0), "alvo": Vector3(0.0, -0.8, -5.0), "fov": 62.0},
	{"offset": Vector3(-2.6, 1.6, -19.0), "alvo": Vector3(0.0, 0.6, 7.0), "fov": 55.0},
	{"offset": Vector3(10.5, -4.2, 6.5), "alvo": Vector3(0.0, 0.4, -3.0), "fov": 66.0},
	{"offset": Vector3(0.0, 7.0, 13.0), "alvo": Vector3(0.0, 26.0, -3.0), "fov": 72.0},
	{"offset": Vector3(-14.5, 7.5, -4.5), "alvo": Vector3(0.0, 0.0, 0.0), "fov": 58.0},
	{"offset": Vector3(4.0, 1.2, 10.5), "alvo": Vector3(0.0, 0.5, -7.0), "fov": 50.0},
	{"offset": Vector3(19.0, 0.6, -2.5), "alvo": Vector3(0.0, 0.0, 0.0), "fov": 60.0}
]

# Enquadramentos do Maycon caindo, sempre bem próximos para mostrar o grito
const ENQUADRAMENTOS_MAYCON := [
	{"offset": Vector3(2.4, 0.7, 3.0), "alvo": Vector3(0.0, 0.95, 0.0), "fov": 48.0},
	{"offset": Vector3(0.2, 5.8, 0.6), "alvo": Vector3(0.0, 0.0, 0.0), "fov": 62.0},
	{"offset": Vector3(-1.9, -1.8, 2.6), "alvo": Vector3(0.0, 1.0, 0.0), "fov": 52.0},
	{"offset": Vector3(0.9, 1.5, -3.1), "alvo": Vector3(0.0, 0.8, 0.0), "fov": 58.0},
	{"offset": Vector3(3.4, 2.3, -2.2), "alvo": Vector3(0.0, 0.75, 0.0), "fov": 50.0},
	{"offset": Vector3(-2.7, 0.2, -2.0), "alvo": Vector3(0.0, 0.95, 0.0), "fov": 46.0},
	{"offset": Vector3(1.3, -2.9, 1.7), "alvo": Vector3(0.0, 1.05, 0.0), "fov": 55.0}
]

@onready var aviao:Node3D = $Aviao
@onready var maycon:Node3D = $Maycon
@onready var cam_aviao:Camera3D = $CamAviao
@onready var cam_maycon:Camera3D = $CamMaycon
@onready var grito:AudioStreamPlayer = $Grito
@onready var vento:AudioStreamPlayer = $Vento
@onready var motor_aviao:AudioStreamPlayer3D = $Aviao/MotorAviao
@onready var fade_rect:ColorRect = $Fade/FadeRect
@onready var sol:DirectionalLight3D = $Sol

var maycon_visual:Node3D
var maycon_animation:AnimationPlayer
var tempo_cena:float = 0.0
var tempo_mundo:float = 0.0
var corte_atual:int = -1
var tempo_no_corte:float = 0.0
var enquadramento_aviao:int = -1
var enquadramento_maycon:int = -1
var cortes_terminados:bool = false
var tempo_retomada:float = 0.0
var saida_iniciada:bool = false
var giro_maycon:float = 0.0


func _ready() -> void:
	get_tree().paused = false
	sol.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(38.0), 0.0)
	_montar_aviao()
	_montar_maycon()
	_posicionar_mundo(0.0)
	_trocar_corte()
	_atualizar_cameras()
	# Fade in normal, vindo do branco que fechou a fase anterior
	var fade_in := create_tween().bind_node(fade_rect)
	fade_in.tween_property(fade_rect, "modulate:a", 0.0, DURACAO_FADE_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grito.play()


func _montar_aviao() -> void:
	var modelo := AviaoModelo.criar_aviao("Modelo")
	aviao.add_child(modelo)
	aviao.position = AVIAO_INICIO
	for lado:float in [-1.0, 1.0]:
		var arma := AviaoModelo.criar_metralhadora()
		arma.name = "MetralhadoraEsquerda" if lado < 0.0 else "MetralhadoraDireita"
		arma.position = Vector3(AviaoModelo.WING_GUN_LOCAL.x * lado, AviaoModelo.WING_GUN_LOCAL.y, AviaoModelo.WING_GUN_LOCAL.z)
		aviao.add_child(arma)


func _montar_maycon() -> void:
	maycon_visual = AviaoModelo.criar_maycon()
	maycon.add_child(maycon_visual)
	maycon_animation = maycon_visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if maycon_animation and maycon_animation.has_animation("Air_Flail"):
		maycon_animation.play("Air_Flail")
		maycon_animation.speed_scale = FATOR_SLOW_MOTION * 2.2
	# Luz de apoio para o Maycon não virar silhueta nos closes
	var luz := OmniLight3D.new()
	luz.name = "LuzDeApoio"
	luz.light_color = Color(1.0, 0.96, 0.9)
	luz.light_energy = 2.6
	luz.omni_range = 9.0
	luz.position = Vector3(1.8, 1.9, 2.6)
	maycon.add_child(luz)
	maycon.position = MAYCON_INICIO


func _process(delta:float) -> void:
	tempo_cena += delta
	var fator := FATOR_SLOW_MOTION
	if cortes_terminados:
		# Câmera lenta acaba pouco antes da batida e tudo volta à velocidade normal
		tempo_retomada = minf(tempo_retomada + delta, DURACAO_RETOMADA)
		var t := tempo_retomada / DURACAO_RETOMADA
		fator = lerpf(FATOR_SLOW_MOTION, 1.0, pow(t, 1.35))
	tempo_mundo = minf(tempo_mundo + delta * fator, TEMPO_MUNDO_TOTAL)
	if maycon_animation:
		maycon_animation.speed_scale = maxf(fator * 2.2, 0.08)
	_posicionar_mundo(tempo_mundo / TEMPO_MUNDO_TOTAL)
	_atualizar_cortes(delta)
	_atualizar_cameras()
	if cortes_terminados and not saida_iniciada and tempo_retomada >= DURACAO_RETOMADA * 0.35:
		_encerrar()


func _posicionar_mundo(progresso:float) -> void:
	var p := clampf(progresso, 0.0, 1.0)
	# Queda acelerada pela gravidade
	var queda := pow(p, 1.75)
	maycon.position = MAYCON_INICIO.lerp(MAYCON_FIM, queda)
	giro_maycon += get_process_delta_time() * (0.6 + p * 2.4)
	# Virado para as câmeras, que ficam na frente dele durante a queda
	maycon.rotation = Vector3(
		deg_to_rad(-24.0) + sin(giro_maycon * 1.3) * 0.22,
		sin(giro_maycon * 0.7) * 0.5,
		sin(giro_maycon * 1.05) * 0.3
	)
	# O avião vem em velocidade constante e chega junto com o Maycon
	aviao.position = AVIAO_INICIO.lerp(AVIAO_FIM, p)
	aviao.rotation = Vector3(
		sin(p * 5.2) * 0.012,
		sin(p * 3.1) * 0.02,
		sin(p * 4.4) * 0.05
	)
	if is_instance_valid(motor_aviao):
		motor_aviao.pitch_scale = lerpf(0.5, 0.95, p)


func _atualizar_cortes(delta:float) -> void:
	if cortes_terminados:
		return
	tempo_no_corte += delta
	if tempo_no_corte >= float(CORTES[corte_atual]):
		if corte_atual + 1 >= CORTES.size():
			cortes_terminados = true
			_acelerar_grito()
			return
		_trocar_corte()


func _trocar_corte() -> void:
	corte_atual += 1
	tempo_no_corte = 0.0
	# Cortes pares mostram o avião chegando, ímpares o Maycon caindo
	if corte_atual % 2 == 0:
		enquadramento_aviao = (enquadramento_aviao + 1) % ENQUADRAMENTOS_AVIAO.size()
		cam_aviao.fov = float(ENQUADRAMENTOS_AVIAO[enquadramento_aviao]["fov"])
		cam_aviao.make_current()
	else:
		enquadramento_maycon = (enquadramento_maycon + 1) % ENQUADRAMENTOS_MAYCON.size()
		cam_maycon.fov = float(ENQUADRAMENTOS_MAYCON[enquadramento_maycon]["fov"])
		cam_maycon.make_current()


func _atualizar_cameras() -> void:
	# Câmera grudada no avião
	var quadro_aviao:Dictionary = ENQUADRAMENTOS_AVIAO[maxi(enquadramento_aviao, 0)]
	var respiro := Vector3(sin(tempo_cena * 0.8) * 0.5, cos(tempo_cena * 0.65) * 0.35, sin(tempo_cena * 0.5) * 0.6)
	cam_aviao.global_position = aviao.position + Vector3(quadro_aviao["offset"]) + respiro
	var alvo_aviao:Vector3 = aviao.position + Vector3(quadro_aviao["alvo"])
	if Vector3(quadro_aviao["alvo"]).y > 10.0:
		# Este enquadramento olha do teto do avião para o Maycon lá em cima
		alvo_aviao = maycon.position
	_olhar_para(cam_aviao, alvo_aviao)

	# Câmera grudada no Maycon caindo
	var quadro_maycon:Dictionary = ENQUADRAMENTOS_MAYCON[maxi(enquadramento_maycon, 0)]
	var tremor := Vector3(sin(tempo_cena * 6.1) * 0.05, cos(tempo_cena * 5.3) * 0.05, 0.0)
	cam_maycon.global_position = maycon.position + Vector3(quadro_maycon["offset"]) + tremor
	_olhar_para(cam_maycon, maycon.position + Vector3(quadro_maycon["alvo"]))


func _olhar_para(camera:Camera3D, alvo:Vector3) -> void:
	if camera.global_position.distance_squared_to(alvo) < 0.0004:
		return
	camera.look_at(alvo, Vector3.UP)


func _acelerar_grito() -> void:
	# O grito sai da câmera lenta junto com a cena
	if not is_instance_valid(grito):
		return
	var tw := create_tween().bind_node(grito)
	tw.tween_property(grito, "pitch_scale", 1.0, DURACAO_RETOMADA * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if is_instance_valid(vento):
		var tw_vento := create_tween().bind_node(vento)
		tw_vento.tween_property(vento, "pitch_scale", 1.1, DURACAO_RETOMADA * 0.8)
		tw_vento.parallel().tween_property(vento, "volume_db", -3.0, DURACAO_RETOMADA * 0.8)


func _encerrar() -> void:
	saida_iniciada = true
	# Fade out antes do Maycon se chocar com o avião
	var fade_out := create_tween().bind_node(fade_rect)
	fade_out.tween_property(fade_rect, "modulate:a", 1.0, DURACAO_FADE_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var som_out := create_tween().bind_node(grito)
	som_out.tween_property(grito, "volume_db", -40.0, DURACAO_FADE_OUT)
	await fade_out.finished
	get_tree().change_scene_to_file.call_deferred(PROXIMA_CENA)
