extends RefCounted
class_name BuildingUnits

# The project stores plan coordinates in pixels for compatibility with the
# existing canvas. The canonical design unit is the millimetre.
const PIXELS_PER_METRE := 48.0
const MILLIMETRES_PER_METRE := 1000.0

static func pixels_to_mm(value: float) -> float:
	return value / PIXELS_PER_METRE * MILLIMETRES_PER_METRE

static func mm_to_pixels(value: float) -> float:
	return value / MILLIMETRES_PER_METRE * PIXELS_PER_METRE

static func pixels_to_metres(value: float) -> float:
	return value / PIXELS_PER_METRE

static func metres_to_pixels(value: float) -> float:
	return value * PIXELS_PER_METRE

static func format_mm(value: float) -> String:
	return "%d mm" % roundi(value)

static func format_metres(value: float, decimals: int = 2) -> String:
	return ("%." + str(clampi(decimals, 0, 4)) + "f m") % (value / MILLIMETRES_PER_METRE)


static func floor_base_elevation(floors: Array, floor_index: int, default_height_m: float = 2.8, default_slab_m: float = 0.22) -> float:
	var elevation := 0.0
	for index in range(mini(floor_index, floors.size())):
		var floor_data: Dictionary = floors[index]
		var level_height := maxf(default_height_m, float(floor_data.get("floor_height_mm", default_height_m * 1000.0)) / 1000.0)
		for wall in floor_data.get("walls", []):
			level_height = maxf(level_height, float(wall.get("height_mm", default_height_m * 1000.0)) / 1000.0)
		var slab_thickness := clampf(float(floor_data.get("slab_thickness_mm", default_slab_m * 1000.0)) / 1000.0, 0.08, 1.0)
		elevation += level_height + slab_thickness
	return elevation


static func room_metrics(faces: Array, floor_height_mm: float = 2800.0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var height_m := maxf(0.1, floor_height_mm / MILLIMETRES_PER_METRE)
	for face_variant in faces:
		if not (face_variant is PackedVector2Array):
			continue
		var points: PackedVector2Array = face_variant
		if points.size() < 3:
			continue
		var twice_area := 0.0
		var perimeter_px := 0.0
		var center := Vector2.ZERO
		for index in range(points.size()):
			var next_point: Vector2 = points[(index + 1) % points.size()]
			var point: Vector2 = points[index]
			twice_area += point.x * next_point.y - next_point.x * point.y
			perimeter_px += point.distance_to(next_point)
			center += point
		var area_m2 := absf(twice_area) * 0.5 / (PIXELS_PER_METRE * PIXELS_PER_METRE)
		if area_m2 <= 0.0001:
			continue
		var perimeter_m := perimeter_px / PIXELS_PER_METRE
		center /= float(points.size())
		result.append({
			"area_m2": area_m2,
			"perimeter_m": perimeter_m,
			"height_m": height_m,
			"volume_m3": area_m2 * height_m,
			"center": center
		})
	return result


static func wall_net_area_m2(walls: Array) -> float:
	var total := 0.0
	for wall_variant in walls:
		if not (wall_variant is Dictionary):
			continue
		var wall: Dictionary = wall_variant
		var a: Variant = wall.get("a")
		var b: Variant = wall.get("b")
		if not (a is Vector2) or not (b is Vector2):
			continue
		var length_m := (a as Vector2).distance_to(b as Vector2) / PIXELS_PER_METRE
		var height_m := maxf(0.0, float(wall.get("height_mm", 2800.0)) / MILLIMETRES_PER_METRE)
		var area := length_m * height_m
		var opening_kind := str(wall.get("opening", ""))
		if opening_kind == "door" or opening_kind == "window":
			var opening_width_m := maxf(0.0, float(wall.get("opening_width_mm", 0.0)) / MILLIMETRES_PER_METRE)
			var opening_height_m := maxf(0.0, float(wall.get("opening_height_mm", 0.0)) / MILLIMETRES_PER_METRE)
			area -= opening_width_m * opening_height_m
		total += maxf(0.0, area)
	return total
