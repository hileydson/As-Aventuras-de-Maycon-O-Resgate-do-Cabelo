extends Node3D

# Cutscene entre a fase do Super Maycon Brother e o interior do avião:
# Maycon cai do buraco da seta em câmera lenta enquanto o avião vem chegando.
# As câmeras alternam entre o avião e o Maycon, cada corte mais rápido que o
# anterior, até que a câmera lenta acaba e o fade out cobre a batida dos dois.

const VENTO_SCRIPT = preload("res://scripts/3D/aviao_linhas_vento.gd")
const PAUSE_SCRIPT = preload("res://scripts/3D/platform_pause.gd")
const PROXIMA_CENA = "res://scenes/3D/aviao_interior.tscn"

# Duração de cada corte de câmera, sempre menor que o anterior (12,4s no total)
const CORTES := [2.30, 1.95, 1.60, 1.30, 1.05, 0.85, 0.68, 0.54, 0.42, 0.33, 0.26, 0.21, 0.17, 0.14]
const FATOR_SLOW_MOTION := 0.26
const DURACAO_FADE_IN := 1.4
const DURACAO_RETOMADA := 1.15   # tempo em que o slow motion volta ao normal
const DURACAO_FADE_OUT := 2.6
# Volume do grito conforme a câmera do corte: alto no Maycon, mudo no avião
const GRITO_PERTO_DB := 1.0
const GRITO_LONGE_DB := -42.0
# A partir deste corte os takes ficam curtos demais para cortar o som: o grito
# passa a rolar direto e vai ficando mais fino conforme a queda acelera
const CORTE_GRITO_CONTINUO := 9
const GRITO_TOM_BASE := 0.45
const GRITO_TOM_FINO := 0.92
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
	{"offset": Vector3(-10.5, -6.0, -14.0), "alvo": Vector3(0.0, 0.4, 5.0), "fov": 66.0},
	{"offset": Vector3(-14.5, 7.5, -4.5), "alvo": Vector3(0.0, 0.0, 0.0), "fov": 58.0},
	{"offset": Vector3(4.0, 1.2, 10.5), "alvo": Vector3(0.0, 0.5, -7.0), "fov": 50.0},
	{"offset": Vector3(19.0, 0.6, -2.5), "alvo": Vector3(0.0, 0.0, 0.0), "fov": 60.0}
]

# Enquadramentos do Maycon caindo, sempre bem próximos para mostrar o grito
const ENQUADRAMENTOS_MAYCON := [
	{"offset": Vector3(3.9, 1.7, 1.0), "alvo": Vector3(0.0, 0.85, 0.0), "fov": 45.0},
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
@onready var grito:AudioStreamPlayer3D = $Maycon/Grito
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
var volume_grito_tw:Tween
var linhas_maycon:MultiMeshInstance3D
var linhas_aviao:MultiMeshInstance3D

# Campos exigidos pelo menu de pausa compartilhado das fases 3D
var exit_started:bool = false
var death_in_progress:bool = false


func _ready() -> void:
	get_tree().paused = false
	sol.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(38.0), 0.0)
	# Começa mudo: o primeiro corte é do avião, o grito entra no corte do Maycon
	grito.volume_db = GRITO_LONGE_DB
	_montar_aviao()
	_montar_maycon()
	_montar_vento()
	_montar_pausa()
	_posicionar_mundo(0.0)
	_trocar_corte()
	_atualizar_cameras()
	# Fade in normal, vindo do branco que fechou a fase anterior
	var fade_in := create_tween().bind_node(fade_rect)
	fade_in.tween_property(fade_rect, "modulate:a", 0.0, DURACAO_FADE_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_preparar_grito()
	grito.play()


# O mp3 do grito tem uma explosão no fim; em loop o trecho do grito cobre a queda
# inteira sem nunca chegar nela (mesma solução usada na entrada do poço infinito).
# O som sai do próprio Maycon (3D), então só se ouve nos cortes em que a câmera
# está perto dele.
func _preparar_grito() -> void:
	var trilha:AudioStream = grito.stream
	if trilha is AudioStreamMP3:
		var copia:AudioStreamMP3 = trilha.duplicate()
		copia.loop = true
		grito.stream = copia


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


func _montar_pausa() -> void:
	var pausa := CanvasLayer.new()
	pausa.name = "PauseFofo"
	pausa.set_script(PAUSE_SCRIPT)
	add_child(pausa)


func exit_to_menu() -> void:
	if exit_started:
		return
	exit_started = true
	saida_iniciada = true
	get_tree().paused = false
	fade_rect.color = Color.BLACK
	var fade_out := create_tween().bind_node(fade_rect)
	fade_out.tween_property(fade_rect, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await fade_out.finished
	Global.back_to_main_camera = true
	Global.save_progress("fase_aviao")
	get_tree().change_scene_to_file.call_deferred("res://scenes/menu.tscn")


# Riscos finos de vento: subindo junto do Maycon em queda e correndo para trás
# junto do avião, igual aos do combate aéreo
func _montar_vento() -> void:
	linhas_maycon = MultiMeshInstance3D.new()
	linhas_maycon.name = "VentoDaQueda"
	linhas_maycon.set_script(VENTO_SCRIPT)
	linhas_maycon.quantidade = 170
	linhas_maycon.alcance_z = 42.0
	linhas_maycon.z_limite = 20.0
	linhas_maycon.raio_min = 0.9
	linhas_maycon.raio_max = 7.5
	linhas_maycon.achatamento = 1.0
	linhas_maycon.velocidade = 78.0
	linhas_maycon.espessura = 0.03
	linhas_maycon.comprimento_min = 1.6
	linhas_maycon.comprimento_max = 5.5
	linhas_maycon.alpha_min = 0.22
	linhas_maycon.alpha_max = 0.6
	# Girado para os riscos subirem, já que o Maycon está despencando
	linhas_maycon.rotation.x = deg_to_rad(-90.0)
	add_child(linhas_maycon)

	linhas_aviao = MultiMeshInstance3D.new()
	linhas_aviao.name = "VentoDoAviao"
	linhas_aviao.set_script(VENTO_SCRIPT)
	linhas_aviao.quantidade = 130
	linhas_aviao.alcance_z = 260.0
	linhas_aviao.z_limite = 34.0
	linhas_aviao.raio_min = 6.0
	linhas_aviao.raio_max = 46.0
	linhas_aviao.velocidade = 210.0
	add_child(linhas_aviao)


func _process(delta:float) -> void:
	tempo_cena += delta
	var fator := FATOR_SLOW_MOTION
	if cortes_terminados:
		# Câmera lenta acaba pouco antes da batida e tudo volta à velocidade normal
		tempo_retomada = minf(tempo_retomada + delta, DURACAO_RETOMADA)
		var t := tempo_retomada / DURACAO_RETOMADA
		fator = lerpf(FATOR_SLOW_MOTION, 1.0, pow(t, 1.35))
	# O avião segue passando por baixo durante o clarão, então o tempo corre um
	# pouco além do encontro; quem trava é só a queda do Maycon
	tempo_mundo = minf(tempo_mundo + delta * fator, TEMPO_MUNDO_TOTAL * 1.4)
	if maycon_animation:
		maycon_animation.speed_scale = maxf(fator * 2.2, 0.08)
	# O vento também entra e sai da câmera lenta junto com a cena
	if is_instance_valid(linhas_maycon):
		linhas_maycon.escala_tempo = fator
		linhas_maycon.position = maycon.position
	if is_instance_valid(linhas_aviao):
		linhas_aviao.escala_tempo = fator
		linhas_aviao.position = aviao.position
	_posicionar_mundo(tempo_mundo / TEMPO_MUNDO_TOTAL)
	_atualizar_cortes(delta)
	_atualizar_cameras()
	# Deixa ver a câmera lenta acabando antes de começar o clarão de transição
	if cortes_terminados and not saida_iniciada and tempo_retomada >= 0.45:
		_encerrar()


func _posicionar_mundo(progresso:float) -> void:
	var p := maxf(progresso, 0.0)
	# Queda acelerada pela gravidade, parando um fio antes de encostar no avião
	var queda := pow(minf(p, 0.99), 1.75)
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
	var no_maycon := corte_atual % 2 == 1
	if no_maycon:
		enquadramento_maycon = (enquadramento_maycon + 1) % ENQUADRAMENTOS_MAYCON.size()
		cam_maycon.fov = float(ENQUADRAMENTOS_MAYCON[enquadramento_maycon]["fov"])
		cam_maycon.make_current()
	else:
		enquadramento_aviao = (enquadramento_aviao + 1) % ENQUADRAMENTOS_AVIAO.size()
		cam_aviao.fov = float(ENQUADRAMENTOS_AVIAO[enquadramento_aviao]["fov"])
		cam_aviao.make_current()
	_ajustar_volume_do_grito(no_maycon)
	_afinar_grito()


# O grito só se ouve nos cortes em que a câmera está no Maycon. Nos cortes do
# avião ele é pausado (e não só abaixado), senão a faixa corre em silêncio e
# volta já no fim quando a câmera retorna para o Maycon.
func _ajustar_volume_do_grito(no_maycon:bool) -> void:
	if saida_iniciada or not is_instance_valid(grito):
		return
	if volume_grito_tw and volume_grito_tw.is_valid():
		volume_grito_tw.kill()
	if corte_atual >= CORTE_GRITO_CONTINUO:
		# Nos cortes relâmpago o grito não é mais cortado, fica contínuo
		grito.stream_paused = false
		if not grito.playing:
			grito.play()
		grito.volume_db = GRITO_PERTO_DB
		return
	volume_grito_tw = create_tween().bind_node(grito)
	if no_maycon:
		grito.stream_paused = false
		# Se a faixa tiver acabado, recomeça: nenhum take pode ficar sem o grito
		if not grito.playing:
			grito.play()
		# Rampa curtíssima: os últimos cortes duram menos de 0,2s
		volume_grito_tw.tween_property(grito, "volume_db", GRITO_PERTO_DB, 0.04)
	else:
		volume_grito_tw.tween_property(grito, "volume_db", GRITO_LONGE_DB, 0.04)
		volume_grito_tw.tween_callback(func():
			if is_instance_valid(grito) and not saida_iniciada:
				grito.stream_paused = true)


# O grito vai afinando ao longo dos cortes rápidos, acompanhando a aceleração
func _afinar_grito() -> void:
	if saida_iniciada or not is_instance_valid(grito):
		return
	if corte_atual < CORTE_GRITO_CONTINUO:
		return
	var restantes := float(CORTES.size() - 1 - CORTE_GRITO_CONTINUO)
	var avanco := 0.0 if restantes <= 0.0 else clampf(float(corte_atual - CORTE_GRITO_CONTINUO) / restantes, 0.0, 1.0)
	grito.pitch_scale = lerpf(GRITO_TOM_BASE, GRITO_TOM_FINO, avanco)


func _atualizar_cameras() -> void:
	# Câmera grudada no avião
	var quadro_aviao:Dictionary = ENQUADRAMENTOS_AVIAO[maxi(enquadramento_aviao, 0)]
	var respiro := Vector3(sin(tempo_cena * 0.8) * 0.5, cos(tempo_cena * 0.65) * 0.35, sin(tempo_cena * 0.5) * 0.6)
	cam_aviao.global_position = aviao.position + Vector3(quadro_aviao["offset"]) + respiro
	var alvo_aviao:Vector3 = aviao.position + Vector3(quadro_aviao["alvo"])
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
	fade_out.tween_property(fade_rect, "modulate:a", 1.0, DURACAO_FADE_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if volume_grito_tw and volume_grito_tw.is_valid():
		volume_grito_tw.kill()
	grito.stream_paused = false
	var som_out := create_tween().bind_node(grito)
	som_out.tween_property(grito, "volume_db", -40.0, DURACAO_FADE_OUT * 0.85)
	await fade_out.finished
	get_tree().change_scene_to_file.call_deferred(PROXIMA_CENA)
