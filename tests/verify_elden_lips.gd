extends SceneTree

var stage:Node3D
var battle:Node3D
var failures:int = 0

func _init() -> void:
	call_deferred("run")

func check(label:String,condition:bool) -> void:
	print(("OK " if condition else "FAIL ")+label)
	if not condition: failures += 1

func frames(count:int) -> void:
	for i in count: await physics_frame

func run() -> void:
	root.get_node("Global").debug_resgate_cabeludo_boss = true
	stage = load("res://scenes/3D/resgate_cabeludo/resgate_cabeludo.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	await frames(3)
	battle = stage.final_battle
	check("cinematic freezes combat",battle.intro and not battle.fighting and not stage.player.control_enabled)
	check("boss waits in front of cage",stage.boss.position.z>stage.cage.position.z)
	check("Blender swordplay animation imported",stage.player.animation_player.has_animation("elden/maycon_slash"))
	check("world transformation starts gradually",battle.atmosphere.world_blend<.02 and battle.atmosphere.environment.fog_density<.002)
	var pause_menu:CanvasLayer = stage.get_node("PauseFofo")
	var intro_position:Vector3 = stage.player.position
	var intro_blend:float = battle.atmosphere.world_blend
	pause_menu._toggle()
	await frames(30)
	check("pause freezes cinematic and world transformation",stage.player.position==intro_position and battle.atmosphere.world_blend==intro_blend and pause_menu.can_process())
	pause_menu._toggle()
	await frames(240)
	check("cinematic picks up sword first",battle.intro and battle.blade_equipped and not battle.shield_equipped)
	await frames(55)
	check("cinematic picks up shield separately",battle.equipped and battle.shield_equipped)
	await frames(65)
	check("cinematic presents Elden Lips title",battle.hud.title==stage.tr("ELDEN_BOSS_NAME") and battle.hud.title_alpha>0)
	await frames(360)
	check("cinematic starts combat naturally",battle.fighting and not battle.intro and stage.player.control_enabled)
	await frames(2)
	await process_frame
	await process_frame
	check("equipment follows both hands",battle.equipped and battle.blade.position.distance_to(stage.player.position)<4 and battle.shield.position.distance_to(stage.player.position)<4)
	check("arena uses a reduced stamina reserve without pentagrams",stage.pentagrams==0 and battle.stamina==battle.MAX_STAMINA and battle.stamina<=50)
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("pt")
	check("Portuguese HUD calls the resource estamina",stage.tr("ELDEN_VIGOR")=="ESTAMINA" and stage.tr("ELDEN_EXHAUSTED")=="Recupere a estamina.")
	TranslationServer.set_locale(locale)
	battle.boss_time = 999
	battle.invulnerability = 0
	stage.player.visual.rotation.y = PI
	battle.guarding = true
	battle.guard_time = .10
	var health:float = stage.hp
	var poise:float = battle.poise
	var expected_damage:float = 18.0 if root.get_node("Global").is_easy_mode() else 30.0
	battle.take_hit(24,stage.player.position+Vector3(0,0,-4))
	check("timed shield reduces incoming damage by only fifteen percent",is_equal_approx(health-stage.hp,expected_damage*.85) and battle.poise<poise)
	check("timed shield still allows blood and recoil",not battle.blood_nodes.is_empty() and not battle.hud.blood_stains.is_empty() and battle.hero_knockback.length_squared()>0)
	battle._clear_blood()
	stage.hp = health
	battle.invulnerability = 0
	battle.guard_time = 1.0
	battle.stamina = battle.MAX_STAMINA
	battle.take_hit(24,stage.player.position+Vector3(0,0,-4))
	check("held shield has the same fifteen percent damage reduction",is_equal_approx(health-stage.hp,expected_damage*.85))
	stage.hp = health
	battle.invulnerability = 0
	battle.guarding = false
	var hero_before:Vector3 = stage.player.position
	battle.take_hit(24,stage.player.position+Vector3(0,0,-4))
	check("unblocked Lips hit deals twenty five percent more damage",is_equal_approx(health-stage.hp,expected_damage))
	check("Maycon has a dedicated damage reaction",stage.player.animation_player.current_animation=="elden/maycon_hurt")
	check("Maycon damage sprays blood and stains screen",not battle.blood_nodes.is_empty() and not battle.hud.blood_stains.is_empty())
	await frames(8)
	check("Maycon recoils away from hit source",stage.player.position.z>hero_before.z+.1)
	stage.hp = 100
	battle.action = ""
	battle.stamina = battle.MAX_STAMINA
	battle.invulnerability = 0
	battle.hero_knockback = Vector3.ZERO
	stage.player.velocity = Vector3.ZERO
	var dash_start:Vector3 = stage.player.position
	battle.dodge()
	check("dash immediately spends stamina and emits the previous gameplay trail",battle.stamina==battle.MAX_STAMINA-24 and not stage.player.dash_ghosts.is_empty() and not stage.player.fart_puffs.is_empty())
	await frames(9)
	var dodge_hp:float = stage.hp
	battle.take_hit(30,stage.boss.position)
	check("dodge i-frames prevent damage",stage.hp==dodge_hp)
	check("dodge consumes stamina",battle.stamina<battle.MAX_STAMINA and stage.pentagrams==0)
	await frames(45)
	check("Maycon dash has a short travel distance",stage.player.position.distance_to(dash_start)>1 and stage.player.position.distance_to(dash_start)<3.2)
	check("dash trail fades instead of accumulating",stage.player.dash_ghosts.is_empty() and stage.player.fart_puffs.is_empty())
	battle.action = ""
	battle.request_action("dash_resgate")
	battle.action = ""
	var exhausted:float = battle.stamina
	battle.request_action("dash_resgate")
	check("two consecutive dashes exhaust the reserve and block a third",exhausted<24 and battle.stamina==exhausted and battle.action.is_empty())
	battle.attack(false)
	check("exhaustion also prevents sword attacks",battle.action.is_empty() and battle.stamina==exhausted)
	battle.action = ""
	battle.stamina = battle.MAX_STAMINA
	stage.player.position = stage.boss.position+Vector3(0,.08,3.5)
	stage.player.visual.rotation.y = PI
	var boss_health:int = stage.boss.hp
	var blood_before:int = battle.blood_nodes.size()
	battle.weapon_contact(false)
	check("wooden weapon damages boss in front",stage.boss.hp<boss_health)
	check("light sword damage requires a sustained boss fight",boss_health-stage.boss.hp<=8 and stage.boss.max_hp/(boss_health-stage.boss.hp)>=20)
	check("Lips damage sprays blood",battle.blood_nodes.size()>blood_before and battle.boss_knockback.z<0)
	var rising_blood := false
	var waiting_stains := false
	for effect in battle.blood_nodes.slice(blood_before):
		if effect.kind=="spray" and effect.node.direction.y>.8:
			rising_blood = effect.node.initial_velocity_min>6 and effect.node.gravity.y<0 and effect.node.particle_flag_align_y and effect.node.mesh.material.vertex_color_use_as_albedo
		if effect.kind=="mark": waiting_stains = waiting_stains or not effect.node.visible
	check("Lips blood jets upward in elongated drops before staining the floor",rising_blood and waiting_stains)
	var hit_sound := false
	var pain_sound := false
	for sound in battle.atmosphere.sound_pool:
		if sound.stream:
			hit_sound = hit_sound or sound.stream.resource_path.contains("wood_body_")
			pain_sound = pain_sound or sound.stream.resource_path.contains("lips_pain_")
	check("boss damage separates wooden contact and pain",hit_sound and pain_sound)
	check("Lips has a dedicated damage reaction",battle.boss_hurt_time>0 and stage.boss.animation.current_animation=="elden/lips_hurt")
	var boss_before:Vector3 = stage.boss.position
	battle.boss_state = "recover"
	battle.boss_time = 999
	await frames(12)
	check("Lips recoils slightly away from sword",stage.boss.position.z<boss_before.z-.1 and stage.boss.position.distance_to(boss_before)<.6)
	await frames(78)
	var landed_stains := false
	for effect in battle.blood_nodes:
		if effect.kind=="mark": landed_stains = landed_stains or effect.node.visible
	check("airborne blood leaves visible floor stains after falling",landed_stains)
	boss_health = stage.boss.hp
	stage.player.visual.rotation.y = 0
	battle.weapon_contact(false)
	check("weapon does not hit enemies behind Maycon",stage.boss.hp==boss_health)
	battle.attack_index = 1
	battle.prepare_attack()
	var target:Vector3 = battle.attack_target
	stage.player.position.x += 5
	check("slam target is fixed during telegraph",battle.attack_target==target)
	battle.clear_attack()
	stage.player.position = Vector3(0,.08,-1794)
	stage.boss.position = Vector3(0,0,-1804)
	battle.attack_index = 3
	battle.prepare_attack()
	check("Lips dash has a telegraph before movement",battle.boss_attack=="dash" and battle.boss_state=="windup" and is_instance_valid(battle.warning))
	var dash_target:Vector3 = battle.attack_target
	await frames(12)
	battle.spawn_projectile(Vector3(10,0,-1790))
	var projectile:Node3D = battle.hazards.back().node
	var projectile_position:Vector3 = projectile.position
	var attack_time:float = battle.boss_time
	var atmosphere_time:float = battle.atmosphere.time
	var score_time:float = battle.atmosphere.score_timer.time_left
	var paused_stamina:float = battle.stamina
	pause_menu._toggle()
	await frames(45)
	battle.request_action("elden_attack")
	check("pause freezes Lips windup and projectiles",battle.boss_time==attack_time and projectile.position==projectile_position)
	check("pause freezes storm and music repeat timer",battle.atmosphere.time==atmosphere_time and battle.atmosphere.score_timer.time_left==score_time)
	check("pause blocks combat actions and keeps resume menu active",battle.stamina==paused_stamina and pause_menu.can_process())
	pause_menu._toggle()
	stage.player.position.x += 5
	await frames(34)
	check("Lips closes distance with a fixed dash and a visible trail",battle.boss_state=="attack" and battle.attack_target==dash_target and not stage.player.dash_ghosts.is_empty())
	var paused_boss:Vector3 = stage.boss.position
	var paused_animation:float = stage.boss.animation.current_animation_position
	projectile_position = projectile.position
	pause_menu._toggle()
	await frames(30)
	check("pause freezes an active dash and boss animation",stage.boss.position==paused_boss and stage.boss.animation.current_animation_position==paused_animation and projectile.position==projectile_position)
	pause_menu._toggle()
	await frames(35)
	check("Lips dash resumes into recovery at the announced endpoint",stage.boss.position.distance_to(dash_target)<.05 and battle.boss_state=="recover")
	check("Lips dash trail fades after recovery",stage.player.dash_ghosts.is_empty())
	battle.clear_attack()
	battle.second_phase()
	await frames(205)
	check("second phase resumes combat",battle.phase_two and battle.boss_state!="phase")
	check("hazards are bounded",battle.hazards.size()<=12)
	battle.action = ""
	battle.flasks = 2
	stage.hp = 20
	battle.request_action("elden_heal")
	await frames(88)
	check("healing restores health and consumes one flask",stage.hp>20 and battle.flasks==1)
	battle.boss_time = 999
	stage.hp = 5
	battle.invulnerability = 0
	battle.guarding = true
	battle.guard_time = 1.0
	battle.stamina = battle.MAX_STAMINA
	stage.player.visual.rotation.y = PI
	battle.take_hit(24,stage.player.position+Vector3(0,0,-4))
	check("shield reduction does not prevent lethal damage",stage.hp==0 and stage.death_in_progress)
	await frames(250)
	check("death retries directly in arena",battle.fighting and stage.player.arena_mode and stage.player.position.z<-1778)
	check("retry resets both phases and resources",not battle.phase_two and stage.boss.hp==stage.boss.max_hp and battle.flasks==2 and stage.hp==100)
	check("retry restores the smaller stamina reserve",battle.stamina==battle.MAX_STAMINA)
	check("retry resets storm phase",battle.atmosphere.phase_heat==0 and battle.atmosphere.rain.emitting)
	check("retry clears blood and knockback",battle.blood_nodes.is_empty() and battle.hud.blood_stains.is_empty() and battle.hero_knockback==Vector3.ZERO and battle.boss_knockback==Vector3.ZERO)
	check("rain is light and lightning remains intermittent",battle.atmosphere.rain.amount<=180 and battle.atmosphere.storm_timer>0)
	var before:float = battle.atmosphere.environment.fog_density
	await frames(45)
	check("weather fog evolves over time",absf(before-battle.atmosphere.environment.fog_density)>.00001)
	check("power animations are distinct",stage.boss.animation.has_animation("elden/lips_throw") and stage.boss.animation.has_animation("elden/lips_sweep_windup"))
	for base_damage in [18.0,20.0,34.0,10.0]:
		stage.hp = 100
		battle.invulnerability = 0
		battle.guarding = false
		var multiplier:float = .75 if root.get_node("Global").is_easy_mode() else 1.25
		battle.take_hit(base_damage,stage.boss.global_position,true)
		check("Lips damage %.0f gains twenty five percent including unblockable powers" % base_damage,is_equal_approx(100-stage.hp,base_damage*multiplier))
	stage.hp = 100
	battle.invulnerability = 1
	# Victory must call the existing ending flow once, after the presentation.
	battle.victory()
	await frames(210)
	check("victory reaches existing rescue ending",stage.finishing and not battle.engaged)
	# Deixe a cinemática concluir: liberar a fase enquanto seus timers aguardam
	# interrompe corrotinas e produz falsos avisos de recursos no encerramento.
	for i in 3600:
		if not is_instance_valid(stage): break
		await frames(1)
	check("rescue cinematic reaches ending bridge",is_instance_valid(current_scene) and current_scene.scene_file_path=="res://scenes/3D/resgate_cabeludo/ending_bridge.tscn")
	if is_instance_valid(stage): stage.queue_free()
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(2)
	check("scoped inputs are released on exit",not InputMap.has_action("elden_guard"))
	print("ELDEN LIPS: %d failures" % failures)
	quit(1 if failures else 0)
