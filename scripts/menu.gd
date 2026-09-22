extends Control

@onready var version: Label = $Camera2D/version
@export var load_from_castle_1:bool = false
@export var load_from_outside_1:bool = false
@export var enable_debug_tab:bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.load_from_castle_1 = load_from_castle_1
	Global.load_from_outside_1 = load_from_outside_1
	Global.show_debug_tab = enable_debug_tab
	
	version.text = "v"+ProjectSettings.get_setting("application/config/version")
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
