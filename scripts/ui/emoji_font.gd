extends RefCounted

const EMOJI_FONT:FontFile = preload("res://assets/fonts/NotoColorEmoji.ttf")
const SYMBOLS_FONT:FontFile = preload("res://assets/fonts/NotoSansSymbols2-Regular.ttf")
static var _ui_font:FontVariation

static func get_ui_font() -> FontVariation:
	if _ui_font == null:
		_ui_font = FontVariation.new()
		_ui_font.base_font = ThemeDB.fallback_font
		_ui_font.fallbacks = [EMOJI_FONT, SYMBOLS_FONT]
	return _ui_font
