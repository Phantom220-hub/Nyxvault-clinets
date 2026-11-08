extends RefCounted
class_name WallGeometry

const JOIN_TOLERANCE_PX := 12.0
const MIN_WALL_LENGTH_PX := 8.0

static func length_px(wall: Dictionary) -> float:
	var a: Vector2 = wall.get("a", Vector2.ZERO)
	var b: Vector2 = wall.get("b", Vector2.ZERO)
	return a.distance_to(b)

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
	var a: Vector2 = wall.get("a", Vector2.ZERO)
	var b: Vector2 = wall.get("b", Vector2.ZERO)
	result["a"] = a + offset
	result["b"] = b + offset
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
	if not (a is Vector2) or not (b is Vector2):
		return false
	var start: Vector2 = a
	var finish: Vector2 = b
	return start.distance_to(finish) >= MIN_WALL_LENGTH_PX

static func snap_point(point: Vector2, grid: float) -> Vector2:
	if grid <= 0.0:
		return point
	return (point / grid).round() * grid

static func constrain_angle(origin: Vector2, point: Vector2, increment_degrees: float = 15.0) -> Vector2:
	if increment_degrees <= 0.0:
		return point
	var delta := point - origin
	if delta.length_squared() <= 0.0001:
		return point
	var increment := deg_to_rad(increment_degrees)
	var angle := roundf(delta.angle() / increment) * increment
	return origin + Vector2.from_angle(angle) * delta.length()


static func connected_component_indices(walls: Array, root_index: int, tolerance: float = JOIN_TOLERANCE_PX) -> Array[int]:
	var result: Array[int] = []
	if root_index < 0 or root_index >= walls.size():
		return result
	var visited: Dictionary = {root_index: true}
	var queue: Array[int] = [root_index]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		result.append(current)
		var current_wall: Dictionary = walls[current]
		for candidate in range(walls.size()):
			if visited.has(candidate):
				continue
			var other: Dictionary = walls[candidate]
			var touches := false
			for endpoint_a in [current_wall.get("a", Vector2.ZERO), current_wall.get("b", Vector2.ZERO)]:
				for endpoint_b in [other.get("a", Vector2.ZERO), other.get("b", Vector2.ZERO)]:
					if endpoint_a.distance_to(endpoint_b) <= tolerance:
						touches = true
			if touches:
				visited[candidate] = true
				queue.append(candidate)
	return result

static func translated_connected_component(walls: Array, root_index: int, offset: Vector2, tolerance: float = JOIN_TOLERANCE_PX) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for wall in walls:
		result.append(wall.duplicate(true))
	for index in connected_component_indices(walls, root_index, tolerance):
		result[index] = translated(walls[index], offset)
	return result

static func move_connected_endpoint(walls: Array, wall_index: int, endpoint_index: int, new_point: Vector2, tolerance: float = JOIN_TOLERANCE_PX) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for wall in walls:
		result.append(wall.duplicate(true))
	if wall_index < 0 or wall_index >= walls.size() or (endpoint_index != 0 and endpoint_index != 1):
		return result
	var source: Dictionary = walls[wall_index]
	var old_point: Vector2 = source.get("a", Vector2.ZERO) if endpoint_index == 0 else source.get("b", Vector2.ZERO)
	var selected := source.duplicate(true)
	selected["a" if endpoint_index == 0 else "b"] = new_point
	result[wall_index] = selected
	for index in range(walls.size()):
		if index == wall_index:
			continue
		var candidate: Dictionary = result[index].duplicate(true)
		for key in ["a", "b"]:
			var endpoint: Vector2 = candidate.get(key, Vector2.ZERO)
			if endpoint.distance_to(old_point) <= tolerance:
				candidate[key] = new_point
		result[index] = candidate
	for wall in result:
		if not valid_wall(wall):
			return []
	return result

static func polygon_area(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0
	var twice_area := 0.0
	for index in range(points.size()):
		var next_index := (index + 1) % points.size()
		twice_area += points[index].x * points[next_index].y - points[next_index].x * points[index].y
	return absf(twice_area) * 0.5

static func polygon_perimeter(points: PackedVector2Array) -> float:
	if points.size() < 2:
		return 0.0
	var total := 0.0
	for index in range(points.size()):
		total += points[index].distance_to(points[(index + 1) % points.size()])
	return total


static func signed_polygon_area(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0
	var twice_area := 0.0
	for index in range(points.size()):
		var next_index := (index + 1) % points.size()
		twice_area += points[index].x * points[next_index].y - points[next_index].x * points[index].y
	return twice_area * 0.5

static func find_bounded_faces(walls: Array, minimum_area_px2: float = 1.0) -> Array[PackedVector2Array]:
	var graph: Dictionary = {}
	for wall in walls:
		if not valid_wall(wall):
			continue
		var a: Vector2 = wall.get("a", Vector2.ZERO)
		var b: Vector2 = wall.get("b", Vector2.ZERO)
		if not graph.has(a):
			graph[a] = []
		if not graph.has(b):
			graph[b] = []
		if not graph[a].has(b):
			graph[a].append(b)
		if not graph[b].has(a):
			graph[b].append(a)
	for vertex in graph.keys():
		var origin: Vector2 = vertex
		var neighbors: Array = graph[vertex]
		neighbors.sort_custom(func(left: Vector2, right: Vector2) -> bool:
			return atan2(left.y - origin.y, left.x - origin.x) < atan2(right.y - origin.y, right.x - origin.x)
		)
		graph[vertex] = neighbors
	var visited: Dictionary = {}
	var faces: Array[PackedVector2Array] = []
	var edge_limit := maxi(8, walls.size() * 4 + 4)
	for origin_variant in graph.keys():
		var origin: Vector2 = origin_variant
		for neighbor_variant in graph[origin]:
			var first_neighbor: Vector2 = neighbor_variant
			var first_key := str(origin) + ">" + str(first_neighbor)
			if visited.has(first_key):
				continue
			var polygon := PackedVector2Array()
			var from_point := origin
			var to_point := first_neighbor
			var closed := false
			for _step in range(edge_limit):
				var directed_key := str(from_point) + ">" + str(to_point)
				if visited.has(directed_key):
					break
				visited[directed_key] = true
				polygon.append(from_point)
				var around: Array = graph.get(to_point, [])
				var reverse_index := around.find(from_point)
				if reverse_index < 0 or around.is_empty():
					break
				var next_index := posmod(reverse_index - 1, around.size())
				var next_point: Vector2 = around[next_index]
				from_point = to_point
				to_point = next_point
				if from_point == origin and to_point == first_neighbor:
					closed = true
					break
			if closed and polygon.size() >= 3 and signed_polygon_area(polygon) > minimum_area_px2:
				faces.append(polygon)
	return faces
