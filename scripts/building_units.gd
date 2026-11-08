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
