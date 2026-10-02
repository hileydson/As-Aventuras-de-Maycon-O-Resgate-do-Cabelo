extends RigidBody3D

# Jaula de metal com o cabelo dentro, parada no meio da arena. Ela é feita de
# barras normais, mas pesa quase nada: qualquer encostão joga ela quicando para
# os lados. O cabelo fica no centro, sempre de frente para a câmera.

const BARRA_LARGURA := 0.1
const LADO := 2.2
const ALTURA := 2.6
# Força de cada encostão e o tempo mínimo entre dois empurrões do mesmo encostador.
const EMPURRAO := 7.5
const ESPERA := 0.25
# Meia largura e meio comprimento do chão da arena, para ela não sair voando dele.
const LIMITE_X := 17.0
const LIMITE_Z := 15.0

var stage:Node3D
var centro:Vector3
var esperas:Dictionary = {}
var hair:AnimatedSprite3D

func _ready() -> void:
	stage = get_tree().get_first_node_in_group("resgate_stage")
	centro = global_position
	mass = 0.7
	gravity_scale = 1.0
	continuous_cd = true
	can_sleep = false
	# Metal leve e saltitante: quica em vez de parar morta no chão.
	var atrito := PhysicsMaterial.new()
	atrito.friction = 0.12
	atrito.bounce = 0.72
	physics_material_override = atrito
	build_bars()
	var forma := CollisionShape3D.new()
	forma.name = "Forma"
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(LADO, ALTURA, LADO)
	forma.shape = caixa
	add_child(forma)

func metal() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8f98a3")
	mat.metallic = 0.92
	mat.metallic_specular = 0.7
	mat.roughness = 0.34
	return mat

func barra(tamanho:Vector3, em:Vector3, mat:StandardMaterial3D) -> void:
	var peca := MeshInstance3D.new()
	var malha := BoxMesh.new()
	malha.size = tamanho
	peca.mesh = malha
	peca.material_override = mat
	peca.position = em
	add_child(peca)

func build_bars() -> void:
	var mat := metal()
	var meio := LADO * 0.5
	var topo := ALTURA * 0.5
	# Quatro pés nos cantos.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			barra(Vector3(BARRA_LARGURA, ALTURA, BARRA_LARGURA), Vector3(sx * meio, 0.0, sz * meio), mat)
	# Grades dos quatro lados, com folga para o cabelo aparecer entre elas.
	var vaos := 5
	for i in vaos:
		var t:float = -meio + LADO * (float(i) + 1.0) / float(vaos + 1)
		barra(Vector3(BARRA_LARGURA, ALTURA, BARRA_LARGURA), Vector3(t, 0.0, -meio), mat)
		barra(Vector3(BARRA_LARGURA, ALTURA, BARRA_LARGURA), Vector3(t, 0.0, meio), mat)
		barra(Vector3(BARRA_LARGURA, ALTURA, BARRA_LARGURA), Vector3(-meio, 0.0, t), mat)
		barra(Vector3(BARRA_LARGURA, ALTURA, BARRA_LARGURA), Vector3(meio, 0.0, t), mat)
	# Aros de cima, do meio e de baixo amarrando a gaiola.
	for altura in [-topo, 0.0, topo]:
		barra(Vector3(LADO + BARRA_LARGURA, BARRA_LARGURA, BARRA_LARGURA), Vector3(0.0, altura, -meio), mat)
		barra(Vector3(LADO + BARRA_LARGURA, BARRA_LARGURA, BARRA_LARGURA), Vector3(0.0, altura, meio), mat)
		barra(Vector3(BARRA_LARGURA, BARRA_LARGURA, LADO + BARRA_LARGURA), Vector3(-meio, altura, 0.0), mat)
		barra(Vector3(BARRA_LARGURA, BARRA_LARGURA, LADO + BARRA_LARGURA), Vector3(meio, altura, 0.0), mat)
	# Tampa e piso em grade, para o cabelo não escapar por cima nem por baixo.
	for altura in [-topo, topo]:
		for i in vaos:
			var t:float = -meio + LADO * (float(i) + 1.0) / float(vaos + 1)
			barra(Vector3(LADO, BARRA_LARGURA, BARRA_LARGURA), Vector3(0.0, altura, t), mat)

# O cabelo entra na jaula sem perder o billboard: ele segue de frente para a
# câmera mesmo com a jaula girando.
func guardar(cabelo:AnimatedSprite3D) -> void:
	hair = cabelo
	if not is_instance_valid(cabelo):
		return
	if cabelo.get_parent() != null:
		cabelo.get_parent().remove_child(cabelo)
	add_child(cabelo)
	cabelo.position = Vector3.ZERO
	cabelo.rotation = Vector3.ZERO
	cabelo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cabelo.shaded = false
	cabelo.double_sided = true
	cabelo.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	cabelo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

# Empurrão de quem encostou, sempre de lado: a jaula sai quicando na horizontal.
func esbarrar(quem:Node3D, forca:float) -> void:
	var chave:int = quem.get_instance_id()
	if freeze or float(esperas.get(chave, 0.0)) > 0.0:
		return
	if is_instance_valid(stage) and stage.finishing:
		return
	esperas[chave] = ESPERA
	var fora := global_position - quem.global_position
	fora.y = 0.0
	if fora.length_squared() < 0.01:
		fora = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	fora = fora.normalized()
	apply_central_impulse(fora * forca * mass + Vector3.UP * forca * 0.35 * mass)
	apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * forca * 0.08)
	if is_instance_valid(stage):
		stage.sound("wood")

func _physics_process(delta:float) -> void:
	for chave in esperas.keys():
		esperas[chave] = maxf(0.0, float(esperas[chave]) - delta)
	if not is_instance_valid(stage):
		return
	# Qualquer um que encostar faz ela quicar: o Maycon e o Lips.
	for quem in [stage.player, stage.boss]:
		if not is_instance_valid(quem):
			continue
		var perto:Node3D = quem as Node3D
		var diff:Vector3 = global_position - perto.global_position
		if Vector2(diff.x, diff.z).length() < LADO * 0.5 + 1.0 and absf(diff.y) < ALTURA:
			esbarrar(perto, EMPURRAO)
	# Ela nunca sai do chão da arena: a borda devolve o quique para dentro.
	var preso := global_position
	preso.x = clampf(preso.x, centro.x - LIMITE_X, centro.x + LIMITE_X)
	preso.z = clampf(preso.z, centro.z - LIMITE_Z, centro.z + LIMITE_Z)
	if not preso.is_equal_approx(global_position):
		global_position = preso
		linear_velocity.x = -linear_velocity.x * 0.6
		linear_velocity.z = -linear_velocity.z * 0.6
