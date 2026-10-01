class_name FloatingText
extends Label
## Текст, который всплывает вверх, тает и удаляется сам.

## На сколько пикселей поднимается.
@export var rise_distance := 110.0
## Сколько секунд живёт.
@export var duration := 1.4


func _ready() -> void:
	# Анимация стартует со следующего кадра, так что позицию можно задать после add_child.
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", -rise_distance, duration) \
		.as_relative().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.chain().tween_callback(queue_free)
