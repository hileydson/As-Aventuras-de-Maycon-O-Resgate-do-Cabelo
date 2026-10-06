extends Node3D

# Combate aéreo estilo Ace Combat contra o Lips gigante.
# O avião voa preso num corredor de céu azul, com linhas de vento passando, duas
# metralhadoras surgindo embaixo das asas e mira central. O Lips voa de um lado
# para o outro cuspindo lanches gigantes; cada lanche que acerta sacode o avião,
# mancha a tela de sangue e tira vida do Maycon. A fase só acaba quando o Lips cai.

const LIPS_SCRIPT = preload("res://scripts/3D/aviao_lips_boss.gd")
const MIRA_SCRIPT = preload("res://scripts/3D/aviao_mira.gd")
const VENTO_SCRIPT = preload("res://scripts/3D/aviao_linhas_vento.gd")
const BLOOD_OVERLAY_SCRIPT = preload("res://scripts/3D/platform_blood_overlay.gd")
const PAUSE_SCRIPT = preload("res://scripts/3D/platform_pause.gd")
const BLOOD_SCENE = preload("res://scenes/3D/blood.tscn")
const LANCHE_TEXTURE = preload("res://assets/novas_imagens/inimigos/xuruzika/inimigo_xuruzika_coxinha.png")
const FONTE_TITULO = preload("res://assets/novas_imagens/menu/gui-for-cyberpunk-pixel-art/10 Font/CyberpunkCraftpixPixel.otf")
const BOTAO_GATILHO = preload("res://assets/novas_imagens/buttons/button_trigger.png")
const BOTAO_MOUSE = preload("res://assets/novas_imagens/buttons/mouse_trigger.png")
const BOTAO_DASH_A = preload("res://assets/novas_imagens/buttons/360_A.png")
const BOTAO_DASH_MOUSE = preload("res://assets/novas_imagens/buttons/mouse_right_click.png")

const PROXIMA_CENA = "res://scenes/fase_1_before_castle_4.tscn"

const LIMITE_X := 23.0
const LIMITE_Y := 13.0
const ACELERACAO := 82.0
const VELOCIDADE_MAX := 33.0
const AMORTECIMENTO := 4.6
const DISTANCIA_MIRA := 160.0
const DASH_VELOCIDADE := 96.0
const DASH_DURACAO := 0.2
const DASH_RECARGA := 1.2

const CAMERA_OFFSET := Vector3(0.0, 12.0, 50.0)
const CAMERA_ALVO := Vector3(0.0, 6.5, -80.0)

const INTERVALO_TIRO := 0.07
const VELOCIDADE_BALA := 430.0
const VIDA_BALA := 1.0
const DANO_BALA := 0.38
const RAIO_BALA_LIPS := 21.0

const DANO_LANCHE := 10.0
const VELOCIDADE_LANCHE := 105.0
const RAIO_LANCHE := 9.0
const TAMANHO_LANCHE := 13.0

# Buraco por onde o Maycon entrou, no alto da fuselagem
const BURACO_LOCAL := Vector3(0.0, 1.78, 2.2)
const INTERVALO_DETRITO := 0.5

# Gotas de sangue do Lips que voam para trás e podem sujar o avião
const VELOCIDADE_GOTA := 95.0
const RAIO_GOTA := 9.0
const COR_DO_SANGUE := Color(0.42, 0.03, 0.05)

@onready var aviao:Node3D = $Aviao
@onready var camera:Camera3D = $Camera3D
@onready var projeteis:Node3D = $Projeteis
@onready var lanches_no:Node3D = $Lanches
@onready var efeitos:Node3D = $Efeitos
@onready var fade_rect:ColorRect = $Fade/FadeRect
@onready var sol:DirectionalLight3D = $Sol
@onready var musica:AudioStreamPlayer = $Musica
@onready var vento:AudioStreamPlayer = $Vento
@onready var motor:AudioStreamPlayer = $Motor
@onready var som_tiro:AudioStreamPlayer = $Tiro
@onready var som_explosao:AudioStreamPlayer = $Explosao
@onready var som_impacto:AudioStreamPlayer = $Impacto
@onready var som_dano:AudioStreamPlayer = $Dano
@onready var som_grito:AudioStreamPlayer = $Grito
@onready var som_engate:AudioStreamPlayer = $Engate
@onready var som_soco:AudioStreamPlayer = $Soco
@onready var som_dash:AudioStreamPlayer = $Dash
var ambiente:Environment

var lips:Node3D
var mira:Control
var metralhadoras:Array[Node3D] = []
var linhas_vento:MultiMeshInstance3D
var hp_bar:ProgressBar
var hp_label:Label
var boss_bar:ProgressBar
var boss_label:Label
var blood_overlay:Control
var aviso_label:Label
var titulo_label:Label
var hud_canvas:CanvasLayer
var aviso_tween:Tween

var vida_maxima:float = 210.0
var vida:float = 210.0
var velocidade_aviao:Vector2 = Vector2.ZERO
var rolagem:float = 0.0
var arfagem:float = 0.0
var ponto_mira:Vector3 = Vector3(0.0, 0.0, -DISTANCIA_MIRA)
var balas:Array[Dictionary] = []
var lanches:Array[Dictionary] = []
var tempo:float = 0.0
var tempo_tiro:float = 0.0
var tempo_ataque:float = 1.2
var tremor:float = 0.0
var armas_prontas:bool = false
var controle_liberado:bool = false
var lado_do_tiro:int = 0
var buraco_aviao:Node3D
var detritos:Array[Dictionary] = []
var tempo_detrito:float = 0.0
var gotas_de_sangue:Array[Dictionary] = []
var materiais_do_aviao:Array[BaseMaterial3D] = []
var sujeira_do_aviao:Array[float] = []
var desfecho_em_andamento:bool = false
var tempo_dash:float = 0.0
var recarga_dash:float = 0.0
var botoes_dash:HBoxContainer

# Campos exigidos pelo menu de pausa compartilhado da fase 3D
var exit_started:bool = false
var death_in_progress:bool = false


func _ready() -> void:
	get_tree().paused = false
	sol.rotation = Vector3(deg_to_rad(-46.0), deg_to_rad(28.0), 0.0)
	# Cópia própria do ambiente: a cena escurece o céu no final sem afetar o recurso
	ambiente = ($WorldEnvironment as WorldEnvironment).environment.duplicate()
	($WorldEnvironment as WorldEnvironment).environment = ambiente
	vida_maxima = Global.realtime_hp_max if Global.battle_mode == Global.battle_mode_realtime else 210.0
	# Entra na batalha aérea com pelo menos metade da vida, senão o chefe fica injusto
	vida = clampf(Global.realtime_hp, vida_maxima * 0.5, vida_maxima) if Global.battle_mode == Global.battle_mode_realtime else vida_maxima
	Global.save_progress("fase_aviao")
	GameSongs.stop(1)
	_montar_aviao()
	_montar_lips()
	_montar_hud()
	_montar_pausa()
	_atualizar_camera(true)
	_preparar_grito()
	musica.play()
	_manter_em_loop(musica)
	_manter_em_loop(vento)
	_manter_em_loop(motor)
	var fade_in := create_tween().bind_node(fade_rect)
	fade_in.tween_property(fade_rect, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade_in.tween_callback(_liberar_controle)


# O mp3 do grito termina com uma explosão; em loop só o trecho do grito toca,
# e o fade de volume encerra antes de chegar nela (igual à entrada do poço infinito)
func _preparar_grito() -> void:
	var trilha:AudioStream = som_grito.stream
	if trilha is AudioStreamMP3:
		var copia:AudioStreamMP3 = trilha.duplicate()
		copia.loop = true
		som_grito.stream = copia


func _manter_em_loop(player:AudioStreamPlayer) -> void:
	# Os mp3 do projeto não são importados em loop, então o som é reiniciado no fim
	if not is_instance_valid(player):
		return
	player.finished.connect(func():
		if is_instance_valid(player):
			player.play())


# ---------------------------------------------------------------- montagem

func _montar_aviao() -> void:
	aviao.add_child(AviaoModelo.criar_aviao("Modelo"))
	for lado:float in [-1.0, 1.0]:
		var arma := AviaoModelo.criar_metralhadora()
		arma.name = "MetralhadoraEsquerda" if lado < 0.0 else "MetralhadoraDireita"
		arma.position = Vector3(AviaoModelo.WING_GUN_LOCAL.x * lado, AviaoModelo.WING_GUN_LOCAL.y + 1.6, AviaoModelo.WING_GUN_LOCAL.z)
		arma.scale = Vector3(0.01, 0.01, 0.01)
		aviao.add_child(arma)
		metralhadoras.append(arma)
	_preparar_pintura_do_aviao()
	_montar_buraco_da_fuselagem()
	linhas_vento = MultiMeshInstance3D.new()
	linhas_vento.name = "LinhasDeVento"
	linhas_vento.set_script(VENTO_SCRIPT)
	add_child(linhas_vento)


# O rombo que o Maycon abriu ao cair em cima do avião: fica escancarado no alto
# da fuselagem, soltando a tralha da cabine no vento.
func _montar_buraco_da_fuselagem() -> void:
	buraco_aviao = Node3D.new()
	buraco_aviao.name = "BuracoDaFuselagem"
	buraco_aviao.position = BURACO_LOCAL
	aviao.add_child(buraco_aviao)

	# Vão escuro e arredondado, acompanhando o contorno das chapas rasgadas
	var vao := StandardMaterial3D.new()
	vao.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vao.albedo_color = Color(0.05, 0.05, 0.07)
	var abertura := CylinderMesh.new()
	abertura.top_radius = 1.0
	abertura.bottom_radius = 1.0
	abertura.height = 0.06
	abertura.radial_segments = 24
	abertura.rings = 0
	var mi_vao := MeshInstance3D.new()
	mi_vao.name = "Vao"
	mi_vao.mesh = abertura
	mi_vao.material_override = vao
	mi_vao.scale = Vector3(1.05, 1.0, 1.65)
	buraco_aviao.add_child(mi_vao)

	# Chapas arrancadas na borda
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.78, 0.79, 0.82)
	metal.metallic = 0.75
	metal.roughness = 0.4
	for i in range(14):
		var angulo := float(i) / 14.0 * TAU
		var lasca := BoxMesh.new()
		lasca.size = Vector3(randf_range(0.16, 0.36), 0.05, randf_range(0.3, 0.75))
		var mi := MeshInstance3D.new()
		mi.name = "Lasca"
		mi.mesh = lasca
		mi.material_override = metal
		mi.position = Vector3(cos(angulo) * 1.08, randf_range(0.02, 0.2), sin(angulo) * 1.72)
		mi.rotation = Vector3(randf_range(0.15, 0.8), angulo, randf_range(-0.5, 0.5))
		buraco_aviao.add_child(mi)

	# Fumaça arrastada para trás pelo vento, denunciando o rombo
	var processo := ParticleProcessMaterial.new()
	processo.direction = Vector3(0.0, 0.45, 1.0)
	processo.spread = 14.0
	processo.initial_velocity_min = 28.0
	processo.initial_velocity_max = 46.0
	processo.gravity = Vector3(0.0, -2.0, 0.0)
	processo.scale_min = 0.25
	processo.scale_max = 1.15
	processo.color = Color(0.9, 0.91, 0.94, 0.16)
	var nuvem := QuadMesh.new()
	nuvem.size = Vector2(2.0, 2.0)
	var nuvem_mat := StandardMaterial3D.new()
	nuvem_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nuvem_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nuvem_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	nuvem_mat.vertex_color_use_as_albedo = true
	nuvem_mat.albedo_color = Color(0.92, 0.93, 0.96, 1.0)
	nuvem_mat.albedo_texture = _textura_de_nuvem()
	nuvem_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	nuvem.material = nuvem_mat
	var fumaca := GPUParticles3D.new()
	fumaca.name = "FumacaDoBuraco"
	fumaca.amount = 30
	fumaca.lifetime = 1.0
	fumaca.local_coords = false
	fumaca.process_material = processo
	fumaca.draw_pass_1 = nuvem
	fumaca.position = Vector3(0.0, 0.25, 0.4)
	buraco_aviao.add_child(fumaca)


# Baforada redonda e suave, em vez do quadrado duro do QuadMesh
func _textura_de_nuvem() -> GradientTexture2D:
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1.0, 1.0, 1.0, 0.85))
	degrade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var textura := GradientTexture2D.new()
	textura.gradient = degrade
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = 64
	textura.height = 64
	return textura


func _soltar_detrito() -> void:
	if not is_instance_valid(buraco_aviao):
		return
	var item:Node3D
	if randf() < 0.32:
		item = AviaoModelo.criar_poltrona()
		item.scale = Vector3.ONE * 0.9
	else:
		item = AviaoModelo.criar_tralha(randf_range(0.5, 1.15))
	efeitos.add_child(item)
	item.global_position = buraco_aviao.global_position + Vector3(randf_range(-0.5, 0.5), 0.2, randf_range(-0.8, 0.8))
	detritos.append({
		"no": item,
		"vel": Vector3(randf_range(-4.0, 4.0), randf_range(6.0, 13.0), randf_range(26.0, 44.0)),
		"giro": Vector3(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)),
		"vida": 3.0
	})


func _atualizar_detritos(delta:float) -> void:
	tempo_detrito -= delta
	if tempo_detrito <= 0.0:
		tempo_detrito = INTERVALO_DETRITO * randf_range(0.5, 1.6)
		_soltar_detrito()
	var restantes:Array[Dictionary] = []
	for detrito in detritos:
		var no:Node3D = detrito["no"]
		if not is_instance_valid(no):
			continue
		var vel:Vector3 = detrito["vel"]
		# O vento de frente joga tudo para trás e para baixo
		vel.z += 46.0 * delta
		vel.y -= 9.0 * delta
		detrito["vel"] = vel
		no.global_position += vel * delta
		no.rotation += Vector3(detrito["giro"]) * delta
		detrito["vida"] = float(detrito["vida"]) - delta
		# Some antes de passar por cima da câmera, para não tapar a tela
		if float(detrito["vida"]) <= 0.0 or no.global_position.z > camera.global_position.z - 8.0:
			no.queue_free()
			continue
		restantes.append(detrito)
	detritos = restantes


# Cada porrada no Lips manda um punhado de gotas em direção ao avião; as que
# acertam ficam grudadas na fuselagem até o fim da fase.
func _ao_jorrar_sangue(ponto:Vector3) -> void:
	for i in range(randi_range(2, 4)):
		var gota := MeshInstance3D.new()
		var bolha := SphereMesh.new()
		bolha.radius = randf_range(0.35, 0.95)
		bolha.height = bolha.radius * 2.0
		bolha.radial_segments = 8
		bolha.rings = 4
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.5, 0.01, 0.045)
		bolha.material = mat
		gota.mesh = bolha
		efeitos.add_child(gota)
		gota.global_position = ponto + Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
		var alvo := aviao.global_position + Vector3(randf_range(-16.0, 16.0), randf_range(-6.0, 6.0), randf_range(-8.0, 8.0))
		gotas_de_sangue.append({
			"no": gota,
			"dir": (alvo - gota.global_position).normalized(),
			"vida": 3.2
		})


func _atualizar_gotas(delta:float) -> void:
	var restantes:Array[Dictionary] = []
	for gota in gotas_de_sangue:
		var no:MeshInstance3D = gota["no"]
		if not is_instance_valid(no):
			continue
		var anterior := no.global_position
		no.global_position = anterior + Vector3(gota["dir"]) * VELOCIDADE_GOTA * delta
		gota["vida"] = float(gota["vida"]) - delta
		if _segmento_acerta(anterior, no.global_position, aviao.global_position, RAIO_GOTA):
			_manchar_aviao(no.global_position)
			no.queue_free()
			continue
		if float(gota["vida"]) <= 0.0 or no.global_position.z > camera.global_position.z:
			no.queue_free()
			continue
		restantes.append(gota)
	gotas_de_sangue = restantes


# O avião é curvo, então decalque plano fica estranho. Em vez disso a própria
# pintura vai ficando vermelha nas partes onde o sangue bate.
func _manchar_aviao(ponto:Vector3) -> void:
	if materiais_do_aviao.is_empty():
		return
	var local:Vector3 = aviao.to_local(ponto)
	# Perto do eixo é fuselagem, mais para fora são as asas
	var indice := 0 if absf(local.x) < 4.0 else 1
	indice = mini(indice, materiais_do_aviao.size() - 1)
	sujeira_do_aviao[indice] = minf(float(sujeira_do_aviao[indice]) + 0.05, 0.9)
	var mat:BaseMaterial3D = materiais_do_aviao[indice]
	if is_instance_valid(mat):
		mat.albedo_color = Color.WHITE.lerp(COR_DO_SANGUE, float(sujeira_do_aviao[indice]))


# Duplica os materiais do avião para poder sujá-los sem mexer no recurso original
func _preparar_pintura_do_aviao() -> void:
	for node in aviao.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi or not mi.mesh:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var origem = mi.get_surface_override_material(i)
			if not origem:
				origem = mi.mesh.surface_get_material(i)
			if origem is BaseMaterial3D:
				var copia = origem.duplicate() as BaseMaterial3D
				mi.set_surface_override_material(i, copia)
				materiais_do_aviao.append(copia)
				sujeira_do_aviao.append(0.0)
		break


func _montar_lips() -> void:
	lips = Node3D.new()
	lips.name = "LipsGigante"
	lips.set_script(LIPS_SCRIPT)
	add_child(lips)
	lips.position = Vector3(0.0, 0.0, -300.0)
	lips.vida_alterada.connect(_ao_mudar_vida_do_lips)
	lips.derrotado.connect(_ao_derrotar_lips)
	lips.jorro_de_sangue.connect(_ao_jorrar_sangue)


func _montar_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	hud_canvas = canvas

	blood_overlay = Control.new()
	blood_overlay.name = "SangueNaTela"
	blood_overlay.set_script(BLOOD_OVERLAY_SCRIPT)
	canvas.add_child(blood_overlay)

	mira = Control.new()
	mira.name = "Mira"
	mira.set_script(MIRA_SCRIPT)
	canvas.add_child(mira)
	mira.camera = camera
	mira.alvo = lips

	var painel := PanelContainer.new()
	painel.anchor_top = 1.0
	painel.anchor_bottom = 1.0
	painel.offset_left = 12.0
	painel.offset_right = 348.0
	painel.offset_top = -62.0
	painel.offset_bottom = -12.0
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.012, 0.018, 0.03, 0.84)
	estilo.border_color = Color(0.31, 0.67, 0.8, 0.65)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(10)
	estilo.set_content_margin_all(8)
	estilo.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	estilo.shadow_size = 6
	estilo.shadow_offset = Vector2(2.0, 3.0)
	painel.add_theme_stylebox_override("panel", estilo)
	canvas.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 5)
	painel.add_child(coluna)
	hp_label = Label.new()
	hp_label.text = tr("UI_HEALTH")
	hp_label.add_theme_font_size_override("font_size", 12)
	coluna.add_child(hp_label)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(310.0, 12.0)
	hp_bar.show_percentage = false
	hp_bar.max_value = vida_maxima
	hp_bar.value = vida
	var preenche := StyleBoxFlat.new()
	preenche.bg_color = Color("b1223e")
	hp_bar.add_theme_stylebox_override("fill", preenche)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color("3a1924")
	hp_bar.add_theme_stylebox_override("background", fundo)
	coluna.add_child(hp_bar)

	# Botões do tiro no canto inferior direito, no mesmo estilo do HUD da moto
	var botoes_tiro := HBoxContainer.new()
	botoes_tiro.name = "BotoesDoTiro"
	botoes_tiro.anchor_left = 1.0
	botoes_tiro.anchor_top = 1.0
	botoes_tiro.anchor_right = 1.0
	botoes_tiro.anchor_bottom = 1.0
	botoes_tiro.offset_left = -152.0
	botoes_tiro.offset_top = -86.0
	botoes_tiro.offset_right = -16.0
	botoes_tiro.offset_bottom = -16.0
	botoes_tiro.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	botoes_tiro.grow_vertical = Control.GROW_DIRECTION_BEGIN
	botoes_tiro.alignment = BoxContainer.ALIGNMENT_END
	botoes_tiro.add_theme_constant_override("separation", 8)
	botoes_tiro.add_child(_hud_icone(BOTAO_MOUSE, Vector2(58.0, 58.0)))
	botoes_tiro.add_child(_hud_icone(BOTAO_GATILHO, Vector2(68.0, 68.0)))
	canvas.add_child(_fundo_hud_acao(Vector2(-160.0, -92.0), Vector2(-12.0, -10.0), Color(1.0, 0.48, 0.68)))
	canvas.add_child(botoes_tiro)

	botoes_dash = HBoxContainer.new()
	botoes_dash.name = "BotoesDoDash"
	botoes_dash.anchor_left = 1.0
	botoes_dash.anchor_top = 1.0
	botoes_dash.anchor_right = 1.0
	botoes_dash.anchor_bottom = 1.0
	botoes_dash.offset_left = -152.0
	botoes_dash.offset_top = -156.0
	botoes_dash.offset_right = -16.0
	botoes_dash.offset_bottom = -92.0
	botoes_dash.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	botoes_dash.grow_vertical = Control.GROW_DIRECTION_BEGIN
	botoes_dash.alignment = BoxContainer.ALIGNMENT_END
	botoes_dash.add_theme_constant_override("separation", 8)
	botoes_dash.add_child(_hud_icone(BOTAO_DASH_MOUSE, Vector2(54.0, 54.0)))
	botoes_dash.add_child(_hud_icone(BOTAO_DASH_A, Vector2(54.0, 54.0)))
	canvas.add_child(_fundo_hud_acao(Vector2(-160.0, -162.0), Vector2(-12.0, -88.0), Color(0.35, 0.9, 1.0)))
	canvas.add_child(botoes_dash)

	var boss_painel := PanelContainer.new()
	boss_painel.name = "BossHUD"
	boss_painel.anchor_left = 0.5
	boss_painel.anchor_right = 0.5
	boss_painel.offset_left = -210.0
	boss_painel.offset_right = 210.0
	boss_painel.offset_top = 14.0
	boss_painel.offset_bottom = 68.0
	boss_painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var boss_estilo := StyleBoxFlat.new()
	boss_estilo.bg_color = Color(0.08, 0.08, 0.12, 0.88)
	boss_estilo.border_color = Color(0.85, 0.72, 0.28, 0.9)
	boss_estilo.set_border_width_all(2)
	boss_estilo.set_corner_radius_all(8)
	boss_estilo.set_content_margin_all(8)
	boss_painel.add_theme_stylebox_override("panel", boss_estilo)
	canvas.add_child(boss_painel)
	var boss_coluna := VBoxContainer.new()
	boss_coluna.add_theme_constant_override("separation", 3)
	boss_painel.add_child(boss_coluna)
	boss_label = Label.new()
	boss_label.text = "★ " + tr("PLATFORM_BOSS_NAME") + " ★"
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override("font_size", 14)
	boss_label.add_theme_color_override("font_color", Color("f9ca51"))
	boss_coluna.add_child(boss_label)
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(400.0, 14.0)
	boss_bar.show_percentage = false
	boss_bar.max_value = lips.vida_maxima
	boss_bar.value = lips.vida_maxima
	var boss_preenche := StyleBoxFlat.new()
	boss_preenche.bg_color = Color("c71a36")
	boss_preenche.set_corner_radius_all(3)
	boss_bar.add_theme_stylebox_override("fill", boss_preenche)
	var boss_fundo := StyleBoxFlat.new()
	boss_fundo.bg_color = Color(0.22, 0.08, 0.12, 0.95)
	boss_fundo.set_corner_radius_all(3)
	boss_bar.add_theme_stylebox_override("background", boss_fundo)
	boss_coluna.add_child(boss_bar)

	aviso_label = Label.new()
	aviso_label.name = "Aviso"
	aviso_label.anchor_left = 0.5
	aviso_label.anchor_right = 0.5
	aviso_label.anchor_top = 0.5
	aviso_label.anchor_bottom = 0.5
	aviso_label.offset_left = -400.0
	aviso_label.offset_right = 400.0
	aviso_label.offset_top = -150.0
	aviso_label.offset_bottom = -90.0
	aviso_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	aviso_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso_label.add_theme_font_size_override("font_size", 30)
	aviso_label.add_theme_color_override("font_color", Color("ffd700"))
	aviso_label.add_theme_color_override("font_outline_color", Color("1a0a00"))
	aviso_label.add_theme_constant_override("outline_size", 8)
	aviso_label.modulate.a = 0.0
	canvas.add_child(aviso_label)

	titulo_label = Label.new()
	titulo_label.name = "TituloDaFase"
	titulo_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	titulo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titulo_label.text = tr("AVIAO_TITULO_FASE")
	titulo_label.add_theme_font_override("font", FONTE_TITULO)
	titulo_label.add_theme_font_size_override("font_size", 116)
	titulo_label.add_theme_color_override("font_color", Color("ff4034"))
	titulo_label.add_theme_color_override("font_outline_color", Color("2a0503"))
	titulo_label.add_theme_constant_override("outline_size", 22)
	titulo_label.modulate.a = 0.0
	canvas.add_child(titulo_label)


func _montar_pausa() -> void:
	var pausa := CanvasLayer.new()
	pausa.name = "PauseFofo"
	pausa.set_script(PAUSE_SCRIPT)
	add_child(pausa)


func _hud_icone(textura:Texture2D, tamanho:Vector2) -> TextureRect:
	var icone := TextureRect.new()
	icone.texture = textura
	Global.input_hints.bind_visibility(icone, textura == BOTAO_GATILHO or textura == BOTAO_DASH_A)
	icone.custom_minimum_size = tamanho
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icone


func _fundo_hud_acao(offset_top_left:Vector2, offset_bottom_right:Vector2, accent:Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = offset_top_left.x
	panel.offset_top = offset_top_left.y
	panel.offset_right = offset_bottom_right.x
	panel.offset_bottom = offset_bottom_right.y
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
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
	return panel


func _liberar_controle() -> void:
	controle_liberado = true
	_abrir_com_titulo()


# Alguns segundos só voando, o título estoura no meio da tela com um soco e só
# então as metralhadoras surgem e o Lips aparece
func _abrir_com_titulo() -> void:
	await get_tree().create_timer(2.6).timeout
	if exit_started or death_in_progress:
		return
	som_soco.pitch_scale = 0.72
	som_soco.play()
	titulo_label.pivot_offset = titulo_label.size * 0.5
	titulo_label.scale = Vector2(2.4, 2.4)
	titulo_label.modulate.a = 1.0
	var entrada := create_tween().bind_node(titulo_label)
	entrada.tween_property(titulo_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrada.tween_interval(1.9)
	entrada.tween_property(titulo_label, "modulate:a", 0.0, 0.7)
	await get_tree().create_timer(2.5).timeout
	if exit_started or death_in_progress:
		return
	_comecar_batalha()


func _comecar_batalha() -> void:
	_mostrar_aviso(tr("AVIAO_AVISO_ARMAS"))
	_armar_metralhadoras()
	# O Lips vem surgindo lá do fundo do céu
	var chegada := create_tween().bind_node(lips)
	chegada.tween_property(lips, "position:z", float(lips.z_base), 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	chegada.tween_callback(func():
		if is_instance_valid(lips):
			lips.ativo = true
			lips.gritar()
			_mostrar_aviso(tr("AVIAO_AVISO_LIPS")))


func _armar_metralhadoras() -> void:
	# As duas metralhadoras vão surgindo embaixo das asas
	som_engate.play()
	for arma in metralhadoras:
		var alvo_y := AviaoModelo.WING_GUN_LOCAL.y
		var tw := create_tween().bind_node(arma).set_parallel(true)
		tw.tween_property(arma, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(arma, "position:y", alvo_y, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.95).timeout
	armas_prontas = true


# ---------------------------------------------------------------- laço

func _process(delta:float) -> void:
	tempo += delta
	if desfecho_em_andamento:
		# A queda final comanda a câmera sozinha
		return
	_atualizar_voo(delta)
	if is_instance_valid(linhas_vento):
		linhas_vento.position = aviao.position
	_atualizar_camera(false)
	_atualizar_mira()
	_atualizar_tiro(delta)
	_atualizar_balas(delta)
	_atualizar_lanches(delta)
	_atualizar_detritos(delta)
	_atualizar_gotas(delta)
	_atualizar_ataques_do_lips(delta)
	if tremor > 0.0:
		tremor = maxf(0.0, tremor - delta * 1.6)


func _atualizar_voo(delta:float) -> void:
	var entrada := Vector2.ZERO
	if controle_liberado and not exit_started and not death_in_progress:
		entrada = Vector2(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
		)
	if entrada.length() > 1.0:
		entrada = entrada.normalized()
	_atualizar_dash(delta, entrada)
	if tempo_dash <= 0.0:
		velocidade_aviao += entrada * ACELERACAO * delta
		if entrada.length_squared() < 0.01:
			velocidade_aviao = velocidade_aviao.lerp(Vector2.ZERO, minf(delta * AMORTECIMENTO, 1.0))
		velocidade_aviao = velocidade_aviao.limit_length(VELOCIDADE_MAX)

	var pos := aviao.position
	pos.x = clampf(pos.x + velocidade_aviao.x * delta, -LIMITE_X, LIMITE_X)
	pos.y = clampf(pos.y + velocidade_aviao.y * delta, -LIMITE_Y, LIMITE_Y)
	if absf(pos.x) >= LIMITE_X:
		velocidade_aviao.x = 0.0
	if absf(pos.y) >= LIMITE_Y:
		velocidade_aviao.y = 0.0
	aviao.position = pos

	rolagem = lerpf(rolagem, -entrada.x * 0.62, minf(delta * 5.0, 1.0))
	arfagem = lerpf(arfagem, entrada.y * 0.2, minf(delta * 5.0, 1.0))
	aviao.rotation = Vector3(arfagem + sin(tempo * 1.7) * 0.012, 0.0, rolagem + sin(tempo * 1.1) * 0.02)
	# As metralhadoras giram os canos enquanto atiram
	if armas_prontas and Input.is_action_pressed("tiro"):
		for arma in metralhadoras:
			arma.rotate_object_local(Vector3(0.0, 0.0, 1.0), delta * 22.0)


# Arrancada curta para escapar dos lanches, no A do controle ou botão direito
func _atualizar_dash(delta:float, entrada:Vector2) -> void:
	tempo_dash = maxf(0.0, tempo_dash - delta)
	recarga_dash = maxf(0.0, recarga_dash - delta)
	if is_instance_valid(botoes_dash):
		botoes_dash.modulate.a = 1.0 if recarga_dash <= 0.0 else 0.32
	if tempo_dash > 0.0 or recarga_dash > 0.0:
		return
	if not controle_liberado or exit_started or death_in_progress:
		return
	if not Input.is_action_just_pressed("dash_aviao"):
		return
	var direcao := entrada
	if direcao.length_squared() < 0.01:
		direcao = Vector2(0.0, 1.0)
	velocidade_aviao = direcao.normalized() * DASH_VELOCIDADE
	tempo_dash = DASH_DURACAO
	recarga_dash = DASH_RECARGA
	som_dash.pitch_scale = randf_range(1.1, 1.3)
	som_dash.play()
	var fov_tw := create_tween().bind_node(camera)
	fov_tw.tween_property(camera, "fov", 78.0, 0.09)
	fov_tw.tween_property(camera, "fov", 68.0, 0.3)


func _atualizar_camera(imediato:bool) -> void:
	var desejada := aviao.position + CAMERA_OFFSET
	if imediato:
		camera.position = desejada
	else:
		camera.position = camera.position.lerp(desejada, minf(get_process_delta_time() * 7.5, 1.0))
	camera.look_at(aviao.global_position + CAMERA_ALVO, Vector3.UP)
	camera.rotation.z = rolagem * 0.32
	if tremor > 0.0:
		camera.h_offset = randf_range(-tremor, tremor) * 0.55
		camera.v_offset = randf_range(-tremor, tremor) * 0.55
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _atualizar_mira() -> void:
	var centro := get_viewport().get_visible_rect().size * 0.5
	# As metralhadoras convergem na distância do Lips, então a mira central é exata
	var alcance := DISTANCIA_MIRA
	if is_instance_valid(lips) and not lips.abatido:
		alcance = camera.global_position.distance_to(lips.global_position)
	ponto_mira = camera.project_ray_origin(centro) + camera.project_ray_normal(centro) * alcance


func _atualizar_tiro(delta:float) -> void:
	tempo_tiro = maxf(tempo_tiro - delta, -INTERVALO_TIRO)
	if not armas_prontas or not controle_liberado or exit_started or death_in_progress:
		return
	if not Input.is_action_pressed("tiro"):
		return
	while tempo_tiro <= 0.0:
		tempo_tiro += INTERVALO_TIRO
		_disparar()


func _disparar() -> void:
	if metralhadoras.is_empty():
		return
	lado_do_tiro = (lado_do_tiro + 1) % metralhadoras.size()
	var arma:Node3D = metralhadoras[lado_do_tiro]
	var boca:Vector3 = arma.global_position + arma.global_transform.basis.z * -1.6
	var direcao:Vector3 = (ponto_mira - boca).normalized()

	var tracante := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.45, 0.45, 10.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.58, 0.12)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.42, 0.06)
	mat.emission_energy_multiplier = 6.0
	mesh.material = mat
	tracante.mesh = mesh
	projeteis.add_child(tracante)
	tracante.global_position = boca
	tracante.look_at(boca + direcao, Vector3.UP)
	balas.append({"no": tracante, "dir": direcao, "vida": VIDA_BALA})

	_clarao_da_boca(boca)
	som_tiro.pitch_scale = randf_range(1.35, 1.65)
	som_tiro.play()


func _clarao_da_boca(posicao:Vector3) -> void:
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.85, 0.4)
	luz.light_energy = 4.0
	luz.omni_range = 6.0
	efeitos.add_child(luz)
	luz.global_position = posicao
	var tw := create_tween().bind_node(luz)
	tw.tween_property(luz, "light_energy", 0.0, 0.08)
	tw.tween_callback(luz.queue_free)


func _atualizar_balas(delta:float) -> void:
	var restantes:Array[Dictionary] = []
	for bala in balas:
		var no:MeshInstance3D = bala["no"]
		if not is_instance_valid(no):
			continue
		var anterior := no.global_position
		no.global_position = anterior + Vector3(bala["dir"]) * VELOCIDADE_BALA * delta
		bala["vida"] = float(bala["vida"]) - delta
		if is_instance_valid(lips) and not lips.abatido and _segmento_acerta(anterior, no.global_position, lips.global_position, RAIO_BALA_LIPS):
			lips.receber_dano(DANO_BALA, no.global_position)
			no.queue_free()
			continue
		if float(bala["vida"]) <= 0.0:
			no.queue_free()
			continue
		restantes.append(bala)
	balas = restantes


func _segmento_acerta(inicio:Vector3, fim:Vector3, centro:Vector3, raio:float) -> bool:
	var direcao := fim - inicio
	var comprimento := direcao.length()
	if comprimento < 0.0001:
		return inicio.distance_to(centro) <= raio
	var t := clampf((centro - inicio).dot(direcao) / (comprimento * comprimento), 0.0, 1.0)
	return (inicio + direcao * t).distance_to(centro) <= raio


# ---------------------------------------------------------------- lanches

func _atualizar_ataques_do_lips(delta:float) -> void:
	if not is_instance_valid(lips) or lips.abatido or lips.investindo or not controle_liberado:
		return
	if float(lips.position.z) < float(lips.z_base) - 60.0:
		return
	tempo_ataque -= delta
	if tempo_ataque <= 0.0:
		var raiva:float = 1.0 - float(lips.vida) / float(lips.vida_maxima)
		tempo_ataque = randf_range(0.65, 1.25) - raiva * 0.35
		_lancar_lanche()


func _lancar_lanche() -> void:
	# O Lips cospe a coxinha do Xuruzika e também vários outros lanches gigantes
	var lanche:Node3D
	var billboard := randf() < 0.25
	if billboard:
		var sprite := Sprite3D.new()
		sprite.name = "CoxinhaGigante"
		sprite.texture = LANCHE_TEXTURE
		sprite.pixel_size = 0.03
		sprite.shaded = false
		sprite.double_sided = true
		sprite.transparent = true
		lanche = sprite
	else:
		lanche = AviaoModelo.criar_lanche(TAMANHO_LANCHE)
	lanches_no.add_child(lanche)
	lanche.global_position = lips.boca_global()
	var mira_lanche := aviao.global_position + Vector3(randf_range(-5.5, 5.5), randf_range(-3.5, 3.5), 0.0)
	var direcao := (mira_lanche - lanche.global_position).normalized()
	lanches.append({
		"no": lanche,
		"dir": direcao,
		"giro": randf_range(-2.6, 2.6),
		"billboard": billboard,
		"giro3d": Vector3(randf_range(-2.4, 2.4), randf_range(-2.4, 2.4), randf_range(-2.4, 2.4))
	})
	lips.gritar()


func _atualizar_lanches(delta:float) -> void:
	var restantes:Array[Dictionary] = []
	for lanche in lanches:
		var no:Node3D = lanche["no"]
		if not is_instance_valid(no):
			continue
		no.global_position += Vector3(lanche["dir"]) * VELOCIDADE_LANCHE * delta
		if bool(lanche["billboard"]):
			# A coxinha é um sprite: fica sempre de frente para a câmera, girando
			no.look_at(no.global_position + (no.global_position - camera.global_position), Vector3.UP)
			no.rotate_object_local(Vector3(0.0, 0.0, 1.0), float(lanche["giro"]) * delta)
		else:
			no.rotation += Vector3(lanche["giro3d"]) * delta
		if no.global_position.distance_to(aviao.global_position) <= RAIO_LANCHE:
			_levar_lanchada(no.global_position)
			no.queue_free()
			continue
		if no.global_position.z > aviao.global_position.z + 16.0:
			no.queue_free()
			continue
		restantes.append(lanche)
	lanches = restantes


func _levar_lanchada(ponto:Vector3) -> void:
	if death_in_progress or exit_started:
		return
	tremor = maxf(tremor, 0.85)
	blood_overlay.call("flash")
	som_impacto.pitch_scale = randf_range(0.85, 1.05)
	som_impacto.play()
	som_dano.pitch_scale = randf_range(0.9, 1.1)
	som_dano.play()
	var sangue := BLOOD_SCENE.instantiate()
	sangue.scale = Vector3.ONE * 2.6
	efeitos.add_child(sangue)
	sangue.global_position = ponto
	get_tree().create_timer(2.2).timeout.connect(func():
		if is_instance_valid(sangue):
			sangue.queue_free())
	_ajustar_vida(vida - DANO_LANCHE)


func _ajustar_vida(nova:float) -> void:
	vida = clampf(nova, 0.0, vida_maxima)
	if is_instance_valid(hp_bar):
		hp_bar.value = vida
	if Global.battle_mode == Global.battle_mode_realtime:
		Global.realtime_hp = vida
	if vida <= 0.0:
		_derrota()


# ---------------------------------------------------------------- boss

func _ao_mudar_vida_do_lips(atual:float, _maxima:float) -> void:
	if is_instance_valid(boss_bar):
		boss_bar.max_value = _maxima
		boss_bar.value = atual


func _ao_derrotar_lips() -> void:
	if exit_started:
		return
	exit_started = true
	controle_liberado = false
	lips.investindo = true
	lips.mergulhar()
	_investida_final()


func _investida_final() -> void:
	# O Lips vem em direção ao avião e explode tudo junto
	var musica_tw := create_tween().bind_node(musica)
	musica_tw.tween_property(musica, "volume_db", -30.0, 2.4)
	var partida:Vector3 = lips.global_position
	var investida := create_tween().bind_node(lips)
	investida.tween_method(func(p:float):
		if not is_instance_valid(lips):
			return
		lips.global_position = partida.lerp(aviao.global_position, p)
		lips.rotation.z += 0.06
		tremor = maxf(tremor, 0.2 + p * 0.9)
		if randf() < 0.4:
			var sangue := BLOOD_SCENE.instantiate()
			sangue.scale = Vector3.ONE * randf_range(5.0, 9.0)
			efeitos.add_child(sangue)
			sangue.global_position = lips.global_position + Vector3(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0), 0.0)
			get_tree().create_timer(2.0).timeout.connect(func():
				if is_instance_valid(sangue):
					sangue.queue_free())
	, 0.0, 1.0, 2.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await investida.finished
	_explodir_tudo()


func _explodir_tudo() -> void:
	som_explosao.play()
	tremor = 2.2
	_bola_de_fogo(aviao.global_position, 46.0)
	for i in range(5):
		_bola_de_fogo(aviao.global_position + Vector3(randf_range(-16.0, 16.0), randf_range(-12.0, 12.0), randf_range(-18.0, 6.0)), randf_range(14.0, 26.0))
	_clarao_branco()
	for i in range(14):
		var sangue := BLOOD_SCENE.instantiate()
		sangue.scale = Vector3.ONE * randf_range(3.0, 8.0)
		efeitos.add_child(sangue)
		sangue.global_position = aviao.global_position + Vector3(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0), randf_range(-16.0, 4.0))
		get_tree().create_timer(2.5).timeout.connect(func():
			if is_instance_valid(sangue):
				sangue.queue_free())
	await get_tree().create_timer(0.55).timeout
	if is_instance_valid(lips):
		lips.queue_free()
	aviao.visible = false
	desfecho_em_andamento = true
	if is_instance_valid(hud_canvas):
		hud_canvas.visible = false
	if is_instance_valid(linhas_vento):
		linhas_vento.visible = false
	for bala in balas:
		if is_instance_valid(bala["no"]):
			bala["no"].queue_free()
	balas.clear()
	for lanche in lanches:
		if is_instance_valid(lanche["no"]):
			lanche["no"].queue_free()
	lanches.clear()
	_queda_no_infinito()


func _bola_de_fogo(posicao:Vector3, tamanho:float) -> void:
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.72, 0.22, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.12)
	mat.emission_energy_multiplier = 4.0
	esfera.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = esfera
	mi.scale = Vector3.ONE * 0.5
	efeitos.add_child(mi)
	mi.global_position = posicao
	var tw := create_tween().bind_node(mi).set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * tamanho, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.9)
	tw.chain().tween_callback(mi.queue_free)


func _clarao_branco() -> void:
	fade_rect.color = Color.WHITE
	fade_rect.modulate.a = 1.0
	var tw := create_tween().bind_node(fade_rect)
	tw.tween_property(fade_rect, "modulate:a", 0.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _queda_no_infinito() -> void:
	# Maycon volta a cair no infinito antes de aterrissar no mundo 2D
	var maycon := Node3D.new()
	maycon.name = "MayconCaindo"
	add_child(maycon)
	var visual := AviaoModelo.criar_maycon()
	maycon.add_child(visual)
	var animation_player := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player and animation_player.has_animation("Air_Flail"):
		animation_player.play("Air_Flail")
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.95, 0.88)
	luz.light_energy = 3.2
	luz.omni_range = 14.0
	luz.position = Vector3(1.5, 2.5, 3.0)
	maycon.add_child(luz)
	maycon.global_position = Vector3(0.0, 8.0, -6.0)
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	tremor = 0.0
	# Grito em câmera lenta cobrindo a queda inteira (o mp3 está em loop)
	som_grito.volume_db = 0.0
	som_grito.pitch_scale = 0.5
	som_grito.play()
	var grito_out := create_tween().bind_node(som_grito)
	grito_out.tween_interval(3.9)
	grito_out.tween_property(som_grito, "volume_db", -40.0, 1.3)
	grito_out.tween_callback(som_grito.stop)
	var escurecer := create_tween().bind_node(self)
	escurecer.tween_method(func(p:float):
		if ambiente:
			ambiente.background_color = AviaoModelo.SKY_COLOR.lerp(Color(0.02, 0.02, 0.05), p)
			ambiente.fog_light_color = AviaoModelo.SKY_FOG_COLOR.lerp(Color(0.05, 0.04, 0.08), p)
			ambiente.ambient_light_energy = lerpf(0.72, 0.0, p)
		# O Maycon apaga junto com o céu, senão fica iluminado sobre o breu
		if is_instance_valid(luz):
			luz.light_energy = lerpf(3.2, 0.0, p)
		if is_instance_valid(sol):
			sol.light_energy = lerpf(1.2, 0.0, p)
	, 0.0, 1.0, 3.4)
	var queda := create_tween().bind_node(maycon)
	queda.tween_method(func(p:float):
		if not is_instance_valid(maycon):
			return
		maycon.position = Vector3(sin(p * 4.0) * 1.2, 8.0 - p * 60.0, -6.0)
		maycon.rotation = Vector3(deg_to_rad(-30.0) + p * 3.0, PI + p * 5.0, p * 2.0)
		camera.position = maycon.position + Vector3(0.0, 5.0, 7.0)
		camera.look_at(maycon.position, Vector3.UP)
	, 0.0, 1.0, 3.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(2.6).timeout
	_voltar_para_o_2d()


func _voltar_para_o_2d() -> void:
	fade_rect.color = Color.BLACK
	var fade_out := create_tween().bind_node(fade_rect)
	fade_out.tween_property(fade_rect, "modulate:a", 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_out.finished
	if Global.battle_mode == Global.battle_mode_realtime:
		Global.realtime_hp = maxf(vida, 1.0)
	Global.platform_arrival_pending = true
	Global.save_progress("fase_4")
	GameSongs.play_song(1)
	get_tree().change_scene_to_file.call_deferred(PROXIMA_CENA)


# ---------------------------------------------------------------- derrota

func _derrota() -> void:
	if death_in_progress or exit_started:
		return
	death_in_progress = true
	controle_liberado = false
	som_grito.volume_db = 0.0
	som_grito.play()
	var grito_morte := create_tween().bind_node(som_grito)
	grito_morte.tween_interval(1.1)
	grito_morte.tween_property(som_grito, "volume_db", -40.0, 1.2)
	grito_morte.tween_callback(som_grito.stop)
	som_explosao.play()
	tremor = 1.6
	blood_overlay.call("flash")
	fade_rect.color = Color(0.35, 0.0, 0.03)
	var fade_out := create_tween().bind_node(fade_rect)
	fade_out.tween_interval(0.9)
	fade_out.tween_property(fade_rect, "modulate:a", 1.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fade_out.finished
	if Global.battle_mode == Global.battle_mode_realtime:
		Global.realtime_hp = Global.realtime_hp_max
	get_tree().reload_current_scene.call_deferred()


func exit_to_menu() -> void:
	if exit_started:
		return
	exit_started = true
	controle_liberado = false
	get_tree().paused = false
	musica.stop()
	fade_rect.color = Color.BLACK
	var fade_out := create_tween().bind_node(fade_rect)
	fade_out.tween_property(fade_rect, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await fade_out.finished
	Global.back_to_main_camera = true
	Global.save_progress("fase_aviao")
	get_tree().change_scene_to_file.call_deferred("res://scenes/menu.tscn")


# ---------------------------------------------------------------- avisos

func _mostrar_aviso(texto:String) -> void:
	if not is_instance_valid(aviso_label):
		return
	aviso_label.text = texto
	if aviso_tween and aviso_tween.is_valid():
		aviso_tween.kill()
	var tw := create_tween().bind_node(aviso_label)
	aviso_tween = tw
	tw.tween_property(aviso_label, "modulate:a", 1.0, 0.4)
	tw.tween_interval(2.2)
	tw.tween_property(aviso_label, "modulate:a", 0.0, 0.6)
