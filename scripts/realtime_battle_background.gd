extends Node2D

var theme_id:String = "forest_road"
var arena_width:float = 2600.0
var arena_height:float = 648.0

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var palette = get_palette()
	draw_rect(Rect2(0, 0, arena_width, arena_height), palette.sky)
	draw_circle(Vector2(350, 105), 68, Color(palette.light, 0.18))
	draw_circle(Vector2(350, 105), 42, Color(palette.light, 0.28))
	draw_rect(Rect2(0, 265, arena_width, 160), palette.back)
	for x in range(-100, int(arena_width) + 200, 220):
		draw_silhouette(float(x), palette)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 375), Vector2(arena_width, 375), Vector2(arena_width, arena_height), Vector2(0, arena_height)
	]), palette.floor)
	for lane in range(6):
		var y = 405.0 + lane * 42.0
		draw_line(Vector2(0, y), Vector2(arena_width, y + 26), Color(palette.line, 0.42), 2.0)
	for x in range(0, int(arena_width), 145):
		draw_line(Vector2(x, 380), Vector2(x + 105, arena_height), Color(palette.line, 0.3), 2.0)
	draw_foreground_details(palette)

func draw_silhouette(x:float, palette:Dictionary) -> void:
	if theme_id == "forest_road":
		draw_rect(Rect2(x + 75, 160, 22, 210), palette.silhouette)
		draw_circle(Vector2(x + 85, 145), 72, palette.silhouette)
		draw_circle(Vector2(x + 35, 190), 54, palette.silhouette)
	elif theme_id == "ash_wasteland":
		draw_colored_polygon(PackedVector2Array([Vector2(x, 375), Vector2(x + 75, 210), Vector2(x + 145, 375)]), palette.silhouette)
		draw_line(Vector2(x + 100, 230), Vector2(x + 150, 135), palette.silhouette, 13)
	else:
		draw_rect(Rect2(x + 18, 125, 58, 250), palette.silhouette)
		draw_rect(Rect2(x, 110, 95, 30), palette.silhouette)
		if theme_id == "throne_ruins":
			draw_colored_polygon(PackedVector2Array([Vector2(x, 110), Vector2(x + 48, 42), Vector2(x + 96, 110)]), palette.silhouette)

func draw_foreground_details(palette:Dictionary) -> void:
	for x in range(180, int(arena_width), 480):
		draw_rect(Rect2(x, 315, 18, 92), Color("211a19"))
		draw_circle(Vector2(x + 9, 315), 30, Color(palette.light, 0.22))
		draw_circle(Vector2(x + 9, 315), 10, palette.light)
	for x in range(80, int(arena_width), 320):
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 560), Vector2(x + 24, 545), Vector2(x + 62, 552), Vector2(x + 74, 570), Vector2(x + 20, 578)
		]), Color(palette.line, 0.7))
	if theme_id == "forest_road":
		draw_rect(Rect2(2120, 105, 360, 275), Color("141523"))
		draw_colored_polygon(PackedVector2Array([Vector2(2070, 110), Vector2(2300, 20), Vector2(2530, 110)]), Color("141523"))
	elif theme_id == "throne_ruins":
		draw_rect(Rect2(2200, 175, 220, 205), Color("241328"))
		draw_colored_polygon(PackedVector2Array([Vector2(2200, 175), Vector2(2310, 75), Vector2(2420, 175)]), Color("3f1836"))

func get_palette() -> Dictionary:
	match theme_id:
		"inferno_castle":
			return {"sky":Color("180d16"), "back":Color("3b1720"), "floor":Color("3a2928"), "line":Color("8c3b32"), "silhouette":Color("21131a"), "light":Color("ff6b35")}
		"abandoned_dungeon":
			return {"sky":Color("0d1720"), "back":Color("24313a"), "floor":Color("30383b"), "line":Color("71816f"), "silhouette":Color("152128"), "light":Color("7bdff2")}
		"ash_wasteland":
			return {"sky":Color("261b25"), "back":Color("51404b"), "floor":Color("493b3d"), "line":Color("876e63"), "silhouette":Color("2f252d"), "light":Color("ff9f68")}
		"throne_ruins":
			return {"sky":Color("100b18"), "back":Color("2d1834"), "floor":Color("32243b"), "line":Color("80558c"), "silhouette":Color("1c1124"), "light":Color("ef476f")}
		"moon_courtyard":
			return {"sky":Color("08182a"), "back":Color("17344a"), "floor":Color("283f4a"), "line":Color("5d8291"), "silhouette":Color("102536"), "light":Color("e0fbfc")}
		_:
			return {"sky":Color("0b1c24"), "back":Color("173b35"), "floor":Color("33463b"), "line":Color("76946f"), "silhouette":Color("102a27"), "light":Color("ffd166")}
