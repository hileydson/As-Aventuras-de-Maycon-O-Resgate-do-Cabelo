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
var blood_stains:Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta:float) -> void:
	if battle == null or not battle.engaged:
		return
	damage_flash = maxf(0.0, damage_flash - delta * 1.6)
	for i in range(blood_stains.size()-1,-1,-1):
		var stain := blood_stains[i]
		stain.life -= delta
		stain.position.y += delta*.002
		if stain.life<=0: blood_stains.remove_at(i)
	if battle.fighting:
		hint_time = maxf(0.0, hint_time - delta)
		boss_trail = move_toward(boss_trail, float(battle.boss.hp) / float(battle.boss.max_hp), delta * 0.15)
	queue_redraw()

func splash_blood(strength:float = 1.0) -> void:
	for i in maxi(2,int(9*strength)):
		var position := Vector2(randf_range(.08,.92),randf_range(.08,.92))
		# As bordas recebem a maior parte das manchas; o alvo e as barras ficam legíveis.
		if i%3!=0:
			if i%2==0: position.x = randf_range(.02,.13) if randf()<.5 else randf_range(.87,.98)
			else: position.y = randf_range(.03,.12) if randf()<.5 else randf_range(.84,.96)
		var contour := PackedVector2Array()
		var radii := PackedFloat32Array()
		for point in 12: radii.append(randf_range(.60,1.20))
		for point in 72:
			var segment := point/6
			var blend := smoothstep(0.0,1.0,float(point%6)/6.0)
			var angle := TAU*float(point)/72
			var reach := lerpf(radii[segment],radii[(segment+1)%12],blend)
			contour.append(Vector2(cos(angle),sin(angle))*reach)
		var specks:Array[Vector3] = []
		for drop in 10:
			specks.append(Vector3(randf_range(-1.6,1.6),randf_range(-1.5,1.5),randf_range(.025,.10)))
		if blood_stains.size()>=20: blood_stains.pop_front()
		blood_stains.append({"position":position,"radius":randf_range(.040,.100)*sqrt(strength),"contour":contour,"specks":specks,"life":randf_range(6,9),"drip":randf_range(.6,1.6)})
	queue_redraw()

func draw_blood() -> void:
	for stain in blood_stains:
		var center:Vector2 = stain.position*size
		var radius:float = stain.radius*minf(size.x,size.y)
		var alpha := clampf(stain.life/2.0,0,1)
		var polygon := PackedVector2Array()
		for point in stain.contour: polygon.append(center+point*radius)
		draw_colored_polygon(polygon,Color(.40,.006,.026,alpha*.58))
		polygon.clear()
		for point in stain.contour: polygon.append(center+point*radius*.72)
		draw_colored_polygon(polygon,Color(.19,.002,.014,alpha*.50))
		for drop in stain.specks:
			draw_circle(center+Vector2(drop.x,drop.y)*radius,drop.z*radius,Color(.40,.005,.020,alpha*.68))
		var end := center+Vector2(0,radius*stain.drip)
		draw_line(center+Vector2(0,radius*.4),end,Color(.30,.002,.014,alpha*.48),maxf(2,radius*.07))
		draw_circle(end,radius*.065,Color(.35,.003,.020,alpha*.6))

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
	var transition:float = battle.atmosphere.world_blend
	if battle.intro and transition>0 and transition<1:
		var veil := sin(transition*PI)
		draw_rect(Rect2(Vector2.ZERO,s),Color(.015,.020,.034,veil*.72))
		for i in 3:
			var radius := (transition+float(i)*.16)*s.length()*.50
			draw_arc(s*.5,radius,0,TAU,96,Color(.27,.38,.40,veil*.09),3*unit)
		var center := s*.5
		var clock_radius := minf(s.x,s.y)*(.23+transition*.28)
		for tick in 48:
			var angle := TAU*float(tick)/48-transition*TAU*.35
			var axis := Vector2(cos(angle),sin(angle))
			var length := 18.0 if tick%4==0 else 7.0
			draw_line(center+axis*clock_radius,center+axis*(clock_radius+length*unit),Color(.53,.76,.78,veil*.35),2*unit)
		for hand in 2:
			var angle := -transition*TAU*(3.0 if hand==0 else 7.0)-PI*.5
			draw_line(center,center+Vector2(cos(angle),sin(angle))*clock_radius*(.55 if hand==0 else .8),Color(.64,.82,.83,veil*.18),3*unit)
		for strand in 7:
			var angle := TAU*float(strand)/7+transition*.7
			var points := PackedVector2Array()
			for step in 6:
				var radius := clock_radius*.5+float(step)*clock_radius*.28
				var bend := angle+sin(float(step)*2.6+float(strand))*.06*veil
				points.append(center+Vector2(cos(bend),sin(bend))*radius)
			draw_polyline(points,Color(.51,.74,.80,veil*.12),1.5*unit,true)
	# Vinheta por faixas suaves: nenhum shader novo ou textura de tela necessária.
	for i in range(12):
		var border := float(12-i) * 5.0 * unit
		draw_rect(Rect2(Vector2.ZERO,s).grow(-border), Color(0.008,0.008,0.015,0.015 + damage_flash*0.018), false, 10.0*unit)
	if damage_flash > 0:
		draw_rect(Rect2(Vector2.ZERO,s),Color(0.45,0.015,0.02,damage_flash*0.13))
	draw_blood()
	if letterbox > 0:
		var h := s.y * 0.105 * letterbox
		draw_rect(Rect2(0,0,s.x,h),Color.BLACK)
		draw_rect(Rect2(0,s.y-h,s.x,h),Color.BLACK)
	if battle.fighting and not battle.stage.death_in_progress:
		var x := 36.0*unit
		var width := minf(300.0*unit,s.x*0.35)
		meter(Rect2(x,35*unit,width,16*unit),battle.stage.hp/100.0,Color("a52b35"))
		meter(Rect2(x,61*unit,width*.65,8*unit),battle.stamina/battle.MAX_STAMINA,Color("778e58"))
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
