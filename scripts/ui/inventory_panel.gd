extends PanelContainer
## Нижняя панель: список предметов в инвентаре с количеством.

@onready var _list: VBoxContainer = %Items
@onready var _empty_label: Label = %EmptyLabel


func _ready() -> void:
	Inventory.changed.connect(_on_inventory_changed)
	_refresh()


func _on_inventory_changed(_item: ItemData, _amount: int) -> void:
	_refresh()


## Перестраиваем список целиком — предметов немного, так проще всего.
func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var items := Inventory.get_items()
	_empty_label.visible = items.is_empty()
	for item in items:
		_list.add_child(ItemView.create(item, true))
