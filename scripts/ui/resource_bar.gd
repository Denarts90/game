extends HBoxContainer
## Верхняя панель: сколько собрано каждого ресурса.

## Какие предметы показывать.
@export var items: Array[ItemData] = []

var _views: Dictionary[StringName, ItemView] = {}


func _ready() -> void:
	for item in items:
		var view := ItemView.create(item, false)
		add_child(view)
		_views[item.id] = view
	Inventory.changed.connect(_on_inventory_changed)


func _on_inventory_changed(item: ItemData, amount: int) -> void:
	if _views.has(item.id):
		_views[item.id].set_amount(amount)
