@tool
class_name MenuCharacter
extends Node2D
## Персонаж для меню: Polygon2D с текстурой, который деформируют кости Skeleton2D.
## Сетка (контур + внутренние вершины) и веса костей считаются автоматически
## по альфа-каналу картинки и положению костей. Анимация дыхания строится по параметрам.
## Точка (0, 0) узла — между ступнями персонажа.

const IDLE_ANIMATION := &"breath/idle"

## Картинка персонажа (фронтальный вид, прозрачный фон).
@export var texture: Texture2D:
	set(value):
		texture = value
		_rebuild_mesh()

@export_group("Сетка")
## Сколько внутренних вершин по ширине и высоте.
@export_range(2, 20) var grid_columns := 7:
	set(value):
		grid_columns = value
		_rebuild_mesh()
@export_range(2, 30) var grid_rows := 14:
	set(value):
		grid_rows = value
		_rebuild_mesh()
## Упрощение контура (пикселей): больше — меньше вершин.
@export_range(0.5, 10.0, 0.5) var outline_epsilon := 2.0:
	set(value):
		outline_epsilon = value
		_rebuild_mesh()

@export_group("Веса")
## Ширина плавного перехода «грудь → голова» вокруг кости head, пикселей картинки.
@export var head_blend := 22.0
## Насколько выше кости chest грудь начинает переходить в spine.
@export var chest_blend := 40.0
## Ширина перехода «spine → hips» (ниже неё — только hips: ноги неподвижны).
@export var hips_blend := 30.0
## Граница руки: линия вдоль кости, сдвинутая на столько пикселей к телу
## (должна проходить по просвету между рукой и туловищем).
@export var arm_split_offset := 32.0
## Ширина плавного перехода веса через эту границу.
@export var arm_split_blend := 10.0

@export_group("Дыхание")
## Период вдоха-выдоха, секунд.
@export_range(0.5, 10.0, 0.1, "suffix:с") var breath_period := 3.5:
	set(value):
		breath_period = value
		_rebuild_animation()
## Растяжение груди на вдохе по вертикали и по горизонтали (0.015 = +1.5%).
@export_range(0.0, 0.1, 0.001) var chest_scale_y := 0.015:
	set(value):
		chest_scale_y = value
		_rebuild_animation()
@export_range(0.0, 0.1, 0.001) var chest_scale_x := 0.008:
	set(value):
		chest_scale_x = value
		_rebuild_animation()
## Подъём головы на вдохе, пикселей картинки.
@export_range(0.0, 20.0, 0.1) var head_rise := 3.5:
	set(value):
		head_rise = value
		_rebuild_animation()
## Наклон головы, ± градусов.
@export_range(0.0, 5.0, 0.1) var head_tilt := 0.8:
	set(value):
		head_tilt = value
		_rebuild_animation()
## Отставание головы от груди, секунд.
@export_range(0.0, 3.0, 0.05, "suffix:с") var head_delay := 0.25:
	set(value):
		head_delay = value
		_rebuild_animation()
## Поворот рук от плеч, ± градусов.
@export_range(0.0, 5.0, 0.1) var arm_angle := 1.0:
	set(value):
		arm_angle = value
		_rebuild_animation()
## Отставание рук от груди, секунд.
@export_range(0.0, 3.0, 0.05, "suffix:с") var arm_delay := 0.4:
	set(value):
		arm_delay = value
		_rebuild_animation()

## Высота персонажа в пикселях картинки (по непрозрачной части).
var image_height := 1.0

@onready var _body: Polygon2D = $Body
@onready var _skeleton: Skeleton2D = $Skeleton2D
@onready var _hips: Bone2D = $Skeleton2D/hips
@onready var _spine: Bone2D = $Skeleton2D/hips/spine
@onready var _chest: Bone2D = $Skeleton2D/hips/spine/chest
@onready var _head: Bone2D = $Skeleton2D/hips/spine/chest/head
@onready var _left_arm: Bone2D = $Skeleton2D/hips/spine/chest/left_arm # рука слева на экране
@onready var _right_arm: Bone2D = $Skeleton2D/hips/spine/chest/right_arm
@onready var _animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_rebuild_mesh()
	_rebuild_animation()


func _notification(what: int) -> void:
	# Сгенерированную сетку не сохраняем в .tscn — она строится заново при загрузке.
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_clear_mesh()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_rebuild_mesh()


## Масштабирует персонажа так, чтобы его высота на экране была height пикселей.
func set_screen_height(height: float) -> void:
	scale = Vector2.ONE * height / image_height


# ---------- Сетка ----------

func _rebuild_mesh() -> void:
	if not is_node_ready() or texture == null:
		return
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var outline := _find_outline(image)
	if outline.is_empty():
		push_warning("MenuCharacter: не удалось найти контур персонажа")
		return

	# Точка опоры — низ картинки по центру непрозрачной части (между ступнями).
	var bounds := _get_bounds(outline)
	var pivot := Vector2(bounds.get_center().x, bounds.end.y)
	image_height = bounds.size.y

	# Внутренние вершины — равномерной сеткой, только внутри контура и не вплотную к краю.
	var internal := PackedVector2Array()
	var step := bounds.size / Vector2(grid_columns, grid_rows)
	var min_edge_distance := minf(step.x, step.y) * 0.2
	for row in grid_rows:
		for column in grid_columns:
			var point := bounds.position + step * Vector2(column + 0.5, row + 0.5)
			if Geometry2D.is_point_in_polygon(point, outline) \
					and _distance_to_outline(point, outline) > min_edge_distance:
				internal.append(point)

	var points := outline + internal
	var triangles := _triangulate(points, outline)

	# uv — пиксели текстуры, вершины — те же пиксели относительно точки опоры.
	var vertices := PackedVector2Array()
	for point in points:
		vertices.append(point - pivot)
	_body.texture = texture
	_body.polygon = vertices
	_body.uv = points
	_body.polygons = triangles
	_body.internal_vertex_count = internal.size()
	_assign_weights(vertices)


func _clear_mesh() -> void:
	if not is_node_ready():
		return
	_body.clear_bones()
	_body.polygons = []
	_body.polygon = PackedVector2Array()
	_body.uv = PackedVector2Array()
	_body.internal_vertex_count = 0


## Контур по альфа-каналу: самый большой из найденных многоугольников.
func _find_outline(image: Image) -> PackedVector2Array:
	var rect := Rect2i(Vector2i.ZERO, image.get_size())
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, 0.05)
	bitmap.grow_mask(1, rect) # чуть шире, чтобы не срезать мягкие края
	var best := PackedVector2Array()
	var best_area := 0.0
	for polygon in bitmap.opaque_to_polygons(rect, outline_epsilon):
		var area := absf(_polygon_area(polygon))
		if area > best_area:
			best_area = area
			best = polygon
	return best


## Триангуляция с учётом вогнутого контура (промежутки между ногами, между рукой и телом):
## сначала режем сам контур, затем вставляем внутренние вершины и выравниваем
## треугольники перестановкой рёбер (рёбра контура не трогаем).
func _triangulate(points: PackedVector2Array, outline: PackedVector2Array) -> Array:
	var outline_size := outline.size()
	var flat := Geometry2D.triangulate_polygon(outline)
	if flat.is_empty():
		push_warning("MenuCharacter: контур не триангулируется, внутренние вершины пропущены")
		return _to_polygons(Geometry2D.triangulate_delaunay(outline))
	var triangles: Array[PackedInt32Array] = []
	for i in range(0, flat.size(), 3):
		triangles.append(PackedInt32Array([flat[i], flat[i + 1], flat[i + 2]]))

	# Каждую внутреннюю вершину вставляем в треугольник, внутри которого она лежит.
	for index in range(outline_size, points.size()):
		var point := points[index]
		for t in triangles.size():
			var tri := triangles[t]
			if Geometry2D.point_is_inside_triangle(point, points[tri[0]], points[tri[1]], points[tri[2]]):
				triangles[t] = PackedInt32Array([tri[0], tri[1], index])
				triangles.append(PackedInt32Array([tri[1], tri[2], index]))
				triangles.append(PackedInt32Array([tri[2], tri[0], index]))
				break

	_flip_edges(points, triangles, outline_size)
	return triangles


## Перестановка рёбер по Делоне: убирает узкие «иглы», чтобы деформация была плавной.
func _flip_edges(points: PackedVector2Array, triangles: Array[PackedInt32Array], outline_size: int) -> void:
	for pass_index in 100:
		var flipped := false
		# Ребро → список треугольников, в которые оно входит.
		var edges := {}
		for t in triangles.size():
			for e in 3:
				var key := _edge_key(triangles[t][e], triangles[t][(e + 1) % 3])
				if edges.has(key):
					edges[key].append(t)
				else:
					edges[key] = [t]
		var touched := {}
		for key in edges:
			var pair: Array = edges[key]
			if pair.size() != 2 or touched.has(pair[0]) or touched.has(pair[1]):
				continue
			var u: int = key >> 16
			var v: int = key & 0xFFFF
			if _is_outline_edge(u, v, outline_size):
				continue
			var o1 := _opposite(triangles[pair[0]], u, v)
			var o2 := _opposite(triangles[pair[1]], u, v)
			# Переставляем, только если четырёхугольник выпуклый и так треугольники «круглее».
			if Geometry2D.segment_intersects_segment(points[o1], points[o2], points[u], points[v]) == null:
				continue
			if not _in_circumcircle(points[u], points[v], points[o1], points[o2]):
				continue
			triangles[pair[0]] = PackedInt32Array([o1, o2, u])
			triangles[pair[1]] = PackedInt32Array([o2, o1, v])
			touched[pair[0]] = true
			touched[pair[1]] = true
			flipped = true
		if not flipped:
			return


func _edge_key(a: int, b: int) -> int:
	return (mini(a, b) << 16) | maxi(a, b)


func _is_outline_edge(a: int, b: int, outline_size: int) -> bool:
	if a >= outline_size or b >= outline_size:
		return false
	var diff := absi(a - b)
	return diff == 1 or diff == outline_size - 1


func _opposite(tri: PackedInt32Array, u: int, v: int) -> int:
	for index in tri:
		if index != u and index != v:
			return index
	return -1


## Лежит ли d внутри окружности, описанной вокруг треугольника abc.
func _in_circumcircle(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ad := a - d
	var bd := b - d
	var cd := c - d
	var det := ad.length_squared() * bd.cross(cd) \
			- bd.length_squared() * ad.cross(cd) \
			+ cd.length_squared() * ad.cross(bd)
	return det * signf((b - a).cross(c - a)) > 1e-6


func _to_polygons(flat: PackedInt32Array) -> Array:
	var result := []
	for i in range(0, flat.size(), 3):
		result.append(PackedInt32Array([flat[i], flat[i + 1], flat[i + 2]]))
	return result


# ---------- Веса ----------

## Веса считаются по положению вершины относительно костей в позе покоя.
func _assign_weights(vertices: PackedVector2Array) -> void:
	var bones := [_hips, _spine, _chest, _head, _left_arm, _right_arm]
	var weights := []
	for bone in bones:
		var array := PackedFloat32Array()
		array.resize(vertices.size())
		weights.append(array)

	var hips_y := _rest_global(_hips).origin.y
	var spine_y := _rest_global(_spine).origin.y
	var chest_y := _rest_global(_chest).origin.y
	var head_y := _rest_global(_head).origin.y

	for i in vertices.size():
		var p := vertices[i]
		var left := _arm_weight(p, _left_arm)
		var right := _arm_weight(p, _right_arm)
		var body := 1.0 - minf(left + right, 1.0)
		# Голова — выше шеи, с плавным переходом.
		var head := 1.0 - smoothstep(head_y - head_blend, head_y + head_blend, p.y)
		# Туловище: грудь → позвоночник → таз; ниже таза (ноги) — только hips.
		var chest := 1.0 - smoothstep(chest_y - chest_blend, spine_y, p.y)
		var hips := smoothstep(spine_y + 10.0, hips_y + hips_blend, p.y)
		var spine := maxf(0.0, 1.0 - chest - hips)
		var torso := body * (1.0 - head)
		weights[0][i] = torso * hips
		weights[1][i] = torso * spine
		weights[2][i] = torso * chest
		weights[3][i] = body * head
		weights[4][i] = left
		weights[5][i] = right

	_body.skeleton = _body.get_path_to(_skeleton)
	_body.clear_bones()
	for b in bones.size():
		_body.add_bone(_skeleton.get_path_to(bones[b]), weights[b])


## Вес руки: всё, что снаружи от границы вдоль кости (со стороны руки), — рука.
## У плеча вес плавно уступает груди.
func _arm_weight(point: Vector2, bone: Bone2D) -> float:
	var rest := _rest_global(bone)
	var start := rest.origin
	var direction := rest.x.normalized()
	# Нормаль, смотрящая от тела наружу.
	var outward := Vector2(-direction.y, direction.x)
	if outward.x * start.x < 0.0:
		outward = -outward
	var side := (point - start).dot(outward) + arm_split_offset
	var t := (point - start).dot(direction) / bone.get_length()
	return smoothstep(-arm_split_blend, arm_split_blend, side) * smoothstep(-0.02, 0.15, t)


## Поза покоя кости в координатах скелета.
func _rest_global(bone: Node) -> Transform2D:
	var result := Transform2D.IDENTITY
	while bone is Bone2D:
		result = bone.rest * result
		bone = bone.get_parent()
	return result


# ---------- Анимация ----------

## Строит зацикленную анимацию idle по параметрам дыхания и запускает её (только в игре).
func _rebuild_animation() -> void:
	if not is_node_ready() or Engine.is_editor_hint():
		return
	var animation := Animation.new()
	animation.length = breath_period
	animation.loop_mode = Animation.LOOP_LINEAR
	const SAMPLES := 24

	var chest_track := _add_track(animation, _chest, "scale")
	var head_position_track := _add_track(animation, _head, "position")
	var head_rotation_track := _add_track(animation, _head, "rotation")
	var left_arm_track := _add_track(animation, _left_arm, "rotation")
	var right_arm_track := _add_track(animation, _right_arm, "rotation")

	for s in SAMPLES + 1:
		var time := breath_period * s / SAMPLES
		var chest_breath := _breath(time)
		animation.track_insert_key(chest_track, time,
				Vector2(1.0 + chest_scale_x * chest_breath, 1.0 + chest_scale_y * chest_breath))
		var head_breath := _breath(time - head_delay)
		animation.track_insert_key(head_position_track, time,
				_head.rest.origin + Vector2(0, -head_rise * head_breath))
		var tilt := sin(TAU * (time - head_delay) / breath_period)
		animation.track_insert_key(head_rotation_track, time,
				_head.rest.get_rotation() + deg_to_rad(head_tilt) * tilt)
		# Руки на вдохе чуть расходятся наружу: левая — по часовой, правая — против.
		var arm_swing := _breath(time - arm_delay) * 2.0 - 1.0
		animation.track_insert_key(left_arm_track, time,
				_left_arm.rest.get_rotation() + deg_to_rad(arm_angle) * arm_swing)
		animation.track_insert_key(right_arm_track, time,
				_right_arm.rest.get_rotation() - deg_to_rad(arm_angle) * arm_swing)

	var library := AnimationLibrary.new()
	library.add_animation(&"idle", animation)
	if _animation_player.has_animation_library(&"breath"):
		_animation_player.remove_animation_library(&"breath")
	_animation_player.add_animation_library(&"breath", library)
	_animation_player.play(IDLE_ANIMATION)


## Фаза дыхания 0..1: 0 — выдох, 1 — вдох. Косинус даёт плавное ease in-out.
func _breath(time: float) -> float:
	return (1.0 - cos(TAU * time / breath_period)) / 2.0


func _add_track(animation: Animation, bone: Node, property: String) -> int:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, "%s:%s" % [get_path_to(bone), property])
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	return track


# ---------- Геометрия ----------

func _get_bounds(points: PackedVector2Array) -> Rect2:
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	return rect


func _polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in points.size():
		area += points[i].cross(points[(i + 1) % points.size()])
	return area / 2.0


func _distance_to_outline(point: Vector2, outline: PackedVector2Array) -> float:
	var best := INF
	for i in outline.size():
		var closest := Geometry2D.get_closest_point_to_segment(point, outline[i], outline[(i + 1) % outline.size()])
		best = minf(best, point.distance_to(closest))
	return best
