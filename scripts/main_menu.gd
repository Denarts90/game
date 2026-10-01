extends Control
## Главное меню: фон, дышащий персонаж и кнопки «Играть» / «Выход».

const GAME_SCENE := "res://scenes/game.tscn"

## Где стоят ноги персонажа: доля высоты экрана сверху.
@export_range(0.0, 1.0, 0.01) var character_feet_y := 0.67
## Высота персонажа: доля высоты экрана.
@export_range(0.1, 1.0, 0.01) var character_height := 0.45

@onready var title_label: Label = %Title
@onready var character: MenuCharacter = %Character
@onready var play_button: Button = %PlayButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	# Название берём из настроек проекта, чтобы не дублировать его.
	title_label.text = ProjectSettings.get_setting("application/config/name")
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# В браузере закрыть вкладку из игры нельзя, поэтому кнопку прячем.
	quit_button.visible = not OS.has_feature("web")
	resized.connect(_place_character)
	_place_character()
	play_button.grab_focus()


## Персонаж — по центру, размер и положение считаются от высоты экрана.
func _place_character() -> void:
	character.position = Vector2(size.x / 2, size.y * character_feet_y)
	character.set_screen_height(size.y * character_height)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
