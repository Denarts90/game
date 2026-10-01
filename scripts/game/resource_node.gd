@tool
class_name ResourceNode
extends Node2D
## Ресурс на локации (дерево, камень, жила). Принимает удары,
## выдаёт добычу, становится пустым и восстанавливается по таймеру.

signal depleted(node: ResourceNode)
signal restored(node: ResourceNode)

const GROUP := &"resource_nodes"
const FLOATING_TEXT_SCENE := preload("res://scenes/game/floating_text.tscn")

## Какой это ресурс (файл из data/resource_nodes/).
@export var data: ResourceNodeData:
	set(value):
		data = value
		if is_node_ready():
			_apply_visuals()
## Запас вокруг фигуры, по которому ещё засчитывается тап (для пальца).
@export var tap_margin := 30.0
## Размер полоски прочности и её отступ над ресурсом.
@export var bar_size := Vector2(130, 18)
@export var bar_offset := 20.0
## Покачивание при ударе: угол в градусах и длительность.
@export var wobble_angle := 7.0
@export var wobble_time := 0.3
## Где появляется текст добычи: доля высоты ресурса от основания (0.5 — середина).
@export_range(0.0, 1.5, 0.05) var loot_text_height := 0.5
## Шаг между строками текста добычи.
@export var loot_text_spacing := 56.0

var durability := 0
var is_depleted := false

var _wobble_tween: Tween

@onready var _visual: Node2D = $Visual
@onready var _sprite: Sprite2D = $Visual/Sprite
@onready var _placeholder: PlaceholderShape = $Visual/Placeholder
@onready var _bar: ProgressBar = $DurabilityBar
@onready var _respawn_timer: Timer = $RespawnTimer


func _ready() -> void:
	_apply_visuals()
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	_respawn_timer.timeout.connect(_restore)
	_restore()


## Попадает ли точка (в координатах родителя) по ресурсу.
func contains_point(point: Vector2) -> bool:
	var s := get_visual_size()
	return Rect2(position + Vector2(-s.x / 2, -s.y), s).grow(tap_margin).has_point(point)


## Один удар по ресурсу.
func hit() -> void:
	if is_depleted:
		return
	durability -= 1
	_bar.value = durability
	_wobble()
	if durability <= 0:
		_deplete()


func get_visual_size() -> Vector2:
	if data == null:
		return Vector2.ZERO
	if data.texture:
		return data.texture.get_size() * _visual.scale.abs()
	return data.placeholder_size


func _deplete() -> void:
	is_depleted = true
	_bar.hide()
	_set_depleted_look(true)
	var drops := data.roll_loot()
	if drops.is_empty():
		_spawn_text("Ничего", 0)
	for i in drops.size():
		var item: ItemData = drops[i].item
		var amount: int = drops[i].amount
		Inventory.add_item(item, amount)
		_spawn_text("+%d %s" % [amount, item.display_name], i)
	_respawn_timer.start(data.respawn_time)
	depleted.emit(self)


func _restore() -> void:
	is_depleted = false
	durability = data.durability
	_bar.max_value = data.durability
	_bar.value = durability
	_bar.show()
	_set_depleted_look(false)
	restored.emit(self)


func _apply_visuals() -> void:
	if data == null:
		return
	if data.texture:
		_sprite.texture = data.texture
		_sprite.offset = Vector2(0, -data.texture.get_height() / 2.0)
		_sprite.show()
		_placeholder.hide()
	else:
		_sprite.hide()
		_placeholder.show()
		_placeholder.shape = data.placeholder_shape
		_placeholder.size = data.placeholder_size
	_set_depleted_look(false)
	# Полоска прочности — над верхом ресурса.
	_bar.size = bar_size
	_bar.position = Vector2(-bar_size.x / 2, -get_visual_size().y - bar_offset - bar_size.y)


func _set_depleted_look(empty: bool) -> void:
	if data.texture:
		var has_empty_texture := data.depleted_texture != null
		_sprite.texture = data.depleted_texture if empty and has_empty_texture else data.texture
		_sprite.modulate = Color(0.5, 0.5, 0.5) if empty and not has_empty_texture else Color.WHITE
	else:
		_placeholder.color = data.depleted_color if empty else data.placeholder_color
		_placeholder.accent_color = data.depleted_color.darkened(0.25) if empty else data.placeholder_accent_color


func _wobble() -> void:
	if _wobble_tween:
		_wobble_tween.kill()
	var angle := deg_to_rad(wobble_angle)
	_wobble_tween = create_tween()
	_wobble_tween.tween_property(_visual, "rotation", angle, wobble_time * 0.25)
	_wobble_tween.tween_property(_visual, "rotation", -angle * 0.6, wobble_time * 0.35)
	_wobble_tween.tween_property(_visual, "rotation", 0.0, wobble_time * 0.4)


## Всплывающий текст над ресурсом. line — номер строки, чтобы тексты не накладывались.
func _spawn_text(text: String, line: int) -> void:
	var label: FloatingText = FLOATING_TEXT_SCENE.instantiate()
	label.text = text
	# Добавляем к родителю, чтобы текст не качался вместе с ресурсом.
	get_parent().add_child(label)
	var top := position.y - get_visual_size().y * loot_text_height - line * loot_text_spacing
	label.position = Vector2(position.x - label.size.x / 2, top - label.size.y)
