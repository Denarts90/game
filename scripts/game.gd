extends Control
## Заглушка игровой сцены. По Esc возвращает в главное меню.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"


func _unhandled_input(event: InputEvent) -> void:
	# ui_cancel по умолчанию привязан к Esc.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
