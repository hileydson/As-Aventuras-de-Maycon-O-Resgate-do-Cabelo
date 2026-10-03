extends Control

@onready var logo: TextureRect = $CenterContainer/Logo
@onready var background: ColorRect = $Background

const FADE_IN_DURATION: float = 4.0
const STAY_DURATION: float = 3.0
const FADE_OUT_DURATION: float = 2.0
const NEXT_SCENE_PATH: String = "res://scenes/intro_pacoca_producoes.tscn"

func _ready() -> void:
	logo.modulate.a = 0.0
	_run_splash_sequence()

func _run_splash_sequence() -> void:
	# Fade in lento e maior (4.0 segundos)
	var tween_in: Tween = create_tween()
	tween_in.set_trans(Tween.TRANS_SINE)
	tween_in.set_ease(Tween.EASE_IN_OUT)
	tween_in.tween_property(logo, "modulate:a", 1.0, FADE_IN_DURATION)
	await tween_in.finished

	# Permanece visível por 3 segundos
	await get_tree().create_timer(STAY_DURATION).timeout

	if not is_inside_tree():
		return

	# Fade out lento
	var tween_out: Tween = create_tween()
	tween_out.set_trans(Tween.TRANS_SINE)
	tween_out.set_ease(Tween.EASE_IN_OUT)
	tween_out.tween_property(logo, "modulate:a", 0.0, FADE_OUT_DURATION)
	await tween_out.finished

	if not is_inside_tree():
		return

	# Pequeno intervalo antes de carregar a próxima cena
	await get_tree().create_timer(0.2).timeout

	if is_inside_tree():
		get_tree().change_scene_to_file(NEXT_SCENE_PATH)

