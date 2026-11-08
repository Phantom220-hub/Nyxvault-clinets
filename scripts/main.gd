extends Control
const PlanCanvasScript = preload("res://scripts/plan_canvas.gd")
const Units = preload("res://scripts/building_units.gd")
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
var view_camera: Camera3D
var selected_furniture := -1
var camera_yaw := 0.72
var camera_pitch := -0.72
var camera_distance := 17.0
var preview_dragging := false
var preview_last_pos := Vector2.ZERO
var pending_opening := ""
var floors: Array[Dictionary] = []
var current_floor := 0
var move_mode_3d := false
var material_theme := 0
var project_dialog: FileDialog

func _ready() -> void:
	floors = [{"walls": [], "furniture": []}]
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
	_add_button(tools, "РИСОВАТЬ СТЕНЫ", _wall_draw_mode, false)
	_add_button(tools, "ВЫБРАТЬ СТЕНУ", _wall_select_mode, false)
	_add_button(tools, "ПАРАМЕТРЫ СТЕНЫ", _edit_selected_wall, false)
	_add_button(tools, "УДАЛИТЬ СТЕНУ", _delete_selected_wall, false)
	_add_button(tools, "3D ВИД", _show_3d, false)
	_add_button(tools, "ОБЪЕКТЫ +", _open_object_menu, false)
	_add_button(tools, "UNDO", _undo, false)
	_add_button(tools, "ОЧИСТИТЬ", _clear, false)
	_add_button(tools, "ВЫБРАТЬ", _select_next_furniture, false)
	_add_button(tools, "←", func(): _move_selected(Vector2(-0.25, 0.0)), false)
	_add_button(tools, "→", func(): _move_selected(Vector2(0.25, 0.0)), false)
	_add_button(tools, "↑", func(): _move_selected(Vector2(0.0, -0.25)), false)
	_add_button(tools, "↓", func(): _move_selected(Vector2(0.0, 0.25)), false)
	_add_button(tools, "ПОВОРОТ", _rotate_selected, false)
	_add_button(tools, "МАСШТАБ +", func(): _scale_selected(1.1), false)
	_add_button(tools, "МАСШТАБ −", func(): _scale_selected(0.9), false)
	_add_button(tools, "УДАЛИТЬ", _delete_selected, false)
	_add_button(tools, "ДВЕРЬ", func(): _set_opening("door"), false)
	_add_button(tools, "ОКНО", func(): _set_opening("window"), false)
	_add_button(tools, "БЕЗ ПРОЁМА", func(): _set_opening(""), false)
	_add_button(tools, "ПЛОЩАДЬ", _calculate_room_areas, true)
	_add_button(tools, "+ ЭТАЖ", _add_floor, false)
	_add_button(tools, "ЭТАЖ ←", func(): _switch_floor(-1), false)
	_add_button(tools, "ЭТАЖ →", func(): _switch_floor(1), false)
	_add_button(tools, "MOVE 3D", _toggle_3d_move, false)
	_add_button(tools, "МАТЕРИАЛ", _cycle_material_theme, false)
	_add_button(tools, "ЭКСПОРТ", _export_project, false)
	_add_button(tools, "ИМПОРТ", _import_project, false)
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
	plan_canvas.wall_selected.connect(_on_plan_wall_selected)
	plan_canvas.walls_changed.connect(_on_plan_walls_changed)
	add_child(plan_canvas)

	preview = SubViewportContainer.new()
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview.offset_left = 14
	preview.offset_top = 158
	preview.offset_right = -14
	preview.offset_bottom = -100
	preview.stretch = true
	preview.visible = false
	preview.gui_input.connect(_on_preview_input)
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

func _sync_plan_furniture() -> void:
	if not is_instance_valid(plan_canvas):
		return
	plan_canvas.furniture = furniture.duplicate(true)
	plan_canvas.selected_furniture = selected_furniture
	plan_canvas.queue_redraw()

func _open_object_menu() -> void:
	object_menu.position = Vector2i(22, 150)
	object_menu.popup()

func _on_object_selected(id: int) -> void:
	var names := ["Диван", "Кровать", "Стол", "Кресло", "Шкаф"]
	var index := furniture.size()
	var placement := Vector2(float((index % 3) - 1) * 2.4, float(int(index / 3)) * 2.4)
	furniture.append({"kind": id, "position": placement, "rotation": 0.0, "scale": 1.0})
	selected_furniture = furniture.size() - 1
	_sync_plan_furniture()
	status_label.text = "Добавлен объект: %s • Всего: %d" % [names[id], furniture.size()]
	if is_3d:
		_rebuild_3d()

func _set_opening(kind: String) -> void:
	pending_opening = kind
	status_label.text = "Следующая стена: " + ("проём двери" if kind == "door" else "проём окна" if kind == "window" else "без проёма")

func _wall_draw_mode() -> void:
	plan_canvas.set_tool_mode("draw")
	status_label.text = "Инструмент стен: рисование • сетка 32 px = 0.667 m"

func _wall_select_mode() -> void:
	plan_canvas.set_tool_mode("select")
	status_label.text = "Выбор стен: каснитесь стены, затем двигайте стену или её конец"

func _on_plan_wall_selected(index: int) -> void:
	if index < 0:
		status_label.text = "Стена не выбрана"
		return
	var wall := plan_canvas.get_selected_wall()
	var length_mm := Units.pixels_to_mm((wall.a as Vector2).distance_to(wall.b as Vector2))
	status_label.text = "Стена %d • длина %.0f mm • толщина %.0f mm • высота %.0f mm" % [index + 1, length_mm, float(wall.get("thickness_mm", 150.0)), float(wall.get("height_mm", 2800.0))]

func _on_plan_walls_changed() -> void:
	walls = plan_canvas.walls.duplicate(true)
	_snapshot_floor()
	if is_3d:
		_rebuild_3d()

func _delete_selected_wall() -> void:
	if plan_canvas.delete_selected_wall():
		status_label.text = "Выбранная стена удалена"
	else:
		status_label.text = "Сначала выберите стену"

func _edit_selected_wall() -> void:
	var wall := plan_canvas.get_selected_wall()
	if wall.is_empty():
		status_label.text = "Сначала выберите стену в режиме ВЫБРАТЬ СТЕНУ"
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Параметры стены — миллиметры"
	dialog.min_size = Vector2i(360, 330)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 8)
	dialog.add_child(form)
	var length_input := SpinBox.new()
	length_input.min_value = 100.0
	length_input.max_value = 50000.0
	length_input.step = 10.0
	length_input.value = Units.pixels_to_mm((wall.a as Vector2).distance_to(wall.b as Vector2))
	form.add_child(_labeled_control(form, "Длина стены (mm)", length_input))
	var thickness_input := SpinBox.new()
	thickness_input.min_value = 50.0
	thickness_input.max_value = 1000.0
	thickness_input.step = 10.0
	thickness_input.value = float(wall.get("thickness_mm", 150.0))
	form.add_child(_labeled_control(form, "Толщина стены (mm)", thickness_input))
	var height_input := SpinBox.new()
	height_input.min_value = 1800.0
	height_input.max_value = 10000.0
	height_input.step = 50.0
	height_input.value = float(wall.get("height_mm", 2800.0))
	form.add_child(_labeled_control(form, "Высота стены (mm)", height_input))
	var bearing := CheckButton.new()
	bearing.text = "Несущая стена (проектная метка)"
	bearing.button_pressed = bool(wall.get("load_bearing", false))
	form.add_child(bearing)
	dialog.confirmed.connect(func():
		var valid := plan_canvas.set_selected_wall_length_mm(length_input.value)
		if valid:
			plan_canvas.set_selected_wall_properties(thickness_input.value, height_input.value, bearing.button_pressed)
			status_label.text = "Параметры стены обновлены • значения в mm"
		else:
			status_label.text = "Не удалось изменить длину стены"
	)
	add_child(dialog)
	dialog.popup_centered()

func _labeled_control(parent: VBoxContainer, caption: String, control: Control) -> Control:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = caption
	row.add_child(label)
	row.add_child(control)
	parent.add_child(row)
	return row

func _on_wall_created(_a: Vector2, _b: Vector2) -> void:
	walls = plan_canvas.walls.duplicate(true)
	if not pending_opening.is_empty() and not walls.is_empty():
		walls[walls.size() - 1]["opening"] = pending_opening
		plan_canvas.walls = walls.duplicate(true)
		plan_canvas.queue_redraw()
		pending_opening = ""
	status_label.text = "Стены: %d • Стена добавлена" % walls.size()
	if is_3d:
		_rebuild_3d()

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
	selected_furniture = -1
	_sync_plan_furniture()
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
	view_camera = Camera3D.new()
	view_camera.fov = 48.0
	preview_world.add_child(view_camera)
	_update_camera()
	view_camera.current = true
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

func _update_camera() -> void:
	if not is_instance_valid(view_camera):
		return
	camera_pitch = clampf(camera_pitch, -1.25, -0.18)
	camera_distance = clampf(camera_distance, 5.0, 34.0)
	var horizontal := camera_distance * cos(camera_pitch)
	view_camera.position = Vector3(sin(camera_yaw) * horizontal, -sin(camera_pitch) * camera_distance, cos(camera_yaw) * horizontal)
	var building_center_y := maxf(0.0, float(floors.size() - 1) * 1.6)
	view_camera.look_at(Vector3(0.0, building_center_y, 0.0), Vector3.UP)

func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			preview_dragging = true
			preview_last_pos = event.position
			if move_mode_3d:
				_pick_furniture(_to_viewport_position(event.position))
		else:
			if preview_dragging and preview_last_pos.distance_to(event.position) < 12.0 and not move_mode_3d:
				_pick_furniture(_to_viewport_position(event.position))
			preview_dragging = false
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and preview_dragging:
		var delta := event.position - preview_last_pos
		preview_last_pos = event.position
		if move_mode_3d and selected_furniture >= 0:
			var hit: Variant = _screen_to_floor(_to_viewport_position(event.position))
			if hit is Vector3:
				furniture[selected_furniture]["position"] = Vector2(hit.x, hit.z)
				_sync_plan_furniture()
				_rebuild_3d()
		else:
			camera_yaw -= delta.x * 0.008
			camera_pitch -= delta.y * 0.006
			_update_camera()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera_distance -= 1.0
		_update_camera()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera_distance += 1.0
		_update_camera()

func _to_viewport_position(container_pos: Vector2) -> Vector2:
	var viewport := preview.get_child(0) as SubViewport
	if viewport == null or preview.size.x <= 0.0 or preview.size.y <= 0.0:
		return container_pos
	return container_pos * Vector2(viewport.size) / preview.size

func _screen_to_floor(screen_pos: Vector2) -> Variant:
	var origin := view_camera.project_ray_origin(screen_pos)
	var direction := view_camera.project_ray_normal(screen_pos)
	var floor_y := float(current_floor) * (WALL_HEIGHT + 0.22)
	return Plane(Vector3.UP, floor_y).intersects_ray(origin, direction)

func _toggle_3d_move() -> void:
	move_mode_3d = not move_mode_3d
	status_label.text = "3D: перетаскивайте выбранную мебель" if move_mode_3d else "3D: перетаскивание камеры"

func _cycle_material_theme() -> void:
	material_theme = (material_theme + 1) % 3
	if is_3d:
		_rebuild_3d()
	var labels := ["Светлый камень", "Тёплое дерево", "Современный серый"]
	status_label.text = "Материалы: " + labels[material_theme]

func _pick_furniture(screen_pos: Vector2) -> void:
	if furniture.is_empty() or not is_instance_valid(view_camera):
		return
	var best_index := -1
	var best_distance := 90.0
	for i in range(furniture.size()):
		var p: Vector2 = furniture[i].get("position", Vector2.ZERO)
		var floor_y := float(current_floor) * (WALL_HEIGHT + 0.22)
		var world_pos := Vector3(p.x, floor_y + 0.8, p.y)
		if view_camera.is_position_behind(world_pos):
			continue
		var d := view_camera.unproject_position(world_pos).distance_to(screen_pos)
		if d < best_distance:
			best_distance = d
			best_index = i
	if best_index >= 0:
		selected_furniture = best_index
		_sync_plan_furniture()
		status_label.text = "Выбран объект %d из %d" % [best_index + 1, furniture.size()]
		_rebuild_3d()

func _select_next_furniture() -> void:
	if furniture.is_empty():
		status_label.text = "Сначала добавьте мебель"
		return
	selected_furniture = (selected_furniture + 1) % furniture.size()
	_sync_plan_furniture()
	status_label.text = "Выбран объект %d из %d" % [selected_furniture + 1, furniture.size()]
	if is_3d:
		_rebuild_3d()

func _move_selected(offset: Vector2) -> void:
	if selected_furniture < 0 or selected_furniture >= furniture.size():
		status_label.text = "Сначала выберите мебель"
		return
	var p: Vector2 = furniture[selected_furniture].get("position", Vector2.ZERO)
	furniture[selected_furniture]["position"] = p + offset
	_sync_plan_furniture()
	status_label.text = "Мебель перемещена"
	if is_3d:
		_rebuild_3d()

func _rotate_selected() -> void:
	if selected_furniture < 0 or selected_furniture >= furniture.size():
		status_label.text = "Сначала выберите мебель"
		return
	furniture[selected_furniture]["rotation"] = float(furniture[selected_furniture].get("rotation", 0.0)) + PI / 4.0
	_sync_plan_furniture()
	status_label.text = "Поворот: 45°"
	if is_3d:
		_rebuild_3d()

func _scale_selected(factor: float) -> void:
	if selected_furniture < 0 or selected_furniture >= furniture.size():
		status_label.text = "Сначала выберите мебель"
		return
	var value := clampf(float(furniture[selected_furniture].get("scale", 1.0)) * factor, 0.5, 1.8)
	furniture[selected_furniture]["scale"] = value
	_sync_plan_furniture()
	status_label.text = "Размер объекта: %.0f%%" % (value * 100.0)
	if is_3d:
		_rebuild_3d()

func _delete_selected() -> void:
	if selected_furniture < 0 or selected_furniture >= furniture.size():
		status_label.text = "Сначала выберите мебель"
		return
	furniture.remove_at(selected_furniture)
	selected_furniture = mini(selected_furniture, furniture.size() - 1)
	_sync_plan_furniture()
	status_label.text = "Объект удалён"
	if is_3d:
		_rebuild_3d()

func _rebuild_3d() -> void:
	if not is_instance_valid(preview_world):
		return
	_snapshot_floor()
	for child in preview_world.get_children():
		if child.is_in_group("generated"):
			child.queue_free()
	var root := Node3D.new()
	root.add_to_group("generated")
	preview_world.add_child(root)
	var floor_colors := [Color("#D9D2C4"), Color("#9A7658"), Color("#707B83")]
	var wall_colors := [Color("#F0E9DC"), Color("#D8C3A5"), Color("#C7CED2")]
	var floor_mat := _mat(floor_colors[material_theme], 0.95)
	var grid_mat := _mat(Color("#B8B1A4"), 0.8)
	var wall_mat := _mat(wall_colors[material_theme], 0.82)
	var trim_mat := _mat(Color("#BDAA8F"), 0.6)
	var glass := _mat(Color("#79CDE0", 0.42), 0.18)
	for i in range(-12, 13):
		_box(root, Vector3(0.012, 0.006, 24), Vector3(i, -0.055, 0), grid_mat)
		_box(root, Vector3(24, 0.006, 0.012), Vector3(0, -0.054, i), grid_mat)
	for floor_index in range(floors.size()):
		var floor_data: Dictionary = floors[floor_index]
		var base_y := float(floor_index) * (WALL_HEIGHT + 0.22)
		_box(root, Vector3(24, 0.12, 24), Vector3(0, base_y - 0.12, 0), floor_mat)
		for wall in floor_data.get("walls", []):
			var a: Vector2 = wall.a
			var b: Vector2 = wall.b
			var mid := (a + b) * 0.5
			var length := a.distance_to(b) / PPM
			var wall_height := float(wall.get("height_mm", 2800.0)) / 1000.0
			var wall_thickness := float(wall.get("thickness_mm", 150.0)) / 1000.0
			var angle := atan2(b.y - a.y, b.x - a.x)
			var center := Vector3((mid.x - plan_canvas.size.x * 0.5) / PPM, base_y + wall_height * 0.5, (mid.y - plan_canvas.size.y * 0.5) / PPM)
			var opening := str(wall.get("opening", ""))
			var direction := Vector3(cos(angle), 0, sin(angle))
			if opening == "door" or opening == "window":
				var opening_width := 0.95 if opening == "door" else 1.25
				var gap := minf(opening_width, maxf(length - 0.25, 0.0))
				var side_length := maxf((length - gap) * 0.5, 0.06)
				for side in [-1.0, 1.0]:
					var side_center := center + direction * side * (gap * 0.5 + side_length * 0.5)
					var side_wall := _box(root, Vector3(side_length, wall_height, wall_thickness), side_center, wall_mat)
					side_wall.rotation.y = -angle
				if opening == "door":
					var lintel := _box(root, Vector3(gap, maxf(wall_height - 2.05, 0.05), wall_thickness), center + Vector3(0, 2.05 + maxf(wall_height - 2.05, 0.05) * 0.5, 0), wall_mat)
					lintel.rotation.y = -angle
				else:
					var sill := _box(root, Vector3(gap, 0.85, wall_thickness), center + Vector3(0, 0.425, 0), wall_mat)
					var header := _box(root, Vector3(gap, maxf(wall_height - 2.1, 0.1), wall_thickness), center + Vector3(0, 2.1 + maxf(wall_height - 2.1, 0.1) * 0.5, 0), wall_mat)
					sill.rotation.y = -angle
					header.rotation.y = -angle
					var pane := _box(root, Vector3(gap * 0.94, maxf(wall_height - 1.0, 0.2), 0.035), center + Vector3(0, wall_height * 0.5, 0), glass)
					pane.rotation.y = -angle
			else:
				var segment := _box(root, Vector3(maxf(length, 0.12), wall_height, wall_thickness), center, wall_mat)
				segment.rotation.y = -angle
			var skirting := _box(root, Vector3(maxf(length, 0.12), 0.1, wall_thickness + 0.03), Vector3(center.x, base_y + 0.1, center.z), trim_mat)
			skirting.rotation.y = -angle
			var crown := _box(root, Vector3(maxf(length, 0.12), 0.07, wall_thickness + 0.03), Vector3(center.x, base_y + wall_height - 0.035, center.z), trim_mat)
			crown.rotation.y = -angle
		for item in floor_data.get("furniture", []):
			_add_furniture(root, item, base_y)
	_update_camera()
	if floors.size() > 1:
		status_label.text = "3D • показаны все этажи: %d" % floors.size()

func _add_furniture(root: Node3D, item: Dictionary, floor_y: float = 0.0) -> void:
	var kind := int(item.get("kind", 0))
	var p: Vector2 = item.get("position", Vector2.ZERO)
	var group := Node3D.new()
	group.position = Vector3(p.x, floor_y, p.y)
	group.rotation.y = float(item.get("rotation", 0.0))
	group.scale = Vector3.ONE * float(item.get("scale", 1.0))
	root.add_child(group)
	if furniture.find(item) == selected_furniture:
		var marker_mat := _mat(Color("#52D6C7", 0.22), 0.3)
		var marker_mesh := _box(group, Vector3(2.5, 0.035, 2.5), Vector3(0, 0.025, 0), marker_mat)
		marker_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var c := Vector3.ZERO
	var wood_colors := [Color("#8B6549"), Color("#B98B5E"), Color("#555F68")]
	var wood := _mat(wood_colors[material_theme], 0.5)
	var fabric := _mat(Color("#477E83"), 0.95)
	var soft := _mat(Color("#B7D0C8"), 0.95)
	var metal := _mat(Color("#333E47"), 0.35)
	match kind:
		0:
			_box(group, Vector3(2.1, 0.42, 0.85), c + Vector3(0, 0.42, 0), fabric)
			_box(group, Vector3(2.1, 0.72, 0.2), c + Vector3(0, 0.86, -0.33), fabric)
			for x in [-0.88, 0.88]:
				_box(group, Vector3(0.2, 0.72, 0.85), c + Vector3(x, 0.68, 0), fabric)
			_box(group, Vector3(1.5, 0.12, 0.58), c + Vector3(0, 0.7, 0.04), soft)
		1:
			_box(group, Vector3(2.2, 0.28, 2.7), c + Vector3(0, 0.38, 0), wood)
			_box(group, Vector3(2.05, 0.22, 2.5), c + Vector3(0, 0.62, 0), soft)
			_box(group, Vector3(2.2, 1.1, 0.16), c + Vector3(0, 0.85, -1.32), wood)
		2:
			_box(group, Vector3(1.8, 0.12, 1.1), c + Vector3(0, 0.95, 0), wood)
			for x in [-0.72, 0.72]:
				for z in [-0.38, 0.38]:
					_box(group, Vector3(0.09, 0.9, 0.09), c + Vector3(x, 0.45, z), metal)
		3:
			_box(group, Vector3(0.95, 0.42, 0.9), c + Vector3(0, 0.48, 0), fabric)
			_box(group, Vector3(0.95, 0.8, 0.18), c + Vector3(0, 0.92, -0.36), fabric)
		4:
			_box(group, Vector3(1.25, 2.1, 0.65), c + Vector3(0, 1.05, 0), wood)
			_box(group, Vector3(0.025, 1.9, 0.02), c + Vector3(0, 1.05, 0.34), metal)


func _snapshot_floor() -> void:
	if floors.size() <= current_floor:
		return
	floors[current_floor] = {"walls": walls.duplicate(true), "furniture": furniture.duplicate(true)}

func _add_floor() -> void:
	_snapshot_floor()
	floors.append({"walls": [], "furniture": []})
	current_floor = floors.size() - 1
	walls.clear()
	furniture.clear()
	selected_furniture = -1
	_sync_plan_furniture()
	plan_canvas.walls.clear()
	plan_canvas.queue_redraw()
	if is_3d:
		_rebuild_3d()
	status_label.text = "Создан этаж %d из %d" % [current_floor + 1, floors.size()]

func _switch_floor(direction: int) -> void:
	if floors.size() < 2:
		status_label.text = "Добавьте ещё один этаж"
		return
	_snapshot_floor()
	current_floor = posmod(current_floor + direction, floors.size())
	walls = floors[current_floor].get("walls", []).duplicate(true)
	furniture = floors[current_floor].get("furniture", []).duplicate(true)
	selected_furniture = -1
	_sync_plan_furniture()
	plan_canvas.walls = walls.duplicate(true)
	plan_canvas.queue_redraw()
	if is_3d:
		_rebuild_3d()
	status_label.text = "Этаж %d из %d" % [current_floor + 1, floors.size()]

func _calculate_room_areas() -> void:
	var graph: Dictionary = {}
	for wall in walls:
		var a: Vector2 = wall.a
		var b: Vector2 = wall.b
		if not graph.has(a): graph[a] = []
		if not graph.has(b): graph[b] = []
		if not graph[a].has(b): graph[a].append(b)
		if not graph[b].has(a): graph[b].append(a)
	var cycles: Array = []
	var signatures: Dictionary = {}
	for start in graph.keys():
		var path: Array = [start]
		_find_cycles(start, start, graph, path, signatures, cycles)
	if cycles.is_empty():
		status_label.text = "Замкнутых комнат не найдено • соедините стены в контур"
		return
	var areas: Array[float] = []
	for polygon in cycles:
		var twice_area := 0.0
		for i in range(polygon.size()):
			var a: Vector2 = polygon[i]
			var b: Vector2 = polygon[(i + 1) % polygon.size()]
			twice_area += a.x * b.y - b.x * a.y
		areas.append(absf(twice_area) / 2.0 / (PPM * PPM))
	areas.sort()
	var total := 0.0
	for area in areas: total += area
	status_label.text = "Этаж %d • контуров: %d • площадь: %.2f м²" % [current_floor + 1, areas.size(), total]

func _find_cycles(current: Vector2, start: Vector2, graph: Dictionary, path: Array, signatures: Dictionary, cycles: Array) -> void:
	for neighbor in graph.get(current, []):
		if neighbor == start and path.size() >= 3:
			var keys: Array[String] = []
			for point in path: keys.append("%.1f,%.1f" % [point.x, point.y])
			keys.sort()
			var signature := "|".join(keys)
			if not signatures.has(signature):
				signatures[signature] = true
				cycles.append(path.duplicate())
		elif not path.has(neighbor) and path.size() < 80:
			path.append(neighbor)
			_find_cycles(neighbor, start, graph, path, signatures, cycles)
			path.pop_back()


func _export_project() -> void:
	_save_project()
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.json", "DreamHouse project")
	dialog.current_file = "dreamhouse_project.json"
	dialog.file_selected.connect(_write_export_file)
	add_child(dialog)
	dialog.popup_centered(Vector2i(820, 620))

func _write_export_file(path: String) -> void:
	var source := FileAccess.open("user://dreamhouse_project.json", FileAccess.READ)
	if source == null:
		status_label.text = "Сначала сохраните проект"
		return
	var contents := source.get_as_text()
	source.close()
	var target := FileAccess.open(path, FileAccess.WRITE)
	if target == null:
		status_label.text = "Не удалось записать файл"
		return
	target.store_string(contents)
	target.close()
	status_label.text = "Экспортировано: " + path.get_file()

func _import_project() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.json", "DreamHouse project")
	dialog.file_selected.connect(_read_import_file)
	add_child(dialog)
	dialog.popup_centered(Vector2i(820, 620))

func _read_import_file(path: String) -> void:
	var source := FileAccess.open(path, FileAccess.READ)
	if source == null:
		status_label.text = "Не удалось прочитать файл"
		return
	var contents := source.get_as_text()
	source.close()
	var target := FileAccess.open("user://dreamhouse_project.json", FileAccess.WRITE)
	if target == null:
		status_label.text = "Не удалось импортировать проект"
		return
	target.store_string(contents)
	target.close()
	_load_project()
	status_label.text = "Импортировано: " + path.get_file()

func _save_project() -> void:
	var wall_data: Array[Dictionary] = []
	for w in walls:
		wall_data.append({"a": [w.a.x, w.a.y], "b": [w.b.x, w.b.y], "opening": w.get("opening", ""), "thickness_mm": w.get("thickness_mm", 150.0), "height_mm": w.get("height_mm", 2800.0), "load_bearing": w.get("load_bearing", false)})
	var furniture_data: Array[Dictionary] = []
	for item in furniture:
		var p: Vector2 = item.get("position", Vector2.ZERO)
		furniture_data.append({"kind": item.get("kind", 0), "position": [p.x, p.y], "rotation": item.get("rotation", 0.0), "scale": item.get("scale", 1.0)})
	_snapshot_floor()
	var floor_data: Array = []
	for floor in floors:
		var fw: Array = []
		for w in floor.get("walls", []): fw.append({"a": [w.a.x, w.a.y], "b": [w.b.x, w.b.y], "opening": w.get("opening", "")})
		var ff: Array = []
		for item in floor.get("furniture", []):
			var fp: Vector2 = item.get("position", Vector2.ZERO)
			ff.append({"kind": item.get("kind", 0), "position": [fp.x, fp.y], "rotation": item.get("rotation", 0.0), "scale": item.get("scale", 1.0)})
		floor_data.append({"walls": fw, "furniture": ff})
	var data := {"version": 3, "current_floor": current_floor, "floors": floor_data, "walls": wall_data, "furniture": furniture_data}
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
			walls.append({"a": Vector2(float(item.a[0]), float(item.a[1])), "b": Vector2(float(item.b[0]), float(item.b[1])), "opening": str(item.get("opening", "")), "thickness_mm": float(item.get("thickness_mm", 150.0)), "height_mm": float(item.get("height_mm", 2800.0)), "load_bearing": bool(item.get("load_bearing", false))})
	furniture.clear()
	for item in data.get("furniture", []):
		if item is Dictionary and item.has("kind") and item.has("position") and item.position.size() == 2:
			furniture.append({"kind": int(item.kind), "position": Vector2(float(item.position[0]), float(item.position[1])), "rotation": float(item.get("rotation", 0.0)), "scale": float(item.get("scale", 1.0))})
	if data.has("floors") and data.floors is Array and not data.floors.is_empty():
		floors.clear()
		for floor_item in data.floors:
			var fwalls: Array[Dictionary] = []
			for w in floor_item.get("walls", []):
				if w is Dictionary and w.has("a") and w.has("b"):
					fwalls.append({"a": Vector2(float(w.a[0]), float(w.a[1])), "b": Vector2(float(w.b[0]), float(w.b[1])), "opening": str(w.get("opening", "")), "thickness_mm": float(w.get("thickness_mm", 150.0)), "height_mm": float(w.get("height_mm", 2800.0)), "load_bearing": bool(w.get("load_bearing", false))})
			var ffurniture: Array[Dictionary] = []
			for item in floor_item.get("furniture", []):
				if item is Dictionary and item.has("position"):
					ffurniture.append({"kind": int(item.get("kind", 0)), "position": Vector2(float(item.position[0]), float(item.position[1])), "rotation": float(item.get("rotation", 0.0)), "scale": float(item.get("scale", 1.0))})
			floors.append({"walls": fwalls, "furniture": ffurniture})
		current_floor = clampi(int(data.get("current_floor", 0)), 0, floors.size() - 1)
		walls = floors[current_floor].walls.duplicate(true)
		furniture = floors[current_floor].furniture.duplicate(true)
	else:
		floors = [{"walls": walls.duplicate(true), "furniture": furniture.duplicate(true)}]
		current_floor = 0
	plan_canvas.walls = walls.duplicate(true)
	_sync_plan_furniture()
	plan_canvas.queue_redraw()
	status_label.text = "Загружено • этаж %d/%d • %d стен • %d объектов" % [current_floor + 1, floors.size(), walls.size(), furniture.size()]
	if is_3d:
		_rebuild_3d()
