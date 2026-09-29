extends Node3D

@export var angulo_maximo_cabeca_graus: float = 25.0
@export var velocidade_rotacao_cabeca: float = 3.0
@export var velocidade_rotacao_olhos: float = 8.0
@export var distancia_maxima_deteccao: float = 25.0

@export var numero_palhaco: int = 1
@export var som_eventual_intervalo_min: float = 8.0
@export var som_eventual_intervalo_max: float = 30.0

@export_range(0.05, 1.0, 0.01) var brilho_superficie: float = 0.34

const PASTA_AUDIOS := "res://assets/novos_audios/calabouco_terror/"

@onready var olho_esquerdo: Node3D = $"palhaco_olho/sclera cornea2"
@onready var olho_direito: Node3D = $"palhaco_olho2/sclera cornea2"

var player: Node3D = null
var rotacao_base_y: float

# Orientação (global, com escala) de cada olho exatamente como foi deixada
# no editor — com a íris virada para frente. Nunca é alterada depois:
# cada frame partimos sempre dela, então o olho nunca perde essa referência.
var basis_repouso_olho_esquerdo: Basis
var basis_repouso_olho_direito: Basis

# A malha da bolinha do olho não é centralizada na origem do nó (o centro
# geométrico real fica deslocado dentro do mesh). Girar em torno da origem
# do nó faz a bola "sair do lugar" — por isso giramos em torno do centro
# verdadeiro da esfera. Esse centro é guardado no espaço LOCAL do pai
# (palhaco_olho/palhaco_olho2), não do mundo: assim, quando a cabeça gira,
# o olho gira junto com ela (preso no mesmo lugar) em vez de ficar para
# trás grudado num ponto fixo do mundo.
var centro_local_olho: Vector3
var centro_no_pai_olho_esquerdo: Vector3
var centro_no_pai_olho_direito: Vector3

# Direção (mundo) para onde a íris aponta em repouso: a mesma direção que
# o palhaço encara ao nascer. É a partir dela que medimos o quanto o olho
# precisa girar para encarar o player.
var direcao_neutra_mundo: Vector3

# Rotação extra (só isso, sem escala) aplicada sobre a orientação de
# repouso para o olho acompanhar o player, suavizada quadro a quadro.
var quat_delta_olho_esquerdo := Quaternion.IDENTITY
var quat_delta_olho_direito := Quaternion.IDENTITY

func _ready() -> void:
	rotacao_base_y = rotation.y
	direcao_neutra_mundo = global_transform.basis.z.normalized()

	basis_repouso_olho_esquerdo = olho_esquerdo.global_transform.basis
	basis_repouso_olho_direito = olho_direito.global_transform.basis

	centro_local_olho = (olho_esquerdo as MeshInstance3D).mesh.get_aabb().get_center()
	centro_no_pai_olho_esquerdo = olho_esquerdo.transform * centro_local_olho
	centro_no_pai_olho_direito = olho_direito.transform * centro_local_olho

	_configurar_audio()
	_escurecer_para_tema_dark()

	await get_tree().physics_frame
	player = _buscar_player_mais_proximo()

func _escurecer_para_tema_dark() -> void:
	for no in find_children("*", "MeshInstance3D", true, false):
		var malha := no as MeshInstance3D
		if malha.mesh == null:
			continue
		for indice in malha.mesh.get_surface_count():
			var original := malha.get_active_material(indice) as StandardMaterial3D
			if original == null:
				continue
			var material := original.duplicate() as StandardMaterial3D
			material.albedo_color = Color(brilho_superficie, brilho_superficie, brilho_superficie, original.albedo_color.a)
			material.metallic = minf(material.metallic, 0.12)
			material.emission_enabled = false
			malha.set_surface_override_material(indice, material)

func _configurar_audio() -> void:
	var riso_stream: AudioStream = load(PASTA_AUDIOS + "palhaco_%d_riso.mp3" % numero_palhaco)
	if riso_stream:
		if riso_stream is AudioStreamMP3:
			riso_stream.loop = true
		var audio_riso := _criar_audio(riso_stream, 9.0, 40.0)
		audio_riso.play()

	var eventual_stream: AudioStream = load(PASTA_AUDIOS + "palhaco_%d_eventual.mp3" % numero_palhaco)
	if eventual_stream:
		var audio_eventual := _criar_audio(eventual_stream, 10.0, 42.0)
		_tocar_som_eventual_em_loop(audio_eventual)

# O áudio fica na raiz, e não nos nós dos olhos: a origem de palhaco_olho tem um
# deslocamento local grande em Y que, multiplicado pela escala do palhaço na cena
# (10x a 14x), cai ~100 a 140 unidades abaixo do mapa. Preso ali, o som ficava
# sempre além do max_distance e nunca era ouvido.
func _criar_audio(stream: AudioStream, volume_db: float, max_distance: float) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.volume_db = volume_db
	audio.max_distance = max_distance
	audio.unit_size = 12.0
	add_child(audio)
	return audio

func _tocar_som_eventual_em_loop(audio: AudioStreamPlayer3D) -> void:
	while is_instance_valid(audio):
		await get_tree().create_timer(randf_range(som_eventual_intervalo_min, som_eventual_intervalo_max)).timeout
		if is_instance_valid(audio):
			audio.play()

func _physics_process(delta: float) -> void:
	player = _buscar_player_mais_proximo()

	if not player:
		return

	if global_position.distance_to(player.global_position) > distancia_maxima_deteccao:
		return

	_girar_cabeca_para_player(delta)
	quat_delta_olho_esquerdo = _olho_seguir_player(olho_esquerdo, basis_repouso_olho_esquerdo, centro_no_pai_olho_esquerdo, quat_delta_olho_esquerdo, delta)
	quat_delta_olho_direito = _olho_seguir_player(olho_direito, basis_repouso_olho_direito, centro_no_pai_olho_direito, quat_delta_olho_direito, delta)

func _buscar_player_mais_proximo() -> Node3D:
	# Cenas padrão colocam o player no grupo "player" (suporte a multiplayer)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var alvo = players[0]
		var menor_distancia = global_position.distance_to(alvo.global_position)
		for p in players:
			var d = global_position.distance_to(p.global_position)
			if d < menor_distancia:
				menor_distancia = d
				alvo = p
		return alvo

	# O Calabouço Terror usa o DungeonPlayer, que não fica no grupo "player"
	var dungeon_players = get_tree().root.find_children("*", "DungeonPlayer", true, false)
	if dungeon_players.size() > 0:
		return dungeon_players[0]

	return null

func _girar_cabeca_para_player(delta: float) -> void:
	var alvo_horizontal = Vector3(player.global_position.x, global_position.y, player.global_position.z)
	if global_position.distance_to(alvo_horizontal) < 0.01:
		return

	var transform_olhando = Transform3D(Basis(), global_position).looking_at(alvo_horizontal, Vector3.UP)
	var angulo_desejado = transform_olhando.basis.get_euler().y

	var angulo_maximo_rad = deg_to_rad(angulo_maximo_cabeca_graus)
	var diferenca = wrapf(angulo_desejado - rotacao_base_y, -PI, PI)
	diferenca = clamp(diferenca, -angulo_maximo_rad, angulo_maximo_rad)

	var angulo_alvo = rotacao_base_y + diferenca
	rotation.y = lerp_angle(rotation.y, angulo_alvo, velocidade_rotacao_cabeca * delta)

func _olho_seguir_player(olho: Node3D, basis_repouso: Basis, centro_no_pai: Vector3, quat_delta_atual: Quaternion, delta: float) -> Quaternion:
	var pai_global = olho.get_parent().global_transform
	# Posição atual (mundo) do centro do olho, seguindo a cabeça — se a
	# cabeça girou, esse ponto já está no lugar novo automaticamente.
	var centro_mundo_atual = pai_global * centro_no_pai

	var para_player = player.global_position - centro_mundo_atual
	if para_player.length() < 0.01:
		return quat_delta_atual
	var alvo_dir = para_player.normalized()

	# Rotação mínima que leva a direção de repouso (íris pra frente) até a
	# direção do player. Aplicada sobre a basis de repouso (que já tem a
	# escala certa), preserva exatamente a orientação que foi montada no
	# editor — só gira, nunca desloca nem distorce o olho.
	var quat_delta_alvo = Quaternion(direcao_neutra_mundo, alvo_dir)
	var peso = min(velocidade_rotacao_olhos * delta, 1.0)
	var nova_quat_delta = quat_delta_atual.slerp(quat_delta_alvo, peso)

	var basis_alvo_mundo = Basis(nova_quat_delta) * basis_repouso
	var nova_basis_local = pai_global.basis.inverse() * basis_alvo_mundo

	# A malha não é centralizada na origem do nó: para o centro real da
	# esfera continuar exatamente no mesmo ponto (preso ao pai, não ao
	# mundo) depois de girar, recalculamos a posição local a partir dele,
	# em vez de deixar a origem do nó como está.
	var nova_origem_local = centro_no_pai - nova_basis_local * centro_local_olho

	olho.transform = Transform3D(nova_basis_local, nova_origem_local)

	return nova_quat_delta
