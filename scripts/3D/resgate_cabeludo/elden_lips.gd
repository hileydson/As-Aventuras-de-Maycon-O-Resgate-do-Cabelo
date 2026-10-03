extends Node3D

# Controlador exclusivo da última arena. A corrida e o final usam seus fluxos originais.
const HUD = preload("res://scripts/3D/resgate_cabeludo/elden_lips_hud.gd")
const ATMOSPHERE = preload("res://scripts/3D/resgate_cabeludo/elden_lips_atmosphere.gd")
const BLADE = preload("res://assets/modelo_3d/elden_lips/wood_blade.glb")
const SHIELD = preload("res://assets/modelo_3d/elden_lips/wood_shield.glb")
const MAYCON_ANIMS = preload("res://assets/modelo_3d/elden_lips/maycon_combat.res")
const LIPS_ANIMS = preload("res://assets/modelo_3d/elden_lips/lips_combat.res")
const FRIES = preload("res://assets/kenney/food_kit/fries.glb")
const TOMATO = preload("res://assets/kenney/food_kit/tomato.glb")
const CENTER := Vector3(0,0,-1800)
const LIGHT_DAMAGE := 6
const HEAVY_DAMAGE := 11
const MAX_STAMINA := 50.0
const FLASKS_EASY := 4
const FLASKS_NORMAL := 1
const WALK_SPEED := 3.8
const GUARD_SPEED := 2.0
const DODGE_TIME := 0.42
const DODGE_SPEED := 9.0
const DODGE_IFRAMES := Vector2(0.05,0.26)
const INPUT_ACTIONS := ["elden_left","elden_right","elden_up","elden_down","elden_guard","elden_attack","elden_heavy","elden_dodge","elden_heal"]
var stage:Node3D
var player:CharacterBody3D
var boss:Node3D
var camera:Camera3D
var engaged:bool = false
var fighting:bool = false
var intro:bool = false
var phase_two:bool = false
# A mira nunca sai de Lips: não existe alternância de alvo nesta arena.
var locked:bool = true
var stamina:float = MAX_STAMINA
var stamina_delay:float = 0
var flasks:int = FLASKS_NORMAL
var guarding:bool = false
var guard_time:float = 0
var action:String = ""
var action_time:float = 0
var action_length:float = 0
var action_contact:bool = false
var dodge_direction:Vector3
var invulnerability:float = 0
var hit_pause:float = 0
var poise:float = 60
var boss_state:String = "wait"
var boss_time:float = 0
var boss_length:float = 0
var boss_attack:String = ""
var boss_contact:bool = false
var attack_index:int = 0
var attack_target:Vector3
var attack_origin:Vector3
var blade:Node3D
var shield:Node3D
var held_food:Node3D
var equipped:bool = false
var hero_skeleton:Skeleton3D
var hud:Control
var atmosphere:Node3D
var hazards:Array[Dictionary] = []
var effects:Array[Dictionary] = []
var warning:MeshInstance3D
var intro_tween:Tween
var message:String = ""
var message_time:float = 0
var elapsed:float = 0
var phase_started:bool = false
var original_camera_fov:float = 70
var original_boss_hp:int = 4
var blade_offset:Basis = Basis.IDENTITY
var shield_offset:Basis = Basis.IDENTITY
var props_calibrated:bool = false
var created_actions:Array[String] = []
var using_gamepad:bool = false
var blade_equipped:bool = false
var shield_equipped:bool = false
var swing_alternate:bool = false
var boss_hurt_time:float = 0.0
var boss_step_time:float = 0.0
var hero_knockback:Vector3 = Vector3.ZERO
var boss_knockback:Vector3 = Vector3.ZERO
var boss_dash_trail_clock:float = 0.0
var close_pressure:float = 0.0
var repulse_cooldown:float = 0.0
var blood_nodes:Array[Dictionary] = []

func setup(owner_stage:Node3D) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	stage = owner_stage
	player = stage.player
	boss = stage.boss
	camera = stage.camera
	hero_skeleton = player.visual_skeleton
	original_camera_fov = camera.fov
	original_boss_hp = boss.max_hp
	_register_input()
	atmosphere = Node3D.new()
	atmosphere.set_script(ATMOSPHERE)
	add_child(atmosphere)
	atmosphere.setup(stage)
	hud = Control.new()
	hud.set_script(HUD)
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.battle = self
	hud.visible = false
	stage.get_node("HUD").add_child(hud)
	# Fade deve continuar acima da apresentação da batalha.
	stage.get_node("HUD").move_child(stage.fade,-1)
	if OS.has_feature("mobile"):
		_build_touch_controls()

func _register_input() -> void:
	var bindings := {
		"elden_left":[KEY_A],"elden_right":[KEY_D],"elden_up":[KEY_W],"elden_down":[KEY_S],
		"elden_guard":[KEY_F,MOUSE_BUTTON_RIGHT,JOY_BUTTON_LEFT_SHOULDER],
		"elden_attack":[MOUSE_BUTTON_LEFT],"elden_heavy":[KEY_E,JOY_BUTTON_RIGHT_SHOULDER],
		"elden_dodge":[KEY_SPACE,JOY_BUTTON_B],
		"elden_heal":[KEY_V,JOY_BUTTON_Y]}
	for name in INPUT_ACTIONS:
		if InputMap.has_action(name): continue
		InputMap.add_action(name)
		created_actions.append(name)
		for code in bindings[name]:
			var event:InputEvent
			if code >= 32:
				event = InputEventKey.new()
				event.physical_keycode = code
			elif name == "elden_attack" or code == MOUSE_BUTTON_RIGHT and name == "elden_guard":
				event = InputEventMouseButton.new()
				event.button_index = code
			else:
				event = InputEventJoypadButton.new()
				event.button_index = code
			InputMap.action_add_event(name,event)

func _build_touch_controls() -> void:
	for i in 8:
		var touch := Button.new()
		var actions := ["ui_left","ui_right","ui_up","ui_down","soco_resgate","elden_guard","elden_dodge","elden_heal"]
		var keys := ["ELDEN_TOUCH_LEFT","ELDEN_TOUCH_RIGHT","ELDEN_TOUCH_UP","ELDEN_TOUCH_DOWN","ELDEN_TOUCH_ATTACK","ELDEN_TOUCH_GUARD","ELDEN_TOUCH_DODGE","ELDEN_TOUCH_HEAL"]
		touch.text = tr(keys[i])
		touch.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT if i<4 else Control.PRESET_BOTTOM_RIGHT)
		var column := i%2
		var row := (i%4)/2
		touch.offset_left = 20+column*82 if i<4 else -184+column*82
		touch.offset_right = touch.offset_left+74
		touch.offset_top = -255+row*74
		touch.offset_bottom = touch.offset_top+66
		touch.button_down.connect(func():
			if fighting:
				Input.action_press(actions[i])
				request_action(actions[i]))
		touch.button_up.connect(func(): Input.action_release(actions[i]))
		hud.add_child(touch)

func _exit_tree() -> void:
	for name in created_actions:
		Input.action_release(name)
		InputMap.erase_action(name)
	if is_instance_valid(camera): camera.fov = original_camera_fov

func handles_player() -> bool:
	return engaged

func begin() -> void:
	if engaged: return
	engaged = true
	hud.visible = true
	intro = true
	player.arena_mode = true
	player.control_enabled = false
	player.step_audio.stop()
	player.velocity = Vector3.ZERO
	player.visual.visible = true
	stage.intro_active = true
	Global.in_cutscene = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	stage.get_node("Arena/Gate").visible = true
	stage.get_node("Arena/Gate/CollisionShape3D").set_deferred("disabled",false)
	stage.cage.freeze = true
	stage.cage.position = Vector3(0,1.4,-1814)
	boss.position = Vector3(0,0,-1807)
	boss.get_node("Visual").rotation.y = 0
	boss.active = false
	boss.max_hp = 160 if Global.is_easy_mode() else 240
	boss.hp = boss.max_hp
	stage.boss_bar.max_value = boss.max_hp
	stage.boss_bar.visible = false
	stage.get_node("HUD/Stats").visible = false
	stage.pentagram_panel.visible = false
	_load_animations(MAYCON_ANIMS,player.animation_player,hero_skeleton,"maycon")
	_load_animations(LIPS_ANIMS,boss.animation,boss.skeleton,"lips")
	_play(boss.animation,"lips_idle")
	_play(player.animation_player,"maycon_walk")
	atmosphere.enter()
	atmosphere.play_sound("gate",player.global_position,-5,0.7)
	stage.set_blur(0,Vector2(.5,.5))
	blade = BLADE.instantiate()
	shield = SHIELD.instantiate()
	shield.scale = Vector3.ONE*.78
	add_child(blade)
	add_child(shield)
	blade.position = Vector3(.30,.12,-1785.42)
	blade.rotation = Vector3(PI*.5,0,.3)
	shield.position = Vector3(-.32,.15,-1785.38)
	shield.rotation.x = PI*.5
	_calibrate_props()
	hud.letterbox = 1
	var start := player.global_position
	player.visual.rotation.y = PI
	intro_tween = create_tween()
	intro_tween.tween_method(func(t:float):
		player.global_position = start.lerp(Vector3(0,.08,-1785),t)
		camera.global_position = player.global_position + Vector3(3.3,1.8,3.4)
		camera.look_at(player.global_position+Vector3.UP*1.05)
	,0.0,1.0,2.6).set_trans(Tween.TRANS_SINE)
	intro_tween.tween_callback(func():
		_play(player.animation_player,"maycon_pickup")
		camera.global_position = player.global_position+Vector3(2.3,1.0,-1.8)
		camera.look_at(player.global_position+Vector3.UP*.65))
	intro_tween.tween_interval(1.09)
	intro_tween.tween_callback(func():
		blade_equipped = true
		atmosphere.play_sound("equip",player.global_position,-16))
	intro_tween.tween_interval(.99)
	intro_tween.tween_callback(func():
		shield_equipped = true
		equipped = true
		atmosphere.play_sound("equip",player.global_position,-15,.9))
	intro_tween.tween_interval(1.12)
	intro_tween.tween_callback(func():
		_play(player.animation_player,"maycon_idle")
		camera.global_position = boss.global_position+Vector3(3.8,2.8,6.5)
		camera.look_at(boss.global_position+Vector3.UP*2.5)
		atmosphere.play_sound("laugh",boss.global_position,-8)
		hud.title = tr("ELDEN_BOSS_NAME")
		hud.subtitle = tr("ELDEN_INTRO_LINE")
		create_tween().tween_property(hud,"title_alpha",1.0,1.5))
	intro_tween.tween_interval(3.6)
	intro_tween.tween_callback(func():
		hud.subtitle = tr("ELDEN_CHALLENGE")
		camera.global_position = player.global_position+Vector3(2.0,2.8,5.8)
		camera.look_at(boss.global_position+Vector3.UP*2.4))
	intro_tween.tween_interval(1.4)
	intro_tween.tween_callback(start_fight)

func _load_animations(asset:Resource,animator:AnimationPlayer,skeleton:Skeleton3D,prefix:String) -> void:
	if animator.has_animation_library("elden"): return
	# Interromper antes de acrescentar a biblioteca evita referências de blend
	# para o cache antigo do AnimationPlayer quando o mapa de animações cresce.
	animator.stop()
	if asset is AnimationLibrary:
		animator.add_animation_library("elden",asset)
		skeleton.reset_bone_poses()
		return
	var source := (asset as PackedScene).instantiate()
	var imported := source.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var source_skeleton := source.find_child("Skeleton3D",true,false) as Skeleton3D
	var library := AnimationLibrary.new()
	var animation_root := animator.get_node(animator.root_node)
	var skeleton_path := str(animation_root.get_path_to(skeleton))
	for key in imported.get_animation_list():
		if not str(key).begins_with(prefix+"_"): continue
		var source_animation := imported.get_animation(key)
		var anim := Animation.new()
		anim.length = source_animation.length
		for track in source_animation.get_track_count():
			var path := source_animation.track_get_path(track)
			if path.get_subname_count()==0 or source_animation.track_get_type(track)!=Animation.TYPE_ROTATION_3D:
				continue
			var bone := str(path.get_subname(0))
			if skeleton.find_bone(bone)<0:
				continue
			var source_bone := source_skeleton.find_bone(bone)
			var target_bone := skeleton.find_bone(bone)
			var source_rest := source_skeleton.get_bone_rest(source_bone).basis.get_rotation_quaternion()
			var target_rest := skeleton.get_bone_rest(target_bone).basis.get_rotation_quaternion()
			var target_track := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(target_track,NodePath(skeleton_path+":"+bone))
			for frame in source_animation.track_get_key_count(track):
				var rotation:Quaternion = source_animation.track_get_key_value(track,frame)
				anim.rotation_track_insert_key(target_track,source_animation.track_get_key_time(track,frame),(target_rest*source_rest.inverse()*rotation).normalized())
		if str(key).ends_with("idle") or str(key).ends_with("walk") or str(key).ends_with("guard"):
			anim.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(key,anim)
	animator.add_animation_library("elden",library)
	skeleton.reset_bone_poses()
	source.free()

func _play(animator:AnimationPlayer,key:String,blend:float = .12,restart:bool = false) -> void:
	if animator and animator.has_animation("elden/"+key) and (restart or animator.current_animation != "elden/"+key):
		animator.speed_scale = 1
		animator.play("elden/"+key,blend)

func start_fight() -> void:
	if not engaged or fighting: return
	if intro_tween and intro_tween.is_running(): intro_tween.call_deferred("kill")
	equipped = true
	blade_equipped = true
	shield_equipped = true
	_calibrate_props()
	intro = false
	fighting = true
	stage.intro_active = false
	Global.in_cutscene = false
	player.control_enabled = true
	boss.active = true
	locked = true
	camera.fov = 62
	player.camera_yaw = 0
	stamina = MAX_STAMINA
	stamina_delay = 0
	flasks = max_flasks()
	invulnerability = 1
	boss_state = "stalk"
	boss_time = 2.0
	close_pressure = 0
	repulse_cooldown = 3.0
	hud.boss_trail = 1
	create_tween().set_parallel(true).tween_property(hud,"title_alpha",0.0,1.0)
	create_tween().tween_property(hud,"letterbox",0.0,.8)
	atmosphere.start_score()
	stage.update_hud()

func _unhandled_input(event:InputEvent) -> void:
	if not engaged: return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion and absf(event.axis_value)>.25:
		using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		using_gamepad = false
	if not fighting or stage.death_in_progress: return
	# A mira fica presa em Lips: nada de girar a câmera nem destravar o alvo.
	for name in ["soco_resgate","elden_attack","elden_heavy","elden_dodge","elden_heal"]:
		if event.is_action_pressed(name):
			request_action(name)
			get_viewport().set_input_as_handled()
			return

func request_action(name:String) -> void:
	if not fighting or stage.death_in_progress or get_tree().paused: return
	if not action.is_empty(): return
	if guarding and name != "elden_dodge": return
	if name == "elden_dodge":
		guarding = false
	if name in ["elden_attack","soco_resgate"]: attack(false)
	elif name == "elden_heavy": attack(true)
	elif name == "elden_dodge": dodge()
	elif name == "elden_heal": drink_flask()

func max_flasks() -> int:
	return FLASKS_EASY if Global.is_easy_mode() else FLASKS_NORMAL

func drink_flask() -> void:
	# Um toque basta: o frasco é gasto e o sangue volta na hora, sem segurar nada.
	if flasks<=0 or stage.hp>=100: return
	flasks -= 1
	set_action("heal",.9)
	action_contact = true
	_play(player.animation_player,"maycon_guard")
	stage.hp = minf(100,stage.hp+45)
	stage.sound("heal")
	heal_magic()
	stage.update_hud()

func heal_magic() -> void:
	# Selo mágico subindo pelo corpo: só malha e partículas, sem shader novo.
	for i in 3:
		var seal := ring(player.global_position,.80+float(i)*.26,Color("8ff0a8") if i<2 else Color("f2e2a0"))
		var height := .10+float(i)*.34
		seal.position.y = height
		effects.append({"node":seal,"life":1.05+float(i)*.12,"duration":1.05+float(i)*.12,
			"growth":-.30,"follow":Vector3(0,height,0),"rise":1.6+float(i)*.3})
	var sparks := CPUParticles3D.new()
	sparks.amount = 90
	sparks.lifetime = 1.1
	sparks.one_shot = true
	sparks.explosiveness = .55
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = Vector3(.45,.1,.45)
	sparks.direction = Vector3.UP
	sparks.spread = 12
	sparks.initial_velocity_min = 1.6
	sparks.initial_velocity_max = 3.4
	sparks.gravity = Vector3(0,1.2,0)
	sparks.scale_amount_min = .05
	sparks.scale_amount_max = .16
	var ramp := Gradient.new()
	ramp.set_color(0,Color("d8ffe2"))
	ramp.set_color(1,Color(.58,.95,.66,0.0))
	ramp.add_point(.4,Color("8ff0a8"))
	sparks.color_ramp = ramp
	var bead := SphereMesh.new()
	bead.radius = .07
	bead.height = .22
	bead.radial_segments = 8
	bead.rings = 4
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color.WHITE
	glow.vertex_color_use_as_albedo = true
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bead.material = glow
	sparks.mesh = bead
	player.visual.add_child(sparks)
	sparks.position = Vector3(0,.15,0)
	sparks.finished.connect(sparks.queue_free)
	sparks.emitting = true
	var halo := OmniLight3D.new()
	halo.light_color = Color("9cf7b2")
	halo.light_energy = 0
	halo.omni_range = 5.0
	player.visual.add_child(halo)
	halo.position = Vector3(0,1.1,0)
	var pulse := create_tween()
	pulse.tween_property(halo,"light_energy",5.0,.18)
	pulse.tween_property(halo,"light_energy",0.0,.85)
	pulse.tween_callback(halo.queue_free)
	hud.heal_flash = 1.0
	stage.burst(player.global_position+Vector3.UP,Color("8ff0a8"),26)
	player.camera_shake = maxf(player.camera_shake,.08)

func spend_stamina(amount:float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	stamina_delay = 1.0
	return true

func set_action(name:String,duration:float) -> void:
	action = name
	action_time = duration
	action_length = duration
	action_contact = false

func attack(heavy:bool) -> void:
	if not spend_stamina(30 if heavy else 18): return
	set_action("heavy" if heavy else "slash",1.15 if heavy else .72)
	var clip := "maycon_heavy" if heavy else "maycon_slash_alt" if swing_alternate else "maycon_slash"
	swing_alternate = not swing_alternate
	_play(player.animation_player,clip,.045,true)

func movement_input() -> Vector2:
	var input := Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	var keys := Input.get_vector("elden_left","elden_right","elden_up","elden_down")
	return (input+keys).limit_length()

func dodge() -> void:
	if not spend_stamina(24): return
	var input := movement_input()
	dodge_direction = player.arena_lado()*input.x-player.orbita()*-input.y
	if dodge_direction.length_squared()<.01: dodge_direction = player.orbita()
	dodge_direction = dodge_direction.normalized()
	set_action("dodge",DODGE_TIME)
	_play(player.animation_player,"maycon_dodge",.04)
	player.animation_player.speed_scale = player.animation_player.get_animation("elden/maycon_dodge").length/DODGE_TIME
	atmosphere.play_sound("swing",player.global_position,-20,1.5)
	player.dash_velocity = dodge_direction*DODGE_SPEED
	player.dash_trail_clock = 0.045
	player._spawn_dash_ghost()
	for i in 3: player._spawn_dash_streak()
	player._spawn_dash_smoke(true)

func physics_player(delta:float) -> void:
	player._update_dash_ghosts(delta)
	player._update_fart_puffs(delta)
	if not fighting or stage.death_in_progress:
		player.velocity = Vector3.ZERO
		return
	invulnerability = maxf(0,invulnerability-delta)
	stamina_delay = maxf(0,stamina_delay-delta)
	var wants_guard := Input.is_action_pressed("elden_guard") and action.is_empty() and stamina>0
	guard_time = guard_time+delta if wants_guard else 0.0
	guarding = wants_guard
	if stamina_delay<=0 and action.is_empty() and not guarding: stamina = minf(MAX_STAMINA,stamina+delta*14)
	var input := movement_input()
	var direction:Vector3 = (player.arena_lado()*input.x-player.orbita()*-input.y).normalized()
	var speed := GUARD_SPEED if guarding else WALK_SPEED
	if not action.is_empty():
		action_time -= delta
		var progress := 1.0-action_time/action_length
		speed = .9
		if action == "dodge":
			direction = dodge_direction
			speed = DODGE_SPEED if progress < .67 else 3.0
			if progress<.67:
				player.dash_trail_clock -= delta
				if player.dash_trail_clock<=0:
					player.dash_trail_clock = .045
					player._spawn_dash_ghost()
					player._spawn_dash_streak()
					player._spawn_dash_smoke(false)
			invulnerability = maxf(invulnerability,.025) if progress*DODGE_TIME>=DODGE_IFRAMES.x and progress*DODGE_TIME<=DODGE_IFRAMES.y else invulnerability
		elif action in ["slash","heavy"] and not action_contact and progress> (.50 if action=="heavy" else .40):
			action_contact = true
			atmosphere.play_sound("swing",player.global_position,-16,.80 if action=="heavy" else 1.0)
			weapon_contact(action=="heavy")
		if action_time<=0: action = ""
	if action in ["hurt","guard_break"]: speed = 0
	player.velocity.x = move_toward(player.velocity.x,direction.x*speed,delta*45)
	player.velocity.z = move_toward(player.velocity.z,direction.z*speed,delta*45)
	if hero_knockback.length_squared()>.001:
		player.velocity.x = hero_knockback.x
		player.velocity.z = hero_knockback.z
		hero_knockback = hero_knockback.move_toward(Vector3.ZERO,delta*16)
	player.velocity.y -= 23*delta
	player.move_and_slide()
	player.position.x = clampf(player.position.x,-17,17)
	player.position.z = clampf(player.position.z,-1811,-1779)
	var to_boss := boss.global_position-player.global_position
	to_boss.y = 0
	if to_boss.length()<2.3 and boss_state not in ["attack","windup"]:
		player.position -= to_boss.normalized()*(2.3-to_boss.length())
	var facing:Vector3 = to_boss if locked or guarding or action in ["slash","heavy"] else direction
	if facing.length_squared()>.01:
		player.visual.rotation.y = lerp_angle(player.visual.rotation.y,atan2(facing.x,facing.z),minf(1,delta*14))
	if action.is_empty():
		_play(player.animation_player,"maycon_guard" if guarding else "maycon_walk" if direction.length_squared()>.01 else "maycon_idle")
		if not guarding and direction.length_squared()>.01: player.animation_player.speed_scale = clampf(speed*.38,1.0,2.3)
	player._update_footsteps(delta,direction,speed)
	player.visual.visible = true
	if player.position.y < -5: stage.respawn()

func weapon_contact(heavy:bool) -> void:
	var diff := boss.global_position-player.global_position
	diff.y = 0
	var facing:Vector3 = player.visual.global_basis.z.normalized()
	if diff.length()>4.4 or facing.dot(diff.normalized())<.35: return
	if absf(boss.position.y-player.position.y)>2.5: return
	var at:Vector3 = player.global_position+facing*2.6+Vector3.UP*1.6
	if boss_state == "phase" or boss.hp<=0: return
	var damage := HEAVY_DAMAGE if heavy else LIGHT_DAMAGE
	if boss_state == "recover": damage = int(damage*1.2)
	boss.hp = maxi(0,boss.hp-damage)
	poise -= 18 if heavy else 7
	boss_knockback = facing*(3.4 if heavy else 2.6)
	atmosphere.play_sound("heavy_hit" if heavy else "hit",at,-6 if heavy else -8)
	atmosphere.play_sound("pain",boss.global_position+Vector3.UP*2,-4)
	boss_hurt_time = .42
	if boss_state in ["stalk","recover"]:
		_play(boss.animation,"lips_hurt",.035,true)
	var wound:Vector3 = boss.global_position+Vector3.UP*1.8-facing*.65
	blood_spray(wound,-facing,1.3 if heavy else 1.0)
	player.camera_shake = .16 if heavy else .07
	hit_pause = .055 if heavy else .035
	Input.start_joy_vibration(0,.2,.35,.10)
	if boss.hp<=0:
		victory()
	elif not phase_two and boss.hp<=boss.max_hp/2:
		second_phase()
	elif poise<=0:
		stagger()
	stage.update_hud()

func take_hit(damage:float,source:Vector3,unblockable:bool = false) -> void:
	if not fighting or stage.death_in_progress or invulnerability>0: return
	var diff := source-player.global_position
	diff.y = 0
	var frontal:bool = player.visual.global_basis.z.normalized().dot(diff.normalized())>.15
	var blocked := false
	if guarding and frontal and not unblockable:
		var perfect := guard_time<=.19
		var cost := 8.0 if perfect else damage*.95
		if stamina>=cost:
			blocked = true
			spend_stamina(cost)
			atmosphere.play_sound("block",player.global_position,-9,.8)
			stage.burst(player.global_position+Vector3.UP,Color("a3dfda"),12)
			player.camera_shake = .12
			if perfect:
				poise -= 45
				show_message("ELDEN_PERFECT_BLOCK",1.2)
				if poise<=0: stagger()
			damage *= .85
		else:
			stamina = 0
			guarding = false
			set_action("guard_break",1.0)
			show_message("ELDEN_GUARD_BREAK",1.5)
	else:
		set_action("hurt",.48)
	damage *= 1.25
	if Global.is_easy_mode(): damage *= .6
	stage.hp = maxf(0,stage.hp-damage)
	invulnerability = .75
	player.camera_shake = .3
	hud.damage_flash = 1
	player_hit_effects(source,.85 if blocked else 1.0)
	atmosphere.play_sound("hit",player.global_position,-11,.9)
	atmosphere.play_sound("hurt",player.global_position,-12)
	_play(player.animation_player,"maycon_guard" if blocked else "maycon_hurt",.025,true)
	Input.start_joy_vibration(0,.35,.55,.18)
	stage.update_hud()
	if stage.hp<=0: stage.respawn()

func stagger() -> void:
	if boss_state == "phase": return
	poise = 60
	clear_attack()
	boss_state = "recover"
	boss_time = 2.0
	show_message("ELDEN_STAGGER",1.4)
	_play(boss.animation,"lips_stagger",.055,true)

func _physics_process(delta:float) -> void:
	if not engaged: return
	elapsed += delta
	boss_hurt_time = maxf(0,boss_hurt_time-delta)
	_update_effects(delta)
	_update_blood(delta)
	if not fighting or stage.death_in_progress: return
	message_time -= delta
	if message_time<=0: message = ""
	if hit_pause>0:
		hit_pause -= delta
		_move_boss_back(delta)
		return
	_update_hazards(delta)
	if not fighting or stage.death_in_progress: return
	_update_close_pressure(delta)
	_update_boss(delta)
	_move_boss_back(delta)

func _move_boss_back(delta:float) -> void:
	if boss_knockback.length_squared()<.001: return
	# Salto e investida mantêm a trajetória anunciada mesmo ao receber dano.
	if not (boss_state=="attack" and boss_attack in ["slam","dash"]):
		boss.position += boss_knockback*delta
		boss.position.x = clampf(boss.position.x,-14,14)
		boss.position.z = clampf(boss.position.z,-1810,-1783)
	boss_knockback = boss_knockback.move_toward(Vector3.ZERO,delta*14)

func player_hit_effects(source:Vector3,strength:float = 1.0) -> void:
	var away := player.global_position-source
	away.y = 0
	if away.length_squared()<.001: away = -player.visual.global_basis.z
	away = away.normalized()
	hero_knockback = away*4.0*strength
	blood_spray(player.global_position+Vector3.UP*1.0,-away,strength)
	hud.splash_blood(strength)

func blood_spray(at:Vector3,direction:Vector3,strength:float) -> void:
	# Gotas alongadas e a mesma rampa de cores do calabouço terror.
	var ramp := Gradient.new()
	ramp.set_color(0,Color(.62,.03,.03,1.0))
	ramp.set_color(1,Color(.2,.004,.008,0.0))
	ramp.add_point(.45,Color(.4,.01,.015,1.0))
	var drops := CPUParticles3D.new()
	drops.amount = maxi(30,int(200*strength))
	drops.lifetime = 1.7
	drops.one_shot = true
	drops.explosiveness = 1.0
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	drops.emission_sphere_radius = .16
	drops.direction = (Vector3.UP+direction*.25).normalized()
	drops.spread = 35
	drops.gravity = Vector3(0,-14,0)
	drops.initial_velocity_min = 7.0
	drops.initial_velocity_max = 10.5
	drops.scale_amount_min = .65
	drops.scale_amount_max = 1.9
	drops.color_ramp = ramp
	drops.particle_flag_align_y = true
	var bead := SphereMesh.new()
	bead.radius = .03
	bead.height = .20
	bead.radial_segments = 12
	bead.rings = 6
	drops.mesh = bead
	var red := StandardMaterial3D.new()
	red.albedo_color = Color.WHITE
	red.vertex_color_use_as_albedo = true
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bead.material = red
	add_child(drops)
	drops.global_position = at
	drops.emitting = true
	drops.restart()
	_track_blood(drops,2.1,"spray")
	var mist := CPUParticles3D.new()
	mist.amount = maxi(18,int(80*strength))
	mist.lifetime = .7
	mist.one_shot = true
	mist.explosiveness = 1.0
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = .22
	mist.direction = (direction+Vector3.UP*.4).normalized()
	mist.spread = 100
	mist.initial_velocity_min = 1.5
	mist.initial_velocity_max = 4.0
	mist.gravity = Vector3(0,-6,0)
	mist.color_ramp = ramp
	var fine := SphereMesh.new()
	fine.radius = .015
	fine.height = .04
	fine.radial_segments = 6
	fine.rings = 3
	fine.material = red
	mist.mesh = fine
	add_child(mist)
	mist.global_position = at
	mist.emitting = true
	mist.restart()
	_track_blood(mist,1.1,"spray")
	for i in maxi(3,int(9*strength)):
		var mark := MeshInstance3D.new()
		var shape := ImmediateMesh.new()
		var radius := randf_range(.13,.40)*sqrt(strength)
		var vertices := PackedVector3Array()
		for point in 14:
			var angle := TAU*float(point)/14
			vertices.append(Vector3(cos(angle),0,sin(angle))*radius*randf_range(.65,1.25))
		shape.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for point in vertices.size():
			shape.surface_add_vertex(Vector3.ZERO)
			shape.surface_add_vertex(vertices[(point+1)%vertices.size()])
			shape.surface_add_vertex(vertices[point])
		shape.surface_end()
		mark.mesh = shape
		var wet := StandardMaterial3D.new()
		wet.albedo_color = Color(.30,.008,.026,.84)
		wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wet.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wet.cull_mode = BaseMaterial3D.CULL_DISABLED
		wet.roughness = .28
		mark.material_override = wet
		mark.visible = false
		add_child(mark)
		var spread := randf_range(.2,2.8)
		var angle := randf()*TAU
		mark.position = Vector3(clampf(at.x+cos(angle)*spread,-16.5,16.5),.025+randf()*.006,clampf(at.z+sin(angle)*spread,-1811,-1779))
		_track_blood(mark,randf_range(14,20),"mark")
		blood_nodes.back()["delay"] = randf_range(.9,1.4)

func _track_blood(node:Node3D,life:float,kind:String) -> void:
	while blood_nodes.size()>=72:
		var oldest:Dictionary = blood_nodes.pop_front()
		if is_instance_valid(oldest.node): oldest.node.queue_free()
	blood_nodes.append({"node":node,"life":life,"kind":kind})

func _update_blood(delta:float) -> void:
	for i in range(blood_nodes.size()-1,-1,-1):
		var data := blood_nodes[i]
		if not is_instance_valid(data.node):
			blood_nodes.remove_at(i)
			continue
		data.life -= delta
		if data.has("delay"):
			data.delay -= delta
			data.node.visible = data.delay<=0
		if data.kind=="mark": data.node.material_override.albedo_color.a = minf(1,data.life/3.0)*.84
		if data.life<=0:
			data.node.queue_free()
			blood_nodes.remove_at(i)

func _clear_blood() -> void:
	for data in blood_nodes:
		if is_instance_valid(data.node): data.node.queue_free()
	blood_nodes.clear()
	hero_knockback = Vector3.ZERO
	boss_knockback = Vector3.ZERO
	hud.blood_stains.clear()
	_clear_dodge_trail()

func _clear_dodge_trail() -> void:
	player._update_dash_ghosts(1.0)
	player._update_fart_puffs(1.0)
	player.dash_velocity = Vector3.ZERO
	player.dash_trail_clock = 0
	boss_dash_trail_clock = 0

func _spawn_boss_dash_trail() -> void:
	var visual:Node3D = boss.get_node("Visual")
	var ghost := visual.duplicate() as Node3D
	var anim := ghost.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if anim:
		anim.stop(true)
		anim.process_mode = Node.PROCESS_MODE_DISABLED
	stage.get_node("Effects").add_child(ghost)
	ghost.global_transform = visual.global_transform
	var skeleton := ghost.find_child("Skeleton3D",true,false) as Skeleton3D
	if skeleton:
		for bone in boss.skeleton.get_bone_count():
			skeleton.set_bone_pose_rotation(bone,boss.skeleton.get_bone_pose_rotation(bone))
			skeleton.set_bone_pose_position(bone,boss.skeleton.get_bone_pose_position(bone))
	var color := Color(.68,.16,.23,.22)
	var mat:StandardMaterial3D = player._dash_material(color)
	for mesh in ghost.find_children("*","MeshInstance3D",true,false):
		(mesh as MeshInstance3D).material_override = mat
	player.dash_ghosts.append({"node":ghost,"mat":mat,"life":.20,"duration":.20,"alpha":color.a,"base_scale":ghost.scale})

func _update_close_pressure(delta:float) -> void:
	repulse_cooldown = maxf(0,repulse_cooldown-delta)
	if boss_state=="phase":
		close_pressure = 0
		return
	var offset := player.global_position-boss.global_position
	offset.y = 0
	close_pressure = minf(6,close_pressure+delta) if offset.length()<5.5 else maxf(0,close_pressure-delta*2)
	if close_pressure<(3.8 if phase_two else 4.8) or repulse_cooldown>0: return
	if boss_state not in ["stalk","recover"] or boss_hurt_time>0: return
	clear_attack()
	close_pressure = 0
	repulse_cooldown = 9.0
	boss_attack = "repulse"
	boss_state = "windup"
	boss_time = .95 if phase_two else 1.15
	boss_contact = false
	warning = ring(boss.position,6.5,Color("bd6a98"))
	_play(boss.animation,"lips_slam_windup",.10,true)
	atmosphere.play_sound("food_charge",boss.position,-12,.65)

func repulse() -> void:
	var away := player.global_position-boss.global_position
	away.y = 0
	if away.length()<6.5 and invulnerability<=0:
		take_hit(12,boss.global_position,true)
		if not stage.death_in_progress:
			hero_knockback = (away.normalized() if away.length_squared()>.001 else Vector3.FORWARD)*14
			player.velocity.y = 3.0
			player.camera_shake = .45
	atmosphere.play_sound("slam",boss.position,-9,.65)
	atmosphere.play_sound("shift",boss.position,-14,1.25)
	stage.burst(boss.position+Vector3.UP,Color("bb7ca6"),45)
	for i in 2:
		var wave := ring(boss.position,1.0,Color("bf86ab"))
		wave.position.y += float(i)*.2
		effects.append({"node":wave,"life":.85,"duration":.85,"growth":8.0})

func _update_boss(delta:float) -> void:
	boss_time -= delta
	var to_player := player.global_position-boss.global_position
	to_player.y = 0
	if boss_state in ["stalk","windup"] and to_player.length_squared()>.01:
		boss.get_node("Visual").rotation.y = lerp_angle(boss.get_node("Visual").rotation.y,atan2(to_player.x,to_player.z),delta*3)
	if boss_state == "stalk":
		if to_player.length()>5.3:
			boss.position += to_player.normalized()*delta*(3.5 if phase_two else 2.7)*(.3 if boss_hurt_time>0 else 1.0)
			if boss_hurt_time<=0: _play(boss.animation,"lips_walk")
			if boss_hurt_time<=0: boss.animation.speed_scale = 1.65 if phase_two else 1.3
			boss_step_time -= delta
			if boss_step_time<=0:
				boss_step_time = .35 if phase_two else .44
				atmosphere.play_sound("step",boss.global_position,-18)
		elif boss_hurt_time<=0: _play(boss.animation,"lips_idle")
		if boss_time<=0: prepare_attack()
	elif boss_state == "windup":
		if warning:
			warning.material_override.albedo_color.a = .25+sin(elapsed*12)*.07
		if boss_time<=0: execute_attack()
	elif boss_state == "attack":
		var progress := 1.0-clampf(boss_time/boss_length,0,1)
		if boss_attack == "slam":
			boss.position = attack_origin.lerp(attack_target,progress)
			boss.position.y = sin(progress*PI)*6
			if progress>.85 and not boss_contact:
				boss_contact = true
				boss.position.y = 0
				impact(attack_target,4.6,34)
				if phase_two: spawn_pool(attack_target,3.0,5.0)
		elif boss_attack == "sweep" and progress>.42 and not boss_contact:
			boss_contact = true
			var front:Vector3 = boss.get_node("Visual").global_basis.z.normalized()
			if to_player.length()<5.6 and front.dot(to_player.normalized())>-.15:
				take_hit(24,boss.global_position)
			atmosphere.play_sound("food_sweep",boss.global_position,-10)
			stage.burst(boss.global_position+front*3+Vector3.UP,Color("e6b85e"),12)
		elif boss_attack == "tomato" and progress>.35 and not boss_contact:
			boss_contact = true
			for offset in [-2.4,0.0,2.4]:
				spawn_projectile(attack_target+Vector3(offset,0,0))
		elif boss_attack == "dash":
			boss.position = attack_origin.lerp(attack_target,progress)
			boss_dash_trail_clock -= delta
			if boss_dash_trail_clock<=0:
				boss_dash_trail_clock = .05
				_spawn_boss_dash_trail()
			if progress>.2 and not boss_contact and boss.position.distance_to(player.position)<2.8:
				boss_contact = true
				take_hit(18,boss.global_position)
		elif boss_attack == "repulse" and progress>.45 and not boss_contact:
			boss_contact = true
			repulse()
		if boss_time<=0:
			boss.position.y = 0
			clear_attack()
			boss_state = "recover"
			boss_time = (.65 if phase_two else .95) if boss_attack=="dash" else 1.0 if phase_two else 1.65
			_play(boss.animation,"lips_idle")
	elif boss_state == "recover" and boss_hurt_time<=0 and boss_time<.5:
		_play(boss.animation,"lips_idle")
		if boss_time<=0:
			boss_state = "stalk"
			boss_time = .8 if phase_two else 1.2
	elif boss_state == "phase" and boss_time<=0:
		phase_two = true
		boss_state = "stalk"
		boss_time = 1.5
		create_tween().tween_property(hud,"title_alpha",0.0,.6)
	boss.position.x = clampf(boss.position.x,-14,14)
	boss.position.z = clampf(boss.position.z,-1810,-1783)

func prepare_attack() -> void:
	var sequence := ["sweep","slam","tomato","dash","sweep","tomato","dash","slam"]
	boss_attack = sequence[attack_index%sequence.size()]
	attack_index += 1
	if player.global_position.distance_to(boss.global_position)>10 and boss_attack=="sweep": boss_attack = "dash"
	boss_state = "windup"
	boss_time = .65 if boss_attack=="dash" else 1.35 if boss_attack=="slam" else 1.15
	if phase_two: boss_time *= .86
	attack_target = player.global_position
	attack_target.y = 0
	attack_origin = boss.position
	boss_contact = false
	if boss_attack=="dash":
		var direction := attack_target-attack_origin
		direction.y = 0
		var distance := direction.length()
		direction = direction.normalized() if distance>.01 else Vector3.FORWARD
		if distance<3.1:
			direction = Vector3(-direction.z,0,direction.x)*(1 if attack_index%2==0 else -1)
			attack_target = attack_origin+direction*3.6
		else:
			attack_target = attack_origin+direction*minf(distance-2.3,9.0 if phase_two else 8.0)
		attack_target.x = clampf(attack_target.x,-14,14)
		attack_target.z = clampf(attack_target.z,-1810,-1783)
		_play(boss.animation,"lips_sweep_windup",.10,true)
		warning = ring(boss.position,1.8,Color("a64d5b"))
		atmosphere.play_sound("food_charge",boss.position,-18,1.2)
		return
	_play(boss.animation,"lips_slam_windup" if boss_attack=="slam" else "lips_sweep_windup" if boss_attack=="sweep" else "lips_throw_windup",.10,true)
	boss.animation.speed_scale = (1.35 if boss_attack=="slam" else 1.15)/boss_time
	held_food = (FRIES if boss_attack=="sweep" else TOMATO).instantiate()
	add_child(held_food)
	_fit_food(held_food,2.6 if boss_attack=="sweep" else 2.1)
	warning = ring(attack_target if boss_attack!="sweep" else boss.position,4.6 if boss_attack=="slam" else 3.2,Color("d29a68"))
	atmosphere.play_sound("food_charge",boss.position,-17,1.1 if phase_two else 1)

func execute_attack() -> void:
	boss_state = "attack"
	boss_length = .42 if boss_attack=="dash" else .85 if boss_attack=="slam" else .9
	boss_time = boss_length
	attack_origin = boss.position
	if boss_attack=="dash":
		var direction := attack_target-attack_origin
		boss.get_node("Visual").rotation.y = atan2(direction.x,direction.z)
		_play(boss.animation,"lips_walk",.035,true)
		boss.animation.speed_scale = 3.8 if phase_two else 3.2
		boss_dash_trail_clock = 0
		atmosphere.play_sound("swing",boss.position,-13,.75)
		return
	# O alvo do salto fica fixo desde o aviso: não persegue Maycon no ar.
	_play(boss.animation,"lips_sweep" if boss_attack=="sweep" else "lips_slam" if boss_attack in ["slam","repulse"] else "lips_throw",.035,true)

func clear_attack() -> void:
	boss_dash_trail_clock = 0
	if is_instance_valid(warning): warning.queue_free()
	warning = null
	if is_instance_valid(held_food): held_food.queue_free()
	held_food = null

func ring(at:Vector3,radius:float,color:Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius-.10
	torus.outer_radius = radius+.10
	torus.rings = 32
	torus.ring_segments = 8
	node.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color,.55)
	mat.emission_enabled = true
	mat.emission = color
	node.material_override = mat
	add_child(node)
	node.position = Vector3(at.x,.09,at.z)
	return node

func impact(at:Vector3,radius:float,damage:float) -> void:
	if Vector2(player.position.x-at.x,player.position.z-at.z).length()<radius:
		take_hit(damage,at)
	atmosphere.play_sound("slam",at,-5,.8)
	atmosphere.play_sound("splat",at,-12)
	stage.burst(at+Vector3.UP*.4,Color("b24e45"),28)
	player.camera_shake = maxf(player.camera_shake,.30)
	var shock := ring(at,radius,Color("b5756b"))
	effects.append({"node":shock,"life":.65,"duration":.65,"expand":true})

func _fit_food(node:Node3D,size:float) -> void:
	var bounds := AABB()
	for child in node.find_children("*","MeshInstance3D",true,false):
		var mesh := child as MeshInstance3D
		if mesh.mesh: bounds = bounds.merge(mesh.transform*mesh.mesh.get_aabb())
	var longest := maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
	if longest>.001: node.scale = Vector3.ONE*size/longest

func spawn_projectile(target:Vector3) -> void:
	if hazards.size()>=12: return
	var tomato := TOMATO.instantiate()
	add_child(tomato)
	_fit_food(tomato,1.3)
	var origin := boss.position+Vector3.UP*3.2
	tomato.position = origin
	var duration := 1.15
	var velocity := (target-origin)/duration+Vector3.UP*9.0*duration*.5
	hazards.append({"node":tomato,"kind":"projectile","velocity":velocity,"life":duration+1,"radius":1.0})
	atmosphere.play_sound("food_launch",origin,-14)

func spawn_pool(at:Vector3,radius:float,duration:float) -> void:
	if hazards.size()>=12: return
	var pool := ring(at,radius,Color("953a48"))
	hazards.append({"node":pool,"kind":"pool","life":duration,"radius":radius,"tick":.7})

func _update_hazards(delta:float) -> void:
	for i in range(hazards.size()-1,-1,-1):
		var data := hazards[i]
		var node := data.node as Node3D
		if not is_instance_valid(node):
			hazards.remove_at(i)
			continue
		data.life -= delta
		if data.kind == "projectile":
			data.velocity.y -= 9*delta
			node.position += data.velocity*delta
			node.rotate_y(delta*3)
			if node.position.distance_to(player.position+Vector3.UP)<1.5:
				take_hit(18,node.position)
				data.life = 0
			if node.position.y<=.2:
				impact(node.position,2.3,20)
				if phase_two: spawn_pool(node.position,2.0,4.0)
				data.life = 0
		else:
			data.tick -= delta
			if data.tick<=0:
				data.tick = .8
				if Vector2(player.position.x-node.position.x,player.position.z-node.position.z).length()<data.radius:
					take_hit(10,node.position,true)
		if data.life<=0:
			node.queue_free()
			hazards.remove_at(i)

func _update_effects(delta:float) -> void:
	for i in range(effects.size()-1,-1,-1):
		var data := effects[i]
		data.life -= delta
		if is_instance_valid(data.node):
			data.node.scale += Vector3.ONE*delta*float(data.get("growth",2.0))
			if data.has("follow"):
				var follow:Vector3 = data.follow
				follow.y += delta*float(data.get("rise",0.0))
				data["follow"] = follow
				data.node.global_position = player.global_position+follow
			data.node.material_override.albedo_color.a = maxf(0,float(data.life)/float(data.duration))*.5
			if data.life<=0: data.node.queue_free()
		if data.life<=0: effects.remove_at(i)

func second_phase() -> void:
	if phase_started: return
	phase_started = true
	clear_attack()
	boss_state = "phase"
	boss_time = 3.2
	poise = 60
	invulnerability = 3.2
	hud.title = tr("ELDEN_PHASE_TITLE")
	hud.subtitle = tr("ELDEN_PHASE_LINE")
	create_tween().tween_property(hud,"title_alpha",1.0,.6)
	atmosphere.second_phase()
	_play(boss.animation,"lips_slam_windup",.15,true)
	boss.animation.speed_scale = 1.35/3.2
	for offset in [Vector3(-7,0,0),Vector3(7,0,0),Vector3(0,0,6)]:
		spawn_pool(boss.position+offset,2,4)

func show_message(key:String,duration:float) -> void:
	message = key
	message_time = duration

func update_camera(delta:float) -> void:
	if not fighting or stage.death_in_progress: return
	var focus := player.position+Vector3.UP*1.4
	var desired:Vector3
	if locked:
		var diff := boss.position-player.position
		diff.y = 0
		if diff.length_squared()>.01:
			var yaw := atan2(-diff.x,-diff.z)
			player.camera_yaw = lerp_angle(player.camera_yaw,yaw,minf(1,delta*7))
		var distance := clampf(diff.length()*.15+6.0,6.0,8.3)
		desired = player.position+player.orbita()*distance+player.arena_lado()*1.5+Vector3.UP*3.0
		focus = player.position.lerp(boss.position,0.36)+Vector3.UP*2.0
	else:
		var look := Vector2(Input.get_axis("look_left","look_right"),Input.get_axis("look_up","look_down"))
		player.camera_yaw -= look.x*delta*2.4
		player.camera_pitch = clampf(player.camera_pitch-look.y*delta,-.5,.35)
		desired = player.position+player.orbita()*6.3+player.arena_lado()*1.3+Vector3.UP*(2.6-player.camera_pitch*3)
		focus -= player.orbita()*2
	var query := PhysicsRayQueryParameters3D.create(player.position+Vector3.UP*1.5,desired,1,[player.get_rid()])
	var collision := get_world_3d().direct_space_state.intersect_ray(query)
	if not collision.is_empty(): desired = collision.position+collision.normal*.35
	camera.position = camera.position.lerp(desired,1-exp(-delta*9))
	camera.look_at(focus)
	player.camera_shake = maxf(0,player.camera_shake-delta*1.5)
	camera.position += Vector3(sin(elapsed*57),cos(elapsed*63),0)*player.camera_shake*.35

func _process(_delta:float) -> void:
	if not engaged: return
	if boss_hurt_time>0 and boss_state in ["windup","attack"]:
		var chest:int = boss.skeleton.find_bone("Chest")
		var weight := sin((1-boss_hurt_time/.42)*PI)*.14
		boss.skeleton.set_bone_pose_rotation(chest,boss.skeleton.get_bone_pose_rotation(chest)*Quaternion(Vector3.RIGHT,-weight))
	if blade_equipped and is_instance_valid(blade):
		_attach_prop(blade,hero_skeleton,"RightHand",blade_offset)
	if shield_equipped and is_instance_valid(shield):
		_attach_prop(shield,hero_skeleton,"LeftHand",shield_offset)
	if is_instance_valid(held_food):
		var skel:Skeleton3D = boss.skeleton
		var bone := skel.find_bone("Arm_Lower.R")
		var pose := skel.global_transform*skel.get_bone_global_pose(bone)
		held_food.global_position = pose.origin+pose.basis.y.normalized()*.6

func _pose_waiting_lips() -> void:
	var skeleton:Skeleton3D = boss.skeleton
	for side in ["L","R"]:
		var sign_side := 1.0 if side=="L" else -1.0
		var visual:Node3D = boss.get_node("Visual")
		var wrist := visual.global_transform*Vector3(sign_side*.40,-.03,.16)
		var pole := visual.global_transform*Vector3(sign_side*.9,.35,-.1)
		_pose_limb(skeleton,"Arm_Upper."+side,"Arm_Lower."+side,"",wrist,pole)

func _pose_ready_maycon() -> void:
	var visual:Node3D = player.visual
	var wrist := Vector3(.20,1.07,.33)
	if guarding or action == "heal": wrist = Vector3(.02,1.28,.38)
	_pose_limb(hero_skeleton,"LeftArm","LeftForeArm","LeftHand",visual.global_transform*wrist,visual.global_transform*Vector3(.6,1.15,.15))
	_pose_limb(hero_skeleton,"RightArm","RightForeArm","RightHand",visual.global_transform*Vector3(-.25,1.02,.36),visual.global_transform*Vector3(-.6,1.1,.15))

func _pose_limb(skeleton:Skeleton3D,upper:String,lower:String,hand:String,target:Vector3,pole:Vector3) -> void:
	var root_pose := skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(upper))
	var elbow_pose := skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(lower))
	var first_length := root_pose.origin.distance_to(elbow_pose.origin)
	var hand_index := skeleton.find_bone(hand) if not hand.is_empty() else -1
	var hand_position := elbow_pose.origin+elbow_pose.basis.y.normalized()*first_length
	if hand_index>=0:
		hand_position = (skeleton.global_transform*skeleton.get_bone_global_pose(hand_index)).origin
	var second_length := elbow_pose.origin.distance_to(hand_position)
	var direction := (target-root_pose.origin).normalized()
	var distance := clampf(root_pose.origin.distance_to(target),absf(first_length-second_length)+.001,first_length+second_length-.001)
	var along := (first_length*first_length-second_length*second_length+distance*distance)/(2*distance)
	var outward := pole-root_pose.origin
	outward = (outward-direction*outward.dot(direction)).normalized()
	var elbow := root_pose.origin+direction*along+outward*sqrt(maxf(0,first_length*first_length-along*along))
	_point_bone(skeleton,upper,elbow,elbow_pose.origin-root_pose.origin)
	elbow_pose = skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(lower))
	var lower_axis := elbow_pose.basis.y.normalized()
	if hand_index>=0:
		lower_axis = (skeleton.global_transform*skeleton.get_bone_global_pose(hand_index)).origin-elbow_pose.origin
	_point_bone(skeleton,lower,root_pose.origin+direction*distance,lower_axis)

func _point_bone(skeleton:Skeleton3D,name:String,target:Vector3,axis:Vector3 = Vector3.ZERO) -> void:
	var index := skeleton.find_bone(name)
	if index<0: return
	var pose := skeleton.global_transform*skeleton.get_bone_global_pose(index)
	var direction := (target-pose.origin).normalized()
	if axis.length_squared()<.001: axis = pose.basis.y
	var desired := Quaternion(axis.normalized(),direction)*pose.basis.get_rotation_quaternion()
	var parent := skeleton.get_bone_parent(index)
	var parent_pose := skeleton.global_transform
	if parent>=0: parent_pose *= skeleton.get_bone_global_pose(parent)
	skeleton.set_bone_pose_rotation(index,(parent_pose.basis.get_rotation_quaternion().inverse()*desired).normalized())

func _calibrate_props() -> void:
	if props_calibrated: return
	var previous:String = player.animation_player.current_animation
	var previous_time:float = player.animation_player.current_animation_position
	player.animation_player.play("elden/maycon_idle")
	player.animation_player.seek(0,true)
	var right_pose := hero_skeleton.global_transform*hero_skeleton.get_bone_global_pose(hero_skeleton.find_bone("RightHand"))
	var left_pose := hero_skeleton.global_transform*hero_skeleton.get_bone_global_pose(hero_skeleton.find_bone("LeftHand"))
	blade_offset = right_pose.basis.orthonormalized().inverse()*player.visual.global_basis.orthonormalized()*Basis.from_euler(Vector3(.4,0,0))
	shield_offset = left_pose.basis.orthonormalized().inverse()*player.visual.global_basis.orthonormalized()
	props_calibrated = true
	if not previous.is_empty():
		player.animation_player.play(previous)
		player.animation_player.seek(previous_time,true)

func _attach_prop(prop:Node3D,skeleton:Skeleton3D,bone_name:String,offset:Basis) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone<0: return
	var pose := skeleton.global_transform*skeleton.get_bone_global_pose(bone)
	var size := .78 if prop==shield else 1.0
	prop.global_transform = Transform3D(pose.basis.orthonormalized()*offset*size,pose.origin)

func _clear_hazards() -> void:
	clear_attack()
	for data in hazards+effects:
		if is_instance_valid(data.node): data.node.queue_free()
	hazards.clear()
	effects.clear()

func retry() -> void:
	if stage.death_in_progress: return
	stage.respawning = true
	stage.death_in_progress = true
	fighting = false
	boss.active = false
	player.control_enabled = false
	player.step_audio.stop()
	_clear_hazards()
	atmosphere.stop_score(.7)
	_play(player.animation_player,"maycon_death")
	hud.title = tr("ELDEN_DEATH")
	hud.subtitle = tr("ELDEN_RETRY")
	create_tween().tween_property(hud,"title_alpha",1.0,.7)
	await get_tree().create_timer(2.0,false).timeout
	await stage.fade_to(1.0,.55)
	_clear_blood()
	stage.hp = 100
	stamina = MAX_STAMINA
	flasks = max_flasks()
	phase_two = false
	phase_started = false
	poise = 60
	action = ""
	guarding = false
	attack_index = 0
	player.position = Vector3(0,.08,-1785)
	player.velocity = Vector3.ZERO
	boss.position = Vector3(0,0,-1807)
	boss.hp = boss.max_hp
	_play(player.animation_player,"maycon_idle",0)
	_play(boss.animation,"lips_idle",0)
	hud.title_alpha = 0
	hud.boss_trail = 1
	atmosphere.enter(false)
	camera.position = player.position+Vector3(1.5,3,6)
	camera.look_at(boss.position+Vector3.UP*2)
	await stage.fade_to(0.0,.6)
	stage.respawning = false
	stage.death_in_progress = false
	start_fight()

func victory() -> void:
	if not fighting: return
	fighting = false
	boss.active = false
	player.control_enabled = false
	player.velocity = Vector3.ZERO
	_clear_dodge_trail()
	_clear_hazards()
	atmosphere.stop_score(2.0)
	_play(boss.animation,"lips_death")
	hud.title = tr("ELDEN_VICTORY")
	hud.subtitle = tr("ELDEN_VICTORY_LINE")
	create_tween().tween_property(hud,"title_alpha",1.0,.7)
	atmosphere.play_sound("boom",boss.position,-14,.6)
	await get_tree().create_timer(3.3,false).timeout
	stage.burst(boss.global_position+Vector3.UP*2,Color("6e7270"),45)
	boss.visible = false
	atmosphere.leave()
	engaged = false
	hud.visible = false
	blade.visible = false
	shield.visible = false
	camera.fov = original_camera_fov
	stage.finish()
