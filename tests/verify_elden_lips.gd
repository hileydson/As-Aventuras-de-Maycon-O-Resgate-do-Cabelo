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
	check("arena uses stamina without charging pentagrams",stage.pentagrams==0 and battle.stamina==100)
	battle.boss_time = 999
	battle.invulnerability = 0
	stage.player.visual.rotation.y = PI
	battle.guarding = true
	battle.guard_time = .10
	var health:float = stage.hp
	var poise:float = battle.poise
	battle.take_hit(24,stage.player.position+Vector3(0,0,-4))
	check("timed frontal block prevents damage and removes poise",stage.hp==health and battle.poise<poise)
	battle.invulnerability = 0
	battle.guarding = false
	battle.take_hit(24,stage.player.position+Vector3(0,0,-4))
	check("unblocked hit removes health",stage.hp<health)
	check("Maycon has a dedicated damage reaction",stage.player.animation_player.current_animation=="elden/maycon_hurt")
	stage.hp = 100
	battle.action = ""
	battle.stamina = 100
	battle.dodge()
	await frames(9)
	var dodge_hp:float = stage.hp
	battle.take_hit(30,stage.boss.position)
	check("dodge i-frames prevent damage",stage.hp==dodge_hp)
	check("dodge consumes stamina",battle.stamina<100 and stage.pentagrams==0)
	await frames(45)
	battle.action = ""
	battle.stamina = 100
	stage.player.position = stage.boss.position+Vector3(0,.08,3.5)
	stage.player.visual.rotation.y = PI
	var boss_health:int = stage.boss.hp
	battle.weapon_contact(false)
	check("wooden weapon damages boss in front",stage.boss.hp<boss_health)
	var hit_sound := false
	var pain_sound := false
	for sound in battle.atmosphere.sound_pool:
		if sound.stream:
			hit_sound = hit_sound or sound.stream.resource_path.contains("wood_body_")
			pain_sound = pain_sound or sound.stream.resource_path.contains("lips_pain_")
	check("boss damage separates wooden contact and pain",hit_sound and pain_sound)
	check("Lips has a dedicated damage reaction",battle.boss_hurt_time>0 and stage.boss.animation.current_animation=="elden/lips_hurt")
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
	stage.respawn()
	await frames(250)
	check("death retries directly in arena",battle.fighting and stage.player.arena_mode and stage.player.position.z<-1778)
	check("retry resets both phases and resources",not battle.phase_two and stage.boss.hp==stage.boss.max_hp and battle.flasks==2 and stage.hp==100)
	check("retry resets storm phase",battle.atmosphere.phase_heat==0 and battle.atmosphere.rain.emitting)
	var before:float = battle.atmosphere.environment.fog_density
	await frames(45)
	check("weather fog evolves over time",absf(before-battle.atmosphere.environment.fog_density)>.00001)
	check("power animations are distinct",stage.boss.animation.has_animation("elden/lips_throw") and stage.boss.animation.has_animation("elden/lips_sweep_windup"))
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
