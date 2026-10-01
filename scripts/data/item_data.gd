class_name ItemData
extends Resource
## Описание предмета: бревно, камень, руда и т.д.

## Уникальный id предмета (по нему инвентарь хранит количество).
@export var id: StringName
## Название, которое видит игрок.
@export var display_name := ""
## Иконка предмета. Пока не задана — вместо неё рисуется квадрат цвета color.
@export var icon: Texture2D
## Описание для подсказки.
@export_multiline var description := ""
## Цвет заглушки, пока нет иконки.
@export var color := Color.WHITE
