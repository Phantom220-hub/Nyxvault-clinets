extends SceneTree

const Units = preload("res://scripts/building_units.gd")
const Geometry = preload("res://scripts/wall_geometry.gd")

func _initialize() -> void:
	assert(is_equal_approx(Units.pixels_to_mm(48.0), 1000.0))
	assert(is_equal_approx(Units.mm_to_pixels(2500.0), 120.0))
	assert(is_equal_approx(Units.pixels_to_metres(96.0), 2.0))

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

	var angled := Geometry.constrain_angle(Vector2.ZERO, Vector2(100.0, 40.0), 15.0)
	assert(is_equal_approx(rad_to_deg(angled.angle()), 30.0))
	assert(is_equal_approx(angled.length(), Vector2(100.0, 40.0).length()))

	var invalid := {"a": Vector2.ZERO, "b": Vector2(1.0, 1.0)}
	assert(not Geometry.valid_wall(invalid))
	print("DreamHouse geometry/unit tests passed")
	quit(0)
