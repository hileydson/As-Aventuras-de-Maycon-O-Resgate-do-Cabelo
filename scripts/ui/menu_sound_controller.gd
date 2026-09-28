extends Node

const MENU_MOVE_SOUND: AudioStream = preload("res://assets/novos_audios/ui_menu_move.wav")
const MENU_START_SOUND: AudioStream = preload("res://assets/novos_audios/pause_sfxr.mp3")

var player: AudioStreamPlayer
var last_navigation_time := -1000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = MENU_MOVE_SOUND
	add_child(player)


func bind_button(button: Button, action: String = "confirm") -> void:
	button.focus_entered.connect(play_navigation)
	button.mouse_entered.connect(_focus_button.bind(button))
	match action:
		"back":
			button.pressed.connect(play_back)
		"start":
			button.pressed.connect(play_start)
		_:
			button.pressed.connect(play_confirm)


func _focus_button(button: Button) -> void:
	if button.disabled or button.has_focus():
		return
	button.grab_focus()


func play_navigation() -> void:
	var now := Time.get_ticks_msec()
	if now - last_navigation_time < 70:
		return
	last_navigation_time = now
	_play(0.92, -13.0)


func play_confirm() -> void:
	_play(1.24, -9.5)


func play_back() -> void:
	_play(0.72, -10.5)


func play_start() -> void:
	_play(1.06, -8.0, MENU_START_SOUND)


func _play(pitch: float, volume: float, sound: AudioStream = MENU_MOVE_SOUND) -> void:
	if not is_instance_valid(player):
		return
	player.stop()
	player.stream = sound
	player.pitch_scale = pitch
	player.volume_db = volume
	player.play()
