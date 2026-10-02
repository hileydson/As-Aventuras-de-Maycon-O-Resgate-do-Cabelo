extends Node

# Mesma poeira da queda dentro do avião (scripts/3D/aviao_interior.gd): grão quente
# que nasce fraco, engrossa e se desfaz. Aqui ela sai do Maycon no trampolim e
# espalha pelo chão no pouso.

static func textura() -> GradientTexture2D:
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1.0, 1.0, 1.0, 0.8))
	degrade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var imagem := GradientTexture2D.new()
	imagem.gradient = degrade
	imagem.fill = GradientTexture2D.FILL_RADIAL
	imagem.fill_from = Vector2(0.5, 0.5)
	imagem.fill_to = Vector2(1.0, 0.5)
	imagem.width = 64
	imagem.height = 64
	return imagem


static func curva() -> CurveTexture:
	var linha := Curve.new()
	linha.add_point(Vector2(0.0, 0.0))
	linha.add_point(Vector2(0.18, 1.0))
	linha.add_point(Vector2(1.0, 0.0))
	var imagem := CurveTexture.new()
	imagem.curve = linha
	return imagem


static func nuvem() -> QuadMesh:
	var forma := QuadMesh.new()
	forma.size = Vector2(1.1, 1.1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.albedo_texture = textura()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	forma.material = mat
	return forma


static func processo(extensao:Vector3, subida:float, minima:float, maxima:float) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = extensao
	mat.direction = Vector3(0.0, subida, 0.0)
	mat.spread = 90.0
	mat.initial_velocity_min = minima
	mat.initial_velocity_max = maxima
	mat.gravity = Vector3(0.0, 0.25, 0.0)
	mat.damping_min = 1.4
	mat.damping_max = 3.2
	mat.scale_min = 0.4
	mat.scale_max = 1.7
	mat.angle_min = -180.0
	mat.angle_max = 180.0
	mat.angular_velocity_min = -35.0
	mat.angular_velocity_max = 35.0
	mat.color = Color(0.78, 0.6, 0.33, 0.42)
	mat.alpha_curve = curva()
	return mat


# Baforada de uma vez, que se apaga sozinha quando termina
static func estouro(parent:Node3D, at:Vector3, quantidade:int, extensao:Vector3, subida:float, minima:float, maxima:float) -> void:
	if not is_instance_valid(parent):
		return
	var fx := GPUParticles3D.new()
	fx.name = "PoeiraDoImpacto"
	fx.amount = quantidade
	fx.lifetime = 3.2
	fx.one_shot = true
	fx.explosiveness = 0.92
	fx.local_coords = false
	fx.process_material = processo(extensao, subida, minima, maxima)
	fx.draw_pass_1 = nuvem()
	fx.visibility_aabb = AABB(Vector3(-24.0, -4.0, -24.0), Vector3(48.0, 18.0, 48.0))
	parent.add_child(fx)
	fx.global_position = at
	fx.emitting = true
	var limpar := parent.create_tween().bind_node(fx)
	limpar.tween_interval(fx.lifetime + 1.0)
	limpar.tween_callback(fx.queue_free)


# Chão coberto de poeira para todo lado no pouso
static func pousar(parent:Node3D, at:Vector3) -> void:
	estouro(parent, at, 220, Vector3(2.6, 0.2, 2.6), 0.35, 5.0, 14.0)


# Baforada curta do trampolim, logo abaixo de quem saltou
static func impulsionar(parent:Node3D, at:Vector3) -> void:
	estouro(parent, at, 170, Vector3(1.6, 0.3, 1.6), 0.7, 4.0, 11.0)


# Poeira de cada pulo comum, saindo dos pés
static func saltar(parent:Node3D, at:Vector3) -> void:
	estouro(parent, at, 90, Vector3(0.7, 0.15, 0.7), 0.5, 2.6, 7.0)


# Poeira de cada aterrissagem comum
static func aterrar(parent:Node3D, at:Vector3) -> void:
	estouro(parent, at, 130, Vector3(1.4, 0.15, 1.4), 0.3, 3.4, 9.0)


# Rastro contínuo preso em quem está voando; some pouco depois de ser desligado
static func rastro(alvo:Node3D) -> GPUParticles3D:
	if not is_instance_valid(alvo):
		return null
	var fx := GPUParticles3D.new()
	fx.name = "PoeiraDoSalto"
	fx.amount = 150
	fx.lifetime = 2.4
	fx.local_coords = false
	fx.process_material = processo(Vector3(0.5, 0.5, 0.5), 0.2, 1.4, 5.0)
	fx.draw_pass_1 = nuvem()
	fx.visibility_aabb = AABB(Vector3(-30.0, -40.0, -30.0), Vector3(60.0, 80.0, 60.0))
	fx.position = Vector3(0.0, 0.45, 0.0)
	alvo.add_child(fx)
	fx.emitting = true
	return fx


static func apagar(fx:GPUParticles3D) -> void:
	if not is_instance_valid(fx):
		return
	fx.emitting = false
	var limpar := fx.create_tween().bind_node(fx)
	limpar.tween_interval(fx.lifetime + 0.5)
	limpar.tween_callback(fx.queue_free)
