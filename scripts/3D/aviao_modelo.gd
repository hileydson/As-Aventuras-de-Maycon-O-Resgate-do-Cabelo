class_name AviaoModelo

# Utilitários compartilhados pelas três cenas do avião (queda, interior e combate aéreo).
# O avião vem do pacote ace_combat em OBJ exportado do 3ds Max (eixo Z para cima e
# nariz no +Y), por isso precisa girar -90° em X e ser reduzido para a escala do jogo.
# A gatling do mesmo pacote vem com vários acessórios no mesmo arquivo; aqui só o
# cano da metralhadora é aproveitado, como pedido para as asas.

const PLANE_MESH = preload("res://assets/modelo_3d/ace_combat/airplane_v2_L2.123c71795678-4b63-46c4-b2c6-549c45f4c806/11805_airplane_v2_L2.obj")
const GUN_SCENE = preload("res://assets/modelo_3d/ace_combat/ScrapGatlingGun.gltf")
const MAYCON_MODEL = preload("res://assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations.glb")
const MAYCON_AIR_FLAIL = preload("res://assets/novas_imagens/3d_enemies/maycon_air_flail.res")

const PLANE_SCALE = 0.02
# Centraliza a fuselagem na origem do nó (eixo do tubo fica em z=183 no OBJ original)
const PLANE_BODY_OFFSET_Y = -3.66
# Medidas já convertidas para o espaço do Godot, usadas para posicionar armas e câmeras
const PLANE_LENGTH = 30.0
const PLANE_WINGSPAN = 31.6
const WING_GUN_LOCAL = Vector3(9.2, -3.05, 3.2)

# A gatling sai do glTF apontando para (0.958, 0, -0.286); este yaw alinha o cano ao -Z
const GUN_FORWARD_YAW_DEG = 73.383
const GUN_KEEP_PREFIXES = ["Gun_", "Motor", "DriveShaft"]

# Céu azul idêntico ao da fase do Super Maycon Brother
const SKY_COLOR = Color(0.5686275, 0.78431374, 0.90588236, 1.0)
const SKY_AMBIENT_COLOR = Color(0.8784314, 0.9019608, 0.9372549, 1.0)
const SKY_FOG_COLOR = Color(0.65882355, 0.8156863, 0.9019608, 1.0)


static func criar_aviao(nome:String = "Aviao") -> Node3D:
	var root := Node3D.new()
	root.name = nome
	var body := MeshInstance3D.new()
	body.name = "Fuselagem"
	body.mesh = PLANE_MESH
	body.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)
	body.scale = Vector3.ONE * PLANE_SCALE
	body.position.y = PLANE_BODY_OFFSET_Y
	root.add_child(body)
	return root


static func criar_metralhadora(comprimento_alvo:float = 2.4) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Metralhadora"
	var imported:Node = GUN_SCENE.instantiate()
	var gun_root := imported.find_child("RotationHelper", true, false) as Node3D
	if gun_root:
		gun_root.get_parent().remove_child(gun_root)
		imported.free()
	else:
		gun_root = imported as Node3D
	gun_root.name = "Cano"
	gun_root.transform = Transform3D.IDENTITY
	for child in gun_root.get_children():
		if not _e_peca_da_metralhadora(String(child.name)):
			gun_root.remove_child(child)
			child.free()

	var pivot := Node3D.new()
	pivot.name = "Pivot"
	pivot.rotation.y = deg_to_rad(GUN_FORWARD_YAW_DEG)
	pivot.add_child(gun_root)

	# A caixa real das peças restantes define a escala e o centro da arma.
	# A escala fica num nó interno para o holder continuar livre para animações.
	var caixa:AABB = Transform3D(Basis(Vector3.UP, pivot.rotation.y), Vector3.ZERO) * _aabb_local(gun_root)
	var fator := 1.0
	if caixa.size.z > 0.001:
		fator = comprimento_alvo / caixa.size.z
	pivot.position = -caixa.get_center()
	var escala := Node3D.new()
	escala.name = "Escala"
	escala.scale = Vector3.ONE * fator
	escala.add_child(pivot)
	holder.add_child(escala)
	return holder


# Maycon já com os materiais corrigidos e a animação de queda disponível,
# igual ao que a fase do Super Maycon Brother faz
static func criar_maycon(nome:String = "Visual") -> Node3D:
	var visual:Node3D = MAYCON_MODEL.instantiate()
	visual.name = nome
	ajustar_materiais_maycon(visual)
	var animation_player := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player and MAYCON_AIR_FLAIL:
		var lib:AnimationLibrary = animation_player.get_animation_library("")
		if lib and not lib.has_animation("Air_Flail"):
			lib.add_animation("Air_Flail", MAYCON_AIR_FLAIL)
	return visual


static func ajustar_materiais_maycon(root:Node) -> void:
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		if not mi:
			continue
		if mi.material_override is BaseMaterial3D:
			var mat = mi.material_override.duplicate() as BaseMaterial3D
			mat.metallic = 0.0
			mat.roughness = 0.85
			mat.metallic_specular = 0.25
			mat.emission_enabled = false
			mi.material_override = mat
		if mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				var mat = mi.get_surface_override_material(s)
				if not mat:
					mat = mi.mesh.surface_get_material(s)
				if mat is BaseMaterial3D:
					var dup = mat.duplicate() as BaseMaterial3D
					dup.metallic = 0.0
					dup.roughness = 0.85
					dup.metallic_specular = 0.25
					dup.emission_enabled = false
					mi.set_surface_override_material(s, dup)


static func criar_ambiente_ceu(densidade_neblina:float = 0.004) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = SKY_AMBIENT_COLOR
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = densidade_neblina > 0.0
	env.fog_light_color = SKY_FOG_COLOR
	env.fog_density = densidade_neblina
	return env


static func criar_sol(nome:String = "Sol") -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = nome
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(38.0), 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = true
	return sun


static func _e_peca_da_metralhadora(nome:String) -> bool:
	for prefixo:String in GUN_KEEP_PREFIXES:
		if nome.begins_with(prefixo):
			return true
	return false


# AABB combinada das malhas de uma árvore que ainda não está na cena
static func _aabb_local(root:Node3D) -> AABB:
	var total := AABB()
	var primeiro := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi or not mi.mesh:
			continue
		var caixa:AABB = _transform_relativo(mi, root) * mi.mesh.get_aabb()
		if primeiro:
			total = caixa
			primeiro = false
		else:
			total = total.merge(caixa)
	return total


static func _transform_relativo(node:Node3D, root:Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var atual:Node3D = node
	while atual != null and atual != root:
		t = atual.transform * t
		atual = atual.get_parent() as Node3D
	return t
