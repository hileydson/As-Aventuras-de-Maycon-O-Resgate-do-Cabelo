extends SceneTree

# Regressão de apresentação do HUD das fases 3D a pé: confere se as molduras
# escuras envolvem os ícones certinho, se a barra de estamina nasce escondida ao
# lado do HUD de corrida e se o overlay de controles aceita o perfil da fase.
# Os autoloads só existem depois que a árvore sobe, então os scripts da UI são
# carregados em tempo de execução em vez de preload.
var BATTLE_HUD_DECOR:GDScript
var CONTROLS_INTRO:GDScript
var PAUSE_VISUAL:GDScript

class FakePlayer extends Node:
	var estamina_atual:float = 100.0
	var estamina_maxima:float = 100.0
	var pode_correr:bool = true

var failures:int = 0
var global:Node
var hud:CanvasLayer
var decor:Node

func _init() -> void:
	call_deferred("run")

func check(label:String, condition:bool) -> void:
	print(("OK " if condition else "FAIL ") + label)
	if not condition:
		failures += 1

func used_rect(texture:Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	var image := texture.get_image()
	if image == null:
		return Rect2(Vector2.ZERO, texture.get_size())
	if image.is_compressed() and image.decompress() != OK:
		return Rect2(Vector2.ZERO, texture.get_size())
	return Rect2(image.get_used_rect())

func icon_rect(node:Node2D) -> Rect2:
	var texture:Texture2D = null
	if node is Sprite2D:
		texture = (node as Sprite2D).texture
	elif node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return Rect2()
	var opaque := used_rect(texture)
	var local := Rect2(opaque.position - texture.get_size() * 0.5, opaque.size)
	return transformed_rect(node.get_global_transform(), local)

func control_rect(control:Control) -> Rect2:
	return transformed_rect(control.get_global_transform(), Rect2(Vector2.ZERO, control.size))

func transformed_rect(transform:Transform2D, rect:Rect2) -> Rect2:
	var corners:Array[Vector2] = [
		transform * rect.position,
		transform * Vector2(rect.end.x, rect.position.y),
		transform * rect.end,
		transform * Vector2(rect.position.x, rect.end.y)
	]
	var result := Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		result = result.expand(corner)
	return result

func margins(outer:Rect2, inner:Rect2) -> Array[float]:
	return [
		inner.position.x - outer.position.x,
		inner.position.y - outer.position.y,
		outer.end.x - inner.end.x,
		outer.end.y - inner.end.y
	]

func check_fits(label:String, panel:Control, inner:Rect2, minimum:float, maximum:float) -> void:
	var outer := control_rect(panel)
	var folgas := margins(outer, inner)
	var ok := true
	for folga in folgas:
		if folga < minimum or folga > maximum:
			ok = false
	check(label + " " + str(folgas), ok)

func pad_button(pressed:bool = true) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_Y
	event.pressed = pressed
	Input.parse_input_event(event)

func key_press(pressed:bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_Q
	event.physical_keycode = KEY_Q
	event.pressed = pressed
	Input.parse_input_event(event)

func settle() -> void:
	for i in 3:
		await process_frame

func run() -> void:
	global = root.get_node("Global")
	BATTLE_HUD_DECOR = load("res://scripts/ui/battle_hud_decor.gd")
	CONTROLS_INTRO = load("res://scripts/ui/controls_intro_overlay.gd")
	PAUSE_VISUAL = load("res://scripts/ui/pause_visual.gd")
	TranslationServer.set_locale("en")
	var instance := (load("res://scenes/3D/maycon_3d.tscn") as PackedScene).instantiate()
	var body := instance.get_node("CharacterBody3D")
	hud = body.get_node("hud_canvas")
	body.remove_child(hud)
	instance.free()

	var player := FakePlayer.new()
	player.name = "FakePlayer"
	root.add_child(player)
	player.add_child(hud)
	hud.get_node("control_gun").visible = true

	decor = BATTLE_HUD_DECOR.new()
	decor.player = player
	hud.add_child(decor)
	await settle()

	var life_hud:Node2D = hud.get_node("maycon_hp")
	var gun_controls:Control = hud.get_node("control_gun")
	var life_panel:PanelContainer = life_hud.get_node("LifeHudBackdrop")
	var run_panel:PanelContainer = life_hud.get_node("RunHudBackdrop")
	var gun_panel:PanelContainer = gun_controls.get_node("GunHudBackdrop")
	var bar:Control = life_hud.get_node("StaminaBar")

	check("moldura de vida é o segundo filho (fica atrás dos corações)", life_hud.get_child(1) == life_panel)
	check("moldura de corrida é o primeiro filho", life_hud.get_child(0) == run_panel)
	check("moldura da arma é o primeiro filho", gun_controls.get_child(0) == gun_panel)

	# Vida: a moldura precisa abraçar os cinco corações.
	var vida := icon_rect(life_hud.get_node("hp_1"))
	for nome in ["hp_2", "hp_3", "hp_4", "hp_5"]:
		vida = vida.merge(icon_rect(life_hud.get_node(nome)))
	check_fits("moldura de vida envolve os corações", life_panel, vida, 5.0, 16.0)

	# Arma: bala, contador e o gatilho visível do dispositivo atual.
	var gun_buttons:Node2D = gun_controls.get_node("hud_gun_buttons")
	var arma := icon_rect(gun_controls.get_node("Bala"))
	arma = arma.merge(control_rect(gun_controls.get_node("balas_numero")))

	key_press()
	await settle()
	check("teclado mostra o ícone do mouse", gun_buttons.get_node("MouseTrigger").visible)
	check_fits("moldura da arma envolve o HUD de teclado", gun_panel, arma.merge(icon_rect(gun_buttons.get_node("MouseTrigger"))), 5.0, 14.0)
	check_fits("moldura de corrida envolve o Shift", run_panel, icon_rect(life_hud.get_node("ShiftDark")), 5.0, 14.0)
	var barra_kbm := control_rect(bar)
	var corrida_kbm := control_rect(run_panel)
	check("barra de estamina fica logo à frente do HUD de corrida", barra_kbm.position.x > corrida_kbm.end.x and barra_kbm.position.x - corrida_kbm.end.x < 14.0)
	check("barra de estamina nasce escondida", bar.modulate.a == 0.0)
	check("barra de estamina é sutil", barra_kbm.size.y <= 10.0 and barra_kbm.size.x <= 100.0)

	pad_button()
	await settle()
	check("controle mostra o ícone do RB", life_hud.get_node("RbXbox").visible)
	check_fits("moldura da arma envolve o HUD de controle", gun_panel, arma.merge(icon_rect(gun_buttons.get_node("ButtonTrigger"))), 5.0, 14.0)
	check_fits("moldura de corrida acompanha o RB", run_panel, icon_rect(life_hud.get_node("RbXbox")), 4.0, 14.0)
	var corrida_pad := control_rect(run_panel)
	check("moldura de corrida muda de lugar com o dispositivo", not corrida_pad.is_equal_approx(corrida_kbm))
	var barra_pad := control_rect(bar)
	check("barra de estamina segue o HUD de corrida", barra_pad.position.x > corrida_pad.end.x and barra_pad.position.x - corrida_pad.end.x < 14.0)

	# A barra aparece ao gastar estamina e some sozinha quando volta a encher.
	player.estamina_atual = 40.0
	await settle()
	check("barra aparece ao gastar estamina", bar.modulate.a > 0.0)
	check("barra mostra o quanto restou", is_equal_approx(bar.fill_ratio, 0.4))
	player.pode_correr = false
	player.estamina_atual = 0.0
	await settle()
	check("barra zera quando a estamina acaba", bar.fill_ratio == 0.0)

	# Overlay de controles com o perfil das fases 3D a pé.
	check("perfil first_3d tem as ações de andar, atirar e correr", PAUSE_VISUAL.controls_for("first_3d").size() == 3)
	var intro = CONTROLS_INTRO.new()
	intro.profile = "first_3d"
	root.add_child(intro)
	await settle()
	var card:Array = intro.get_node("ControlsIntroOverlay").find_children("PauseControlsCard", "", true, false)
	check("overlay monta o card do perfil informado", card.size() == 1)
	check("overlay segura o jogo até o jogador confirmar", paused and global.block_pause_before_prologo)
	intro.finish()
	await settle()
	check("overlay devolve o jogo ao sair", not paused and not global.block_pause_before_prologo)

	print("FAILURES: " + str(failures))
	quit(1 if failures > 0 else 0)
