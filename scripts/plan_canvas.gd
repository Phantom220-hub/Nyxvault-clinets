extends Control
class_name PlanCanvas

signal wall_created(a: Vector2, b: Vector2)
signal wall_selected(index: int)
signal walls_changed
signal wall_deleted(index: int)
signal measurement_completed(distance_m: float, angle_degrees: float)

const Units = preload("res://scripts/building_units.gd")
const Geometry = preload("res://scripts/wall_geometry.gd")
const GRID_MINOR := Color("#293B49")
const GRID_MAJOR := Color("#365263")
const WALL_COLOR := Color("#52D6C7")
const PREVIEW_COLOR := Color("#FFC878")
const SELECTED_COLOR := Color("#FFCA78")
const PIXELS_PER_METRE := 48.0

var walls: Array[Dictionary] = []
var undo_history: Array = []
var redo_history: Array = []
const MAX_HISTORY := 60
var furniture: Array[Dictionary] = []
var selected_furniture := -1
var selected_wall := -1
var tool_mode := "draw" # draw | select
var drawing := false
var dragging_wall := false
var drag_endpoint := -1 # 0=start, 1=end, -1=whole wall
var drag_history_recorded := false
var drag_start_pointer := Vector2.ZERO
var drag_start_wall: Dictionary = {}
var start_point := Vector2.ZERO
var current_point := Vector2.ZERO
var grid_size := 32.0
var snap_enabled := true
var angle_snap_enabled := true
var angle_snap_degrees := 15.0
var dimensions_visible := true
var measurement_start := Vector2.ZERO
var measurement_end := Vector2.ZERO
var measurement_active := false
var measurement_visible := false
var layer_visibility: Dictionary = {"walls": true, "furniture": true, "rooms": true, "dimensions": true}
var drag_start_walls: Array[Dictionary] = []
var view_zoom := 1.0
var view_pan := Vector2.ZERO
var touch_points: Dictionary = {}
var pinch_distance := 0.0
var pinch_centroid := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#121E28"), true)
	draw_set_transform(view_pan, 0.0, Vector2(view_zoom, view_zoom))
	var step := maxi(1, int(grid_size))
	for x in range(0, int(size.x) + step, step):
		var major := (x / step) % 4 == 0
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_MAJOR if major else GRID_MINOR, 1.4 if major else 0.7)
	for y in range(0, int(size.y) + step, step):
		var major := (y / step) % 4 == 0
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_MAJOR if major else GRID_MINOR, 1.4 if major else 0.7)

	for item_index in range(furniture.size()):
		var item: Dictionary = furniture[item_index]
		if not bool(layer_visibility.get("furniture", true)):
			continue
		var world_pos: Vector2 = item.get("position", Vector2.ZERO)
		var center := Vector2(size.x * 0.5 + world_pos.x * PIXELS_PER_METRE, size.y * 0.5 + world_pos.y * PIXELS_PER_METRE)
		var kind := int(item.get("kind", 0))
		var dims := [Vector2(92, 48), Vector2(58, 92), Vector2(72, 48), Vector2(42, 42), Vector2(58, 32), Vector2(88, 32), Vector2(42, 42), Vector2(36, 48), Vector2(82, 40), Vector2(44, 36), Vector2(30, 30), Vector2(26, 26), Vector2(56, 108)]
		var footprint: Vector2 = dims[clampi(kind, 0, dims.size() - 1)] * float(item.get("scale", 1.0))
		draw_set_transform(center, float(item.get("rotation", 0.0)), Vector2.ONE)
		var rect := Rect2(-footprint * 0.5, footprint)
		draw_rect(rect, Color("#52D6C7") if item_index == selected_furniture else Color("#B98B5E"), true)
		draw_rect(rect, Color("#EAFBF8"), false, 2.0)
		var labels := ["ДИВАН", "КРОВАТЬ", "СТОЛ", "КРЕСЛО", "ШКАФ", "ТУМБА", "ХОЛОД.", "УНИТАЗ", "ВАННА", "РАКОВИНА", "РАСТ.", "ТОРШЕР", "ЛЕСТНИЦА"]
		draw_string(ThemeDB.fallback_font, Vector2(-footprint.x * 0.5 + 2, -footprint.y * 0.5 - 4), labels[clampi(kind, 0, labels.size() - 1)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#F2F6F8"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var room_faces := Geometry.find_bounded_faces(walls) if bool(layer_visibility.get("walls", true)) and bool(layer_visibility.get("rooms", true)) else []
	for room_index in range(room_faces.size()):
		var polygon: PackedVector2Array = room_faces[room_index]
		var center := Vector2.ZERO
		for vertex in polygon:
			center += vertex
		center /= float(polygon.size())
		var area_m2 := Geometry.polygon_area(polygon) / (PIXELS_PER_METRE * PIXELS_PER_METRE)
		draw_string(ThemeDB.fallback_font, center + Vector2(-34, -4), "КОМНАТА %d" % (room_index + 1), HORIZONTAL_ALIGNMENT_LEFT, 100, 10, Color("#A7C8D0"))
		draw_string(ThemeDB.fallback_font, center + Vector2(-18, 12), "%.2f м²" % area_m2, HORIZONTAL_ALIGNMENT_LEFT, 80, 11, Color("#EAFBF8"))

	for i in range(walls.size()):
		var wall: Dictionary = walls[i]
		if not bool(layer_visibility.get("walls", true)):
			continue
		var a: Vector2 = wall.get("a", Vector2.ZERO)
		var b: Vector2 = wall.get("b", Vector2.ZERO)
		var thickness_mm := float(wall.get("thickness_mm", 150.0))
		var width_px := clampf(Units.mm_to_pixels(thickness_mm), 3.0, 24.0)
		var color := SELECTED_COLOR if i == selected_wall else WALL_COLOR
		draw_line(a, b, Color("#0A1118"), width_px + 5.0, true)
		draw_line(a, b, color, width_px, true)
		draw_circle(a, 5.0 if i != selected_wall else 7.0, Color("#EAFBF8"))
		draw_circle(b, 5.0 if i != selected_wall else 7.0, Color("#EAFBF8"))
		var mid := (a + b) * 0.5
		if dimensions_visible and bool(layer_visibility.get("dimensions", true)):
			var direction := (b - a).normalized()
			var normal := Vector2(-direction.y, direction.x)
			var dimension_offset := normal * 22.0
			var dimension_a := a + dimension_offset
			var dimension_b := b + dimension_offset
			draw_line(a + normal * 5.0, dimension_a + normal * 4.0, Color("#8DAAB5"), 1.0)
			draw_line(b + normal * 5.0, dimension_b + normal * 4.0, Color("#8DAAB5"), 1.0)
			draw_line(dimension_a, dimension_b, Color("#A7C8D0"), 1.2)
			draw_line(dimension_a - normal * 4.0, dimension_a + normal * 4.0, Color("#A7C8D0"), 1.2)
			draw_line(dimension_b - normal * 4.0, dimension_b + normal * 4.0, Color("#A7C8D0"), 1.2)
			draw_string(ThemeDB.fallback_font, mid + dimension_offset + Vector2(5, -4), Units.format_metres(a.distance_to(b) / PIXELS_PER_METRE), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#D9F5F0"))
		else:
			draw_string(ThemeDB.fallback_font, mid + Vector2(7, -10), Units.format_metres(a.distance_to(b) / PIXELS_PER_METRE), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#D9F5F0"))
		var opening := str(wall.get("opening", ""))
		if opening == "door" or opening == "window":
			var wall_length_mm := Units.pixels_to_mm(a.distance_to(b))
			var opening_offset := float(wall.get("opening_offset_mm", wall_length_mm * 0.5))
			var opening_point := a.lerp(b, clampf(opening_offset / maxf(wall_length_mm, 1.0), 0.0, 1.0))
			draw_string(ThemeDB.fallback_font, opening_point + Vector2(7, 15), "ДВЕРЬ" if opening == "door" else "ОКНО", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#FFC878"))
		if i == selected_wall:
			draw_circle(a, 9.0, Color("#FFCA78", 0.28))
			draw_circle(b, 9.0, Color("#FFCA78", 0.28))

	if measurement_visible:
		draw_line(measurement_start, measurement_end, Color("#FFC878"), 2.0, true)
		draw_circle(measurement_start, 5.0, Color("#FFC878"))
		draw_circle(measurement_end, 5.0, Color("#FFC878"))
		var measured_delta := measurement_end - measurement_start
		var measured_distance := measured_delta.length() / PIXELS_PER_METRE
		var measured_angle := rad_to_deg(measured_delta.angle())
		var measured_label := "%.2f m  •  %.1f°" % [measured_distance, measured_angle]
		draw_string(ThemeDB.fallback_font, (measurement_start + measurement_end) * 0.5 + Vector2(8, -10), measured_label, HORIZONTAL_ALIGNMENT_LEFT, 220, 13, Color("#FFE2B8"))
	if drawing:
		draw_line(start_point, current_point, PREVIEW_COLOR, 7.0, true)
		draw_circle(start_point, 7.0, PREVIEW_COLOR)
		draw_circle(current_point, 7.0, PREVIEW_COLOR)

func set_angle_snap_enabled(enabled: bool) -> void:
	angle_snap_enabled = enabled
	queue_redraw()

func set_dimensions_visible(enabled: bool) -> void:
	dimensions_visible = enabled
	queue_redraw()

func set_layer_visibility(layer_name: String, visible: bool) -> void:
	if not layer_visibility.has(layer_name):
		return
	layer_visibility[layer_name] = visible
	queue_redraw()

func _snap(p: Vector2) -> Vector2:
	var point := Geometry.snap_point(p, grid_size) if snap_enabled else p
	# Endpoint snapping makes wall intersections share exact coordinates.
	var nearest := point
	var best := 13.0
	for wall in walls:
		for endpoint in [wall.get("a", Vector2.ZERO), wall.get("b", Vector2.ZERO)]:
			var distance := point.distance_to(endpoint)
			if distance < best:
				best = distance
				nearest = endpoint
	return nearest

func _constrained_point(raw_point: Vector2) -> Vector2:
	var point := _snap(raw_point)
	if angle_snap_enabled:
		point = Geometry.constrain_angle(start_point, point, angle_snap_degrees)
	return point

func set_tool_mode(mode: String) -> void:
	tool_mode = "select" if mode == "select" else "measure" if mode == "measure" else "draw"
	drawing = false
	dragging_wall = false
	measurement_active = false
	if tool_mode != "measure":
		measurement_visible = false
	queue_redraw()

func _screen_to_canvas(point: Vector2) -> Vector2:
	return (point - view_pan) / maxf(view_zoom, 0.001)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			if touch_points.size() == 2:
				var points: Array = touch_points.values()
				var first_point: Vector2 = points[0]
				var second_point: Vector2 = points[1]
				pinch_distance = first_point.distance_to(second_point)
				pinch_centroid = (first_point + second_point) * 0.5
				drawing = false
				dragging_wall = false
				measurement_active = false
				queue_redraw()
				accept_event()
				return
			if touch_points.size() > 2:
				return
			_pointer_down(_screen_to_canvas(event.position))
		else:
			touch_points.erase(event.index)
			pinch_distance = 0.0
			if touch_points.is_empty():
				_pointer_up(_screen_to_canvas(event.position))
		accept_event()
	elif event is InputEventScreenDrag:
		if touch_points.has(event.index):
			touch_points[event.index] = event.position
		if touch_points.size() >= 2:
			var points: Array = touch_points.values()
			var first_point: Vector2 = points[0]
			var second_point: Vector2 = points[1]
			var distance_now := first_point.distance_to(second_point)
			var centroid_now := (first_point + second_point) * 0.5
			if pinch_distance > 1.0:
				var next_zoom := clampf(view_zoom * distance_now / pinch_distance, 0.45, 3.5)
				var anchor_world := (pinch_centroid - view_pan) / maxf(view_zoom, 0.001)
				view_pan = centroid_now - anchor_world * next_zoom
				view_zoom = next_zoom
			view_pan += centroid_now - pinch_centroid
			pinch_distance = distance_now
			pinch_centroid = centroid_now
			queue_redraw()
			accept_event()
			return
		var canvas_point := _screen_to_canvas(event.position)
		if drawing:
			current_point = _constrained_point(canvas_point)
			queue_redraw()
		elif dragging_wall:
			_pointer_drag(canvas_point)
		elif tool_mode == "measure" and measurement_active:
			measurement_end = _snap(canvas_point)
			queue_redraw()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down(_screen_to_canvas(event.position))
		else:
			_pointer_up(_screen_to_canvas(event.position))
		accept_event()
	elif event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var anchor := event.position
		var world_anchor := _screen_to_canvas(anchor)
		var zoom_factor := 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
		view_zoom = clampf(view_zoom * zoom_factor, 0.45, 3.5)
		view_pan = anchor - world_anchor * view_zoom
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion:
		var canvas_point := _screen_to_canvas(event.position)
		if drawing:
			current_point = _constrained_point(canvas_point)
			queue_redraw()
		elif dragging_wall:
			_pointer_drag(canvas_point)
		elif tool_mode == "measure" and measurement_active:
			measurement_end = _snap(canvas_point)
			queue_redraw()


func _pointer_down(point: Vector2) -> void:
	if tool_mode == "draw":
		drawing = true
		start_point = _snap(point)
		current_point = start_point
	elif tool_mode == "measure":
		var measured_point := _snap(point)
		if not measurement_active:
			measurement_start = measured_point
			measurement_end = measured_point
			measurement_active = true
			measurement_visible = true
		else:
			measurement_end = measured_point
			measurement_active = false
			var delta := measurement_end - measurement_start
			measurement_completed.emit(delta.length() / PIXELS_PER_METRE, rad_to_deg(delta.angle()))
	else:
		_select_wall_at(point)
		if selected_wall >= 0:
			var wall: Dictionary = walls[selected_wall]
			var a: Vector2 = wall.a
			var b: Vector2 = wall.b
			if point.distance_to(a) <= 16.0:
				drag_endpoint = 0
			elif point.distance_to(b) <= 16.0:
				drag_endpoint = 1
			else:
				drag_endpoint = -1
			dragging_wall = true
			drag_history_recorded = false
			drag_start_pointer = point
			drag_start_wall = wall.duplicate(true)
			drag_start_walls = walls.duplicate(true)
	accept_event()
	queue_redraw()

func _pointer_drag(point: Vector2) -> void:
	if selected_wall < 0 or selected_wall >= walls.size():
		return
	if not drag_history_recorded:
		_record_history()
		drag_history_recorded = true
	var wall: Dictionary = drag_start_wall.duplicate(true)
	if drag_endpoint == 0 or drag_endpoint == 1:
		var old_point: Vector2 = wall.a if drag_endpoint == 0 else wall.b
		var new_point := _snap(point)
		if old_point.distance_to(new_point) < 0.001:
			return
		if drag_endpoint == 0:
			wall.a = new_point
		else:
			wall.b = new_point
		var moved_walls := Geometry.move_connected_endpoint(drag_start_walls, selected_wall, drag_endpoint, new_point)
		if moved_walls.is_empty():
			return
		walls = moved_walls
	else:
		var original_a: Vector2 = drag_start_wall.get("a", wall.a)
		var desired_a := original_a + (point - drag_start_pointer)
		var offset := _snap(desired_a) - original_a
		walls = _translated_connected_component(selected_wall, offset)
	if not Geometry.valid_wall(walls[selected_wall]):
		walls = drag_start_walls.duplicate(true)
		return
	queue_redraw()

func _translated_connected_component(root_index: int, offset: Vector2) -> Array[Dictionary]:
	return Geometry.translated_connected_component(drag_start_walls, root_index, offset)

func _pointer_up(point: Vector2) -> void:
	if drawing:
		current_point = _constrained_point(point)
		drawing = false
		if start_point.distance_to(current_point) >= grid_size:
			_record_history()
			var new_wall := {"a": start_point, "b": current_point, "thickness_mm": 150.0, "height_mm": 2800.0, "load_bearing": false, "opening": "", "layer": "walls"}
			walls.append(new_wall)
			selected_wall = walls.size() - 1
			wall_created.emit(start_point, current_point)
			walls_changed.emit()
	elif dragging_wall:
		dragging_wall = false
		drag_endpoint = -1
		drag_start_wall.clear()
		drag_start_walls.clear()
		drag_history_recorded = false
		walls_changed.emit()
	accept_event()
	queue_redraw()

func _select_wall_at(point: Vector2) -> void:
	if not bool(layer_visibility.get("walls", true)):
		selected_wall = -1
		wall_selected.emit(-1)
		return
	var best_index := -1
	var best_distance := 18.0
	for i in range(walls.size()):
		var wall: Dictionary = walls[i]
		var distance := Geometry.distance_to_segment(point, wall.a, wall.b)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	selected_wall = best_index
	wall_selected.emit(selected_wall)

func delete_selected_wall() -> bool:
	if selected_wall < 0 or selected_wall >= walls.size():
		return false
	var removed := selected_wall
	_record_history()
	walls.remove_at(removed)
	selected_wall = -1
	wall_deleted.emit(removed)
	walls_changed.emit()
	queue_redraw()
	return true

func set_selected_wall_length_mm(length_mm: float) -> bool:
	if selected_wall < 0 or selected_wall >= walls.size() or length_mm < 200.0:
		return false
	var wall: Dictionary = walls[selected_wall]
	_record_history()
	walls[selected_wall] = Geometry.resized_to_length(wall, Units.mm_to_pixels(length_mm))
	walls_changed.emit()
	queue_redraw()
	return true

func set_selected_wall_properties(thickness_mm: float, height_mm: float, load_bearing: bool) -> bool:
	if selected_wall < 0 or selected_wall >= walls.size():
		return false
	var wall: Dictionary = walls[selected_wall]
	_record_history()
	wall["thickness_mm"] = clampf(thickness_mm, 50.0, 1000.0)
	wall["height_mm"] = clampf(height_mm, 1800.0, 10000.0)
	wall["load_bearing"] = load_bearing
	walls[selected_wall] = wall
	walls_changed.emit()
	queue_redraw()
	return true

func set_selected_wall_opening(kind: String, width_mm: float, offset_mm: float, sill_height_mm: float = 850.0, opening_height_mm: float = 2050.0) -> bool:
	if selected_wall < 0 or selected_wall >= walls.size():
		return false
	if kind != "" and kind != "door" and kind != "window":
		return false
	var wall: Dictionary = walls[selected_wall].duplicate(true)
	var a: Vector2 = wall.get("a", Vector2.ZERO)
	var b: Vector2 = wall.get("b", Vector2.ZERO)
	var length_mm := Units.pixels_to_mm(a.distance_to(b))
	if not kind.is_empty() and length_mm < 600.0:
		return false
	if kind.is_empty():
		_record_history()
		wall["opening"] = ""
		wall.erase("opening_width_mm")
		wall.erase("opening_offset_mm")
		wall.erase("sill_height_mm")
	else:
		var minimum_width := 300.0
		var safe_width := clampf(width_mm, minimum_width, maxf(minimum_width, length_mm - 100.0))
		var safe_offset := clampf(offset_mm, safe_width * 0.5, maxf(safe_width * 0.5, length_mm - safe_width * 0.5))
		_record_history()
		wall["opening"] = kind
		wall["opening_width_mm"] = safe_width
		wall["opening_offset_mm"] = safe_offset
		wall["opening_height_mm"] = clampf(opening_height_mm, 300.0, 4000.0)
		wall["sill_height_mm"] = clampf(sill_height_mm, 0.0, 2500.0)
	walls[selected_wall] = wall
	walls_changed.emit()
	queue_redraw()
	return true

func apply_selected_wall_settings(length_mm: float, thickness_mm: float, height_mm: float, load_bearing: bool, opening_kind: String, opening_width_mm: float, opening_offset_mm: float, sill_height_mm: float, opening_height_mm: float) -> bool:
	if selected_wall < 0 or selected_wall >= walls.size() or length_mm < 200.0:
		return false
	if opening_kind != "" and opening_kind != "door" and opening_kind != "window":
		return false
	if not opening_kind.is_empty() and length_mm < 600.0:
		return false
	var wall: Dictionary = walls[selected_wall].duplicate(true)
	var a: Vector2 = wall.get("a", Vector2.ZERO)
	var b: Vector2 = wall.get("b", Vector2.ZERO)
	var direction := (b - a).normalized()
	var new_length_px := Units.mm_to_pixels(length_mm)
	if direction.length() < 0.001:
		return false
	_record_history()
	wall["b"] = a + direction * new_length_px
	wall["thickness_mm"] = clampf(thickness_mm, 50.0, 1000.0)
	wall["height_mm"] = clampf(height_mm, 1800.0, 10000.0)
	wall["load_bearing"] = load_bearing
	if opening_kind.is_empty():
		wall["opening"] = ""
		wall.erase("opening_width_mm")
		wall.erase("opening_offset_mm")
		wall.erase("opening_height_mm")
		wall.erase("sill_height_mm")
	else:
		var safe_width := clampf(opening_width_mm, 300.0, maxf(300.0, length_mm - 100.0))
		wall["opening"] = opening_kind
		wall["opening_width_mm"] = safe_width
		wall["opening_offset_mm"] = clampf(opening_offset_mm, safe_width * 0.5, maxf(safe_width * 0.5, length_mm - safe_width * 0.5))
		wall["opening_height_mm"] = clampf(opening_height_mm, 300.0, 4000.0)
		wall["sill_height_mm"] = clampf(sill_height_mm, 0.0, 2500.0)
	walls[selected_wall] = wall
	walls_changed.emit()
	queue_redraw()
	return true

func get_selected_wall() -> Dictionary:
	if selected_wall < 0 or selected_wall >= walls.size():
		return {}
	return walls[selected_wall].duplicate(true)


func add_wall_by_dimensions(start_mm: Vector2, length_mm: float, angle_degrees: float, thickness_mm: float = 150.0, height_mm: float = 2800.0) -> bool:
	if length_mm < 200.0 or length_mm > 100000.0:
		return false
	var start_px := Vector2(size.x * 0.5, size.y * 0.5) + Vector2(Units.mm_to_pixels(start_mm.x), Units.mm_to_pixels(start_mm.y))
	var direction := Vector2.from_angle(deg_to_rad(angle_degrees))
	var end_px := start_px + direction * Units.mm_to_pixels(length_mm)
	var new_wall := {
		"a": start_px,
		"b": end_px,
		"thickness_mm": clampf(thickness_mm, 50.0, 1000.0),
		"height_mm": clampf(height_mm, 1800.0, 10000.0),
		"load_bearing": false,
		"opening": "",
		"layer": "walls"
	}
	if not Geometry.valid_wall(new_wall):
		return false
	_record_history()
	walls.append(new_wall)
	selected_wall = walls.size() - 1
	walls_changed.emit()
	queue_redraw()
	return true



func add_wall_between_points(start_point_px: Vector2, end_point_px: Vector2, constrain_angle: bool = true, thickness_mm: float = 150.0, height_mm: float = 2800.0) -> bool:
	var a := _snap(start_point_px)
	var b := _snap(end_point_px)
	if constrain_angle and angle_snap_enabled:
		b = Geometry.constrain_angle(a, b, angle_snap_degrees)
	if a.distance_to(b) < Geometry.MIN_WALL_LENGTH_PX:
		return false
	var wall := {
		"a": a,
		"b": b,
		"thickness_mm": clampf(thickness_mm, 50.0, 1000.0),
		"height_mm": clampf(height_mm, 1800.0, 10000.0),
		"load_bearing": false,
		"opening": "",
		"layer": "walls"
	}
	if not Geometry.valid_wall(wall):
		return false
	_record_history()
	walls.append(wall)
	selected_wall = walls.size() - 1
	wall_created.emit(a, b)
	walls_changed.emit()
	queue_redraw()
	return true

func split_selected_wall_at_mm(distance_mm: float) -> bool:
	if selected_wall < 0 or selected_wall >= walls.size():
		return false
	var result := Geometry.split_wall_at_distance(walls, selected_wall, Units.mm_to_pixels(distance_mm))
	if not bool(result.get("ok", false)):
		return false
	_record_history()
	walls = result["walls"]
	selected_wall = int(result.get("new_index", selected_wall + 1))
	walls_changed.emit()
	queue_redraw()
	return true


func merge_selected_wall_with_neighbor() -> bool:
	if selected_wall < 0 or selected_wall >= walls.size():
		return false
	var result := Geometry.merge_collinear_walls(walls, selected_wall)
	if not bool(result.get("ok", false)):
		return false
	_record_history()
	walls = result["walls"]
	selected_wall = int(result.get("merged_index", selected_wall))
	walls_changed.emit()
	queue_redraw()
	return true



func move_wall_endpoint(wall_index: int, endpoint_index: int, target_point: Vector2) -> bool:
	if wall_index < 0 or wall_index >= walls.size():
		return false
	var snapped_target := _snap(target_point)
	var moved := Geometry.move_connected_endpoint(walls, wall_index, endpoint_index, snapped_target)
	if moved.is_empty():
		return false
	_record_history()
	walls = moved
	selected_wall = wall_index
	walls_changed.emit()
	queue_redraw()
	return true

func duplicate_selected_wall(offset_mm: Vector2 = Vector2(250.0, 250.0)) -> bool:
	if selected_wall < 0 or selected_wall >= walls.size():
		return false
	var source: Dictionary = walls[selected_wall]
	var offset_px := Vector2(Units.mm_to_pixels(offset_mm.x), Units.mm_to_pixels(offset_mm.y))
	var copied := Geometry.translated(source, offset_px)
	_record_history()
	walls.append(copied)
	selected_wall = walls.size() - 1
	walls_changed.emit()
	queue_redraw()
	return true


func mirror_selected_wall() -> bool:
	if selected_wall < 0 or selected_wall >= walls.size():
		return false
	var source: Dictionary = walls[selected_wall]
	var mirrored: Dictionary = source.duplicate(true)
	var axis_x := size.x * 0.5
	var a: Vector2 = source.get("a", Vector2.ZERO)
	var b: Vector2 = source.get("b", Vector2.ZERO)
	mirrored["a"] = Vector2(2.0 * axis_x - a.x, a.y)
	mirrored["b"] = Vector2(2.0 * axis_x - b.x, b.y)
	_record_history()
	walls.append(mirrored)
	selected_wall = walls.size() - 1
	walls_changed.emit()
	queue_redraw()
	return true


func array_selected_wall(copy_count: int, spacing_mm: float) -> bool:
	if selected_wall < 0 or selected_wall >= walls.size() or copy_count < 1 or copy_count > 20 or spacing_mm <= 0.0:
		return false
	var source: Dictionary = walls[selected_wall]
	var a: Vector2 = source.get("a", Vector2.ZERO)
	var b: Vector2 = source.get("b", Vector2.ZERO)
	var direction := (b - a).normalized()
	if direction.length_squared() < 0.001:
		return false
	var normal := Vector2(-direction.y, direction.x)
	var offset := normal * Units.mm_to_pixels(spacing_mm)
	_record_history()
	for index in range(1, copy_count + 1):
		walls.append(Geometry.translated(source, offset * float(index)))
	selected_wall = walls.size() - 1
	walls_changed.emit()
	queue_redraw()
	return true


func resolve_wall_intersections() -> Dictionary:
	if walls.size() < 2:
		return {"ok": true, "changed": false, "count": walls.size()}
	var result := Geometry.split_all_intersections(walls)
	if not bool(result.get("ok", false)):
		return result
	if bool(result.get("changed", false)):
		_record_history()
		walls = result["walls"]
		selected_wall = -1
		walls_changed.emit()
		queue_redraw()
	return {"ok": true, "changed": bool(result.get("changed", false)), "count": walls.size()}

func _record_history() -> void:
	undo_history.append(walls.duplicate(true))
	if undo_history.size() > MAX_HISTORY:
		undo_history.pop_front()
	redo_history.clear()

func undo() -> bool:
	if undo_history.is_empty():
		return false
	redo_history.append(walls.duplicate(true))
	walls = undo_history.pop_back()
	selected_wall = -1
	walls_changed.emit()
	queue_redraw()
	return true

func redo() -> bool:
	if redo_history.is_empty():
		return false
	undo_history.append(walls.duplicate(true))
	walls = redo_history.pop_back()
	selected_wall = -1
	walls_changed.emit()
	queue_redraw()
	return true

func reset_history() -> void:
	undo_history.clear()
	redo_history.clear()

func clear_plan() -> void:
	if not walls.is_empty():
		_record_history()
	walls.clear()
	selected_wall = -1
	drawing = false
	dragging_wall = false
	walls_changed.emit()
	queue_redraw()
