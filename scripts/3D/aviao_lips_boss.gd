extends Node3D

# Lips gigante do combate aéreo: voa de um lado para o outro, para cima e para
# baixo, e cospe lanches gigantes no avião. Sangra igual ao Lips da fase do
# Super Maycon Brother quando leva tiro.

const MODEL = preload("res://assets/modelo_3d/mario_3d_models/lips_3d_rigged.glb")
const BLOOD_SCENE = preload("res://scenes/3D/blood.tscn")
const SCREAM_SOUND = preload("res://assets/novos_audios/mario_part_sounds/lips_scream_air.mp3")
const GRUNT_SOUND = preload("res://assets/novos_audios/mario_part_sounds/lips_jump_grunt.mp3")

const ESCALA := 26.0
const RAIO_ACERTO := 21.0
const LIMITE_X := 38.0
const LIMITE_Y := 19.0

signal vida_alterada(atual:float, maxima:float)
signal derrotado()

var vida_maxima:float = 130.0
var vida:float = 130.0
var abatido:bool = false
var investindo:bool = false

var modelo:Node3D
var animation_player:AnimationPlayer
var materiais:Array[BaseMaterial3D] = []
var scream_audio:AudioStreamPlayer
var grunt_audio:AudioStreamPlayer

var ativo:bool = false
var tempo:float = 0.0
var tempo_dano:float = 0.0
var z_base:float = -112.0
var fase_x:float = 0.0
var fase_y:float = 0.0


func _ready() -> void:
	modelo = MODEL.instantiate()
	modelo.name = "LipsModelo"
	modelo.scale = Vector3.ONE * ESCALA
	add_child(modelo)
	animation_player = modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_tocar("Idle")
	_coletar_materiais()
	scream_audio = _criar_audio(SCREAM_SOUND, 0.0)
	grunt_audio = _criar_audio(GRUNT_SOUND, -4.0)
	fase_x = randf() * TAU
	fase_y = randf() * TAU


func _criar_audio(stream:AudioStream, volume:float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player


func _coletar_materiais() -> void:
	for node in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi or not mi.mesh:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var mat = mi.get_surface_override_material(s)
			if not mat:
				mat = mi.mesh.surface_get_material(s)
			if mat is BaseMaterial3D:
				var dup = mat.duplicate() as BaseMaterial3D
				mi.set_surface_override_material(s, dup)
				materiais.append(dup)


func _process(delta:float) -> void:
	if abatido or investindo or not ativo:
		return
	tempo += delta
	# Quanto mais machucado, mais rápido e nervoso ele fica
	var raiva := 1.0 + (1.0 - vida / vida_maxima) * 1.1
	var x := sin(tempo * 0.55 * raiva + fase_x) * LIMITE_X * 0.78 + sin(tempo * 1.23 * raiva) * LIMITE_X * 0.2
	var y := sin(tempo * 0.83 * raiva + fase_y) * LIMITE_Y * 0.7 + cos(tempo * 1.61 * raiva) * LIMITE_Y * 0.25
	var z := z_base + sin(tempo * 0.47) * 22.0
	var alvo := Vector3(x, y, z)
	if tempo < 1.5:
		# Entrada suave, sem pulo ao assumir o controle do voo
		alvo = Vector3(0.0, 0.0, z_base).lerp(alvo, tempo / 1.5)
	position = alvo
	rotation.z = sin(tempo * 0.9 * raiva) * 0.28
	rotation.y = PI + sin(tempo * 0.6) * 0.35
	rotation.x = sin(tempo * 1.1) * 0.12
	if tempo_dano > 0.0:
		tempo_dano = maxf(0.0, tempo_dano - delta)
		_pintar(Color(1.0, 0.35, 0.35) if int(tempo_dano * 30.0) % 2 == 0 else Color.WHITE)
		if tempo_dano <= 0.0:
			_pintar(Color.WHITE)


func receber_dano(quantidade:float, ponto:Vector3) -> void:
	if abatido:
		return
	vida = maxf(0.0, vida - quantidade)
	tempo_dano = 0.16
	vida_alterada.emit(vida, vida_maxima)
	if randf() < 0.55:
		_espirrar_sangue(ponto)
	if randf() < 0.08 and not grunt_audio.playing:
		grunt_audio.pitch_scale = randf_range(0.5, 0.7)
		grunt_audio.play()
	if vida <= 0.0:
		abatido = true
		_pintar(Color.WHITE)
		scream_audio.pitch_scale = 0.55
		scream_audio.play()
		derrotado.emit()


func _espirrar_sangue(ponto:Vector3) -> void:
	var sangue := BLOOD_SCENE.instantiate()
	sangue.scale = Vector3.ONE * randf_range(6.0, 11.0)
	get_parent().add_child(sangue)
	sangue.global_position = ponto
	get_tree().create_timer(2.2).timeout.connect(func():
		if is_instance_valid(sangue):
			sangue.queue_free())


func boca_global() -> Vector3:
	return global_position + Vector3(0.0, -ESCALA * 0.12, ESCALA * 0.4)


func gritar() -> void:
	scream_audio.pitch_scale = randf_range(0.75, 0.95)
	scream_audio.play()


func mergulhar() -> void:
	_tocar("Belly_Dive")


func _tocar(nome:String) -> void:
	if animation_player == null or not animation_player.has_animation(nome):
		return
	if animation_player.current_animation == nome and animation_player.is_playing():
		return
	animation_player.play(nome, 0.3)


func _pintar(cor:Color) -> void:
	for mat in materiais:
		if is_instance_valid(mat):
			mat.albedo_color = cor
