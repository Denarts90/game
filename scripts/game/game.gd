extends Control
## Игровая сцена: панель ресурсов сверху, локация посередине, инвентарь снизу.
## Здесь обрабатываются тапы/клики по локации.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

## Размер локации (в ней расставлены ресурсы). Она центрируется в средней зоне.
@export var world_size := Vector2(1080, 1240)
## Отступ от краёв локации, за который персонаж не заходит.
@export var walk_margin := 60.0

@onready var _location_area: Control = %LocationArea
@onready var _world: Node2D = %World
@onready var _player: Player = %Player
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	_player.walk_bounds = Rect2(Vector2.ONE * walk_margin, world_size - Vector2.ONE * walk_margin * 2)
	_location_area.resized.connect(_center_world)
	_center_world()
	_menu_button.pressed.connect(_go_to_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_to_menu()
		return
	var press_position: Variant = _get_press_position(event)
	if press_position == null:
		return
	# Тапы по панелям сверху и снизу не считаем.
	if not _location_area.get_global_rect().has_point(press_position):
		return
	get_viewport().set_input_as_handled()
	var point: Vector2 = _world.get_global_transform().affine_inverse() * press_position
	var node := _find_resource_at(point)
	if node:
		_player.gather(node)
	else:
		_player.move_to(point)


## Позиция нажатия мышью или касанием; null — если это не нажатие.
func _get_press_position(event: InputEvent) -> Variant:
	if event is InputEventScreenTouch and event.pressed:
		return event.position
	# Касание дублируется «эмулированной» мышью — её пропускаем, чтобы не было двойного тапа.
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		return event.position
	return null


## Ресурс под точкой (в координатах локации). Если попали в несколько — ближайший по основанию.
func _find_resource_at(point: Vector2) -> ResourceNode:
	var best: ResourceNode = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(ResourceNode.GROUP):
		var resource_node := node as ResourceNode
		if resource_node and resource_node.contains_point(point):
			var distance := point.distance_squared_to(resource_node.position)
			if distance < best_distance:
				best_distance = distance
				best = resource_node
	return best


## Держим локацию по центру средней зоны при любом размере экрана.
func _center_world() -> void:
	_world.position = ((_location_area.size - world_size) / 2).floor()


func _go_to_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
