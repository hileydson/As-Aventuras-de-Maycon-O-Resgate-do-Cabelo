extends Control

# Layout proporcional ao viewport, sem fontes pequenas presas a uma resolução.
var battle:Node3D
var title:String = ""
var subtitle:String = ""
var title_alpha:float = 0.0
var letterbox:float = 0.0
var damage_flash:float = 0.0
var boss_trail:float = 1.0
var hint_time:float = 18.0
var font:Font = ThemeDB.fallback_font
var gold := Color("c6b88c")
var ivory := Color("e0dac9")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta:float) -> void:
	if battle == null or not battle.engaged:
		return
	damage_flash = maxf(0.0, damage_flash - delta * 1.6)
	if battle.fighting:
		hint_time = maxf(0.0, hint_time - delta)
		boss_trail = move_toward(boss_trail, float(battle.boss.hp) / float(battle.boss.max_hp), delta * 0.15)
	queue_redraw()

func text_center(text:String, center:Vector2, font_size:int, color:Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func meter(rect:Rect2, value:float, color:Color, trail:float = -1.0) -> void:
	draw_rect(rect.grow(3), Color("0c0d10"))
	draw_rect(rect.grow(2), Color(gold, 0.65), false, 1.0)
	if trail >= 0:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(trail, 0, 1), rect.size.y)), Color("857445"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(value, 0, 1), rect.size.y)), color)
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(1,1,1,0.18))

func _draw() -> void:
	if battle == null or not battle.engaged:
		return
	var s := size
	var unit := clampf(s.y / 720.0, 0.7, 1.65)
	# Vinheta por faixas suaves: nenhum shader novo ou textura de tela necessária.
	for i in range(12):
		var border := float(12-i) * 5.0 * unit
		draw_rect(Rect2(Vector2.ZERO,s).grow(-border), Color(0.008,0.008,0.015,0.015 + damage_flash*0.018), false, 10.0*unit)
	if damage_flash > 0:
		draw_rect(Rect2(Vector2.ZERO,s),Color(0.45,0.015,0.02,damage_flash*0.13))
	if letterbox > 0:
		var h := s.y * 0.105 * letterbox
		draw_rect(Rect2(0,0,s.x,h),Color.BLACK)
		draw_rect(Rect2(0,s.y-h,s.x,h),Color.BLACK)
	if battle.fighting and not battle.stage.death_in_progress:
		var x := 36.0*unit
		var width := minf(300.0*unit,s.x*0.35)
		meter(Rect2(x,35*unit,width,16*unit),battle.stage.hp/100.0,Color("a52b35"))
		meter(Rect2(x,61*unit,width,8*unit),battle.stamina/100.0,Color("778e58"))
		draw_string(font,Vector2(x,90*unit),tr("ELDEN_VIGOR"),HORIZONTAL_ALIGNMENT_LEFT,-1,int(12*unit),gold)
		draw_string(font,Vector2(x,120*unit),tr("ELDEN_FLASK").format({"count":battle.flasks}),HORIZONTAL_ALIGNMENT_LEFT,-1,int(17*unit),ivory)
		var boss_width := minf(s.x*0.74,960*unit)
		var bx := (s.x-boss_width)*0.5
		var by := s.y-62*unit
		draw_string(font,Vector2(bx,by-15*unit),tr("ELDEN_BOSS_PHASE2") if battle.phase_two else tr("ELDEN_BOSS_NAME"),HORIZONTAL_ALIGNMENT_LEFT,-1,int(23*unit),ivory)
		meter(Rect2(bx,by,boss_width,12*unit),float(battle.boss.hp)/battle.boss.max_hp,Color("9f2932"),boss_trail)
		if battle.locked and not battle.camera.is_position_behind(battle.boss.global_position+Vector3.UP*2.7):
			var aim:Vector2 = battle.camera.unproject_position(battle.boss.global_position+Vector3.UP*2.7)
			draw_circle(aim,3.0*unit,ivory)
			draw_arc(aim,9.0*unit,0,TAU,24,Color(ivory,0.6),1.0)
		if hint_time > 0:
			var hint := tr("ELDEN_CONTROLS_PAD") if battle.using_gamepad else tr("ELDEN_CONTROLS")
			var hint_size := int(14*unit)
			var hint_color := Color(ivory,minf(1,hint_time))
			if font.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,hint_size).x>s.x*.92:
				var parts := hint.split(" · ")
				var middle := ceili(parts.size()*.5)
				text_center(" · ".join(parts.slice(0,middle)),Vector2(s.x*.5,s.y-145*unit),hint_size,hint_color)
				text_center(" · ".join(parts.slice(middle)),Vector2(s.x*.5,s.y-126*unit),hint_size,hint_color)
			else:
				text_center(hint,Vector2(s.x*0.5,s.y-130*unit),hint_size,hint_color)
		if not battle.message.is_empty():
			text_center(tr(battle.message),Vector2(s.x*.5,s.y*.22),int(20*unit),gold)
	if title_alpha > 0:
		var fs := int(minf(76*unit,s.x*0.10))
		draw_rect(Rect2(0,s.y*.38,s.x,s.y*.24),Color(0.01,0.008,0.012,title_alpha*0.60))
		text_center(title,Vector2(s.x*.5,s.y*.52),fs,Color(gold,title_alpha))
		var line_width := minf(s.x*.4,420*unit)
		draw_line(Vector2((s.x-line_width)/2,s.y*.55),Vector2((s.x+line_width)/2,s.y*.55),Color(gold,title_alpha*.5),1)
		text_center(subtitle,Vector2(s.x*.5,s.y*.61),int(19*unit),Color(ivory,title_alpha))
	if battle.intro:
		text_center(tr("ELDEN_SKIP"),Vector2(s.x*.5,s.y-35*unit),int(13*unit),Color(ivory,.7))
