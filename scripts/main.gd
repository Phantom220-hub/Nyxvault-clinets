extends Control
const PlanCanvasScript = preload("res://scripts/plan_canvas.gd")
const WALL_HEIGHT := 2.8
const PPM := 48.0
const BG := Color("#101923")
const PANEL := Color("#192633")
const ACCENT := Color("#52D6C7")
const TEXT := Color("#F2F6F8")
const MUTED := Color("#9AAAB8")
var plan_canvas: PlanCanvas
var preview: SubViewportContainer
var preview_world: Node3D
var status_label: Label
var walls: Array[Dictionary] = []
var furniture: Array[Dictionary] = []
var is_3d := false
var object_menu: PopupMenu

func _ready() -> void:
	_build_interface()
	_rebuild_3d()

func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var header := PanelContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 14
	header.offset_right = -14
	header.offset_top = 14
	header.offset_bottom = 142
	header.add_theme_stylebox_override("panel", _style(PANEL, 20))
	add_child(header)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	header.add_child(stack)
	var title := Label.new()
	title.text = "DREAMHOUSE 3D"
	title.add_theme_color_override("font_color", TEXT)
	title.add_theme_font_size_override("font_size", 25)
	stack.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "ПРОЕКТИРУЙ • ОБСТАВЛЯЙ • ВИЗУАЛИЗИРУЙ"
	subtitle.add_theme_color_override("font_color", MUTED)
	subtitle.add_theme_font_size_override("font_size", 10)
	stack.add_child(subtitle)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 7)
	scroll.add_child(tools)
	_add_button(tools, "2D ПЛАН", _show_plan, true)
	_add_button(tools, "3D ВИД", _show_3d, false)
	_add_button(tools, "ОБЪЕКТЫ +", _open_object_menu, false)
	_add_button(tools, "UNDO", _undo, false)
	_add_button(tools, "ОЧИСТИТЬ", _clear, false)
	object_menu = PopupMenu.new()
	for pair in [["Диван", 0], ["Кровать", 1], ["Стол", 2], ["Кресло", 3], ["Шкаф", 4]]:
		object_menu.add_item(pair[0], pair[1])
	object_menu.id_pressed.connect(_on_object_selected)
	add_child(object_menu)

	plan_canvas = PlanCanvasScript.new()
	plan_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	plan_canvas.offset_left = 14
	plan_canvas.offset_top = 158
	plan_canvas.offset_right = -14
	plan_canvas.offset_bottom = -100
	plan_canvas.wall_created.connect(_on_wall_created)
	add_child(plan_canvas)

	preview = SubViewportContainer.new()
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview.offset_left = 14
	preview.offset_top = 158
	preview.offset_right = -14
	preview.offset_bottom = -100
	preview.stretch = true
	preview.visible = false
	add_child(preview)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 1400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	preview.add_child(viewport)
	preview_world = Node3D.new()
	viewport.add_child(preview_world)
	_setup_3d(viewport)

	var footer := PanelContainer.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 14
	footer.offset_right = -14
	footer.offset_top = -88
	footer.offset_bottom = -14
	footer.add_theme_stylebox_override("panel", _style(PANEL, 18))
	add_child(footer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	footer.add_child(row)
	var status_stack := VBoxContainer.new()
	status_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status_stack)
	var label := Label.new()
	label.text = "СТАТУС ПРОЕКТА"
	label.add_theme_color_override("font_color", MUTED)
	label.add_theme_font_size_override("font_size", 10)
	status_stack.add_child(label)
	status_label = Label.new()
	status_label.text = "Режим 2D • Нарисуйте стены пальцем"
	status_label.add_theme_color_override("font_color", TEXT)
	status_label.add_theme_font_size_override("font_size", 12)
	status_stack.add_child(status_label)
	_add_button(row, "СОХРАНИТЬ", _save_project, true)
	_add_button(row, "ОТКРЫТЬ", _load_project, false)

func _style(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.border_color = Color("#304554")
	s.border_width_bottom = 1
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s

func _add_button(parent: Container, caption: String, callback: Callable, accent: bool) -> void:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(0, 43)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", Color("#10242A") if accent else TEXT)
	b.add_theme_stylebox_override("normal", _style(ACCENT if accent else Color("#263847"), 11))
	b.add_theme_stylebox_override("hover", _style(Color("#75E8D9") if accent else Color("#344C5D"), 11))
	b.pressed.connect(callback)
	parent.add_child(b)

func _open_object_menu() -> void:
	object_menu.position = Vector2i(22, 150)
	object_menu.popup()

func _on_object_selected(id: int) -> void:
	var names := ["Диван", "Кровать", "Стол", "Кресло", "Шкаф"]
	furniture.append({"kind": id, "position": Vector2.ZERO})
	status_label.text = "Добавлен объект: %s • Всего: %d" % [names[id], furniture.size()]
	if is_3d:
		_rebuild_3d()

func _on_wall_created(_a: Vector2, _b: Vector2) -> void:
	walls = plan_canvas.walls.duplicate(true)
	status_label.text = "Стены: %d • Добавлена новая стена" % walls.size()

func _show_plan() -> void:
	is_3d = false
	plan_canvas.visible = true
	preview.visible = false
	status_label.text = "2D-план • Касайтесь и ведите пальцем"

func _show_3d() -> void:
	is_3d = true
	walls = plan_canvas.walls.duplicate(true)
	plan_canvas.visible = false
	preview.visible = true
	_rebuild_3d()
	status_label.text = "3D • Стен: %d • Мебели: %d" % [walls.size(), furniture.size()]

func _undo() -> void:
	plan_canvas.undo()
	walls = plan_canvas.walls.duplicate(true)
	status_label.text = "Последняя стена отменена"
	if is_3d:
		_rebuild_3d()

func _clear() -> void:
	plan_canvas.clear_plan()
	walls.clear()
	furniture.clear()
	status_label.text = "План очищен"
	if is_3d:
		_rebuild_3d()

func _setup_3d(_viewport: SubViewport) -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#243F59")
	sky_mat.sky_horizon_color = Color("#D8C9B2")
	sky_mat.ground_bottom_color = Color("#17232C")
	sky_mat.ground_horizon_color = Color("#A9A59A")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = env
	preview_world.add_child(world_env)
	var camera := Camera3D.new()
	camera.position = Vector3(10, 10, 12)
	camera.fov = 48.0
	camera.look_at(Vector3.ZERO, Vector3.UP)
	preview_world.add_child(camera)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	preview_world.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 5, 0)
	fill.light_energy = 0.55
	fill.omni_range = 18.0
	preview_world.add_child(fill)

func _mat(color: Color, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _box(parent: Node3D, size_3d: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size_3d
	mesh.mesh = shape
	mesh.position = pos
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

func _rebuild_3d() -> void:
	if not is_instance_valid(preview_world):
		return
	for child in preview_world.get_children():
		if child.is_in_group("generated"):
			child.queue_free()
	var root := Node3D.new()
	root.add_to_group("generated")
	preview_world.add_child(root)
	var floor_mat := _mat(Color("#D9D2C4"), 0.95)
	var grid_mat := _mat(Color("#B8B1A4"), 0.8)
	_box(root, Vector3(24, 0.12, 24), Vector3(0, -0.12, 0), floor_mat)
	for i in range(-12, 13):
		_box(root, Vector3(0.012, 0.006, 24), Vector3(i, -0.055, 0), grid_mat)
		_box(root, Vector3(24, 0.006, 0.012), Vector3(0, -0.054, i), grid_mat)
	var wall_mat := _mat(Color("#F0E9DC"), 0.82)
	var trim_mat := _mat(Color("#BDAA8F"), 0.6)
	for wall in walls:
		var a: Vector2 = wall.a
		var b: Vector2 = wall.b
		var mid := (a + b) * 0.5
		var length := a.distance_to(b) / PPM
		var angle := atan2(b.y - a.y, b.x - a.x)
		var center := Vector3((mid.x - plan_canvas.size.x * 0.5) / PPM, 1.4, (mid.y - plan_canvas.size.y * 0.5) / PPM)
		var segment := _box(root, Vector3(maxf(length, 0.12), WALL_HEIGHT, 0.16), center, wall_mat)
		segment.rotation.y = -angle
		var skirting := _box(root, Vector3(maxf(length, 0.12), 0.1, 0.19), Vector3(center.x, 0.1, center.z), trim_mat)
		skirting.rotation.y = -angle
		var crown := _box(root, Vector3(maxf(length, 0.12), 0.07, 0.19), Vector3(center.x, WALL_HEIGHT - 0.035, center.z), trim_mat)
		crown.rotation.y = -angle
	for item in furniture:
		_add_furniture(root, item)

func _add_furniture(root: Node3D, item: Dictionary) -> void:
	var kind := int(item.get("kind", 0))
	var p: Vector2 = item.get("position", Vector2.ZERO)
	var c := Vector3(p.x, 0, p.y)
	var wood := _mat(Color("#8B6549"), 0.5)
	var fabric := _mat(Color("#477E83"), 0.95)
	var soft := _mat(Color("#B7D0C8"), 0.95)
	var metal := _mat(Color("#333E47"), 0.35)
	match kind:
		0:
			_box(root, Vector3(2.1, 0.42, 0.85), c + Vector3(0, 0.42, 0), fabric)
			_box(root, Vector3(2.1, 0.72, 0.2), c + Vector3(0, 0.86, -0.33), fabric)
			for x in [-0.88, 0.88]:
				_box(root, Vector3(0.2, 0.72, 0.85), c + Vector3(x, 0.68, 0), fabric)
			_box(root, Vector3(1.5, 0.12, 0.58), c + Vector3(0, 0.7, 0.04), soft)
		1:
			_box(root, Vector3(2.2, 0.28, 2.7), c + Vector3(0, 0.38, 0), wood)
			_box(root, Vector3(2.05, 0.22, 2.5), c + Vector3(0, 0.62, 0), soft)
			_box(root, Vector3(2.2, 1.1, 0.16), c + Vector3(0, 0.85, -1.32), wood)
		2:
			_box(root, Vector3(1.8, 0.12, 1.1), c + Vector3(0, 0.95, 0), wood)
			for x in [-0.72, 0.72]:
				for z in [-0.38, 0.38]:
					_box(root, Vector3(0.09, 0.9, 0.09), c + Vector3(x, 0.45, z), metal)
		3:
			_box(root, Vector3(0.95, 0.42, 0.9), c + Vector3(0, 0.48, 0), fabric)
			_box(root, Vector3(0.95, 0.8, 0.18), c + Vector3(0, 0.92, -0.36), fabric)
		4:
			_box(root, Vector3(1.25, 2.1, 0.65), c + Vector3(0, 1.05, 0), wood)
			_box(root, Vector3(0.025, 1.9, 0.02), c + Vector3(0, 1.05, 0.34), metal)

func _save_project() -> void:
	var wall_data: Array[Dictionary] = []
	for w in walls:
		wall_data.append({"a": [w.a.x, w.a.y], "b": [w.b.x, w.b.y]})
	var furniture_data: Array[Dictionary] = []
	for item in furniture:
		var p: Vector2 = item.get("position", Vector2.ZERO)
		furniture_data.append({"kind": item.get("kind", 0), "position": [p.x, p.y]})
	var data := {"version": 2, "walls": wall_data, "furniture": furniture_data}
	var file := FileAccess.open("user://dreamhouse_project.json", FileAccess.WRITE)
	if file == null:
		status_label.text = "Ошибка сохранения"
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	status_label.text = "Сохранено • %d стен • %d объектов" % [walls.size(), furniture.size()]

func _load_project() -> void:
	if not FileAccess.file_exists("user://dreamhouse_project.json"):
		status_label.text = "Сохранённый проект не найден"
		return
	var file := FileAccess.open("user://dreamhouse_project.json", FileAccess.READ)
	if file == null:
		status_label.text = "Не удалось открыть проект"
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary or not data.has("walls"):
		status_label.text = "Файл проекта повреждён"
		return
	walls.clear()
	for item in data.get("walls", []):
		if item is Dictionary and item.has("a") and item.has("b") and item.a.size() == 2 and item.b.size() == 2:
			walls.append({"a": Vector2(float(item.a[0]), float(item.a[1])), "b": Vector2(float(item.b[0]), float(item.b[1]))})
	furniture.clear()
	for item in data.get("furniture", []):
		if item is Dictionary and item.has("kind") and item.has("position") and item.position.size() == 2:
			furniture.append({"kind": int(item.kind), "position": Vector2(float(item.position[0]), float(item.position[1]))})
	plan_canvas.walls = walls.duplicate(true)
	plan_canvas.queue_redraw()
	status_label.text = "Загружено • %d стен • %d объектов" % [walls.size(), furniture.size()]
	if is_3d:
		_rebuild_3d()
