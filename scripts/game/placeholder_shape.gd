@tool
class_name PlaceholderShape
extends Node2D
## Цветная фигура-заглушка вместо спрайта.
## Точка (0, 0) — низ фигуры («ноги»), чтобы её было удобно ставить на землю.

enum Shape { RECT, CIRCLE, TREE, ROCK, ORE, CHARACTER }

@export var shape := Shape.RECT:
	set(value):
		shape = value
		queue_redraw()
@export var size := Vector2(100, 100):
	set(value):
		size = value
		queue_redraw()
@export var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()
## Второй цвет: ствол дерева, вкрапления руды, глаз персонажа.
@export var accent_color := Color.BLACK:
	set(value):
		accent_color = value
		queue_redraw()

# Контур камня в долях размера.
const ROCK_POINTS: Array[Vector2] = [
	Vector2(-0.5, 0), Vector2(-0.44, -0.55), Vector2(-0.18, -1.0),
	Vector2(0.22, -0.92), Vector2(0.5, -0.45), Vector2(0.46, 0),
]


func _draw() -> void:
	var w := size.x
	var h := size.y
	match shape:
		Shape.RECT:
			draw_rect(Rect2(-w / 2, -h, w, h), color)
		Shape.CIRCLE:
			draw_circle(Vector2(0, -h / 2), minf(w, h) / 2, color)
		Shape.TREE:
			# Ствол + круглая крона.
			var trunk_w := w * 0.22
			draw_rect(Rect2(-trunk_w / 2, -h * 0.45, trunk_w, h * 0.45), accent_color)
			draw_circle(Vector2(0, -h + w / 2), w / 2, color)
		Shape.ROCK, Shape.ORE:
			var points := PackedVector2Array()
			for p in ROCK_POINTS:
				points.append(p * size)
			draw_colored_polygon(points, color)
			if shape == Shape.ORE:
				# Вкрапления руды.
				for p in [Vector2(-0.2, -0.6), Vector2(0.18, -0.35), Vector2(0.05, -0.75)]:
					draw_circle(p * size, w * 0.09, accent_color)
		Shape.CHARACTER:
			# Тело, голова и глаз (по глазу видно, куда смотрит персонаж).
			var body_h := h * 0.6
			draw_rect(Rect2(-w / 2, -body_h, w, body_h), color)
			var head_r := w * 0.42
			var head := Vector2(0, -body_h - head_r)
			draw_circle(head, head_r, color.lightened(0.25))
			draw_circle(head + Vector2(head_r * 0.45, -head_r * 0.1), head_r * 0.2, accent_color)
