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

const VENTO_SCRIPT = preload("res://scripts/3D/aviao_linhas_vento.gd")
const PAUSE_SCRIPT = preload("res://scripts/3D/platform_pause.gd")

const Z_BURACO := 16.2
const SAIDA_BURACO := Vector3(0.0, 5.2, Z_BURACO)
const INTERVALO_TRALHA := 0.38

# As animações do Maycon estão trocadas de propósito nesta cena
const ANIM_ANDANDO := "Idle"
const ANIM_PARADO := "Walking"

const VELOCIDADE_MAYCON := 4.2
const DURACAO_BALANCO := 1.5
const DURACAO_FADE_IN := 5.0
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
var buraco:Node3D
var linhas_buraco:MultiMeshInstance3D
var tralhas:Array[Dictionary] = []
var tempo_tralha:float = 0.0
var controle_liberado:bool = false

# Campos exigidos pelo menu de pausa compartilhado das fases 3D
var exit_started:bool = false
var death_in_progress:bool = false

var esqueleto:Skeleton3D
var osso_cabeca:int = -1
var balanco_cabeca:float = -1.0
var caminhando_para_cabine:bool = false
var entrando_na_cabine:bool = false
var tempo:float = 0.0
var tempo_passo:float = 0.0


func _ready() -> void:
	get_tree().paused = false
	# Roda depois do AnimationPlayer, senão o balanço da cabeça é sobrescrito
	process_priority = 10
	_montar_cabine()
	_montar_maycon()
	_posicionar_camera(true)
	_montar_pausa()
	_manter_em_loop($Vento)
	_manter_em_loop($Motor)
	dica.text = tr("AVIAO_INTERIOR_DICA")
	dica.modulate.a = 0.0
	var fade_in := create_tween().bind_node(fade_rect)
	fade_in.tween_property(fade_rect, "modulate:a", 0.0, DURACAO_FADE_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_abertura()


# Maycon acorda caído no chão da cabine, se levanta e balança a cabeça tonto
# antes de o jogador assumir o controle
func _abertura() -> void:
	await get_tree().create_timer(DURACAO_FADE_IN * 0.5).timeout
	await _levantar_do_chao()
	await _balancar_a_cabeca()
	controle_liberado = true
	var dica_tw := create_tween().bind_node(dica)
	dica_tw.tween_property(dica, "modulate:a", 1.0, 0.6)
	dica_tw.tween_interval(4.5)
	dica_tw.tween_property(dica, "modulate:a", 0.0, 0.8)


func _levantar_do_chao() -> void:
	if maycon_animation == null or not maycon_animation.has_animation("Dead"):
		return
	# A animação de cair tocada ao contrário vira a de levantar
	maycon_animation.play_backwards("Dead")
	await get_tree().create_timer(maycon_animation.get_animation("Dead").length + 0.15).timeout
	maycon_animation.speed_scale = 1.0
	_tocar_animacao(ANIM_PARADO)


func _balancar_a_cabeca() -> void:
	if osso_cabeca < 0:
		await get_tree().create_timer(0.6).timeout
		return
	balanco_cabeca = 0.0
	await get_tree().create_timer(DURACAO_BALANCO).timeout
	balanco_cabeca = -1.0


func _montar_pausa() -> void:
	var pausa := CanvasLayer.new()
	pausa.name = "PauseFofo"
	pausa.set_script(PAUSE_SCRIPT)
	add_child(pausa)


func exit_to_menu() -> void:
	if exit_started:
		return
	exit_started = true
	controle_liberado = false
	get_tree().paused = false
	fade_rect.color = Color.BLACK
	var fade_out := create_tween().bind_node(fade_rect)
	fade_out.tween_property(fade_rect, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await fade_out.finished
	Global.back_to_main_camera = true
	Global.save_progress("fase_aviao")
	get_tree().change_scene_to_file.call_deferred("res://scenes/menu.tscn")


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
	_montar_buraco_no_teto()
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


# Buraco rasgado no teto, bem em cima de onde o Maycon caiu dentro do avião
func _montar_buraco_no_teto() -> void:
	buraco = Node3D.new()
	buraco.name = "BuracoNoTeto"
	buraco.position = Vector3(0.0, 0.0, Z_BURACO)
	cabine.add_child(buraco)

	# Céu aberto visto por dentro
	var ceu := StandardMaterial3D.new()
	ceu.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ceu.albedo_color = AviaoModelo.SKY_COLOR
	ceu.emission_enabled = true
	ceu.emission = Color(1.0, 1.0, 1.0)
	ceu.emission_energy_multiplier = 2.4
	# Abertura arredondada, acompanhando o contorno das chapas rasgadas
	var abertura := CylinderMesh.new()
	abertura.top_radius = 0.78
	abertura.bottom_radius = 0.78
	abertura.height = 0.06
	abertura.radial_segments = 24
	abertura.rings = 0
	var mi_ceu := MeshInstance3D.new()
	mi_ceu.name = "CeuAberto"
	mi_ceu.mesh = abertura
	mi_ceu.material_override = ceu
	mi_ceu.position = Vector3(0.0, 3.12, 0.0)
	mi_ceu.scale = Vector3(1.0, 1.0, 1.7)
	buraco.add_child(mi_ceu)

	# Chapas retorcidas na borda do rasgo
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.72, 0.73, 0.76)
	metal.metallic = 0.7
	metal.roughness = 0.45
	for i in range(16):
		var angulo := float(i) / 16.0 * TAU
		var lasca := BoxMesh.new()
		lasca.size = Vector3(randf_range(0.14, 0.32), 0.05, randf_range(0.25, 0.6))
		var mi := MeshInstance3D.new()
		mi.name = "Lasca"
		mi.mesh = lasca
		mi.material_override = metal
		mi.position = Vector3(cos(angulo) * 0.82, 3.06 - absf(cos(angulo)) * 0.16, sin(angulo) * 1.35)
		mi.rotation = Vector3(randf_range(-0.7, -0.15), angulo, randf_range(-0.5, 0.5))
		buraco.add_child(mi)

	# Feixe de luz entrando pelo rasgo
	var feixe_mat := StandardMaterial3D.new()
	feixe_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	feixe_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	feixe_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	feixe_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	feixe_mat.albedo_color = Color(0.85, 0.93, 1.0, 0.05)
	var feixe := CylinderMesh.new()
	feixe.top_radius = 0.75
	feixe.bottom_radius = 1.7
	feixe.height = 3.1
	feixe.radial_segments = 16
	feixe.material = feixe_mat
	var mi_feixe := MeshInstance3D.new()
	mi_feixe.name = "FeixeDeLuz"
	mi_feixe.mesh = feixe
	mi_feixe.position = Vector3(0.0, 1.55, 0.0)
	buraco.add_child(mi_feixe)

	var luz := OmniLight3D.new()
	luz.name = "LuzDoBuraco"
	luz.light_color = Color(0.9, 0.95, 1.0)
	luz.light_energy = 3.4
	luz.omni_range = 9.0
	luz.position = Vector3(0.0, 2.9, 0.0)
	buraco.add_child(luz)

	# Vento entrando e subindo pelo rasgo
	linhas_buraco = MultiMeshInstance3D.new()
	linhas_buraco.name = "VentoDoBuraco"
	linhas_buraco.set_script(VENTO_SCRIPT)
	linhas_buraco.quantidade = 70
	linhas_buraco.alcance_z = 6.0
	linhas_buraco.z_limite = 4.4
	linhas_buraco.raio_min = 0.05
	linhas_buraco.raio_max = 1.15
	linhas_buraco.achatamento = 1.25
	linhas_buraco.velocidade = 13.0
	linhas_buraco.espessura = 0.022
	linhas_buraco.comprimento_min = 0.5
	linhas_buraco.comprimento_max = 1.9
	linhas_buraco.alpha_min = 0.12
	linhas_buraco.alpha_max = 0.4
	# Girado para os riscos subirem em direção ao céu
	linhas_buraco.rotation.x = deg_to_rad(-90.0)
	linhas_buraco.position = Vector3(0.0, 0.2, 0.0)
	buraco.add_child(linhas_buraco)


# A cabine está furada, então a tralha solta vai sendo sugada pelo buraco
func _soltar_tralha() -> void:
	var item:Node3D
	if randf() < 0.18:
		item = AviaoModelo.criar_poltrona()
		item.scale = Vector3.ONE * 0.7
	else:
		item = AviaoModelo.criar_tralha(randf_range(0.45, 1.05))
	cabine.add_child(item)
	var inicio := Vector3(
		randf_range(-1.9, 1.9),
		randf_range(0.15, 1.5),
		Z_BURACO + randf_range(-11.0, 3.5)
	)
	item.position = inicio
	tralhas.append({
		"no": item,
		"inicio": inicio,
		"t": 0.0,
		"dur": randf_range(1.0, 2.1),
		"giro": Vector3(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0), randf_range(-7.0, 7.0))
	})


func _atualizar_tralhas(delta:float) -> void:
	tempo_tralha -= delta
	if tempo_tralha <= 0.0:
		tempo_tralha = INTERVALO_TRALHA * randf_range(0.6, 1.5)
		_soltar_tralha()
	var restantes:Array[Dictionary] = []
	for tralha in tralhas:
		var no:Node3D = tralha["no"]
		if not is_instance_valid(no):
			continue
		var t := float(tralha["t"]) + delta / float(tralha["dur"])
		tralha["t"] = t
		if t >= 1.0:
			no.queue_free()
			continue
		# Sugado cada vez mais rápido em direção ao rasgo
		var avanco := pow(t, 2.1)
		no.position = Vector3(tralha["inicio"]).lerp(SAIDA_BURACO, avanco)
		no.rotation += Vector3(tralha["giro"]) * delta
		restantes.append(tralha)
	tralhas = restantes


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
	var esqueletos:Array[Node] = maycon_visual.find_children("*", "Skeleton3D", true, false)
	if not esqueletos.is_empty():
		esqueleto = esqueletos[0] as Skeleton3D
		osso_cabeca = esqueleto.find_bone("Head")
	maycon.position = Vector3(0.0, 0.05, Z_FUNDO - 1.0)
	add_child(maycon)
	# Começa caído no chão, no último quadro da animação de queda
	if maycon_animation and maycon_animation.has_animation("Dead"):
		maycon_animation.play("Dead")
		maycon_animation.seek(maycon_animation.get_animation("Dead").length, true)
		maycon_animation.pause()
	else:
		_tocar_animacao(ANIM_PARADO)


func _tocar_animacao(nome:String) -> void:
	if maycon_animation == null or not maycon_animation.has_animation(nome):
		return
	if maycon_animation.current_animation == nome and maycon_animation.is_playing():
		return
	maycon_animation.play(nome, 0.25)


func _process(delta:float) -> void:
	if balanco_cabeca < 0.0 or osso_cabeca < 0 or not is_instance_valid(esqueleto):
		return
	balanco_cabeca += delta
	# Nega com a cabeça, perdendo força até parar
	var forca := 1.0 - clampf(balanco_cabeca / DURACAO_BALANCO, 0.0, 1.0)
	var angulo := sin(balanco_cabeca * 13.0) * 0.42 * forca
	var pose := esqueleto.get_bone_pose_rotation(osso_cabeca)
	esqueleto.set_bone_pose_rotation(osso_cabeca, pose * Quaternion(Vector3.UP, angulo))


func _physics_process(delta:float) -> void:
	tempo += delta
	_atualizar_tralhas(delta)
	if entrando_na_cabine or not controle_liberado:
		if is_instance_valid(maycon):
			maycon.velocity = Vector3.ZERO
		# As animações do modelo não são em loop, então precisam ser reativadas
		if entrando_na_cabine:
			_tocar_animacao(ANIM_ANDANDO if caminhando_para_cabine else ANIM_PARADO)
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
		_tocar_animacao(ANIM_ANDANDO)
		_atualizar_passos(delta)
	else:
		_tocar_animacao(ANIM_PARADO)
		tempo_passo = 0.0
	_posicionar_camera(false)


func _atualizar_passos(delta:float) -> void:
	tempo_passo -= delta
	if tempo_passo <= 0.0:
		tempo_passo = 0.62
		passo.pitch_scale = randf_range(0.92, 1.06)
		passo.play()


func _posicionar_camera(imediato:bool) -> void:
	if not is_instance_valid(maycon):
		return
	# Balanço constante de avião em voo, com alguns solavancos de turbulência
	var balanco := Vector3(
		sin(tempo * 1.7) * 0.075 + sin(tempo * 5.9) * 0.022,
		sin(tempo * 2.3) * 0.06 + cos(tempo * 7.3) * 0.018,
		0.0
	)
	var solavanco := maxf(sin(tempo * 0.41) - 0.85, 0.0) * 1.6
	balanco.y += sin(tempo * 23.0) * 0.09 * solavanco
	balanco.x += cos(tempo * 19.0) * 0.07 * solavanco
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
	camera.rotation.z = sin(tempo * 1.9) * 0.02 + sin(tempo * 6.7) * 0.006 + sin(tempo * 17.0) * 0.012 * solavanco


# ---------------------------------------------------------------- saída

func _ao_entrar_na_cabine(body:Node3D) -> void:
	if entrando_na_cabine or exit_started or body != maycon:
		return
	entrando_na_cabine = true
	controle_liberado = false
	maycon.velocity = Vector3.ZERO
	caminhando_para_cabine = true
	_tocar_animacao(ANIM_ANDANDO)
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
	caminhando_para_cabine = false
	_tocar_animacao(ANIM_PARADO)
	await get_tree().create_timer(0.45).timeout

	var fade_out := create_tween().bind_node(fade_rect)
	fade_out.tween_property(fade_rect, "modulate:a", 1.0, DURACAO_FADE_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fade_out.finished
	get_tree().change_scene_to_file.call_deferred(PROXIMA_CENA)
