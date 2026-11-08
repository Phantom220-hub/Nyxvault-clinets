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
