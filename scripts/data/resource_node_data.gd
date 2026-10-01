class_name ResourceNodeData
extends Resource
## Описание добываемого ресурса на локации: дерево, камень, рудная жила.

enum GatherType { CHOP, MINE } # рубка, копка

@export var display_name := ""
## Прочность: сколько ударов нужно, чтобы добыть.
@export_range(1, 100) var durability := 5
## Время одного удара.
@export_range(0.1, 10.0, 0.1, "suffix:с") var hit_time := 1.0
## Тип добычи (позже по нему будем выбирать инструмент).
@export var gather_type := GatherType.CHOP
## Таблица добычи.
@export var loot: Array[LootEntry] = []
## Через сколько секунд пустой ресурс восстанавливается.
@export_range(0.0, 3600.0, 0.5, "suffix:с") var respawn_time := 15.0

@export_group("Внешний вид")
## Спрайт целого ресурса. Если не задан — рисуется заглушка.
@export var texture: Texture2D
## Спрайт пустого ресурса. Если не задан — целый спрайт затемняется.
@export var depleted_texture: Texture2D
@export var placeholder_shape := PlaceholderShape.Shape.RECT
@export var placeholder_size := Vector2(120, 160)
@export var placeholder_color := Color.WHITE
@export var placeholder_accent_color := Color.BLACK
## Цвет заглушки, когда ресурс пустой.
@export var depleted_color := Color(0.35, 0.35, 0.35)


## Разыгрывает таблицу добычи. Возвращает список {item, amount}.
func roll_loot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in loot:
		var amount := entry.roll()
		if amount > 0:
			result.append({ "item": entry.item, "amount": amount })
	return result
