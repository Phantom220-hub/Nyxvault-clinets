extends SceneTree

const Units = preload("res://scripts/building_units.gd")
const Geometry = preload("res://scripts/wall_geometry.gd")

func _initialize() -> void:
	assert(is_equal_approx(Units.pixels_to_mm(48.0), 1000.0))
	assert(is_equal_approx(Units.mm_to_pixels(2500.0), 120.0))
	assert(is_equal_approx(Units.pixels_to_metres(96.0), 2.0))

	var level_data: Array = [
		{"floor_height_mm": 3000.0, "slab_thickness_mm": 200.0, "walls": [{"height_mm": 3500.0}]},
		{"floor_height_mm": 2800.0, "slab_thickness_mm": 220.0, "walls": []}
	]
	assert(is_equal_approx(Units.floor_base_elevation(level_data, 1), 3.7))

	var wall := {"a": Vector2(0.0, 0.0), "b": Vector2(100.0, 0.0)}
	assert(Geometry.valid_wall(wall))
	assert(is_equal_approx(Geometry.length_px(wall), 100.0))
	assert(is_equal_approx(Geometry.distance_to_segment(Vector2(50.0, 10.0), wall.a, wall.b), 10.0))

	var resized := Geometry.resized_to_length(wall, 200.0)
	assert(is_equal_approx(Geometry.length_px(resized), 200.0))
	assert(resized.a == Vector2.ZERO)
	assert(resized.b == Vector2(200.0, 0.0))

	var moved := Geometry.translated(wall, Vector2(32.0, 64.0))
	assert(moved.a == Vector2(32.0, 64.0))
	assert(moved.b == Vector2(132.0, 64.0))

	var angled := Geometry.constrain_angle(Vector2.ZERO, Vector2(100.0, 50.0), 15.0)
	assert(is_equal_approx(rad_to_deg(angled.angle()), 30.0))
	assert(is_equal_approx(angled.length(), Vector2(100.0, 50.0).length()))

	var connected_walls: Array = [
		{"a": Vector2(0, 0), "b": Vector2(100, 0)},
		{"a": Vector2(100, 0), "b": Vector2(100, 100)},
		{"a": Vector2(300, 0), "b": Vector2(400, 0)}
	]
	var moved_component := Geometry.translated_connected_component(connected_walls, 0, Vector2(10, 20))
	assert(moved_component[0].a == Vector2(10, 20))
	assert(moved_component[1].a == Vector2(110, 20))
	assert(moved_component[2].a == Vector2(300, 0))
	var moved_endpoint := Geometry.move_connected_endpoint(connected_walls, 0, 1, Vector2(120, 0))
	assert(moved_endpoint[0].b == Vector2(120, 0))
	assert(moved_endpoint[1].a == Vector2(120, 0))
	var rectangle := PackedVector2Array([Vector2(0, 0), Vector2(200, 0), Vector2(200, 100), Vector2(0, 100)])
	assert(is_equal_approx(Geometry.polygon_area(rectangle), 20000.0))
	assert(is_equal_approx(Geometry.polygon_perimeter(rectangle), 600.0))
	var square_with_diagonal: Array = [
		{"a": Vector2(0, 0), "b": Vector2(200, 0)},
		{"a": Vector2(200, 0), "b": Vector2(200, 100)},
		{"a": Vector2(200, 100), "b": Vector2(0, 100)},
		{"a": Vector2(0, 100), "b": Vector2(0, 0)},
		{"a": Vector2(0, 0), "b": Vector2(200, 100)}
	]
	var faces := Geometry.find_bounded_faces(square_with_diagonal)
	assert(faces.size() == 2)
	var face_area_total := 0.0
	for face in faces:
		face_area_total += Geometry.polygon_area(face)
	assert(is_equal_approx(face_area_total, 20000.0))

	var invalid := {"a": Vector2.ZERO, "b": Vector2(1.0, 1.0)}
	assert(not Geometry.valid_wall(invalid))
	print("DreamHouse geometry/unit tests passed")
	quit(0)
