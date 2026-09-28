extends Node2D

var theme_id:String = "forest_road"
var arena_width:float = 2600.0
var arena_height:float = 648.0

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var palette = get_palette()
	draw_foreground_lamp_posts(palette)

func draw_foreground_lamp_posts(palette:Dictionary) -> void:
	for x in range(180, int(arena_width), 480):
		var post_w:float = 28.0
		var post_top_y:float = 512.0
		var visible_h:float = arena_height - post_top_y + 40.0
		var lamp_cx:float = x + post_w * 0.5
		var lamp_cy:float = 478.0

		# Suave iluminacao circular no chao/calcada abaixo do poste
		draw_set_transform(Vector2(lamp_cx, 638.0), 0.0, Vector2(2.1, 0.52))
		draw_circle(Vector2.ZERO, 78.0, Color(palette.light, 0.11))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Coluna principal do poste cortada pela metade na parte inferior da tela
		draw_rect(Rect2(x, post_top_y, post_w, visible_h), Color("140f11"))
		draw_rect(Rect2(x + 2, post_top_y, 5, visible_h), Color("261c1f"))
		draw_rect(Rect2(x + post_w - 6, post_top_y, 6, visible_h), Color("0b0809"))

		# Aneis e detalhes decorativos do poste
		draw_rect(Rect2(x - 3, 568, post_w + 6, 9), Color("1f1618"))
		draw_rect(Rect2(x - 4, post_top_y, post_w + 8, 8), Color("261b1e"))

		# Suporte e braco da luminaria
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 5, post_top_y),
			Vector2(x + post_w + 5, post_top_y),
			Vector2(x + post_w + 2, 496.0),
			Vector2(x - 2, 496.0)
		]), Color("1a1214"))

		# Armacao da lanterna
		draw_rect(Rect2(x - 2, 460.0, post_w + 4, 36.0), Color("100a0c"))
		draw_rect(Rect2(x + 2, 464.0, post_w - 4, 28.0), Color(palette.light, 0.38))

		# Telhado / topo da lanterna
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 6, 460.0),
			Vector2(x + post_w + 6, 460.0),
			Vector2(lamp_cx, 442.0)
		]), Color("22171a"))
		draw_circle(Vector2(lamp_cx, 440.0), 3.5, Color("2d1f23"))

		# Brilho volumetrico e foco de luz da lampada
		var lamp_pos = Vector2(lamp_cx, lamp_cy)
		draw_circle(lamp_pos, 115.0, Color(palette.light, 0.04))
		draw_circle(lamp_pos, 72.0, Color(palette.light, 0.11))
		draw_circle(lamp_pos, 38.0, Color(palette.light, 0.24))
		draw_circle(lamp_pos, 14.0, palette.light)
		draw_circle(lamp_pos, 6.0, Color(1.0, 1.0, 0.95, 0.92))

func get_palette() -> Dictionary:
	match theme_id:
		"inferno_castle":
			return {"light":Color("ff6b35")}
		"abandoned_dungeon":
			return {"light":Color("7bdff2")}
		"ash_wasteland":
			return {"light":Color("ff9f68")}
		"throne_ruins":
			return {"light":Color("ef476f")}
		"moon_courtyard":
			return {"light":Color("e0fbfc")}
		_:
			return {"light":Color("ffd166")}
