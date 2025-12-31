extends Node

const language_pt_br = "PT-BR"
const language_en = "EN"

var default_language:String = language_pt_br

var back_to_main_camera = false
var back_to_fase = false

var battle_background:String = "1" # default o cenario de fogo fora do castelo
var battle_next_enemy:String = "1"
var battle_next_boss:int = 0
var battle_started:bool = false
