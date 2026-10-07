extends Sprite2D

@onready var animacoes: AnimationPlayer = $animacoes
const LOGO_OTHER = preload("res://assets/imagens_publicidade/logo_other.png")
@onready var logo_end: Sprite2D = $logo_end
var portuguese_logo: Texture2D

var time_to_skip:bool = false
func _ready() -> void:
	portuguese_logo = logo_end.texture
	_update_end_logo()
	logo_end.modulate.a = 0.0
	var movie: AnimationPlayer = $"../end_movie"
	var reveal_duration := minf(25.0, maxf(1.0, movie.get_animation("the_end").length - 5.0))
	var reveal := create_tween()
	reveal.tween_property(logo_end, "modulate:a", 1.0, reveal_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(portuguese_logo):
		_update_end_logo()

func _update_end_logo() -> void:
	logo_end.texture = portuguese_logo if Global.default_language == Global.language_pt_br else LOGO_OTHER


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	#pra tela inicial
	if time_to_skip and Input.is_action_just_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	


func _on_end_movie_animation_finished(anim_name: StringName) -> void:
	if anim_name == "the_end":
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
