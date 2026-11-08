extends Control
class_name PlanCanvas

signal wall_created(a: Vector2, b: Vector2)

var walls: Array[Dictionary] = []
var drawing := false
var start_point := Vector2.ZERO
var current_point := Vector2.ZERO
var grid_size := 32.0
var snap_enabled := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _draw() -> void:
	var step := grid_size
	for x in range(0, int(size.x) + 1, int(step)):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.25, 0.30, 0.36, 0.35), 1.0)
	for y in range(0, int(size.y) + 1, int(step)):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.25, 0.30, 0.36, 0.35), 1.0)
	for wall in walls:
		draw_line(wall.a, wall.b, Color(0.12, 0.72, 0.95), 8.0, true)
	if drawing:
		draw_line(start_point, current_point, Color(1.0, 0.75, 0.25), 6.0, true)
		draw_circle(current_point, 7.0, Color(1.0, 0.75, 0.25))

func _snap(point: Vector2) -> Vector2:
	if not snap_enabled:
		return point
	return (point / grid_size).round() * grid_size

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drawing = true
			start_point = _snap(event.position)
			current_point = start_point
			accept_event()
		else:
			if drawing:
				current_point = _snap(event.position)
				_finish_wall()
	elif event is InputEventMouseMotion and drawing:
		current_point = _snap(event.position)
		queue_redraw()
	elif event is InputEventScreenTouch:
		if event.pressed:
			drawing = true
			start_point = _snap(event.position)
			current_point = start_point
			accept_event()
		else:
			if drawing:
				current_point = _snap(event.position)
				_finish_wall()
	elif event is InputEventScreenDrag and drawing:
		current_point = _snap(event.position)
		queue_redraw()

func _finish_wall() -> void:
	drawing = false
	if start_point.distance_to(current_point) >= grid_size:
		walls.append({"a": start_point, "b": current_point})
		wall_created.emit(start_point, current_point)
	queue_redraw()

func undo() -> void:
	if not walls.is_empty():
		walls.pop_back()
		queue_redraw()

func clear_plan() -> void:
	walls.clear()
	queue_redraw()
