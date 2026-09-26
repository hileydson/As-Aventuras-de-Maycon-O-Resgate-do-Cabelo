class_name ZombieAnimationFactory
extends RefCounted

# O modelo infected_zombie_animated.glb TEM um rig (esqueleto de 66 ossos, malha
# corretamente vinculada), mas as animações do glb vêm "achatadas" (todos os
# keyframes iguais = T-pose parada). Por isso a animação antiga era feita via código.
#
# Esta fábrica gera animações REAIS, com keyframes, em uma AnimationLibrary que pode
# ser salva em .res e editada no editor pelo AnimationPlayer. As rotações são absolutas
# (pose local = rest * delta), no mesmo padrão que o código procedural usava.

const B := "CityDeadOutfit_"      # prefixo dos ossos
const SKEL_PATH := "Armature/Skeleton3D"
const LIBRARY_PATH := "res://assets/horror_creatures/zombie_authored_animations.res"

# Carrega a biblioteca salva (editável) se existir; senão gera a partir do esqueleto e
# salva em disco. É o ponto único usado tanto pelo gigante quanto pelos zumbis normais.
static func load_or_build(skel:Skeleton3D) -> AnimationLibrary:
	if ResourceLoader.exists(LIBRARY_PATH):
		var saved := ResourceLoader.load(LIBRARY_PATH) as AnimationLibrary
		if saved:
			return saved
	var lib := build_library(skel)
	ResourceSaver.save(lib, LIBRARY_PATH)
	return lib

# Constrói a biblioteca de animações para um esqueleto do zumbi.
static func build_library(skel:Skeleton3D, skel_path:String = SKEL_PATH) -> AnimationLibrary:
	var rest := _rest_map(skel)
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _idle(rest, skel_path))
	lib.add_animation("walk", _walk(rest, skel_path))
	lib.add_animation("scream", _scream(rest, skel_path))
	lib.add_animation("watch", _watch(rest, skel_path))
	lib.add_animation("prepare", _prepare(rest, skel_path))
	lib.add_animation("attack", _attack(rest, skel_path))
	lib.add_animation("grab", _grab(rest, skel_path))
	return lib

static func _rest_map(skel:Skeleton3D) -> Dictionary:
	var rest := {}
	for i in skel.get_bone_count():
		rest[skel.get_bone_name(i)] = skel.get_bone_rest(i).basis.get_rotation_quaternion()
	return rest

# Cria uma nova track de rotação para um osso e insere os keyframes (delta em euler).
static func _rot_track(anim:Animation, rest:Dictionary, skel_path:String, bone:String, keys:Array) -> void:
	var full := B + bone
	if not rest.has(full):
		return
	var t := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t, skel_path + ":" + full)
	anim.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR)
	var r:Quaternion = rest[full]
	for k in keys:
		anim.rotation_track_insert_key(t, k[0], r * Quaternion.from_euler(k[1]))

# Postura base do zumbi (encurvado, braços caídos para frente). Retorna um dicionário
# osso -> euler delta, usado como ponto de partida das poses.
static func _stance() -> Dictionary:
	return {
		"Spine": Vector3(0.17, 0, 0), "Spine1": Vector3(0.11, 0, 0), "Spine2": Vector3(0.05, 0, 0),
		"Neck": Vector3(0.14, 0, 0), "Head": Vector3(0.12, 0, 0.04),
		"LeftShoulder": Vector3(0, 0, -0.1), "RightShoulder": Vector3(0, 0, 0.1),
		"LeftArm": Vector3(0.55, 0.1, 1.12), "RightArm": Vector3(0.55, -0.1, -1.12),
		"LeftForeArm": Vector3(0.6, 0, 0.2), "RightForeArm": Vector3(0.6, 0, -0.2),
		"LeftUpLeg": Vector3(0.03, 0, 0), "RightUpLeg": Vector3(0.03, 0, 0),
	}

static func _apply(base:Dictionary, over:Dictionary) -> Dictionary:
	var d := base.duplicate()
	for k in over:
		d[k] = over[k]
	return d

# Insere, para cada osso da lista, uma track com um key por frame (t, pose[bone]).
static func _build(anim:Animation, rest:Dictionary, skel_path:String, frames:Array) -> void:
	var bones := {}
	for f in frames:
		for b in f[1]:
			bones[b] = true
	for bone in bones:
		var keys := []
		for f in frames:
			var pose:Dictionary = f[1]
			keys.append([f[0], pose.get(bone, Vector3.ZERO)])
		_rot_track(anim, rest, skel_path, bone, keys)

static func _idle(rest:Dictionary, skel_path:String) -> Animation:
	var a := Animation.new()
	a.length = 4.0
	a.loop_mode = Animation.LOOP_LINEAR
	var frames := []
	var samples := 8
	for i in range(samples + 1):
		var t := 4.0 * i / samples
		var ph := TAU * i / samples
		var breath := sin(ph) * 0.03
		var pose := _apply(_stance(), {
			"Spine": Vector3(0.17 + breath, 0, 0),
			"Head": Vector3(0.12 + breath * 0.5, sin(ph) * 0.05, 0.04),
			"LeftArm": Vector3(0.55, 0.1, 1.12 + breath),
			"RightArm": Vector3(0.55, -0.1, -1.12 - breath),
		})
		frames.append([t, pose])
	_build(a, rest, skel_path, frames)
	return a

static func _watch(rest:Dictionary, skel_path:String) -> Animation:
	# Igual ao idle, mas a cabeça vira lentamente de um lado ao outro (vigiando).
	var a := Animation.new()
	a.length = 6.0
	a.loop_mode = Animation.LOOP_LINEAR
	var frames := []
	var samples := 12
	for i in range(samples + 1):
		var t := 6.0 * i / samples
		var ph := TAU * i / samples
		var breath := sin(ph * 2.0) * 0.025
		var look := sin(ph) * 0.5
		var pose := _apply(_stance(), {
			"Spine": Vector3(0.15 + breath, sin(ph) * 0.04, 0),
			"Neck": Vector3(0.13, look * 0.4, 0),
			"Head": Vector3(0.08, look, 0.04),
			"LeftArm": Vector3(0.5, 0.1, 1.1 + breath),
			"RightArm": Vector3(0.5, -0.1, -1.1 - breath),
		})
		frames.append([t, pose])
	_build(a, rest, skel_path, frames)
	return a

static func _walk(rest:Dictionary, skel_path:String) -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	var frames := []
	var samples := 8
	for i in range(samples + 1):
		var t := 1.0 * i / samples
		var ph := TAU * i / samples
		var swing := sin(ph)
		var bob := sin(ph * 2.0)
		var pose := _apply(_stance(), {
			"Spine": Vector3(0.2, 0, swing * 0.05),
			"LeftUpLeg": Vector3(swing * 0.5, 0, 0),
			"RightUpLeg": Vector3(-swing * 0.5, 0, 0),
			"LeftLeg": Vector3(maxf(0.0, -bob) * 0.7, 0, 0),
			"RightLeg": Vector3(maxf(0.0, bob) * 0.7, 0, 0),
			"LeftArm": Vector3(0.55 - swing * 0.2, 0.1, 1.1),
			"RightArm": Vector3(0.55 + swing * 0.2, -0.1, -1.1),
		})
		frames.append([t, pose])
	_build(a, rest, skel_path, frames)
	return a

static func _scream(rest:Dictionary, skel_path:String) -> Animation:
	var a := Animation.new()
	a.length = 1.4
	a.loop_mode = Animation.LOOP_NONE
	_build(a, rest, skel_path, [
		[0.0, _stance()],
		[0.4, _apply(_stance(), {
			"Spine": Vector3(-0.1, 0, 0), "Neck": Vector3(-0.2, 0, 0), "Head": Vector3(-0.45, 0, 0),
			"LeftArm": Vector3(-0.2, 0.2, 0.6), "RightArm": Vector3(-0.2, -0.2, -0.6),
			"LeftForeArm": Vector3(0.9, 0, 0.2), "RightForeArm": Vector3(0.9, 0, -0.2),
		})],
		[1.0, _apply(_stance(), {
			"Spine": Vector3(-0.12, 0, 0), "Neck": Vector3(-0.22, 0, 0), "Head": Vector3(-0.5, 0.05, 0),
			"LeftArm": Vector3(-0.25, 0.2, 0.55), "RightArm": Vector3(-0.25, -0.2, -0.55),
			"LeftForeArm": Vector3(0.85, 0, 0.2), "RightForeArm": Vector3(0.85, 0, -0.2),
		})],
		[1.4, _stance()],
	])
	return a

static func _prepare(rest:Dictionary, skel_path:String) -> Animation:
	# Gigante se prepara: recua o tronco e ergue os braços atrás (carregando o golpe).
	var a := Animation.new()
	a.length = 1.2
	a.loop_mode = Animation.LOOP_NONE
	var wound := _apply(_stance(), {
		"Spine": Vector3(-0.12, 0, 0), "Spine1": Vector3(-0.08, 0, 0),
		"Neck": Vector3(-0.15, 0, 0), "Head": Vector3(-0.28, 0, 0),
		"LeftArm": Vector3(-0.35, 0.15, 0.55), "RightArm": Vector3(-0.35, -0.15, -0.55),
		"LeftForeArm": Vector3(0.35, 0, 0.2), "RightForeArm": Vector3(0.35, 0, -0.2),
	})
	_build(a, rest, skel_path, [
		[0.0, _stance()],
		[0.7, wound],
		[1.2, wound],
	])
	return a

static func _attack(rest:Dictionary, skel_path:String) -> Animation:
	# Gigante avança os braços para dentro tentando agarrar.
	var a := Animation.new()
	a.length = 0.7
	a.loop_mode = Animation.LOOP_NONE
	var wound := _apply(_stance(), {
		"Spine": Vector3(-0.12, 0, 0), "Head": Vector3(-0.28, 0, 0),
		"LeftArm": Vector3(-0.35, 0.15, 0.55), "RightArm": Vector3(-0.35, -0.15, -0.55),
		"LeftForeArm": Vector3(0.35, 0, 0.2), "RightForeArm": Vector3(0.35, 0, -0.2),
	})
	var thrust := _apply(_stance(), {
		"Spine": Vector3(0.4, 0, 0), "Spine1": Vector3(0.2, 0, 0),
		"Neck": Vector3(0.2, 0, 0), "Head": Vector3(0.3, 0, 0.04),
		"LeftArm": Vector3(1.35, 0.05, 0.8), "RightArm": Vector3(1.35, -0.05, -0.8),
		"LeftForeArm": Vector3(0.15, 0, 0.15), "RightForeArm": Vector3(0.15, 0, -0.15),
	})
	_build(a, rest, skel_path, [
		[0.0, wound],
		[0.28, thrust],
		[0.7, thrust],
	])
	return a

static func _grab(rest:Dictionary, skel_path:String) -> Animation:
	# Segurando o player: tronco/cabeça sacudindo de um lado para o outro (balançar).
	var a := Animation.new()
	a.length = 0.9
	a.loop_mode = Animation.LOOP_LINEAR
	var frames := []
	var samples := 8
	for i in range(samples + 1):
		var t := 0.9 * i / samples
		var ph := TAU * i / samples
		var twist := sin(ph)
		var pose := _apply(_stance(), {
			"Spine": Vector3(0.3, twist * 0.35, 0),
			"Spine1": Vector3(0.15, twist * 0.3, 0),
			"Neck": Vector3(0.15, twist * 0.2, 0),
			"Head": Vector3(0.2 + absf(twist) * 0.15, twist * 0.25, 0),
			"LeftArm": Vector3(1.15, 0.05, 0.7), "RightArm": Vector3(1.15, -0.05, -0.7),
			"LeftForeArm": Vector3(1.2, 0, 0.2), "RightForeArm": Vector3(1.2, 0, -0.2),
		})
		frames.append([t, pose])
	_build(a, rest, skel_path, frames)
	return a
