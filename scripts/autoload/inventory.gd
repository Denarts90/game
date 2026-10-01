extends Node
## Инвентарь игрока (autoload «Inventory»).
## Хранит количество предметов и сообщает об изменениях сигналом.

## Количество предмета item стало amount.
signal changed(item: ItemData, amount: int)

var _amounts: Dictionary[StringName, int] = {}
# Предметы в порядке получения — чтобы список в UI не прыгал.
var _items: Dictionary[StringName, ItemData] = {}


func add_item(item: ItemData, amount := 1) -> void:
	if item == null or amount <= 0:
		return
	_items[item.id] = item
	_amounts[item.id] = get_amount(item) + amount
	changed.emit(item, _amounts[item.id])


## Забирает предметы. Возвращает false, если их не хватает.
func remove_item(item: ItemData, amount := 1) -> bool:
	if get_amount(item) < amount:
		return false
	_amounts[item.id] -= amount
	changed.emit(item, _amounts[item.id])
	return true


func get_amount(item: ItemData) -> int:
	return _amounts.get(item.id, 0)


## Все предметы, которых больше нуля.
func get_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for id in _items:
		if _amounts[id] > 0:
			result.append(_items[id])
	return result
