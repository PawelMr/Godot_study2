extends Control

# Ссылки на прогресс-бары (перетащите в инспекторе)
@export var shift_bar: TextureProgressBar = null
@export var shift_bar2: TextureProgressBar = null
@export var q_bar: TextureProgressBar = null
@export var f_bar: TextureProgressBar = null

@export var button_1_bar: TextureProgressBar = null
@export var button_2_bar: TextureProgressBar = null
@export var button_3_bar: TextureProgressBar = null
@export var button_4_bar: TextureProgressBar = null
@export var lable1: Label=null
@export var lable3: Label=null

var dict_bar = {
	"shift": {"bar":shift_bar, "max_value":100.0},
	"shift2": {"bar":shift_bar2, "max_value":100.0},
	"Q": {"bar": q_bar, "max_value":100.0},
	"F": {"bar": f_bar, "max_value":100.0},
	"1": {"bar": button_1_bar, "max_value":100.0},
	"2": {"bar": button_2_bar, "max_value":100.0},
	"3": {"bar": button_3_bar, "max_value":100.0},
	"4": {"bar": button_4_bar, "max_value":100.0},
}

# Текущие значения
var current_shift: float = 0

# Максимальные значения
var max_shift: float = 100


func _ready():
	# Инициализация прогресс-баров
	shift_bars()


func shift_bars():
	# Настройка рывка
	if shift_bar:
		shift_bar.min_value = 0
		shift_bar.max_value = 100
		shift_bar.value = 0
		dict_bar["shift"]["bar"] = shift_bar
	if shift_bar2:
		shift_bar2.min_value = 0
		shift_bar2.max_value = 100
		shift_bar2.value = 0
		dict_bar["shift2"]["bar"] = shift_bar2
	

func update_bar(current_value, max_value, name_bab):
	var bar = dict_bar[name_bab]["bar"]
	var max_bar_value = dict_bar[name_bab]["max_value"]
	#print(str(current_value)+"  "+str(max_value))
	if bar:
		bar.value = get_part_progres(current_value, max_value)*max_bar_value


func get_part_progres(current_value, max_value) -> float:
	return (current_value / max_value)
	
func ubdate_txt(value1,value2):
	lable1.text=str(value1)
	lable3.text=str(value2)
