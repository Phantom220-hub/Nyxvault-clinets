extends Control
const PlanCanvasScript = preload("res://scripts/plan_canvas.gd")
const Units = preload("res://scripts/building_units.gd")
const Geometry = preload("res://scripts/wall_geometry.gd")
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
var camera_projection := Camera3D.PROJECTION_PERSPECTIVE
var preview_dragging := false
var preview_last_pos := Vector2.ZERO
var preview_press_pos := Vector2.ZERO
var pending_opening := ""
var floors: Array[Dictionary] = []
var current_floor := 0
var move_mode_3d := false
var select_walls_3d := false
var draw_walls_3d := false
var wall_3d_has_start := false
var wall_3d_start_point := Vector2.ZERO
var edit_wall_ends_3d := false
var wall_3d_endpoint_pick: Dictionary = {}
var material_theme := 0
var project_dialog: FileDialog
var dimensions_enabled := true
var current_project_name := ""
var autosave_timer: Timer

func _ready() -> void:
	floors = [{"name": "Этаж 1", "floor_height_mm": 2800.0, "slab_thickness_mm": 220.0, "walls": [], "furniture": []}]
	_build_interface()
	_rebuild_3d()
	_start_autosave()
	call_deferred("_check_autosave_recovery")

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
	_add_button(tools, "УГОЛ 15°: ВКЛ", _toggle_angle_snap, false)
	_add_button(tools, "РАЗМЕРЫ: ВКЛ", _toggle_dimensions, false)
	_add_button(tools, "ИЗМЕРИТЬ", _measure_mode, false)
	_add_button(tools, "СТЕНА ПО РАЗМЕРАМ", _numeric_wall_dialog, false)
	_add_button(tools, "РАЗДЕЛИТЬ СТЕНУ", _split_selected_wall_dialog, false)
	_add_button(tools, "ОБЪЕДИНИТЬ СТЕНУ", _merge_selected_wall, false)
	_add_button(tools, "КОПИЯ СТЕНЫ", _copy_selected_wall, false)
	_add_button(tools, "ЗЕРКАЛО СТЕНЫ", _mirror_selected_wall, false)
	_add_button(tools, "МАССИВ СТЕНЫ", _array_selected_wall_dialog, false)
	_add_button(tools, "УЗЛЫ: РЕШИТЬ", _resolve_wall_intersections, false)
	_add_button(tools, "СЛОИ ЧЕРТЕЖА", _show_layers_dialog, false)
	_add_button(tools, "ВЫБРАТЬ СТЕНУ", _wall_select_mode, false)
	_add_button(tools, "ПАРАМЕТРЫ СТЕНЫ", _edit_selected_wall, false)
	_add_button(tools, "УДАЛИТЬ СТЕНУ", _delete_selected_wall, false)
	_add_button(tools, "3D ВИД", _show_3d, false)
	_add_button(tools, "СВЕРХУ", _camera_top, false)
	_add_button(tools, "СПЕРЕДИ", _camera_front, false)
	_add_button(tools, "СБОКУ", _camera_side, false)
	_add_button(tools, "ОРТО/ПЕРСП", _toggle_camera_projection, false)
	_add_button(tools, "ОБЪЕКТЫ +", _open_object_menu, false)
	_add_button(tools, "UNDO", _undo, false)
	_add_button(tools, "REDO", _redo, false)
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
	_add_button(tools, "КОПИЯ ЭТАЖА", _duplicate_current_floor, false)
	_add_button(tools, "ЭТАЖ ↑", func(): _move_current_floor(-1), false)
	_add_button(tools, "ЭТАЖ ↓", func(): _move_current_floor(1), false)
	_add_button(tools, "ВИДИМОСТЬ ЭТАЖА", _toggle_current_floor_visibility, false)
	_add_button(tools, "ЭТАЖ ←", func(): _switch_floor(-1), false)
	_add_button(tools, "ЭТАЖ →", func(): _switch_floor(1), false)
	_add_button(tools, "НАСТРОЙКИ ЭТАЖА", _edit_current_floor, false)
	_add_button(tools, "MOVE 3D", _toggle_3d_move, false)
	_add_button(tools, "ВЫБРАТЬ СТЕНУ 3D", _toggle_3d_wall_select, false)
	_add_button(tools, "СТЕНА В 3D", _toggle_3d_wall_draw, false)
	_add_button(tools, "КОНЦЫ СТЕН 3D", _toggle_3d_wall_endpoint_edit, false)
	_add_button(tools, "МАТЕРИАЛ", _cycle_material_theme, false)
	_add_button(tools, "ПРОЕКТЫ", _open_project_manager, false)
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
	plan_canvas.measurement_completed.connect(_on_measurement_completed)
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
	furniture.append({"kind": id, "position": placement, "rotation": 0.0, "scale": 1.0, "layer": "furniture"})
	selected_furniture = furniture.size() - 1
	_sync_plan_furniture()
	status_label.text = "Добавлен объект: %s • Всего: %d" % [names[id], furniture.size()]
	if is_3d:
		_rebuild_3d()

func _set_opening(kind: String) -> void:
	pending_opening = kind
	status_label.text = "Следующая стена: " + ("проём двери" if kind == "door" else "проём окна" if kind == "window" else "без проёма")

func _toggle_angle_snap() -> void:
	plan_canvas.set_angle_snap_enabled(not plan_canvas.angle_snap_enabled)
	status_label.text = "Ограничение угла 15°: " + ("включено" if plan_canvas.angle_snap_enabled else "выключено")


func _numeric_wall_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Точное построение стены"
	dialog.min_size = Vector2i(360, 420)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 7)
	dialog.add_child(form)
	var x_input := SpinBox.new()
	x_input.min_value = -100000.0
	x_input.max_value = 100000.0
	x_input.step = 50.0
	x_input.value = 0.0
	_labeled_control(form, "X начала относительно центра плана (mm)", x_input)
	var y_input := SpinBox.new()
	y_input.min_value = -100000.0
	y_input.max_value = 100000.0
	y_input.step = 50.0
	y_input.value = 0.0
	_labeled_control(form, "Y начала относительно центра плана (mm)", y_input)
	var length_input := SpinBox.new()
	length_input.min_value = 200.0
	length_input.max_value = 100000.0
	length_input.step = 50.0
	length_input.value = 4000.0
	_labeled_control(form, "Длина стены (mm)", length_input)
	var angle_input := SpinBox.new()
	angle_input.min_value = -360.0
	angle_input.max_value = 360.0
	angle_input.step = 0.5
	angle_input.value = 0.0
	angle_input.allow_greater = true
	angle_input.allow_lesser = true
	_labeled_control(form, "Угол от горизонтали (градусы)", angle_input)
	dialog.confirmed.connect(func():
		if plan_canvas.add_wall_by_dimensions(Vector2(x_input.value, y_input.value), length_input.value, angle_input.value):
			status_label.text = "Точная стена создана • %.0f mm • %.1f°" % [length_input.value, angle_input.value]
		else:
			status_label.text = "Не удалось создать стену: проверьте длину и координаты"
	)
	add_child(dialog)
	dialog.popup_centered()


func _split_selected_wall_dialog() -> void:
	var wall := plan_canvas.get_selected_wall()
	if wall.is_empty():
		status_label.text = "Сначала выберите стену"
		return
	var a: Vector2 = wall.get("a", Vector2.ZERO)
	var b: Vector2 = wall.get("b", Vector2.ZERO)
	var length_mm := Units.pixels_to_mm(a.distance_to(b))
	var dialog := ConfirmationDialog.new()
	dialog.title = "Разделить стену"
	var input := SpinBox.new()
	input.min_value = 200.0
	input.max_value = maxf(200.0, length_mm - 200.0)
	input.step = 50.0
	input.value = length_mm * 0.5
	var form := VBoxContainer.new()
	_labeled_control(form, "Расстояние от начала выбранной стены (mm)", input)
	dialog.add_child(form)
	dialog.confirmed.connect(func():
		status_label.text = "Стена разделена" if plan_canvas.split_selected_wall_at_mm(input.value) else "Разделение невозможно: близко к краю или пересекает проём"
	)
	add_child(dialog)
	dialog.popup_centered()


func _merge_selected_wall() -> void:
	status_label.text = "Стены объединены" if plan_canvas.merge_selected_wall_with_neighbor() else "Не найдено единственной коллинеарной соседней стены с совпадающими параметрами"


func _copy_selected_wall() -> void:
	status_label.text = "Создана копия стены со смещением 250 mm" if plan_canvas.duplicate_selected_wall() else "Сначала выберите стену"


func _mirror_selected_wall() -> void:
	status_label.text = "Создана зеркальная копия относительно центральной вертикальной оси плана" if plan_canvas.mirror_selected_wall() else "Сначала выберите стену"


func _array_selected_wall_dialog() -> void:
	if plan_canvas.get_selected_wall().is_empty():
		status_label.text = "Сначала выберите стену"
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Линейный массив стен"
	var form := VBoxContainer.new()
	var count_input := SpinBox.new()
	count_input.min_value = 1
	count_input.max_value = 20
	count_input.step = 1
	count_input.value = 3
	_labeled_control(form, "Количество дополнительных копий", count_input)
	var spacing_input := SpinBox.new()
	spacing_input.min_value = 100.0
	spacing_input.max_value = 20000.0
	spacing_input.step = 50.0
	spacing_input.value = 1000.0
	_labeled_control(form, "Расстояние между копиями (mm)", spacing_input)
	dialog.add_child(form)
	dialog.confirmed.connect(func():
		var ok := plan_canvas.array_selected_wall(int(count_input.value), spacing_input.value)
		status_label.text = "Массив создан" if ok else "Не удалось создать массив"
	)
	add_child(dialog)
	dialog.popup_centered()


func _resolve_wall_intersections() -> void:
	var result := plan_canvas.resolve_wall_intersections()
	if not bool(result.get("ok", false)):
		var error := str(result.get("error", "unknown"))
		var messages := {
			"intersection_crosses_opening": "Узел попадает в дверной/оконный проём. Переместите проём.",
			"intersection_creates_tiny_segment": "Соединение создаёт слишком короткий сегмент.",
			"invalid_wall": "В проекте обнаружена некорректная стена."
		}
		status_label.text = str(messages.get(error, "Не удалось разрешить пересечения стен: " + error))
	elif bool(result.get("changed", false)):
		status_label.text = "Топология обновлена • сегментов стен: %d" % int(result.get("count", 0))
	else:
		status_label.text = "Новых пересечений для разделения не найдено"


func _show_layers_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Видимость слоёв чертежа"
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 8)
	dialog.add_child(form)
	var checks: Dictionary = {}
	var entries := [
		["walls", "Архитектура — стены"],
		["furniture", "Мебель и оборудование"],
		["rooms", "Помещения и подписи"],
		["dimensions", "Размерные линии"]
	]
	for entry in entries:
		var layer_name: String = entry[0]
		var check := CheckButton.new()
		check.text = str(entry[1])
		check.button_pressed = bool(plan_canvas.layer_visibility.get(layer_name, true))
		form.add_child(check)
		checks[layer_name] = check
	dialog.confirmed.connect(func():
		for layer_name in checks.keys():
			plan_canvas.set_layer_visibility(str(layer_name), (checks[layer_name] as CheckButton).button_pressed)
		if is_3d:
			_rebuild_3d()
		status_label.text = "Видимость слоёв чертежа обновлена"
	)
	add_child(dialog)
	dialog.popup_centered()

func _measure_mode() -> void:
	plan_canvas.set_tool_mode("measure")
	status_label.text = "Измерение: коснитесь начальной и конечной точки"


func _on_measurement_completed(distance_m: float, angle_degrees: float) -> void:
	status_label.text = "Измерено: %.2f m • угол %.1f°" % [distance_m, angle_degrees]

func _toggle_dimensions() -> void:
	dimensions_enabled = not dimensions_enabled
	plan_canvas.set_dimensions_visible(dimensions_enabled)
	status_label.text = "Размерные линии: " + ("включены" if dimensions_enabled else "выключены")

func _wall_draw_mode() -> void:
	plan_canvas.set_tool_mode("draw")
	status_label.text = "Инструмент стен: рисование • шаг сетки 250 mm"

func _wall_select_mode() -> void:
	plan_canvas.set_tool_mode("select")
	status_label.text = "Выбор стен: каснитесь стены, затем двигайте стену или её конец"

func _on_plan_wall_selected(index: int) -> void:
	if index < 0:
		status_label.text = "Стена не выбрана"
		return
	var wall := plan_canvas.get_selected_wall()
	var wall_a: Vector2 = wall.get("a", Vector2.ZERO)
	var wall_b: Vector2 = wall.get("b", Vector2.ZERO)
	var length_mm := Units.pixels_to_mm(wall_a.distance_to(wall_b))
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
	length_input.min_value = 200.0
	length_input.max_value = 50000.0
	length_input.step = 10.0
	var wall_a: Vector2 = wall.get("a", Vector2.ZERO)
	var wall_b: Vector2 = wall.get("b", Vector2.ZERO)
	length_input.value = Units.pixels_to_mm(wall_a.distance_to(wall_b))
	_labeled_control(form, "Длина стены (mm)", length_input)
	var thickness_input := SpinBox.new()
	thickness_input.min_value = 50.0
	thickness_input.max_value = 1000.0
	thickness_input.step = 10.0
	thickness_input.value = float(wall.get("thickness_mm", 150.0))
	_labeled_control(form, "Толщина стены (mm)", thickness_input)
	var height_input := SpinBox.new()
	height_input.min_value = 1800.0
	height_input.max_value = 10000.0
	height_input.step = 50.0
	height_input.value = float(wall.get("height_mm", 2800.0))
	_labeled_control(form, "Высота стены (mm)", height_input)
	var bearing := CheckButton.new()
	bearing.text = "Несущая стена (проектная метка)"
	bearing.button_pressed = bool(wall.get("load_bearing", false))
	form.add_child(bearing)
	var opening_select := OptionButton.new()
	opening_select.add_item("Без проёма", 0)
	opening_select.add_item("Дверь", 1)
	opening_select.add_item("Окно", 2)
	var opening_kind := str(wall.get("opening", ""))
	opening_select.select(1 if opening_kind == "door" else 2 if opening_kind == "window" else 0)
	_labeled_control(form, "Тип проёма", opening_select)
	var opening_width := SpinBox.new()
	opening_width.min_value = 300.0
	opening_width.max_value = 5000.0
	opening_width.step = 50.0
	opening_width.value = float(wall.get("opening_width_mm", 900.0 if opening_kind == "door" else 1250.0))
	_labeled_control(form, "Ширина проёма (mm)", opening_width)
	var opening_offset := SpinBox.new()
	opening_offset.min_value = 0.0
	opening_offset.max_value = 50000.0
	opening_offset.step = 50.0
	var wall_length_mm := Units.pixels_to_mm(wall_a.distance_to(wall_b))
	opening_offset.value = float(wall.get("opening_offset_mm", wall_length_mm * 0.5))
	_labeled_control(form, "Центр проёма от начала стены (mm)", opening_offset)
	var opening_height := SpinBox.new()
	opening_height.min_value = 300.0
	opening_height.max_value = 4000.0
	opening_height.step = 50.0
	opening_height.value = float(wall.get("opening_height_mm", 2050.0 if opening_kind == "door" else 1200.0))
	_labeled_control(form, "Высота проёма (mm)", opening_height)
	var sill_height := SpinBox.new()
	sill_height.min_value = 0.0
	sill_height.max_value = 2500.0
	sill_height.step = 50.0
	sill_height.value = float(wall.get("sill_height_mm", 850.0))
	_labeled_control(form, "Высота подоконника (mm)", sill_height)
	dialog.confirmed.connect(func():
		var selected_opening := "door" if opening_select.selected == 1 else "window" if opening_select.selected == 2 else ""
		var valid := plan_canvas.apply_selected_wall_settings(length_input.value, thickness_input.value, height_input.value, bearing.button_pressed, selected_opening, opening_width.value, opening_offset.value, sill_height.value, opening_height.value)
		status_label.text = "Параметры стены и проёма обновлены • mm" if valid else "Не удалось изменить параметры стены"
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
	var opening_warning := false
	if not pending_opening.is_empty() and not walls.is_empty():
		var last_index := walls.size() - 1
		var last_wall: Dictionary = walls[last_index]
		var last_a: Vector2 = last_wall.get("a", Vector2.ZERO)
		var last_b: Vector2 = last_wall.get("b", Vector2.ZERO)
		var length_mm := Units.pixels_to_mm(last_a.distance_to(last_b))
		if length_mm >= 600.0:
			last_wall["opening"] = pending_opening
			last_wall["opening_width_mm"] = minf(900.0 if pending_opening == "door" else 1250.0, maxf(300.0, length_mm - 100.0))
			last_wall["opening_offset_mm"] = length_mm * 0.5
			last_wall["sill_height_mm"] = 850.0
			last_wall["opening_height_mm"] = 2050.0 if pending_opening == "door" else 1200.0
			walls[last_index] = last_wall
			plan_canvas.walls = walls.duplicate(true)
			plan_canvas.queue_redraw()
		else:
			opening_warning = true
		pending_opening = ""
	status_label.text = "Стены: %d • Стена добавлена" % walls.size()
	if opening_warning:
		status_label.text = "Стена короче 600 mm: проём не создан"
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
	if plan_canvas.undo():
		walls = plan_canvas.walls.duplicate(true)
		_snapshot_floor()
		status_label.text = "Отменено последнее изменение стен"
		if is_3d:
			_rebuild_3d()
	else:
		status_label.text = "История отмены пуста"

func _redo() -> void:
	if plan_canvas.redo():
		walls = plan_canvas.walls.duplicate(true)
		_snapshot_floor()
		status_label.text = "Изменение стен восстановлено"
		if is_3d:
			_rebuild_3d()
	else:
		status_label.text = "История повтора пуста"

func _clear() -> void:
	plan_canvas.clear_plan()
	walls.clear()
	furniture.clear()
	selected_furniture = -1
	_snapshot_floor()
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
	view_camera.projection = camera_projection
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

func _floor_base_y(floor_index: int) -> float:
	return Units.floor_base_elevation(floors, floor_index, WALL_HEIGHT, 0.22)

func _update_camera() -> void:
	if not is_instance_valid(view_camera):
		return
	camera_pitch = clampf(camera_pitch, -1.52, -0.12)
	camera_distance = clampf(camera_distance, 5.0, 34.0)
	var horizontal := camera_distance * cos(camera_pitch)
	view_camera.position = Vector3(sin(camera_yaw) * horizontal, -sin(camera_pitch) * camera_distance, cos(camera_yaw) * horizontal)
	var building_center_y := 1.4
	if floors.size() > 1:
		building_center_y = (_floor_base_y(floors.size() - 1) + WALL_HEIGHT) * 0.5
	view_camera.look_at(Vector3(0.0, building_center_y, 0.0), Vector3.UP)
	if camera_projection == Camera3D.PROJECTION_ORTHOGONAL:
		view_camera.size = camera_distance

func _camera_top() -> void:
	camera_yaw = 0.0
	camera_pitch = -1.48
	camera_distance = 22.0
	_update_camera()
	status_label.text = "Камера: вид сверху"

func _camera_front() -> void:
	camera_yaw = 0.0
	camera_pitch = -0.12
	camera_distance = 18.0
	_update_camera()
	status_label.text = "Камера: вид спереди"

func _camera_side() -> void:
	camera_yaw = PI * 0.5
	camera_pitch = -0.12
	camera_distance = 18.0
	_update_camera()
	status_label.text = "Камера: вид сбоку"

func _toggle_camera_projection() -> void:
	camera_projection = Camera3D.PROJECTION_ORTHOGONAL if camera_projection == Camera3D.PROJECTION_PERSPECTIVE else Camera3D.PROJECTION_PERSPECTIVE
	if is_instance_valid(view_camera):
		view_camera.projection = camera_projection
		_update_camera()
	status_label.text = "Проекция: " + ("ортографическая" if camera_projection == Camera3D.PROJECTION_ORTHOGONAL else "перспективная")

func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			preview_dragging = true
			preview_last_pos = event.position
			preview_press_pos = event.position
			if edit_wall_ends_3d:
				wall_3d_endpoint_pick = _pick_wall_endpoint_3d(_to_viewport_position(event.position))
				status_label.text = "Выбран конец стены: перетащите его" if not wall_3d_endpoint_pick.is_empty() else "Коснитесь маркера конца стены"
			elif move_mode_3d:
				_pick_furniture(_to_viewport_position(event.position))
		else:
			var pointer_movement := preview_press_pos.distance_to(event.position)
			if edit_wall_ends_3d:
				if pointer_movement >= 12.0 and not wall_3d_endpoint_pick.is_empty():
					_move_wall_endpoint_from_3d(_to_viewport_position(event.position))
				elif wall_3d_endpoint_pick.is_empty():
					status_label.text = "Коснитесь маркера конца стены"
				wall_3d_endpoint_pick.clear()
			elif pointer_movement < 12.0:
				if draw_walls_3d:
					_handle_3d_wall_tap(_to_viewport_position(event.position))
				elif select_walls_3d:
					_pick_wall_3d(_to_viewport_position(event.position))
				elif not move_mode_3d:
					_pick_furniture(_to_viewport_position(event.position))
			preview_dragging = false
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and preview_dragging:
		var delta: Vector2 = event.position - preview_last_pos
		preview_last_pos = event.position
		if edit_wall_ends_3d:
			if not wall_3d_endpoint_pick.is_empty():
				status_label.text = "Перемещайте выбранный конец стены в плоскости этажа"
		elif draw_walls_3d:
			var hit: Variant = _screen_to_floor(_to_viewport_position(event.position))
			if hit is Vector3 and wall_3d_has_start:
				var plan_point := _world_to_plan_point(hit)
				status_label.text = "3D-стена • длина %.0f mm • отпустите и коснитесь конечной точки" % Units.pixels_to_mm(wall_3d_start_point.distance_to(plan_point))
		elif move_mode_3d and selected_furniture >= 0:
			var hit: Variant = _screen_to_floor(_to_viewport_position(event.position))
			if hit is Vector3:
				furniture[selected_furniture]["position"] = Vector2(hit.x, hit.z)
				_sync_plan_furniture()
				_update_dragged_furniture_node()
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



func _pick_wall_endpoint_3d(screen_pos: Vector2) -> Dictionary:
	if not is_instance_valid(view_camera) or current_floor < 0 or current_floor >= floors.size():
		return {}
	var floor_data: Dictionary = floors[current_floor]
	var floor_walls: Array = floor_data.get("walls", [])
	var base_y := _floor_base_y(current_floor)
	var best_index := -1
	var best_endpoint := -1
	var best_distance := 30.0
	for wall_index in range(floor_walls.size()):
		var wall: Dictionary = floor_walls[wall_index]
		var wall_height := float(wall.get("height_mm", 2800.0)) / 1000.0
		for endpoint_index in [0, 1]:
			var point: Vector2 = wall.get("a", Vector2.ZERO) if endpoint_index == 0 else wall.get("b", Vector2.ZERO)
			var world_point := Vector3((point.x - plan_canvas.size.x * 0.5) / PPM, base_y + wall_height * 0.5, (point.y - plan_canvas.size.y * 0.5) / PPM)
			if view_camera.is_position_behind(world_point):
				continue
			var distance := view_camera.unproject_position(world_point).distance_to(screen_pos)
			if distance < best_distance:
				best_distance = distance
				best_index = wall_index
				best_endpoint = endpoint_index
	if best_index < 0:
		return {}
	plan_canvas.selected_wall = best_index
	plan_canvas.queue_redraw()
	return {"wall_index": best_index, "endpoint_index": best_endpoint}


func _move_wall_endpoint_from_3d(screen_pos: Vector2) -> void:
	var hit: Variant = _screen_to_floor(screen_pos)
	if not (hit is Vector3):
		status_label.text = "Не удалось определить новую точку стены"
		return
	var wall_index := int(wall_3d_endpoint_pick.get("wall_index", -1))
	var endpoint_index := int(wall_3d_endpoint_pick.get("endpoint_index", -1))
	var target := _world_to_plan_point(hit)
	if plan_canvas.move_wall_endpoint(wall_index, endpoint_index, target):
		walls = plan_canvas.walls.duplicate(true)
		_snapshot_floor()
		status_label.text = "Конец стены перемещён • связанные стены обновлены"
		_rebuild_3d()
	else:
		status_label.text = "Перемещение невозможно: образуется некорректная стена"

func _world_to_plan_point(world_point: Vector3) -> Vector2:
	return Vector2(
		world_point.x * PPM + plan_canvas.size.x * 0.5,
		world_point.z * PPM + plan_canvas.size.y * 0.5
	)


func _handle_3d_wall_tap(screen_pos: Vector2) -> void:
	var hit: Variant = _screen_to_floor(screen_pos)
	if not (hit is Vector3):
		status_label.text = "Не удалось определить точку на уровне этажа"
		return
	var plan_point := _world_to_plan_point(hit)
	if not wall_3d_has_start:
		wall_3d_start_point = plan_point
		wall_3d_has_start = true
		status_label.text = "3D-стена: начальная точка выбрана • коснитесь конечной точки"
		return
	var created := plan_canvas.add_wall_between_points(wall_3d_start_point, plan_point, true)
	wall_3d_has_start = false
	if created:
		walls = plan_canvas.walls.duplicate(true)
		_snapshot_floor()
		status_label.text = "Стена создана непосредственно в 3D • всего стен: %d" % walls.size()
		_rebuild_3d()
	else:
		status_label.text = "Стена не создана: длина меньше минимальной"



func _toggle_3d_wall_endpoint_edit() -> void:
	edit_wall_ends_3d = not edit_wall_ends_3d
	if edit_wall_ends_3d:
		is_3d = true
		move_mode_3d = false
		draw_walls_3d = false
		select_walls_3d = false
		wall_3d_has_start = false
		plan_canvas.visible = false
		preview.visible = true
		status_label.text = "3D-редактирование концов включено • перетащите маркер конца стены"
	else:
		wall_3d_endpoint_pick.clear()
		status_label.text = "3D-редактирование концов выключено"

func _toggle_3d_wall_draw() -> void:
	draw_walls_3d = not draw_walls_3d
	wall_3d_has_start = false
	edit_wall_ends_3d = false
	wall_3d_endpoint_pick.clear()
	if draw_walls_3d:
		move_mode_3d = false
		select_walls_3d = false
		is_3d = true
		plan_canvas.visible = false
		preview.visible = true
		status_label.text = "3D-рисование включено • коснитесь начальной, затем конечной точки на уровне этажа"
	else:
		status_label.text = "3D-рисование выключено"

func _toggle_3d_wall_select() -> void:
	select_walls_3d = not select_walls_3d
	if select_walls_3d:
		draw_walls_3d = false
		edit_wall_ends_3d = false
		wall_3d_endpoint_pick.clear()
		wall_3d_has_start = false
		move_mode_3d = false
		status_label.text = "3D: каснитесь стены для выбора; параметры редактируются через «ПАРАМЕТРЫ СТЕНЫ»"
	else:
		status_label.text = "3D: выбор стен выключен"

func _pick_wall_3d(screen_pos: Vector2) -> void:
	if not is_instance_valid(view_camera) or current_floor < 0 or current_floor >= floors.size():
		return
	var best_index := -1
	var best_distance := 72.0
	var floor_data: Dictionary = floors[current_floor]
	var floor_walls: Array = floor_data.get("walls", [])
	var base_y := _floor_base_y(current_floor)
	for wall_index in range(floor_walls.size()):
		var wall: Dictionary = floor_walls[wall_index]
		if not bool(plan_canvas.layer_visibility.get("walls", true)):
			continue
		var a: Vector2 = wall.get("a", Vector2.ZERO)
		var b: Vector2 = wall.get("b", Vector2.ZERO)
		var mid := (a + b) * 0.5
		var wall_height := float(wall.get("height_mm", 2800.0)) / 1000.0
		var world_mid := Vector3((mid.x - plan_canvas.size.x * 0.5) / PPM, base_y + wall_height * 0.5, (mid.y - plan_canvas.size.y * 0.5) / PPM)
		if view_camera.is_position_behind(world_mid):
			continue
		var distance := view_camera.unproject_position(world_mid).distance_to(screen_pos)
		if distance < best_distance:
			best_distance = distance
			best_index = wall_index
	if best_index >= 0:
		plan_canvas.selected_wall = best_index
		plan_canvas.queue_redraw()
		var selected := plan_canvas.get_selected_wall()
		var selected_a: Vector2 = selected.get("a", Vector2.ZERO)
		var selected_b: Vector2 = selected.get("b", Vector2.ZERO)
		status_label.text = "3D выбрана стена %d • %.0f mm" % [best_index + 1, Units.pixels_to_mm(selected_a.distance_to(selected_b))]
		_rebuild_3d()
	else:
		status_label.text = "Стена не найдена в точке касания"

func _to_viewport_position(container_pos: Vector2) -> Vector2:
	var viewport := preview.get_child(0) as SubViewport
	if viewport == null or preview.size.x <= 0.0 or preview.size.y <= 0.0:
		return container_pos
	return container_pos * Vector2(viewport.size) / preview.size

func _screen_to_floor(screen_pos: Vector2) -> Variant:
	var origin := view_camera.project_ray_origin(screen_pos)
	var direction := view_camera.project_ray_normal(screen_pos)
	var floor_y := _floor_base_y(current_floor)
	return Plane(Vector3.UP, floor_y).intersects_ray(origin, direction)

func _toggle_3d_move() -> void:
	move_mode_3d = not move_mode_3d
	if move_mode_3d:
		select_walls_3d = false
		edit_wall_ends_3d = false
		wall_3d_endpoint_pick.clear()
		draw_walls_3d = false
		wall_3d_has_start = false
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
		var floor_y := _floor_base_y(current_floor)
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
		if not bool(floor_data.get("visible", true)):
			continue
		var base_y := _floor_base_y(floor_index)
		_box(root, Vector3(24, 0.12, 24), Vector3(0, base_y - 0.12, 0), floor_mat)
		var floor_walls: Array = floor_data.get("walls", [])
		for wall_index in range(floor_walls.size()):
			var wall: Dictionary = floor_walls[wall_index]
			if not bool(plan_canvas.layer_visibility.get("walls", true)):
				continue
			var active_wall_mat: Material = wall_mat
			if floor_index == current_floor and wall_index == plan_canvas.selected_wall:
				active_wall_mat = _mat(Color("#FFC878"), 0.62)
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
				var default_width_mm := 900.0 if opening == "door" else 1250.0
				var gap := minf(float(wall.get("opening_width_mm", default_width_mm)) / 1000.0, maxf(length - 0.1, 0.1))
				var opening_offset_m := clampf(float(wall.get("opening_offset_mm", length * 500.0)) / 1000.0, gap * 0.5, maxf(gap * 0.5, length - gap * 0.5))
				var left_length := opening_offset_m - gap * 0.5
				var right_length := length - opening_offset_m - gap * 0.5
				var opening_center := center + direction * (opening_offset_m - length * 0.5)
				if left_length > 0.05:
					var left_center := center - direction * (length * 0.5 - left_length * 0.5)
					var left_wall := _box(root, Vector3(left_length, wall_height, wall_thickness), left_center, active_wall_mat)
					left_wall.rotation.y = -angle
				if right_length > 0.05:
					var right_center := center + direction * (length * 0.5 - right_length * 0.5)
					var right_wall := _box(root, Vector3(right_length, wall_height, wall_thickness), right_center, active_wall_mat)
					right_wall.rotation.y = -angle
				if opening == "door":
					var door_opening_height := minf(float(wall.get("opening_height_mm", 2050.0)) / 1000.0, wall_height * 0.95)
					var lintel_height := maxf(wall_height - door_opening_height, 0.02)
					var lintel := _box(root, Vector3(gap, lintel_height, wall_thickness), Vector3(opening_center.x, base_y + door_opening_height + lintel_height * 0.5, opening_center.z), active_wall_mat)
					lintel.rotation.y = -angle
				else:
					var sill_height := minf(float(wall.get("sill_height_mm", 850.0)) / 1000.0, wall_height * 0.4)
					var window_top := minf(sill_height + float(wall.get("opening_height_mm", 1200.0)) / 1000.0, wall_height * 0.95)
					var pane_height := maxf(window_top - sill_height, 0.1)
					var header_height := maxf(wall_height - window_top, 0.02)
					var sill := _box(root, Vector3(gap, sill_height, wall_thickness), Vector3(opening_center.x, base_y + sill_height * 0.5, opening_center.z), active_wall_mat)
					var header := _box(root, Vector3(gap, header_height, wall_thickness), Vector3(opening_center.x, base_y + window_top + header_height * 0.5, opening_center.z), active_wall_mat)
					sill.rotation.y = -angle
					header.rotation.y = -angle
					var pane := _box(root, Vector3(gap * 0.94, pane_height, 0.035), Vector3(opening_center.x, base_y + sill_height + pane_height * 0.5, opening_center.z), glass)
					pane.rotation.y = -angle
			else:
				var segment := _box(root, Vector3(maxf(length, 0.12), wall_height, wall_thickness), center, active_wall_mat)
				segment.rotation.y = -angle
			var skirting := _box(root, Vector3(maxf(length, 0.12), 0.1, wall_thickness + 0.03), Vector3(center.x, base_y + 0.1, center.z), trim_mat)
			skirting.rotation.y = -angle
			var crown := _box(root, Vector3(maxf(length, 0.12), 0.07, wall_thickness + 0.03), Vector3(center.x, base_y + wall_height - 0.035, center.z), trim_mat)
			crown.rotation.y = -angle
		var floor_furniture: Array = floor_data.get("furniture", [])
		if bool(plan_canvas.layer_visibility.get("furniture", true)):
			for furniture_index in range(floor_furniture.size()):
				_add_furniture(root, floor_furniture[furniture_index], base_y, floor_index, furniture_index)
	_update_camera()
	if floors.size() > 1:
		status_label.text = "3D • показаны все этажи: %d" % floors.size()

func _update_dragged_furniture_node() -> void:
	if selected_furniture < 0 or selected_furniture >= furniture.size():
		return
	var target_name := "Furniture_%d_%d" % [current_floor, selected_furniture]
	for generated_root in preview_world.get_children():
		if not generated_root.is_in_group("generated"):
			continue
		for node in generated_root.get_children():
			if node is Node3D and node.name == target_name:
				var position_2d: Vector2 = furniture[selected_furniture].get("position", Vector2.ZERO)
				node.position = Vector3(position_2d.x, _floor_base_y(current_floor), position_2d.y)
				return

func _add_furniture(root: Node3D, item: Dictionary, floor_y: float = 0.0, floor_index: int = 0, item_index: int = 0) -> void:
	var kind := int(item.get("kind", 0))
	var p: Vector2 = item.get("position", Vector2.ZERO)
	var group := Node3D.new()
	group.name = "Furniture_%d_%d" % [floor_index, item_index]
	group.position = Vector3(p.x, floor_y, p.y)
	group.rotation.y = float(item.get("rotation", 0.0))
	group.scale = Vector3.ONE * float(item.get("scale", 1.0))
	root.add_child(group)
	if floor_index == current_floor and item_index == selected_furniture:
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
	var floor_data: Dictionary = floors[current_floor].duplicate(true)
	floor_data["walls"] = walls.duplicate(true)
	floor_data["furniture"] = furniture.duplicate(true)
	floors[current_floor] = floor_data

func _add_floor() -> void:
	_snapshot_floor()
	floors.append({"name": "Этаж %d" % (floors.size() + 1), "floor_height_mm": 2800.0, "slab_thickness_mm": 220.0, "visible": true, "walls": [], "furniture": []})
	current_floor = floors.size() - 1
	walls.clear()
	furniture.clear()
	selected_furniture = -1
	_sync_plan_furniture()
	plan_canvas.walls.clear()
	plan_canvas.reset_history()
	plan_canvas.queue_redraw()
	if is_3d:
		_rebuild_3d()
	status_label.text = "Создан этаж %d из %d" % [current_floor + 1, floors.size()]

func _duplicate_current_floor() -> void:
	if current_floor < 0 or current_floor >= floors.size():
		return
	_snapshot_floor()
	var copied: Dictionary = floors[current_floor].duplicate(true)
	copied["name"] = str(copied.get("name", "Этаж")) + " — копия"
	floors.insert(current_floor + 1, copied)
	current_floor += 1
	walls = copied.get("walls", []).duplicate(true)
	furniture = copied.get("furniture", []).duplicate(true)
	selected_furniture = -1
	plan_canvas.walls = walls.duplicate(true)
	plan_canvas.selected_wall = -1
	plan_canvas.reset_history()
	_sync_plan_furniture()
	plan_canvas.queue_redraw()
	if is_3d:
		_rebuild_3d()
	status_label.text = "Этаж скопирован • %s" % str(copied.get("name", "Этаж"))


func _move_current_floor(direction: int) -> void:
	if floors.size() < 2 or direction == 0:
		return
	_snapshot_floor()
	var target_index := clampi(current_floor + direction, 0, floors.size() - 1)
	if target_index == current_floor:
		status_label.text = "Этаж уже на этом месте"
		return
	var moving: Dictionary = floors[current_floor]
	floors.remove_at(current_floor)
	floors.insert(target_index, moving)
	current_floor = target_index
	walls = floors[current_floor].get("walls", []).duplicate(true)
	furniture = floors[current_floor].get("furniture", []).duplicate(true)
	selected_furniture = -1
	plan_canvas.walls = walls.duplicate(true)
	plan_canvas.selected_wall = -1
	plan_canvas.reset_history()
	_sync_plan_furniture()
	plan_canvas.queue_redraw()
	if is_3d:
		_rebuild_3d()
	status_label.text = "Порядок этажей изменён • %d/%d" % [current_floor + 1, floors.size()]


func _toggle_current_floor_visibility() -> void:
	if current_floor < 0 or current_floor >= floors.size():
		return
	var floor_data: Dictionary = floors[current_floor].duplicate(true)
	floor_data["visible"] = not bool(floor_data.get("visible", true))
	floors[current_floor] = floor_data
	status_label.text = "%s • %s в 3D" % [str(floor_data.get("name", "Этаж")), "видим" if floor_data["visible"] else "скрыт"]
	if is_3d:
		_rebuild_3d()

func _edit_current_floor() -> void:
	if current_floor < 0 or current_floor >= floors.size():
		return
	var floor_data: Dictionary = floors[current_floor]
	var dialog := ConfirmationDialog.new()
	dialog.title = "Параметры этажа"
	dialog.min_size = Vector2i(340, 190)
	var form := VBoxContainer.new()
	dialog.add_child(form)
	var name_input := LineEdit.new()
	name_input.text = str(floor_data.get("name", "Этаж %d" % (current_floor + 1)))
	name_input.placeholder_text = "Название этажа"
	_labeled_control(form, "Название", name_input)
	var height_input := SpinBox.new()
	height_input.min_value = 2000.0
	height_input.max_value = 6000.0
	height_input.step = 50.0
	height_input.value = float(floor_data.get("floor_height_mm", 2800.0))
	_labeled_control(form, "Высота этажа (mm)", height_input)
	var slab_input := SpinBox.new()
	slab_input.min_value = 80.0
	slab_input.max_value = 1000.0
	slab_input.step = 10.0
	slab_input.value = float(floor_data.get("slab_thickness_mm", 220.0))
	_labeled_control(form, "Толщина перекрытия (mm)", slab_input)
	dialog.confirmed.connect(func():
		var updated: Dictionary = floors[current_floor].duplicate(true)
		updated["name"] = name_input.text.strip_edges() if not name_input.text.strip_edges().is_empty() else "Этаж %d" % (current_floor + 1)
		updated["floor_height_mm"] = height_input.value
		updated["slab_thickness_mm"] = slab_input.value
		floors[current_floor] = updated
		status_label.text = "%s • высота %.0f mm • перекрытие %.0f mm" % [updated["name"], height_input.value, slab_input.value]
		if is_3d:
			_rebuild_3d()
	)
	add_child(dialog)
	dialog.popup_centered()


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
	plan_canvas.selected_wall = -1
	plan_canvas.reset_history()
	plan_canvas.queue_redraw()
	if is_3d:
		_rebuild_3d()
	status_label.text = "Этаж %d из %d" % [current_floor + 1, floors.size()]

func _calculate_room_areas() -> void:
	var faces := Geometry.find_bounded_faces(walls)
	if faces.is_empty():
		status_label.text = "Замкнутых помещений не найдено • проверьте точность соединения стен"
		return
	var total_area_m2 := 0.0
	var total_perimeter_m := 0.0
	for face in faces:
		total_area_m2 += Geometry.polygon_area(face) / (PPM * PPM)
		total_perimeter_m += Geometry.polygon_perimeter(face) / PPM
	status_label.text = "Этаж %d • помещений: %d • площадь: %.2f м² • периметры: %.2f м" % [current_floor + 1, faces.size(), total_area_m2, total_perimeter_m]

func _ensure_projects_directory() -> void:
	DirAccess.make_dir_recursive("user://projects")


func _safe_project_name(raw_name: String) -> String:
	var safe := raw_name.strip_edges()
	for invalid_character in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		safe = safe.replace(str(invalid_character), "_")
	return safe.strip_edges()


func _named_project_path(project_name: String) -> String:
	return "user://projects/" + _safe_project_name(project_name) + ".json"


func _copy_user_file(source_path: String, target_path: String) -> bool:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return false
	var contents := source.get_as_text()
	source.close()
	var target := FileAccess.open(target_path, FileAccess.WRITE)
	if target == null:
		return false
	target.store_string(contents)
	target.close()
	return true


func _start_autosave() -> void:
	autosave_timer = Timer.new()
	autosave_timer.wait_time = 60.0
	autosave_timer.one_shot = false
	autosave_timer.timeout.connect(_autosave_project)
	add_child(autosave_timer)
	autosave_timer.start()


func _autosave_project() -> void:
	var previous_status := status_label.text if is_instance_valid(status_label) else ""
	_save_project()
	_copy_user_file("user://dreamhouse_project.json", "user://dreamhouse_autosave.json")
	if is_instance_valid(status_label):
		status_label.text = previous_status


func _check_autosave_recovery() -> void:
	if not FileAccess.file_exists("user://dreamhouse_autosave.json"):
		return
	var autosave_time := FileAccess.get_modified_time("user://dreamhouse_autosave.json")
	var project_time := FileAccess.get_modified_time("user://dreamhouse_project.json") if FileAccess.file_exists("user://dreamhouse_project.json") else 0
	if autosave_time <= project_time:
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Восстановление автосохранения"
	dialog.dialog_text = "Найдено более новое автосохранение. Восстановить его? Текущий файл проекта не будет удалён."
	dialog.confirmed.connect(func():
		if _copy_user_file("user://dreamhouse_autosave.json", "user://dreamhouse_project.json"):
			_load_project()
			status_label.text = "Проект восстановлен из автосохранения"
	)
	add_child(dialog)
	dialog.popup_centered()


func _open_project_manager() -> void:
	_ensure_projects_directory()
	var window := Window.new()
	window.title = "Менеджер проектов DreamHouse 3D"
	window.size = Vector2i(460, 370)
	window.min_size = Vector2i(360, 300)
	window.transient = true
	window.exclusive = true
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	window.add_child(root)
	var title := Label.new()
	title.text = "Сохранённые проекты на устройстве"
	root.add_child(title)
	var project_select := OptionButton.new()
	project_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(project_select)
	var name_input := LineEdit.new()
	name_input.placeholder_text = "Название проекта"
	name_input.text = current_project_name
	root.add_child(name_input)
	var row := HBoxContainer.new()
	root.add_child(row)
	var save_button := Button.new()
	save_button.text = "СОХРАНИТЬ КАК"
	row.add_child(save_button)
	var open_button := Button.new()
	open_button.text = "ОТКРЫТЬ"
	row.add_child(open_button)
	var delete_button := Button.new()
	delete_button.text = "УДАЛИТЬ"
	row.add_child(delete_button)
	var refresh_button := Button.new()
	refresh_button.text = "ОБНОВИТЬ СПИСОК"
	root.add_child(refresh_button)
	var hint := Label.new()
	hint.text = "Автосохранение выполняется каждые 60 секунд."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)
	add_child(window)
	var refresh := func():
		project_select.clear()
		for filename in DirAccess.get_files_at("user://projects"):
			if filename.ends_with(".json"):
				project_select.add_item(filename.trim_suffix(".json"))
	refresh_button.pressed.connect(refresh)
	save_button.pressed.connect(func():
		var safe_name := _safe_project_name(name_input.text)
		if safe_name.is_empty():
			hint.text = "Введите название проекта."
			return
		_save_project()
		if _copy_user_file("user://dreamhouse_project.json", _named_project_path(safe_name)):
			current_project_name = safe_name
			hint.text = "Проект сохранён: " + safe_name
			refresh.call()
		else:
			hint.text = "Не удалось сохранить проект."
	)
	open_button.pressed.connect(func():
		if project_select.item_count == 0 or project_select.selected < 0:
			hint.text = "Выберите проект из списка."
			return
		var selected_name := project_select.get_item_text(project_select.selected)
		if _copy_user_file(_named_project_path(selected_name), "user://dreamhouse_project.json"):
			current_project_name = selected_name
			_load_project()
			hint.text = "Открыт проект: " + selected_name
		else:
			hint.text = "Не удалось открыть проект."
	)
	delete_button.pressed.connect(func():
		if project_select.item_count == 0 or project_select.selected < 0:
			hint.text = "Выберите проект для удаления."
			return
		var selected_name := project_select.get_item_text(project_select.selected)
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(_named_project_path(selected_name)))
		if error == OK:
			if current_project_name == selected_name:
				current_project_name = ""
			hint.text = "Удалён проект: " + selected_name
			refresh.call()
		else:
			hint.text = "Не удалось удалить проект. Код: %d" % error
	)
	refresh.call()
	window.popup_centered()

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
		wall_data.append({"a": [w.a.x, w.a.y], "b": [w.b.x, w.b.y], "opening": w.get("opening", ""), "thickness_mm": w.get("thickness_mm", 150.0), "height_mm": w.get("height_mm", 2800.0), "load_bearing": w.get("load_bearing", false), "opening_width_mm": w.get("opening_width_mm", 900.0), "opening_offset_mm": w.get("opening_offset_mm", 0.0), "opening_height_mm": w.get("opening_height_mm", 2050.0), "sill_height_mm": w.get("sill_height_mm", 850.0), "layer": w.get("layer", "walls")})
	var furniture_data: Array[Dictionary] = []
	for item in furniture:
		var p: Vector2 = item.get("position", Vector2.ZERO)
		furniture_data.append({"kind": item.get("kind", 0), "position": [p.x, p.y], "rotation": item.get("rotation", 0.0), "scale": item.get("scale", 1.0), "layer": item.get("layer", "furniture")})
	_snapshot_floor()
	var floor_data: Array = []
	for floor in floors:
		var fw: Array = []
		for w in floor.get("walls", []):
			fw.append({"a": [w.a.x, w.a.y], "b": [w.b.x, w.b.y], "opening": w.get("opening", ""), "thickness_mm": w.get("thickness_mm", 150.0), "height_mm": w.get("height_mm", 2800.0), "load_bearing": w.get("load_bearing", false), "opening_width_mm": w.get("opening_width_mm", 900.0), "opening_offset_mm": w.get("opening_offset_mm", 0.0), "opening_height_mm": w.get("opening_height_mm", 2050.0), "sill_height_mm": w.get("sill_height_mm", 850.0), "layer": w.get("layer", "walls")})
		var ff: Array = []
		for item in floor.get("furniture", []):
			var fp: Vector2 = item.get("position", Vector2.ZERO)
			ff.append({"kind": item.get("kind", 0), "position": [fp.x, fp.y], "rotation": item.get("rotation", 0.0), "scale": item.get("scale", 1.0), "layer": item.get("layer", "furniture")})
		floor_data.append({"name": str(floor.get("name", "Этаж")), "floor_height_mm": float(floor.get("floor_height_mm", 2800.0)), "slab_thickness_mm": float(floor.get("slab_thickness_mm", 220.0)), "visible": bool(floor.get("visible", true)), "walls": fw, "furniture": ff})
	var data := {"version": 6, "current_floor": current_floor, "floors": floor_data, "walls": wall_data, "furniture": furniture_data, "layers": plan_canvas.layer_visibility.duplicate(true), "camera": {"yaw": camera_yaw, "pitch": camera_pitch, "distance": camera_distance, "projection": camera_projection}}
	var file := FileAccess.open("user://dreamhouse_project.json", FileAccess.WRITE)
	if file == null:
		status_label.text = "Ошибка сохранения"
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if not current_project_name.is_empty():
		_copy_user_file("user://dreamhouse_project.json", _named_project_path(current_project_name))
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
	var saved_layers: Variant = data.get("layers", {})
	if saved_layers is Dictionary:
		for layer_name in plan_canvas.layer_visibility.keys():
			plan_canvas.layer_visibility[layer_name] = bool(saved_layers.get(layer_name, plan_canvas.layer_visibility[layer_name]))
	var camera_data: Variant = data.get("camera", {})
	if camera_data is Dictionary:
		camera_yaw = float(camera_data.get("yaw", camera_yaw))
		camera_pitch = clampf(float(camera_data.get("pitch", camera_pitch)), -1.52, -0.12)
		camera_distance = clampf(float(camera_data.get("distance", camera_distance)), 5.0, 34.0)
		camera_projection = int(camera_data.get("projection", camera_projection))
	walls.clear()
	for item in data.get("walls", []):
		if item is Dictionary and item.has("a") and item.has("b") and item.a.size() == 2 and item.b.size() == 2:
			walls.append({"a": Vector2(float(item.a[0]), float(item.a[1])), "b": Vector2(float(item.b[0]), float(item.b[1])), "opening": str(item.get("opening", "")), "thickness_mm": float(item.get("thickness_mm", 150.0)), "height_mm": float(item.get("height_mm", 2800.0)), "load_bearing": bool(item.get("load_bearing", false)), "opening_width_mm": float(item.get("opening_width_mm", 900.0)), "opening_offset_mm": float(item.get("opening_offset_mm", 0.0)), "opening_height_mm": float(item.get("opening_height_mm", 2050.0)), "sill_height_mm": float(item.get("sill_height_mm", 850.0)), "layer": str(item.get("layer", "walls"))})
	furniture.clear()
	for item in data.get("furniture", []):
		if item is Dictionary and item.has("kind") and item.has("position") and item.position.size() == 2:
			furniture.append({"kind": int(item.kind), "position": Vector2(float(item.position[0]), float(item.position[1])), "rotation": float(item.get("rotation", 0.0)), "scale": float(item.get("scale", 1.0)), "layer": str(item.get("layer", "furniture"))})
	if data.has("floors") and data.floors is Array and not data.floors.is_empty():
		floors.clear()
		for floor_item in data.floors:
			var fwalls: Array[Dictionary] = []
			for w in floor_item.get("walls", []):
				if w is Dictionary and w.has("a") and w.has("b"):
					fwalls.append({"a": Vector2(float(w.a[0]), float(w.a[1])), "b": Vector2(float(w.b[0]), float(w.b[1])), "opening": str(w.get("opening", "")), "thickness_mm": float(w.get("thickness_mm", 150.0)), "height_mm": float(w.get("height_mm", 2800.0)), "load_bearing": bool(w.get("load_bearing", false)), "opening_width_mm": float(w.get("opening_width_mm", 900.0)), "opening_offset_mm": float(w.get("opening_offset_mm", 0.0)), "opening_height_mm": float(w.get("opening_height_mm", 2050.0)), "sill_height_mm": float(w.get("sill_height_mm", 850.0)), "layer": str(w.get("layer", "walls"))})
			var ffurniture: Array[Dictionary] = []
			for item in floor_item.get("furniture", []):
				if item is Dictionary and item.has("position"):
					ffurniture.append({"kind": int(item.get("kind", 0)), "position": Vector2(float(item.position[0]), float(item.position[1])), "rotation": float(item.get("rotation", 0.0)), "scale": float(item.get("scale", 1.0)), "layer": str(item.get("layer", "furniture"))})
			floors.append({"name": str(floor_item.get("name", "Этаж %d" % (floors.size() + 1))), "floor_height_mm": float(floor_item.get("floor_height_mm", 2800.0)), "slab_thickness_mm": float(floor_item.get("slab_thickness_mm", 220.0)), "visible": bool(floor_item.get("visible", true)), "walls": fwalls, "furniture": ffurniture})
		current_floor = clampi(int(data.get("current_floor", 0)), 0, floors.size() - 1)
		walls = floors[current_floor].walls.duplicate(true)
		furniture = floors[current_floor].furniture.duplicate(true)
	else:
		floors = [{"name": "Этаж 1", "floor_height_mm": 2800.0, "slab_thickness_mm": 220.0, "visible": true, "walls": walls.duplicate(true), "furniture": furniture.duplicate(true)}]
		current_floor = 0
	plan_canvas.walls = walls.duplicate(true)
	plan_canvas.reset_history()
	plan_canvas.selected_wall = -1
	_sync_plan_furniture()
	plan_canvas.queue_redraw()
	status_label.text = "Загружено • этаж %d/%d • %d стен • %d объектов" % [current_floor + 1, floors.size(), walls.size(), furniture.size()]
	if is_3d:
		_rebuild_3d()
