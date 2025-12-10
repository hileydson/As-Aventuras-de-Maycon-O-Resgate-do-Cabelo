extends Sprite2D
@onready var animacoes: AnimationPlayer = $animacoes
@onready var maycon_falling: AnimatedSprite2D = $maycon_falling


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animacoes.play("maycon_falling")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !maycon_falling.is_playing() && maycon_falling.animation != "on_gound":
		maycon_falling.play("on_gound")
