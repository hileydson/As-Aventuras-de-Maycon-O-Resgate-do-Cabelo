extends MultiMeshInstance3D

# Linhas finas de vento passando da frente para trás, dando a sensação de
# velocidade durante o combate aéreo.

const QUANTIDADE := 150
const ALCANCE_Z := 300.0
const RAIO_MIN := 5.5
const RAIO_MAX := 52.0
const VELOCIDADE := 240.0
const Z_LIMITE := 26.0

var posicoes:Array[Vector3] = []
var comprimentos:Array[float] = []


func _ready() -> void:
	var risco := BoxMesh.new()
	risco.size = Vector3(0.07, 0.07, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	risco.material = mat

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = risco
	multimesh.instance_count = QUANTIDADE
	posicoes.resize(QUANTIDADE)
	comprimentos.resize(QUANTIDADE)
	for i in range(QUANTIDADE):
		_sortear(i, randf_range(-ALCANCE_Z, Z_LIMITE))
		multimesh.set_instance_color(i, Color(1.0, 1.0, 1.0, randf_range(0.18, 0.5)))
	_aplicar()


func _process(delta:float) -> void:
	for i in range(QUANTIDADE):
		var p:Vector3 = posicoes[i]
		p.z += VELOCIDADE * delta
		if p.z > Z_LIMITE:
			_sortear(i, -ALCANCE_Z)
		else:
			posicoes[i] = p
	_aplicar()


func _sortear(indice:int, z:float) -> void:
	var angulo := randf() * TAU
	var raio := sqrt(randf()) * (RAIO_MAX - RAIO_MIN) + RAIO_MIN
	posicoes[indice] = Vector3(cos(angulo) * raio, sin(angulo) * raio * 0.7, z)
	comprimentos[indice] = randf_range(6.0, 18.0)


func _aplicar() -> void:
	for i in range(QUANTIDADE):
		var base := Basis.IDENTITY.scaled(Vector3(1.0, 1.0, comprimentos[i]))
		multimesh.set_instance_transform(i, Transform3D(base, posicoes[i]))
