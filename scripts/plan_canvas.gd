extends Control
class_name PlanCanvas
signal wall_created(a: Vector2, b: Vector2)
var walls: Array[Dictionary] = []
var drawing := false
var start_point := Vector2.ZERO
var current_point := Vector2.ZERO
var grid_size := 32.0
var snap_enabled := true
const GRID_MINOR := Color("#293B49")
const GRID_MAJOR := Color("#365263")
const WALL_COLOR := Color("#52D6C7")
const PREVIEW_COLOR := Color("#FFC878")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#121E28"), true)
	var step := int(grid_size)
	for x in range(0, int(size.x) + step, step):
		var major := (x / step) % 4 == 0
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_MAJOR if major else GRID_MINOR, 1.4 if major else 0.7)
	for y in range(0, int(size.y) + step, step):
		var major := (y / step) % 4 == 0
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_MAJOR if major else GRID_MINOR, 1.4 if major else 0.7)
	for wall in walls:
		draw_line(wall.a, wall.b, Color("#0A1118"), 13.0, true)
		draw_line(wall.a, wall.b, WALL_COLOR, 8.0, true)
		draw_circle(wall.a, 5.0, Color("#EAFBF8"))
		draw_circle(wall.b, 5.0, Color("#EAFBF8"))
		var mid: Vector2 = (wall.a + wall.b) * 0.5
		draw_string(ThemeDB.fallback_font, mid + Vector2(7, -10), "%.2f м" % (wall.a.distance_to(wall.b) / 48.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#D9F5F0"))
		var opening := str(wall.get("opening", ""))
		if opening == "door" or opening == "window":
			var tag := "ДВЕРЬ" if opening == "door" else "ОКНО"
			draw_string(ThemeDB.fallback_font, mid + Vector2(7, 15), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#FFC878"))
	if drawing:
		draw_line(start_point, current_point, PREVIEW_COLOR, 7.0, true)
		draw_circle(start_point, 7.0, PREVIEW_COLOR)
		draw_circle(current_point, 7.0, PREVIEW_COLOR)

func _snap(p: Vector2) -> Vector2:
	return (p / grid_size).round() * grid_size if snap_enabled else p

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_wall(event.position)
		else:
			_finish_wall(event.position)
	elif event is InputEventMouseMotion and drawing:
		current_point = _snap(event.position)
		queue_redraw()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_wall(event.position)
		else:
			_finish_wall(event.position)
	elif event is InputEventScreenDrag and drawing:
		current_point = _snap(event.position)
		queue_redraw()

func _begin_wall(p: Vector2) -> void:
	drawing = true
	start_point = _snap(p)
	current_point = start_point
	accept_event()
	queue_redraw()

func _finish_wall(p: Vector2) -> void:
	if not drawing:
		return
	current_point = _snap(p)
	drawing = false
	if start_point.distance_to(current_point) >= grid_size:
		walls.append({"a": start_point, "b": current_point})
		wall_created.emit(start_point, current_point)
	accept_event()
	queue_redraw()

func undo() -> void:
	if not walls.is_empty():
		walls.pop_back()
		queue_redraw()

func clear_plan() -> void:
	walls.clear()
	drawing = false
	queue_redraw()
