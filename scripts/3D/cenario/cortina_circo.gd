@tool
extends Node3D

@export var largura_total: float = 3.0:
	set(v):
		largura_total = v
		_atualizar_malhas()
@export var altura: float = 3.6:
	set(v):
		altura = v
		_atualizar_malhas()
@export var numero_pregas: int = 8:
	set(v):
		numero_pregas = max(2, v)
		_atualizar_malhas()
@export var profundidade_prega: float = 0.16:
	set(v):
		profundidade_prega = v
		_atualizar_malhas()
@export var cor_a: Color = Color(0.5, 0.03, 0.05):
	set(v):
		cor_a = v
		_atualizar_malhas()
@export var cor_b: Color = Color(0.62, 0.47, 0.1):
	set(v):
		cor_b = v
		_atualizar_malhas()

@export var distancia_abertura: float = 1.6
@export var tempo_abertura: float = 2.5

# Distância real (em metros do mundo) na frente do palhaço, independente da
# escala que o pai (palhaco_N) tiver — se alguém reescalar o palhaço depois,
# a cortina se reajusta sozinha em vez de ficar torta/deslocada.
@export var distancia_frente_mundo: float = 1.8

@onready var painel_esquerdo: MeshInstance3D = $PainelEsquerdo
@onready var painel_direito: MeshInstance3D = $PainelDireito
@onready var area_gatilho: Area3D = $AreaGatilho

var ja_abriu: bool = false
var x_fechado_esquerdo: float
var x_fechado_direito: float

func _ready() -> void:
	_ajustar_para_escala_do_pai()
	_atualizar_malhas()

	if Engine.is_editor_hint():
		return

	x_fechado_esquerdo = painel_esquerdo.position.x
	x_fechado_direito = painel_direito.position.x
	area_gatilho.body_entered.connect(_on_body_entered)

func _ajustar_para_escala_do_pai() -> void:
	var pai := get_parent()
	if not (pai is Node3D):
		return
	var escala_pai: float = (pai as Node3D).scale.x
	if is_zero_approx(escala_pai):
		return
	scale = Vector3.ONE / escala_pai
	position.z = -distancia_frente_mundo / escala_pai

func _atualizar_malhas() -> void:
	if not is_inside_tree():
		return
	if not (painel_esquerdo and painel_direito):
		return
	painel_esquerdo.mesh = _gerar_malha_painel(-1)
	painel_esquerdo.material_override = _gerar_material()
	painel_direito.mesh = _gerar_malha_painel(1)
	painel_direito.material_override = _gerar_material()

func _gerar_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.85
	return mat

func _gerar_malha_painel(lado: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var largura_meio := largura_total * 0.5
	var colunas := numero_pregas + 1
	var passo := largura_meio / float(numero_pregas)

	var pontos: Array = []
	for i in range(colunas):
		var x := float(lado) * i * passo
		var z := profundidade_prega if i % 2 == 0 else -profundidade_prega
		pontos.append(Vector2(x, z))

	for i in range(colunas - 1):
		var p0: Vector2 = pontos[i]
		var p1: Vector2 = pontos[i + 1]
		var cor0 := cor_a if i % 2 == 0 else cor_b
		var cor1 := cor_a if (i + 1) % 2 == 0 else cor_b

		var v0 := Vector3(p0.x, 0.0, p0.y)
		var v1 := Vector3(p1.x, 0.0, p1.y)
		var v2 := Vector3(p1.x, altura, p1.y)
		var v3 := Vector3(p0.x, altura, p0.y)

		var normal := (v1 - v0).cross(v3 - v0).normalized()

		st.set_normal(normal); st.set_color(cor0); st.add_vertex(v0)
		st.set_normal(normal); st.set_color(cor1); st.add_vertex(v1)
		st.set_normal(normal); st.set_color(cor1); st.add_vertex(v2)

		st.set_normal(normal); st.set_color(cor0); st.add_vertex(v0)
		st.set_normal(normal); st.set_color(cor1); st.add_vertex(v2)
		st.set_normal(normal); st.set_color(cor0); st.add_vertex(v3)

	return st.commit()

func _on_body_entered(body: Node) -> void:
	if ja_abriu:
		return
	if not (body.is_in_group("player") or body is DungeonPlayer):
		return

	ja_abriu = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(painel_esquerdo, "position:x", x_fechado_esquerdo - distancia_abertura, tempo_abertura)
	tween.tween_property(painel_direito, "position:x", x_fechado_direito + distancia_abertura, tempo_abertura)
