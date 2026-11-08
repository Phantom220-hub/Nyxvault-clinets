extends RefCounted
class_name WallGeometry

const JOIN_TOLERANCE_PX := 12.0
const MIN_WALL_LENGTH_PX := 8.0

static func length_px(wall: Dictionary) -> float:
	return (wall.get("a", Vector2.ZERO) as Vector2).distance_to(wall.get("b", Vector2.ZERO) as Vector2)

static func direction(wall: Dictionary) -> Vector2:
	var a: Vector2 = wall.get("a", Vector2.ZERO)
	var b: Vector2 = wall.get("b", Vector2.ZERO)
	return (b - a).normalized()

static func closest_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var segment := b - a
	var denominator := segment.length_squared()
	if denominator <= 0.0001:
		return a
	var t := clampf((point - a).dot(segment) / denominator, 0.0, 1.0)
	return a + segment * t

static func distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	return point.distance_to(closest_point_on_segment(point, a, b))

static func translated(wall: Dictionary, offset: Vector2) -> Dictionary:
	var result := wall.duplicate(true)
	result["a"] = (wall.get("a", Vector2.ZERO) as Vector2) + offset
	result["b"] = (wall.get("b", Vector2.ZERO) as Vector2) + offset
	return result

static func resized_to_length(wall: Dictionary, length_px: float) -> Dictionary:
	var result := wall.duplicate(true)
	var a: Vector2 = wall.get("a", Vector2.ZERO)
	var b: Vector2 = wall.get("b", Vector2.ZERO)
	var delta := b - a
	if delta.length() < 0.001:
		return result
	result["b"] = a + delta.normalized() * maxf(MIN_WALL_LENGTH_PX, length_px)
	return result

static func valid_wall(wall: Dictionary) -> bool:
	var a: Variant = wall.get("a")
	var b: Variant = wall.get("b")
	return a is Vector2 and b is Vector2 and a.distance_to(b) >= MIN_WALL_LENGTH_PX

static func snap_point(point: Vector2, grid: float) -> Vector2:
	if grid <= 0.0:
		return point
	return (point / grid).round() * grid
