class_name LootEntry
extends Resource
## Строка таблицы добычи: какой предмет, сколько и с каким шансом.

@export var item: ItemData
@export_range(0, 100) var min_amount := 1
@export_range(0, 100) var max_amount := 1
## Шанс выпадения от 0 до 1 (1 = всегда).
@export_range(0.0, 1.0, 0.01) var chance := 1.0


## Бросает кубик: возвращает выпавшее количество (0 — не выпало).
func roll() -> int:
	if item == null or randf() >= chance:
		return 0
	return randi_range(min_amount, maxi(min_amount, max_amount))
