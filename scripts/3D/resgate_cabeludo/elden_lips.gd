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
const LIGHT_DAMAGE := 16
const HEAVY_DAMAGE := 28
const DODGE_TIME := 0.62
const DODGE_IFRAMES := Vector2(0.07,0.40)
const INPUT_ACTIONS := ["elden_left","elden_right","elden_up","elden_down","elden_guard","elden_attack","elden_heavy","elden_dodge","elden_lock","elden_heal"]
var stage:Node3D
var player:CharacterBody3D
var boss:Node3D
var camera:Camera3D
var engaged:bool = false
var fighting:bool = false
var intro:bool = false
var phase_two:bool = false
var locked:bool = true
var stamina:float = 100
var stamina_delay:float = 0
var flasks:int = 2
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

func setup(owner_stage:Node3D) -> void:
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
		"elden_dodge":[KEY_SPACE],"elden_lock":[KEY_TAB,MOUSE_BUTTON_MIDDLE,JOY_BUTTON_RIGHT_STICK],
		"elden_heal":[KEY_R,JOY_BUTTON_Y]}
	for name in INPUT_ACTIONS:
		if InputMap.has_action(name): continue
		InputMap.add_action(name)
		created_actions.append(name)
		for code in bindings[name]:
			var event:InputEvent
			if code >= 32:
				event = InputEventKey.new()
				event.physical_keycode = code
			elif name == "elden_attack" or code == MOUSE_BUTTON_RIGHT and name == "elden_guard" or code == MOUSE_BUTTON_MIDDLE and name == "elden_lock":
				event = InputEventMouseButton.new()
				event.button_index = code
			else:
				event = InputEventJoypadButton.new()
				event.button_index = code
			InputMap.action_add_event(name,event)

func _build_touch_controls() -> void:
	for i in 8:
		var touch := Button.new()
		var actions := ["ui_left","ui_right","ui_up","ui_down","soco_resgate","elden_guard","dash_resgate","elden_heal"]
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
	add_child(blade)
	add_child(shield)
	blade.position = Vector3(0.8,.12,-1786)
	blade.rotation = Vector3(PI*.5,0,.3)
	shield.position = Vector3(-.6,.15,-1786)
	shield.rotation.x = PI*.5
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
	intro_tween.tween_interval(1.05)
	intro_tween.tween_callback(func():
		equipped = true
		atmosphere.play_sound("equip",player.global_position,-13,1.3))
	intro_tween.tween_interval(1.15)
	intro_tween.tween_callback(func():
		_play(player.animation_player,"maycon_idle")
		camera.global_position = boss.global_position+Vector3(3.8,2.8,6.5)
		camera.look_at(boss.global_position+Vector3.UP*2.5)
		atmosphere.play_sound("roar",boss.global_position,-14,.75)
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

func _play(animator:AnimationPlayer,key:String,blend:float = .12) -> void:
	if animator and animator.has_animation("elden/"+key) and animator.current_animation != "elden/"+key:
		animator.speed_scale = 1
		animator.play("elden/"+key,blend)

func start_fight() -> void:
	if not engaged or fighting: return
	if intro_tween and intro_tween.is_running(): intro_tween.call_deferred("kill")
	equipped = true
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
	stamina = 100
	flasks = 2
	invulnerability = 1
	boss_state = "stalk"
	boss_time = 2.0
	hud.hint_time = 22
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
	if intro and event.is_action_pressed("ui_accept"):
		start_fight()
		get_viewport().set_input_as_handled()
		return
	if not fighting or stage.death_in_progress: return
	for name in ["soco_resgate","dash_resgate","elden_attack","elden_heavy","elden_dodge","elden_lock","elden_heal"]:
		if event.is_action_pressed(name):
			request_action(name)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and not locked:
		player.camera_yaw -= event.relative.x*.0035
		player.camera_pitch = clampf(player.camera_pitch-event.relative.y*.002,-.5,.35)

func request_action(name:String) -> void:
	if not fighting or stage.death_in_progress: return
	if name == "elden_lock":
		locked = not locked
		return
	if not action.is_empty(): return
	if guarding and name not in ["elden_dodge","dash_resgate"]: return
	if name in ["elden_dodge","dash_resgate"]:
		guarding = false
	if name in ["elden_attack","soco_resgate"]: attack(false)
	elif name == "elden_heavy": attack(true)
	elif name in ["elden_dodge","dash_resgate"]: dodge()
	elif name == "elden_heal" and flasks>0 and stage.hp<100:
		flasks -= 1
		set_action("heal",1.3)
		_play(player.animation_player,"maycon_guard")

func spend_stamina(amount:float) -> bool:
	if stamina < amount:
		show_message("ELDEN_EXHAUSTED",1.2)
		return false
	stamina -= amount
	stamina_delay = .7
	return true

func set_action(name:String,duration:float) -> void:
	action = name
	action_time = duration
	action_length = duration
	action_contact = false

func attack(heavy:bool) -> void:
	if not spend_stamina(30 if heavy else 18): return
	set_action("heavy" if heavy else "slash",1.15 if heavy else .72)
	_play(player.animation_player,"maycon_"+action,.06)
	atmosphere.play_sound("swing",player.global_position,-17,1.2 if not heavy else .8)

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
	atmosphere.play_sound("swing",player.global_position,-20,1.5)

func physics_player(delta:float) -> void:
	if not fighting or stage.death_in_progress:
		player.velocity = Vector3.ZERO
		return
	invulnerability = maxf(0,invulnerability-delta)
	stamina_delay = maxf(0,stamina_delay-delta)
	var wants_guard := Input.is_action_pressed("elden_guard") and action.is_empty() and stamina>0
	guard_time = guard_time+delta if wants_guard else 0.0
	guarding = wants_guard
	if stamina_delay<=0 and action.is_empty(): stamina = minf(100,stamina+delta*(9 if guarding else 29))
	var input := movement_input()
	var direction:Vector3 = (player.arena_lado()*input.x-player.orbita()*-input.y).normalized()
	var speed := 3.0 if guarding else 5.8
	if not action.is_empty():
		action_time -= delta
		var progress := 1.0-action_time/action_length
		speed = .9
		if action == "dodge":
			direction = dodge_direction
			speed = 12.0 if progress < .67 else 4.0
			invulnerability = maxf(invulnerability,.025) if progress*DODGE_TIME>=DODGE_IFRAMES.x and progress*DODGE_TIME<=DODGE_IFRAMES.y else invulnerability
		elif action in ["slash","heavy"] and not action_contact and progress> (.50 if action=="heavy" else .40):
			action_contact = true
			weapon_contact(action=="heavy")
		elif action == "heal" and not action_contact and progress>.65:
			action_contact = true
			stage.hp = minf(100,stage.hp+45)
			stage.sound("heal")
			stage.burst(player.global_position+Vector3.UP,Color("99cda0"),16)
		if action_time<=0: action = ""
	if action in ["hurt","guard_break"]: speed = 0
	player.velocity.x = move_toward(player.velocity.x,direction.x*speed,delta*45)
	player.velocity.z = move_toward(player.velocity.z,direction.z*speed,delta*45)
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
	player._update_footsteps(delta,direction,speed)
	player.visual.visible = true
	if player.position.y < -5: stage.respawn()

func weapon_contact(heavy:bool) -> void:
	var diff := boss.global_position-player.global_position
	diff.y = 0
	var facing:Vector3 = player.visual.global_basis.z.normalized()
	if diff.length()>4.4 or facing.dot(diff.normalized())<.35: return
	var at:Vector3 = player.global_position+facing*2.6+Vector3.UP*1.6
	if boss_state == "phase" or boss.hp<=0: return
	var damage := HEAVY_DAMAGE if heavy else LIGHT_DAMAGE
	if boss_state == "recover": damage = int(damage*1.2)
	boss.hp = maxi(0,boss.hp-damage)
	poise -= 32 if heavy else 12
	atmosphere.play_sound("block",at,-12,1.15)
	stage.burst(at,Color("e6ca8c"),14)
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
	if guarding and frontal and not unblockable:
		var perfect := guard_time<=.19
		var cost := 8.0 if perfect else damage*.95
		if stamina>=cost:
			spend_stamina(cost)
			atmosphere.play_sound("block",player.global_position,-9,.8)
			stage.burst(player.global_position+Vector3.UP,Color("a3dfda"),12)
			player.camera_shake = .12
			if perfect:
				poise -= 45
				show_message("ELDEN_PERFECT_BLOCK",1.2)
				if poise<=0: stagger()
			else:
				stage.hp = maxf(1,stage.hp-damage*.12)
			invulnerability = .25
			return
		stamina = 0
		guarding = false
		set_action("guard_break",1.0)
		show_message("ELDEN_GUARD_BREAK",1.5)
	else:
		set_action("hurt",.48)
	if Global.is_easy_mode(): damage *= .6
	stage.hp = maxf(0,stage.hp-damage)
	invulnerability = .75
	player.camera_shake = .3
	hud.damage_flash = 1
	atmosphere.play_sound("slam",player.global_position,-12,1.3)
	_play(player.animation_player,"maycon_guard",.02)
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
	_play(boss.animation,"lips_guard",.08)

func _physics_process(delta:float) -> void:
	if not engaged: return
	elapsed += delta
	_update_effects(delta)
	if not fighting or stage.death_in_progress: return
	message_time -= delta
	if message_time<=0: message = ""
	if hit_pause>0:
		hit_pause -= delta
		return
	_update_hazards(delta)
	if not fighting or stage.death_in_progress: return
	_update_boss(delta)

func _update_boss(delta:float) -> void:
	boss_time -= delta
	var to_player := player.global_position-boss.global_position
	to_player.y = 0
	if boss_state in ["stalk","windup"] and to_player.length_squared()>.01:
		boss.get_node("Visual").rotation.y = lerp_angle(boss.get_node("Visual").rotation.y,atan2(to_player.x,to_player.z),delta*3)
	if boss_state == "stalk":
		if to_player.length()>5.3:
			boss.position += to_player.normalized()*delta*(3.5 if phase_two else 2.7)
			_play(boss.animation,"lips_walk")
		else: _play(boss.animation,"lips_idle")
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
			atmosphere.play_sound("swing",boss.global_position,-10,.75)
			stage.burst(boss.global_position+front*3+Vector3.UP,Color("e6b85e"),12)
		elif boss_attack == "tomato" and progress>.35 and not boss_contact:
			boss_contact = true
			for offset in [-2.4,0.0,2.4]:
				spawn_projectile(attack_target+Vector3(offset,0,0))
		if boss_time<=0:
			boss.position.y = 0
			clear_attack()
			boss_state = "recover"
			boss_time = 1.0 if phase_two else 1.65
			_play(boss.animation,"lips_idle")
	elif boss_state == "recover" and boss_time<=0:
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
	var sequence := ["sweep","slam","tomato","sweep","tomato","slam"]
	boss_attack = sequence[attack_index%sequence.size()]
	attack_index += 1
	if player.global_position.distance_to(boss.global_position)>10 and boss_attack=="sweep": boss_attack = "slam"
	boss_state = "windup"
	boss_time = 1.35 if boss_attack=="slam" else 1.15
	if phase_two: boss_time *= .86
	attack_target = player.global_position
	attack_target.y = 0
	attack_origin = boss.position
	boss_contact = false
	_play(boss.animation,"lips_slam" if boss_attack=="slam" else "lips_heavy",.12)
	held_food = (FRIES if boss_attack=="sweep" else TOMATO).instantiate()
	add_child(held_food)
	_fit_food(held_food,2.6 if boss_attack=="sweep" else 2.1)
	warning = ring(attack_target if boss_attack!="sweep" else boss.position,4.6 if boss_attack=="slam" else 3.2,Color("d29a68"))
	show_message("ELDEN_WARN_SLAM" if boss_attack=="slam" else "ELDEN_WARN_SWEEP" if boss_attack=="sweep" else "ELDEN_WARN_TOMATO",boss_time)
	atmosphere.play_sound("roar",boss.position,-20,1.2 if phase_two else 1)

func execute_attack() -> void:
	boss_state = "attack"
	boss_length = .85 if boss_attack=="slam" else .9
	boss_time = boss_length
	attack_origin = boss.position
	# O alvo do salto fica fixo desde o aviso: não persegue Maycon no ar.
	_play(boss.animation,"lips_slash" if boss_attack=="sweep" else "lips_slam",.04)

func clear_attack() -> void:
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
	atmosphere.play_sound("boom",at,-16,.8)
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
	atmosphere.play_sound("swing",origin,-14,1.1)

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
			data.node.scale += Vector3.ONE*delta*2.0
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
	_play(boss.animation,"lips_heavy")
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
	if intro or boss_state in ["stalk","recover"]:
		_pose_waiting_lips()
	if equipped and is_instance_valid(blade):
		if not props_calibrated: _calibrate_props()
		if action.is_empty() or action == "heal":
			_pose_ready_maycon()
		_attach_prop(blade,hero_skeleton,"RightHand",blade_offset)
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
	prop.global_transform = Transform3D(pose.basis.orthonormalized()*offset,pose.origin)

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
	await get_tree().create_timer(2.0).timeout
	await stage.fade_to(1.0,.55)
	stage.hp = 100
	stamina = 100
	flasks = 2
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
	atmosphere.enter()
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
	_clear_hazards()
	atmosphere.stop_score(2.0)
	_play(boss.animation,"lips_death")
	hud.title = tr("ELDEN_VICTORY")
	hud.subtitle = tr("ELDEN_VICTORY_LINE")
	create_tween().tween_property(hud,"title_alpha",1.0,.7)
	atmosphere.play_sound("boom",boss.position,-14,.6)
	await get_tree().create_timer(3.3).timeout
	atmosphere.leave()
	engaged = false
	hud.visible = false
	blade.visible = false
	shield.visible = false
	camera.fov = original_camera_fov
	stage.finish()
