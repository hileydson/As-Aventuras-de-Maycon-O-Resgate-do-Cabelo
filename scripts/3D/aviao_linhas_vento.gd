extends MultiMeshInstance3D

# Linhas finas de vento passando da frente para trás (no eixo +Z local), dando a
# sensação de velocidade. Serve tanto para o combate aéreo quanto para a queda do
# Maycon e para o ar entrando pelo buraco do avião: basta girar o nó e ajustar os
# valores abaixo antes de adicioná-lo à cena.

@export var quantidade:int = 150
@export var alcance_z:float = 300.0
@export var raio_min:float = 5.5
@export var raio_max:float = 52.0
@export var achatamento:float = 0.7
@export var velocidade:float = 240.0
@export var z_limite:float = 26.0
@export var espessura:float = 0.07
@export var comprimento_min:float = 6.0
@export var comprimento_max:float = 18.0
@export var alpha_min:float = 0.18
@export var alpha_max:float = 0.5
@export var cor:Color = Color(1.0, 1.0, 1.0)

# Multiplicador externo de tempo, usado pela cutscene em câmera lenta
var escala_tempo:float = 1.0

var posicoes:Array[Vector3] = []
var comprimentos:Array[float] = []


func _ready() -> void:
	var risco := BoxMesh.new()
	risco.size = Vector3(espessura, espessura, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = cor
	risco.material = mat

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = risco
	multimesh.instance_count = quantidade
	posicoes.resize(quantidade)
	comprimentos.resize(quantidade)
	for i in range(quantidade):
		_sortear(i, randf_range(-alcance_z, z_limite))
		multimesh.set_instance_color(i, Color(cor.r, cor.g, cor.b, randf_range(alpha_min, alpha_max)))
	_aplicar()


func _process(delta:float) -> void:
	var passo := velocidade * delta * escala_tempo
	for i in range(quantidade):
		var p:Vector3 = posicoes[i]
		p.z += passo
		if p.z > z_limite:
			_sortear(i, -alcance_z)
		else:
			posicoes[i] = p
	_aplicar()


func _sortear(indice:int, z:float) -> void:
	var angulo := randf() * TAU
	var raio := sqrt(randf()) * (raio_max - raio_min) + raio_min
	posicoes[indice] = Vector3(cos(angulo) * raio, sin(angulo) * raio * achatamento, z)
	comprimentos[indice] = randf_range(comprimento_min, comprimento_max)


func _aplicar() -> void:
	for i in range(quantidade):
		var base := Basis.IDENTITY.scaled(Vector3(1.0, 1.0, comprimentos[i]))
		multimesh.set_instance_transform(i, Transform3D(base, posicoes[i]))
