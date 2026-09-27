extends Node3D

# Interior simples do avião: Maycon acorda no fundo da cabine e anda pelo corredor
# entre as poltronas vazias até a porta da cabine de comando. Ao entrar na cabine
# a cena fecha em fade out e começa o combate aéreo.
# As texturas de tecido, carpete e fuselagem vêm da Poly Haven (CC0).

const PROXIMA_CENA = "res://scenes/3D/aviao_ace_combat.tscn"

const TEX_ASSENTO = preload("res://assets/polyhaven/aviao_interior/seat_fabric_diff_1k.jpg")
const TEX_ASSENTO_NORMAL = preload("res://assets/polyhaven/aviao_interior/seat_fabric_normal_1k.jpg")
const TEX_CARPETE_NORMAL = preload("res://assets/polyhaven/aviao_interior/carpet_normal_1k.jpg")
const TEX_FUSELAGEM_NORMAL = preload("res://assets/polyhaven/aviao_interior/hull_panel_normal_1k.jpg")

const RAIO_TUBO := 2.35
const COMPRIMENTO_CABINE := 46.0
const MEIA_LARGURA_CORREDOR := 0.78
const Z_FUNDO := 19.5
const Z_PORTA_CABINE := -18.0
const Z_POSTO_PILOTO := -21.6
const PRIMEIRA_FILEIRA_Z := 15.0
const FILEIRAS := 13
const ESPACO_FILEIRA := 2.4

const VELOCIDADE_MAYCON := 4.2
const DURACAO_FADE_IN := 1.1
const DURACAO_FADE_OUT := 1.0

@onready var cabine:Node3D = $Cabine
@onready var camera:Camera3D = $Camera3D
@onready var fade_rect:ColorRect = $Fade/FadeRect
@onready var passo:AudioStreamPlayer = $Passo
@onready var dica:Label = $Hud/Dica

var maycon:CharacterBody3D
var maycon_visual:Node3D
var maycon_animation:AnimationPlayer
var porta_cabine:Area3D
var controle_liberado:bool = false
var entrando_na_cabine:bool = false
var tempo:float = 0.0
var tempo_passo:float = 0.0


func _ready() -> void:
	get_tree().paused = false
	_montar_cabine()
	_montar_maycon()
	_posicionar_camera(true)
	_manter_em_loop($Vento)
	_manter_em_loop($Motor)
	dica.text = tr("AVIAO_INTERIOR_DICA")
	dica.modulate.a = 0.0
	var fade_in := create_tween().bind_node(fade_rect)
	fade_in.tween_property(fade_rect, "modulate:a", 0.0, DURACAO_FADE_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade_in.tween_callback(func(): controle_liberado = true)
	var dica_tw := create_tween().bind_node(dica)
	dica_tw.tween_interval(DURACAO_FADE_IN)
	dica_tw.tween_property(dica, "modulate:a", 1.0, 0.6)
	dica_tw.tween_interval(4.5)
	dica_tw.tween_property(dica, "modulate:a", 0.0, 0.8)


func _manter_em_loop(player:AudioStreamPlayer) -> void:
	# Os mp3 do projeto não são importados em loop, então o som é reiniciado no fim
	if not is_instance_valid(player):
		return
	player.finished.connect(func():
		if is_instance_valid(player):
			player.play())


# ---------------------------------------------------------------- cenário

func _montar_cabine() -> void:
	_montar_fuselagem()
	_montar_piso()
	_montar_poltronas()
	_montar_bagageiros()
	_montar_janelas()
	_montar_luzes()
	_montar_anteparo_e_cabine_de_comando()
	_montar_colisoes()


func _material_texturizado(albedo:Texture2D, normal:Texture2D, uv:Vector3, tom:Color, aspereza:float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = albedo
	mat.normal_enabled = normal != null
	mat.normal_texture = normal
	mat.uv1_scale = uv
	mat.albedo_color = tom
	mat.roughness = aspereza
	mat.metallic = 0.0
	return mat


func _caixa(nome:String, tamanho:Vector3, posicao:Vector3, material:Material, pai:Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = tamanho
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = mesh
	mi.position = posicao
	mi.material_override = material
	if pai == null:
		pai = cabine
	pai.add_child(mi)
	return mi


func _montar_fuselagem() -> void:
	# Tubo da fuselagem visto por dentro (cull invertido)
	var tubo := CylinderMesh.new()
	tubo.top_radius = RAIO_TUBO
	tubo.bottom_radius = RAIO_TUBO
	tubo.height = COMPRIMENTO_CABINE
	tubo.radial_segments = 28
	tubo.rings = 1
	# Painel claro de cabine: só o relevo da textura da fuselagem, sem a cor enferrujada
	var mat := _material_texturizado(null, TEX_FUSELAGEM_NORMAL, Vector3(12.0, 30.0, 1.0), Color(0.9, 0.91, 0.94), 0.4)
	mat.normal_scale = 0.55
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	var mi := MeshInstance3D.new()
	mi.name = "Fuselagem"
	mi.mesh = tubo
	mi.material_override = mat
	mi.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	mi.position = Vector3(0.0, 1.05, 0.0)
	cabine.add_child(mi)


func _montar_piso() -> void:
	# Carpete azul-marinho de avião, usando só o relevo da textura de carpete
	var carpete := _material_texturizado(null, TEX_CARPETE_NORMAL, Vector3(3.0, 26.0, 1.0), Color(0.19, 0.21, 0.3), 1.0)
	carpete.normal_scale = 0.8
	_caixa("Piso", Vector3(4.3, 0.2, COMPRIMENTO_CABINE), Vector3(0.0, -0.1, 0.0), carpete)


func _montar_poltronas() -> void:
	var tecido := _material_texturizado(TEX_ASSENTO, TEX_ASSENTO_NORMAL, Vector3(2.0, 2.0, 1.0), Color(0.62, 0.68, 0.85), 0.85)
	var plastico := StandardMaterial3D.new()
	plastico.albedo_color = Color(0.16, 0.17, 0.2)
	plastico.roughness = 0.6
	for fileira in range(FILEIRAS):
		var z := PRIMEIRA_FILEIRA_Z - float(fileira) * ESPACO_FILEIRA
		for lado:float in [-1.0, 1.0]:
			for coluna in range(2):
				var x:float = lado * (1.05 + float(coluna) * 0.62)
				_montar_poltrona(Vector3(x, 0.0, z), tecido, plastico)


func _montar_poltrona(base:Vector3, tecido:Material, plastico:Material) -> void:
	var poltrona := Node3D.new()
	poltrona.name = "Poltrona"
	poltrona.position = base
	cabine.add_child(poltrona)
	_caixa("Assento", Vector3(0.56, 0.16, 0.54), Vector3(0.0, 0.45, 0.0), tecido, poltrona)
	_caixa("Encosto", Vector3(0.56, 0.72, 0.14), Vector3(0.0, 0.83, 0.29), tecido, poltrona)
	_caixa("Apoio", Vector3(0.6, 0.12, 0.2), Vector3(0.0, 1.16, 0.29), tecido, poltrona)
	_caixa("Pe", Vector3(0.12, 0.38, 0.4), Vector3(0.0, 0.18, 0.05), plastico, poltrona)
	for lado:float in [-1.0, 1.0]:
		_caixa("Braco", Vector3(0.07, 0.08, 0.46), Vector3(lado * 0.3, 0.62, 0.02), plastico, poltrona)


func _montar_bagageiros() -> void:
	var plastico := StandardMaterial3D.new()
	plastico.albedo_color = Color(0.82, 0.82, 0.85)
	plastico.roughness = 0.45
	for lado:float in [-1.0, 1.0]:
		_caixa("Bagageiro", Vector3(1.2, 0.5, 34.0), Vector3(lado * 1.78, 1.98, -1.0), plastico)


func _montar_janelas() -> void:
	# Janelas bem claras, simulando a luz do dia do lado de fora
	var vidro := StandardMaterial3D.new()
	vidro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vidro.albedo_color = Color(0.82, 0.92, 1.0)
	vidro.emission_enabled = true
	vidro.emission = Color(0.78, 0.9, 1.0)
	vidro.emission_energy_multiplier = 2.2
	var quadro := QuadMesh.new()
	quadro.size = Vector2(0.42, 0.52)
	for fileira in range(FILEIRAS + 2):
		var z := PRIMEIRA_FILEIRA_Z + 1.2 - float(fileira) * ESPACO_FILEIRA
		for lado:float in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			mi.name = "Janela"
			mi.mesh = quadro
			mi.material_override = vidro
			mi.position = Vector3(lado * (RAIO_TUBO - 0.28), 1.5, z)
			mi.rotation = Vector3(0.0, deg_to_rad(-90.0 * lado), 0.0)
			cabine.add_child(mi)


func _montar_luzes() -> void:
	for i in range(9):
		var luz := OmniLight3D.new()
		luz.name = "LuzCabine"
		luz.light_color = Color(1.0, 0.95, 0.86)
		luz.light_energy = 1.5
		luz.omni_range = 7.5
		luz.position = Vector3(0.0, 2.25, 17.0 - float(i) * 4.6)
		cabine.add_child(luz)


func _montar_anteparo_e_cabine_de_comando() -> void:
	var parede := StandardMaterial3D.new()
	parede.albedo_color = Color(0.78, 0.78, 0.8)
	parede.roughness = 0.5
	# Anteparo com o vão da porta da cabine de comando
	for lado:float in [-1.0, 1.0]:
		_caixa("Anteparo", Vector3(1.6, 2.3, 0.18), Vector3(lado * 1.35, 1.15, Z_PORTA_CABINE), parede)
	_caixa("AnteparoTopo", Vector3(1.2, 0.55, 0.18), Vector3(0.0, 2.02, Z_PORTA_CABINE), parede)

	var batente := StandardMaterial3D.new()
	batente.albedo_color = Color(0.2, 0.22, 0.26)
	batente.roughness = 0.4
	_caixa("BatentePorta", Vector3(1.28, 0.06, 0.24), Vector3(0.0, 1.76, Z_PORTA_CABINE), batente)

	# Painel e poltronas dos pilotos
	var painel := StandardMaterial3D.new()
	painel.albedo_color = Color(0.12, 0.13, 0.16)
	painel.roughness = 0.35
	_caixa("Painel", Vector3(3.0, 0.6, 0.5), Vector3(0.0, 1.05, Z_POSTO_PILOTO - 1.5), painel)
	_caixa("Console", Vector3(0.6, 0.25, 1.4), Vector3(0.0, 0.62, Z_POSTO_PILOTO - 0.6), painel)
	var luzes_painel := StandardMaterial3D.new()
	luzes_painel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	luzes_painel.albedo_color = Color(0.25, 1.0, 0.7)
	luzes_painel.emission_enabled = true
	luzes_painel.emission = Color(0.25, 1.0, 0.7)
	luzes_painel.emission_energy_multiplier = 2.0
	_caixa("PainelLuzes", Vector3(2.6, 0.16, 0.06), Vector3(0.0, 1.16, Z_POSTO_PILOTO - 1.27), luzes_painel)

	var tecido_piloto := _material_texturizado(TEX_ASSENTO, TEX_ASSENTO_NORMAL, Vector3(2.0, 2.0, 1.0), Color(0.3, 0.32, 0.4), 0.8)
	var plastico := StandardMaterial3D.new()
	plastico.albedo_color = Color(0.16, 0.17, 0.2)
	for lado:float in [-1.0, 1.0]:
		_montar_poltrona(Vector3(lado * 0.72, 0.0, Z_POSTO_PILOTO), tecido_piloto, plastico)

	# Para-brisa claro no fim da cabine de comando
	var ceu := StandardMaterial3D.new()
	ceu.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ceu.albedo_color = AviaoModelo.SKY_COLOR
	ceu.emission_enabled = true
	ceu.emission = AviaoModelo.SKY_COLOR
	ceu.emission_energy_multiplier = 1.6
	_caixa("ParaBrisa", Vector3(3.0, 1.0, 0.08), Vector3(0.0, 1.75, Z_POSTO_PILOTO - 2.4), ceu)
	_caixa("FundoCabine", Vector3(5.0, 5.0, 0.1), Vector3(0.0, 1.2, Z_POSTO_PILOTO - 2.6), ceu)

	# Gatilho que dispara a entrada na cabine de comando
	porta_cabine = Area3D.new()
	porta_cabine.name = "PortaCabine"
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(1.4, 2.2, 0.9)
	forma.shape = caixa
	porta_cabine.add_child(forma)
	porta_cabine.position = Vector3(0.0, 1.1, Z_PORTA_CABINE)
	porta_cabine.monitoring = true
	porta_cabine.body_entered.connect(_ao_entrar_na_cabine)
	cabine.add_child(porta_cabine)


func _montar_colisoes() -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "ColisoesCabine"
	cabine.add_child(corpo)
	_adicionar_colisao(corpo, Vector3(6.0, 0.4, COMPRIMENTO_CABINE), Vector3(0.0, -0.2, 0.0))
	# Paredes invisíveis mantendo o Maycon dentro do corredor
	for lado:float in [-1.0, 1.0]:
		_adicionar_colisao(corpo, Vector3(0.3, 3.0, COMPRIMENTO_CABINE), Vector3(lado * (MEIA_LARGURA_CORREDOR + 0.15), 1.4, 0.0))
	_adicionar_colisao(corpo, Vector3(6.0, 3.0, 0.4), Vector3(0.0, 1.4, Z_FUNDO + 1.2))
	_adicionar_colisao(corpo, Vector3(6.0, 3.0, 0.4), Vector3(0.0, 1.4, Z_PORTA_CABINE - 0.9))


func _adicionar_colisao(corpo:StaticBody3D, tamanho:Vector3, posicao:Vector3) -> void:
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	forma.shape = caixa
	forma.position = posicao
	corpo.add_child(forma)


# ---------------------------------------------------------------- Maycon

func _montar_maycon() -> void:
	maycon = CharacterBody3D.new()
	maycon.name = "Maycon"
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.32
	capsula.height = 1.65
	forma.shape = capsula
	forma.position.y = 0.83
	maycon.add_child(forma)
	maycon_visual = AviaoModelo.criar_maycon()
	maycon_visual.rotation.y = PI
	maycon.add_child(maycon_visual)
	maycon_animation = maycon_visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	maycon.position = Vector3(0.0, 0.05, Z_FUNDO - 1.0)
	add_child(maycon)
	_tocar_animacao("Idle")


func _tocar_animacao(nome:String) -> void:
	if maycon_animation == null or not maycon_animation.has_animation(nome):
		return
	if maycon_animation.current_animation == nome and maycon_animation.is_playing():
		return
	maycon_animation.play(nome, 0.25)


func _physics_process(delta:float) -> void:
	tempo += delta
	if entrando_na_cabine or not controle_liberado:
		if is_instance_valid(maycon):
			maycon.velocity = Vector3.ZERO
		_posicionar_camera(false)
		return
	var entrada := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	var direcao := Vector3(entrada.x, 0.0, entrada.y)
	if direcao.length() > 1.0:
		direcao = direcao.normalized()
	maycon.velocity.x = direcao.x * VELOCIDADE_MAYCON
	maycon.velocity.z = direcao.z * VELOCIDADE_MAYCON
	maycon.velocity.y -= 22.0 * delta
	maycon.move_and_slide()
	if maycon.is_on_floor():
		maycon.velocity.y = 0.0
	if direcao.length_squared() > 0.01:
		maycon_visual.rotation.y = lerp_angle(maycon_visual.rotation.y, atan2(direcao.x, direcao.z), minf(delta * 11.0, 1.0))
		_tocar_animacao("Walking")
		_atualizar_passos(delta)
	else:
		_tocar_animacao("Idle")
		tempo_passo = 0.0
	_posicionar_camera(false)


func _atualizar_passos(delta:float) -> void:
	tempo_passo -= delta
	if tempo_passo <= 0.0:
		tempo_passo = 0.42
		passo.pitch_scale = randf_range(0.92, 1.06)
		passo.play()


func _posicionar_camera(imediato:bool) -> void:
	if not is_instance_valid(maycon):
		return
	var balanco := Vector3(sin(tempo * 1.7) * 0.035, sin(tempo * 2.3) * 0.028, 0.0)
	if entrando_na_cabine:
		# Dentro da cabine de comando a câmera fica de lado, vendo o Maycon entrar
		var posto := Vector3(1.55, 1.5, Z_POSTO_PILOTO + 0.1) + balanco
		camera.global_position = camera.global_position.lerp(posto, 0.12)
		camera.look_at(maycon.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
		return
	# Câmera atrás do Maycon, com uma leve oscilação de voo
	var desejada := maycon.global_position + Vector3(0.0, 1.62, 3.1) + balanco
	if imediato:
		camera.global_position = desejada
	else:
		camera.global_position = camera.global_position.lerp(desejada, 0.22)
	camera.look_at(maycon.global_position + Vector3(0.0, 1.12, -2.4), Vector3.UP)


# ---------------------------------------------------------------- saída

func _ao_entrar_na_cabine(body:Node3D) -> void:
	if entrando_na_cabine or body != maycon:
		return
	entrando_na_cabine = true
	controle_liberado = false
	maycon.velocity = Vector3.ZERO
	_tocar_animacao("Walking")
	var dica_tw := create_tween().bind_node(dica)
	dica_tw.tween_property(dica, "modulate:a", 0.0, 0.3)

	# Maycon entra na cabine de comando e senta no posto do piloto
	var destino := Vector3(-0.72, maycon.position.y, Z_POSTO_PILOTO + 0.75)
	var caminhada := create_tween().bind_node(maycon)
	caminhada.tween_property(maycon, "position", Vector3(0.0, maycon.position.y, Z_PORTA_CABINE - 0.6), 0.9).set_trans(Tween.TRANS_SINE)
	caminhada.tween_property(maycon, "position", destino, 1.3).set_trans(Tween.TRANS_SINE)
	var giro := create_tween().bind_node(maycon_visual)
	giro.tween_interval(0.9)
	giro.tween_property(maycon_visual, "rotation:y", PI + 0.35, 0.9)
	await caminhada.finished
	_tocar_animacao("Idle")
	await get_tree().create_timer(0.45).timeout

	var fade_out := create_tween().bind_node(fade_rect)
	fade_out.tween_property(fade_rect, "modulate:a", 1.0, DURACAO_FADE_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fade_out.finished
	get_tree().change_scene_to_file.call_deferred(PROXIMA_CENA)
