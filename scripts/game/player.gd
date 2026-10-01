class_name Player
extends Node2D
## Персонаж: ходит по локации и сам добывает ресурсы.
## Добыв ресурс, сам идёт к ближайшему такому же; если таких нет — ждёт.

enum State { IDLE, MOVING, GATHERING, WAITING }

## Скорость ходьбы, пикселей в секунду.
@export var move_speed := 450.0
## На каком расстоянии сбоку от ресурса персонаж встаёт добывать.
@export var gather_distance := 110.0
## Замах при ударе: угол в градусах и длительность.
@export var swing_angle := 18.0
@export var swing_time := 0.25
## Спрайт персонажа. Пока не задан — рисуется цветная заглушка.
@export var texture: Texture2D

## Где можно ходить (в координатах локации). Задаёт игровая сцена.
var walk_bounds := Rect2()
var state := State.IDLE

var _move_target := Vector2.ZERO
var _target_node: ResourceNode # что сейчас добываем или к чему идём
var _wanted_kind: ResourceNodeData # какой ресурс добываем (для автопродолжения)
var _facing := 1.0 # 1 — вправо, -1 — влево
var _swing_tween: Tween

@onready var _visual: Node2D = $Visual
@onready var _sprite: Sprite2D = $Visual/Sprite
@onready var _placeholder: PlaceholderShape = $Visual/Placeholder
@onready var _hit_timer: Timer = $HitTimer


func _ready() -> void:
	if texture:
		_sprite.texture = texture
		_sprite.offset = Vector2(0, -texture.get_height() / 2.0)
		_placeholder.hide()
	_hit_timer.timeout.connect(_on_hit_timer_timeout)


## Идти в точку и прекратить добычу.
func move_to(point: Vector2) -> void:
	_hit_timer.stop()
	_target_node = null
	_wanted_kind = null
	_move_target = _clamp_to_bounds(point)
	state = State.MOVING


## Идти к ресурсу и добывать его.
func gather(node: ResourceNode) -> void:
	if node == _target_node and state != State.IDLE:
		return # уже занимаемся им
	_hit_timer.stop()
	_wanted_kind = node.data
	_approach(node)


func _physics_process(delta: float) -> void:
	match state:
		State.MOVING:
			_face(_move_target.x - position.x)
			position = position.move_toward(_move_target, move_speed * delta)
			if position == _move_target:
				_on_arrived()
		State.WAITING:
			# Ждём, пока восстановится ресурс нужного типа.
			var next := _find_nearest_available(_wanted_kind)
			if next:
				_approach(next)


func _approach(node: ResourceNode) -> void:
	_target_node = node
	# Встаём сбоку от ресурса — с той стороны, где стоим сейчас.
	var side := 1.0 if position.x >= node.position.x else -1.0
	var point := node.position + Vector2(side * gather_distance, 0)
	if walk_bounds.has_area() and not walk_bounds.has_point(point):
		point = node.position - Vector2(side * gather_distance, 0)
	_move_target = _clamp_to_bounds(point)
	state = State.MOVING


func _on_arrived() -> void:
	if _target_node == null:
		state = State.IDLE
		return
	_face(_target_node.position.x - position.x)
	if _target_node.is_depleted:
		state = State.WAITING
		return
	state = State.GATHERING
	_hit_timer.start(_target_node.data.hit_time)


func _on_hit_timer_timeout() -> void:
	if state != State.GATHERING or _target_node == null:
		return
	_swing()
	_target_node.hit()
	if not _target_node.is_depleted:
		return
	# Ресурс добыт — ищем следующий такой же.
	_hit_timer.stop()
	_target_node = null
	var next := _find_nearest_available(_wanted_kind)
	if next:
		_approach(next)
	else:
		state = State.WAITING


func _find_nearest_available(kind: ResourceNodeData) -> ResourceNode:
	if kind == null:
		return null
	var best: ResourceNode = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(ResourceNode.GROUP):
		var resource_node := node as ResourceNode
		if resource_node == null or resource_node.data != kind or resource_node.is_depleted:
			continue
		var distance := global_position.distance_squared_to(resource_node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = resource_node
	return best


## Поворот вправо/влево — отражаем визуал по горизонтали.
func _face(direction_x: float) -> void:
	if absf(direction_x) > 1.0:
		_facing = signf(direction_x)
		_visual.scale.x = _facing


func _swing() -> void:
	if _swing_tween:
		_swing_tween.kill()
	_swing_tween = create_tween()
	_swing_tween.tween_property(_visual, "rotation", deg_to_rad(swing_angle) * _facing, swing_time * 0.35)
	_swing_tween.tween_property(_visual, "rotation", 0.0, swing_time * 0.65)


func _clamp_to_bounds(point: Vector2) -> Vector2:
	if not walk_bounds.has_area():
		return point
	return point.clamp(walk_bounds.position, walk_bounds.end)
