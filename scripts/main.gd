extends Control

const PlanCanvasScript = preload("res://scripts/plan_canvas.gd")
var plan_canvas: PlanCanvas
var preview: SubViewportContainer
var preview_world: Node3D
var status_label: Label
var walls: Array[Dictionary] = []
var is_3d := false

func _ready() -> void:
	_build_interface()

func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("#18212b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var header := VBoxContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 18
	header.offset_right = -18
	header.offset_top = 18
	header.offset_bottom = 150
	add_child(header)

	var title := Label.new()
	title.text = "DREAMHOUSE 3D"
	title.add_theme_font_size_override("font_size", 30)
	header.add_child(title)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	header.add_child(tools)
	_add_button(tools, "План 2D", _show_plan)
	_add_button(tools, "Просмотр 3D", _show_3d)
	_add_button(tools, "Отменить", _undo)
	_add_button(tools, "Очистить", _clear)

	plan_canvas = PlanCanvasScript.new()
	plan_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	plan_canvas.offset_left = 12
	plan_canvas.offset_top = 170
	plan_canvas.offset_right = -12
	plan_canvas.offset_bottom = -100
	plan_canvas.wall_created.connect(_on_wall_created)
	add_child(plan_canvas)

	preview = SubViewportContainer.new()
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview.offset_left = 0
	preview.offset_top = 165
	preview.offset_right = 0
	preview.offset_bottom = -90
	preview.stretch = true
	preview.visible = false
	add_child(preview)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080, 1500)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview.add_child(viewport)
	preview_world = Node3D.new()
	viewport.add_child(preview_world)
	_build_3d_camera(viewport)

	var footer := HBoxContainer.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 18
	footer.offset_right = -18
	footer.offset_top = -78
	footer.offset_bottom = -18
	add_child(footer)
	status_label = Label.new()
	status_label.text = "Режим плана • Нарисуйте стены пальцем"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("font_size", 18)
	footer.add_child(status_label)
	_add_button(footer, "Сохранить", _save_project)
	_add_button(footer, "Загрузить", _load_project)

func _add_button(parent: Container, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)

func _on_wall_created(a: Vector2, b: Vector2) -> void:
	walls = plan_canvas.walls.duplicate(true)
	status_label.text = "Стены: %d • Добавлена новая стена" % walls.size()

func _show_plan() -> void:
	is_3d = false
	plan_canvas.visible = true
	preview.visible = false
	status_label.text = "Режим плана • Нарисуйте стены пальцем"

func _show_3d() -> void:
	is_3d = true
	plan_canvas.visible = false
	preview.visible = true
	_rebuild_3d()
	status_label.text = "3D-просмотр • Пока базовая геометрия стен"

func _undo() -> void:
	plan_canvas.undo()
	walls = plan_canvas.walls.duplicate(true)
	status_label.text = "Отменено • Стен: %d" % walls.size()
	if is_3d:
		_rebuild_3d()

func _clear() -> void:
	plan_canvas.clear_plan()
	walls.clear()
	status_label.text = "План очищен"
	if is_3d:
		_rebuild_3d()

func _build_3d_camera(viewport: SubViewport) -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0, 9, 13)
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	camera.current = true
	preview_world.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.4
	preview_world.add_child(light)

func _rebuild_3d() -> void:
	for child in preview_world.get_children():
		if child is MeshInstance3D:
			child.queue_free()
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#c8c4b8")
	floor_mesh.material_override = floor_material
	floor_mesh.position.y = -0.08
	preview_world.add_child(floor_mesh)

	for wall in walls:
		var a: Vector2 = wall.a
		var b: Vector2 = wall.b
		var midpoint := (a + b) * 0.5
		var length := a.distance_to(b) / 32.0
		var angle := atan2(b.y - a.y, b.x - a.x)
		var mesh_instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(maxf(length, 0.2), 2.6, 0.16)
		mesh_instance.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("#e8e2d5")
		mesh_instance.material_override = material
		mesh_instance.position = Vector3((midpoint.x - 540.0) / 32.0, 1.3, (midpoint.y - 850.0) / 32.0)
		mesh_instance.rotation.y = -angle
		preview_world.add_child(mesh_instance)

func _save_project() -> void:
	var data := {"walls": []}
	for wall in walls:
		data.walls.append({"a": [wall.a.x, wall.a.y], "b": [wall.b.x, wall.b.y]})
	var file := FileAccess.open("user://dreamhouse_project.json", FileAccess.WRITE)
	if file == null:
		status_label.text = "Ошибка сохранения"
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	status_label.text = "Проект сохранён на устройстве"

func _load_project() -> void:
	if not FileAccess.file_exists("user://dreamhouse_project.json"):
		status_label.text = "Сохранённый проект не найден"
		return
	var file := FileAccess.open("user://dreamhouse_project.json", FileAccess.READ)
	if file == null:
		status_label.text = "Не удалось открыть файл"
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("walls"):
		status_label.text = "Файл проекта повреждён"
		return
	walls.clear()
	for item in parsed.walls:
		if item.has("a") and item.has("b") and item.a.size() == 2 and item.b.size() == 2:
			walls.append({"a": Vector2(item.a[0], item.a[1]), "b": Vector2(item.b[0], item.b[1])})
	plan_canvas.walls = walls.duplicate(true)
	plan_canvas.queue_redraw()
	status_label.text = "Проект загружен • Стен: %d" % walls.size()
	if is_3d:
		_rebuild_3d()
