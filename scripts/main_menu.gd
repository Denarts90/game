extends Control
## Стартовое меню: название игры и кнопки «Играть» / «Выход».

const GAME_SCENE := "res://scenes/game.tscn"

@onready var title_label: Label = %Title
@onready var play_button: Button = %PlayButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	# Название берём из настроек проекта, чтобы не дублировать его.
	title_label.text = ProjectSettings.get_setting("application/config/name")
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# В браузере закрыть вкладку из игры нельзя, поэтому кнопку прячем.
	quit_button.visible = not OS.has_feature("web")
	play_button.grab_focus()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
