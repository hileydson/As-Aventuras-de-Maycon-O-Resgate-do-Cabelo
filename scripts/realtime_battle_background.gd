extends Node2D

var theme_id:String = "forest_road"
var arena_width:float = 2600.0
var arena_height:float = 648.0

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var palette = get_palette()
	draw_circle(Vector2(350, 75), 82, Color(palette.light, 0.08))
	draw_circle(Vector2(350, 75), 48, Color(palette.light, 0.14))
	draw_rect(Rect2(-400, 160, arena_width + 800, 220), Color(palette.back, 0.11))
	for x in range(-400, int(arena_width) + 400, 220):
		draw_silhouette(float(x), palette)
	for lane in range(10):
		var y = 205.0 + lane * 42.0
		draw_line(Vector2(-400, y), Vector2(arena_width + 400, y + 28), Color(palette.line, 0.14), 2.0)
	for x in range(-400, int(arena_width) + 400, 145):
		draw_line(Vector2(x, 195), Vector2(x + 105, arena_height), Color(palette.line, 0.11), 2.0)
	draw_foreground_details(palette)

func draw_silhouette(x:float, palette:Dictionary) -> void:
	var shadow = Color(palette.silhouette, 0.16)
	if theme_id == "forest_road":
		draw_rect(Rect2(x + 75, 100, 22, 210), shadow)
		draw_circle(Vector2(x + 85, 85), 72, shadow)
		draw_circle(Vector2(x + 35, 130), 54, shadow)
	elif theme_id == "ash_wasteland":
		draw_colored_polygon(PackedVector2Array([Vector2(x, 315), Vector2(x + 75, 150), Vector2(x + 145, 315)]), shadow)
		draw_line(Vector2(x + 100, 170), Vector2(x + 150, 75), shadow, 13)
	else:
		draw_rect(Rect2(x + 18, 65, 58, 250), shadow)
		draw_rect(Rect2(x, 50, 95, 30), shadow)
		if theme_id == "throne_ruins":
			draw_colored_polygon(PackedVector2Array([Vector2(x, 50), Vector2(x + 48, -18), Vector2(x + 96, 50)]), shadow)

func draw_foreground_details(palette:Dictionary) -> void:
	for x in range(80, int(arena_width), 320):
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 560), Vector2(x + 24, 545), Vector2(x + 62, 552), Vector2(x + 74, 570), Vector2(x + 20, 578)
		]), Color(palette.line, 0.7))
	if theme_id == "throne_ruins":
		draw_rect(Rect2(2200, 115, 220, 205), Color("241328"))
		draw_colored_polygon(PackedVector2Array([Vector2(2200, 115), Vector2(2310, 15), Vector2(2420, 115)]), Color("3f1836"))

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
