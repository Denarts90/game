class_name ItemView
extends HBoxContainer
## Строка «иконка + количество» для панелей ресурсов и инвентаря.

## Размер иконки.
@export var icon_size := 64.0
## Показывать ли название предмета рядом с количеством.
@export var show_name := true

var item: ItemData

var _label := Label.new()


## Создаёт строку для предмета.
static func create(p_item: ItemData, p_show_name: bool) -> ItemView:
	var view := ItemView.new()
	view.item = p_item
	view.show_name = p_show_name
	return view


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	tooltip_text = item.description
	add_child(_make_icon())
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	set_amount(Inventory.get_amount(item))


func set_amount(amount: int) -> void:
	_label.text = "%s × %d" % [item.display_name, amount] if show_name else str(amount)


## Иконка предмета или цветной квадрат-заглушка.
func _make_icon() -> Control:
	var icon: Control
	if item.icon:
		var texture_rect := TextureRect.new()
		texture_rect.texture = item.icon
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon = texture_rect
	else:
		var color_rect := ColorRect.new()
		color_rect.color = item.color
		icon = color_rect
	icon.custom_minimum_size = Vector2.ONE * icon_size
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
