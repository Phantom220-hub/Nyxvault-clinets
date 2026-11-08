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



static func _cross2(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x


static func segment_intersection_parameters(a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2, epsilon: float = 0.000001) -> Dictionary:
	var r := a1 - a0
	var s := b1 - b0
	var denominator := _cross2(r, s)
	var q_minus_p := b0 - a0
	if absf(denominator) <= epsilon:
		return {"collinear": absf(_cross2(q_minus_p, r)) <= epsilon}
	var t := _cross2(q_minus_p, s) / denominator
	var u := _cross2(q_minus_p, r) / denominator
	if t < -epsilon or t > 1.0 + epsilon or u < -epsilon or u > 1.0 + epsilon:
		return {}
	return {"t": clampf(t, 0.0, 1.0), "u": clampf(u, 0.0, 1.0), "point": a0 + r * clampf(t, 0.0, 1.0)}


static func _opening_interval_mm(wall: Dictionary) -> Vector2:
	var width := float(wall.get("opening_width_mm", 0.0))
	var center := float(wall.get("opening_offset_mm", 0.0))
	return Vector2(center - width * 0.5, center + width * 0.5)


static func _opening_is_cut_by_split(wall: Dictionary, split_distance_px: float) -> bool:
	var kind := str(wall.get("opening", ""))
	if kind != "door" and kind != "window":
		return false
	var split_mm := split_distance_px / 48.0 * 1000.0
	var interval := _opening_interval_mm(wall)
	return split_mm > interval.x + 0.01 and split_mm < interval.y - 0.01


static func _without_opening(wall: Dictionary) -> Dictionary:
	var result := wall.duplicate(true)
	result["opening"] = ""
	result.erase("opening_width_mm")
	result.erase("opening_offset_mm")
	result.erase("opening_height_mm")
	result.erase("sill_height_mm")
	return result


static func split_wall_at_distance(walls: Array, wall_index: int, split_distance_px: float) -> Dictionary:
	if wall_index < 0 or wall_index >= walls.size():
		return {"ok": false, "error": "invalid_wall_index"}
	var source: Dictionary = walls[wall_index]
	var wall_length := length_px(source)
	if split_distance_px <= MIN_WALL_LENGTH_PX or split_distance_px >= wall_length - MIN_WALL_LENGTH_PX:
		return {"ok": false, "error": "split_too_close_to_endpoint"}
	if _opening_is_cut_by_split(source, split_distance_px):
		return {"ok": false, "error": "split_crosses_opening"}
	var a: Vector2 = source.get("a", Vector2.ZERO)
	var b: Vector2 = source.get("b", Vector2.ZERO)
	var split_point := a.lerp(b, split_distance_px / wall_length)
	var first := source.duplicate(true)
	var second := source.duplicate(true)
	first["b"] = split_point
	second["a"] = split_point
	var opening := str(source.get("opening", ""))
	if opening == "door" or opening == "window":
		var split_mm := split_distance_px / 48.0 * 1000.0
		var interval := _opening_interval_mm(source)
		if interval.y <= split_mm + 0.01:
			second = _without_opening(second)
		elif interval.x >= split_mm - 0.01:
			first = _without_opening(first)
			second["opening_offset_mm"] = float(source.get("opening_offset_mm", 0.0)) - split_mm
	var result: Array[Dictionary] = []
	for index in range(walls.size()):
		if index == wall_index:
			result.append(first)
			result.append(second)
		else:
			var untouched: Dictionary = walls[index]
			result.append(untouched.duplicate(true))
	return {"ok": true, "walls": result, "new_index": wall_index + 1}


static func split_all_intersections(walls: Array, endpoint_epsilon: float = 0.00001) -> Dictionary:
	var split_parameters: Array = []
	for _wall in walls:
		split_parameters.append([0.0, 1.0])
	for first_index in range(walls.size()):
		var first: Dictionary = walls[first_index]
		if not valid_wall(first):
			return {"ok": false, "error": "invalid_wall", "walls": []}
		var a0: Vector2 = first.get("a", Vector2.ZERO)
		var a1: Vector2 = first.get("b", Vector2.ZERO)
		for second_index in range(first_index + 1, walls.size()):
			var second: Dictionary = walls[second_index]
			if not valid_wall(second):
				return {"ok": false, "error": "invalid_wall", "walls": []}
			var b0: Vector2 = second.get("a", Vector2.ZERO)
			var b1: Vector2 = second.get("b", Vector2.ZERO)
			var hit := segment_intersection_parameters(a0, a1, b0, b1)
			if not hit.has("t"):
				continue
			var t := float(hit["t"])
			var u := float(hit["u"])
			var first_interior := t > endpoint_epsilon and t < 1.0 - endpoint_epsilon
			var second_interior := u > endpoint_epsilon and u < 1.0 - endpoint_epsilon
			if not first_interior and not second_interior:
				continue
			if first_interior and _opening_is_cut_by_split(first, length_px(first) * t):
				return {"ok": false, "error": "intersection_crosses_opening", "wall_index": first_index, "other_wall_index": second_index, "walls": []}
			if second_interior and _opening_is_cut_by_split(second, length_px(second) * u):
				return {"ok": false, "error": "intersection_crosses_opening", "wall_index": second_index, "other_wall_index": first_index, "walls": []}
			if first_interior:
				split_parameters[first_index].append(t)
			if second_interior:
				split_parameters[second_index].append(u)
	var normalized: Array[Dictionary] = []
	var changed := false
	for wall_index in range(walls.size()):
		var source: Dictionary = walls[wall_index]
		var params: Array = split_parameters[wall_index]
		params.sort()
		var unique_params: Array[float] = []
		for raw_t in params:
			var t := float(raw_t)
			if unique_params.is_empty() or absf(t - unique_params.back()) > endpoint_epsilon:
				unique_params.append(t)
		if unique_params.size() > 2:
			changed = true
		var a: Vector2 = source.get("a", Vector2.ZERO)
		var b: Vector2 = source.get("b", Vector2.ZERO)
		var full_length_px := a.distance_to(b)
		var full_length_mm := full_length_px / 48.0 * 1000.0
		var opening := str(source.get("opening", ""))
		var interval := _opening_interval_mm(source)
		for part_index in range(unique_params.size() - 1):
			var t0 := unique_params[part_index]
			var t1 := unique_params[part_index + 1]
			var part_a := a.lerp(b, t0)
			var part_b := b if t1 >= 1.0 - endpoint_epsilon else a.lerp(b, t1)
			if t0 <= endpoint_epsilon:
				part_a = a
			if t1 >= 1.0 - endpoint_epsilon:
				part_b = b
			if part_a.distance_to(part_b) < MIN_WALL_LENGTH_PX:
				return {"ok": false, "error": "intersection_creates_tiny_segment", "wall_index": wall_index, "walls": []}
			var child := source.duplicate(true)
			child["a"] = part_a
			child["b"] = part_b
			if opening == "door" or opening == "window":
				var part_start_mm := t0 * full_length_mm
				var part_end_mm := t1 * full_length_mm
				if interval.x >= part_start_mm - 0.01 and interval.y <= part_end_mm + 0.01:
					child["opening_offset_mm"] = float(source.get("opening_offset_mm", 0.0)) - part_start_mm
				else:
					child = _without_opening(child)
			normalized.append(child)
	return {"ok": true, "changed": changed, "walls": normalized}


static func merge_collinear_walls(walls: Array, wall_index: int, tolerance_px: float = JOIN_TOLERANCE_PX, angle_tolerance_degrees: float = 2.0) -> Dictionary:
	if wall_index < 0 or wall_index >= walls.size():
		return {"ok": false, "error": "invalid_wall_index"}
	var first: Dictionary = walls[wall_index]
	if not valid_wall(first):
		return {"ok": false, "error": "invalid_wall"}
	var a: Vector2 = first.get("a", Vector2.ZERO)
	var b: Vector2 = first.get("b", Vector2.ZERO)
	var first_dir := (b - a).normalized()
	var candidate_index := -1
	var first_far := Vector2.ZERO
	var second_far := Vector2.ZERO
	for index in range(walls.size()):
		if index == wall_index:
			continue
		var candidate: Dictionary = walls[index]
		if not valid_wall(candidate):
			continue
		if float(candidate.get("thickness_mm", 150.0)) != float(first.get("thickness_mm", 150.0)) or float(candidate.get("height_mm", 2800.0)) != float(first.get("height_mm", 2800.0)) or bool(candidate.get("load_bearing", false)) != bool(first.get("load_bearing", false)) or str(candidate.get("layer", "walls")) != str(first.get("layer", "walls")):
			continue
		var ca: Vector2 = candidate.get("a", Vector2.ZERO)
		var cb: Vector2 = candidate.get("b", Vector2.ZERO)
		var joins: Array = []
		if b.distance_to(ca) <= tolerance_px:
			joins.append([b, a, ca, cb])
		if b.distance_to(cb) <= tolerance_px:
			joins.append([b, a, cb, ca])
		if a.distance_to(cb) <= tolerance_px:
			joins.append([a, b, cb, ca])
		if a.distance_to(ca) <= tolerance_px:
			joins.append([a, b, ca, cb])
		for join in joins:
			var joint: Vector2 = join[0]
			var far_first: Vector2 = join[1]
			var far_second: Vector2 = join[3]
			var merged_dir := (far_second - far_first).normalized()
			var candidate_dir := (cb - ca).normalized()
			var angle := absf(rad_to_deg(acos(clampf(absf(first_dir.dot(candidate_dir)), -1.0, 1.0))))
			var lateral_error := absf((joint - far_first).cross(merged_dir))
			if angle <= angle_tolerance_degrees and lateral_error <= tolerance_px:
				if candidate_index >= 0:
					return {"ok": false, "error": "ambiguous_multiple_neighbors"}
				candidate_index = index
				first_far = far_first
				second_far = far_second
	if candidate_index < 0:
		return {"ok": false, "error": "no_collinear_neighbor"}
	var second: Dictionary = walls[candidate_index]
	var first_opening := str(first.get("opening", ""))
	var second_opening := str(second.get("opening", ""))
	if not first_opening.is_empty() and not second_opening.is_empty():
		return {"ok": false, "error": "two_openings_cannot_be_merged"}
	var merged := first.duplicate(true)
	var merged_start := first_far
	var merged_end := second_far
	var merged_length_px := merged_start.distance_to(merged_end)
	if merged_length_px < MIN_WALL_LENGTH_PX:
		return {"ok": false, "error": "merged_wall_invalid"}
	merged["a"] = merged_start
	merged["b"] = merged_end
	var source_opening_wall: Dictionary = first if not first_opening.is_empty() else second
	var source_opening := first_opening if not first_opening.is_empty() else second_opening
	if not source_opening.is_empty():
		var source_a: Vector2 = source_opening_wall.get("a", Vector2.ZERO)
		var source_b: Vector2 = source_opening_wall.get("b", Vector2.ZERO)
		var opening_center_px: Vector2 = source_a + (source_b - source_a).normalized() * (float(source_opening_wall.get("opening_offset_mm", 0.0)) / 1000.0 * 48.0)
		var opening_global_offset_mm := merged_start.distance_to(opening_center_px) * 1000.0 / 48.0
		merged["opening"] = source_opening
		merged["opening_offset_mm"] = clampf(opening_global_offset_mm, 0.0, merged_length_px * 1000.0 / 48.0)
		merged["opening_width_mm"] = float(source_opening_wall.get("opening_width_mm", 0.0))
		merged["opening_height_mm"] = float(source_opening_wall.get("opening_height_mm", 0.0))
		merged["sill_height_mm"] = float(source_opening_wall.get("sill_height_mm", 0.0))
	else:
		merged = _without_opening(merged)
	var result: Array[Dictionary] = []
	for index in range(walls.size()):
		if index == mini(wall_index, candidate_index):
			result.append(merged)
		if index != wall_index and index != candidate_index:
			var untouched: Dictionary = walls[index]
			result.append(untouched.duplicate(true))
	return {"ok": true, "walls": result, "merged_index": mini(wall_index, candidate_index)}


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
