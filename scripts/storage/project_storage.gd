class_name ProjectStorage
extends RefCounted

const CURRENT_SCHEMA_VERSION: int = 8
const DEFAULT_LAYER_VISIBILITY: Dictionary = {
	"walls": true,
	"doors": true,
	"windows": true,
	"furniture": true,
	"electrical": true,
	"plumbing": true,
	"heating": true,
	"rooms": true,
	"dimensions": true
}
const ARRAY_FIELDS: PackedStringArray = [
	"floors",
	"walls",
	"furniture",
	"roofs",
	"stairs",
	"engineering_networks",
	"dimensions",
	"materials",
	"custom_layers",
	"objects"
]

static func migrate_document(source: Dictionary) -> Dictionary:
	var data: Dictionary = source.duplicate(true)
	var version := int(data.get("version", data.get("schema_version", 1)))
	if version < 1:
		return {"ok": false, "error": "invalid_schema_version"}
	if version > CURRENT_SCHEMA_VERSION:
		return {"ok": false, "error": "unsupported_future_schema", "found_version": version}
	while version < CURRENT_SCHEMA_VERSION:
		match version:
			1:
				_migrate_v1_to_v2(data)
			2:
				_migrate_v2_to_v3(data)
			3:
				_migrate_v3_to_v4(data)
			4:
				_migrate_v4_to_v5(data)
			5:
				_migrate_v5_to_v6(data)
			6:
				_migrate_v6_to_v7(data)
			7:
				_migrate_v7_to_v8(data)
			_:
				return {"ok": false, "error": "missing_migration", "from_version": version}
			version += 1
	data["version"] = CURRENT_SCHEMA_VERSION
	var validation := validate_document(data)
	if not bool(validation.get("ok", false)):
		return validation
	return {"ok": true, "data": data, "migrated": int(source.get("version", source.get("schema_version", 1))) != CURRENT_SCHEMA_VERSION}

static func validate_document(data: Dictionary) -> Dictionary:
	for field in ARRAY_FIELDS:
		if data.has(field) and not data[field] is Array:
			return {"ok": false, "error": "invalid_array_field", "field": field}
	if data.has("current_floor") and not data.current_floor is int and not data.current_floor is float:
		return {"ok": false, "error": "invalid_current_floor"}
	if data.has("layers") and not data.layers is Dictionary:
		return {"ok": false, "error": "invalid_layers"}
	if data.has("camera") and not data.camera is Dictionary:
		return {"ok": false, "error": "invalid_camera"}
	if data.has("site") and not data.site is Dictionary:
		return {"ok": false, "error": "invalid_site"}
	if not data.has("floors") and not data.has("walls"):
		return {"ok": false, "error": "missing_project_geometry"}
	return {"ok": true}

static func encode_document(data: Dictionary) -> Dictionary:
	var migrated := migrate_document(data)
	if not bool(migrated.get("ok", false)):
		return migrated
	var json_text := JSON.stringify(migrated.data, "\t")
	return {"ok": true, "text": json_text, "data": migrated.data}

static func decode_document(json_text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(json_text)
	if not parsed is Dictionary:
		return {"ok": false, "error": "invalid_json_root"}
	return migrate_document(parsed)

static func write_json_atomic(path: String, data: Dictionary) -> Dictionary:
	var encoded := encode_document(data)
	if not bool(encoded.get("ok", false)):
		return encoded
	var absolute_path := ProjectSettings.globalize_path(path)
	var parent_path := absolute_path.get_base_dir()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(parent_path)
	if mkdir_error != OK and not DirAccess.dir_exists_absolute(parent_path):
		return {"ok": false, "error": "directory_create_failed", "code": mkdir_error}
	var temporary_path := absolute_path + ".tmp"
	var backup_path := absolute_path + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "temporary_open_failed", "code": FileAccess.get_open_error()}
	file.store_string(str(encoded.text))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary_path)
		return {"ok": false, "error": "temporary_write_failed", "code": write_error}
	var had_original := FileAccess.file_exists(absolute_path)
	if had_original:
		if FileAccess.file_exists(backup_path):
			var remove_backup_error := DirAccess.remove_absolute(backup_path)
			if remove_backup_error != OK:
				DirAccess.remove_absolute(temporary_path)
				return {"ok": false, "error": "old_backup_remove_failed", "code": remove_backup_error}
		var backup_error := DirAccess.rename_absolute(absolute_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary_path)
			return {"ok": false, "error": "backup_rename_failed", "code": backup_error}
	var replace_error := DirAccess.rename_absolute(temporary_path, absolute_path)
	if replace_error != OK:
		if had_original and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, absolute_path)
		DirAccess.remove_absolute(temporary_path)
		return {"ok": false, "error": "atomic_replace_failed", "code": replace_error}
	return {"ok": true, "path": path, "backup_created": had_original}

static func read_json(path: String, allow_backup: bool = true) -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(path)
	var primary := _read_and_decode(absolute_path)
	if bool(primary.get("ok", false)):
		primary["recovered_from_backup"] = false
		return primary
	if allow_backup:
		var backup_path := absolute_path + ".bak"
		if FileAccess.file_exists(backup_path):
			var backup := _read_and_decode(backup_path)
			if bool(backup.get("ok", false)):
				backup["recovered_from_backup"] = true
				backup["primary_error"] = primary.get("error", "unknown")
				return backup
	return primary

static func _read_and_decode(absolute_path: String) -> Dictionary:
	if not FileAccess.file_exists(absolute_path):
		return {"ok": false, "error": "file_not_found"}
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "file_open_failed", "code": FileAccess.get_open_error()}
	var contents := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		return {"ok": false, "error": "file_read_failed", "code": read_error}
	return decode_document(contents)

static func _migrate_v1_to_v2(data: Dictionary) -> void:
	if not data.has("floors"):
		data["floors"] = []
	if not data.has("walls"):
		data["walls"] = []
	if not data.has("furniture"):
		data["furniture"] = []

static func _migrate_v2_to_v3(data: Dictionary) -> void:
	if not data.has("layers"):
		data["layers"] = DEFAULT_LAYER_VISIBILITY.duplicate(true)

static func _migrate_v3_to_v4(data: Dictionary) -> void:
	if not data.has("camera"):
		data["camera"] = {"yaw": 0.72, "pitch": -0.72, "distance": 17.0, "projection": 0}

static func _migrate_v4_to_v5(data: Dictionary) -> void:
	if not data.has("site"):
		data["site"] = {"enabled": false, "width_m": 20.0, "depth_m": 20.0}

static func _migrate_v5_to_v6(data: Dictionary) -> void:
	if not data.has("roof_style"):
		data["roof_style"] = 1

static func _migrate_v6_to_v7(data: Dictionary) -> void:
	if data.has("floors") and data.floors is Array:
		for floor_variant in data.floors:
			if floor_variant is Dictionary:
				if not floor_variant.has("visible"):
					floor_variant["visible"] = true
				if not floor_variant.has("floor_height_mm"):
					floor_variant["floor_height_mm"] = 2800.0
				if not floor_variant.has("slab_thickness_mm"):
					floor_variant["slab_thickness_mm"] = 220.0

static func _migrate_v7_to_v8(data: Dictionary) -> void:
	data["schema_version"] = CURRENT_SCHEMA_VERSION
	data["metadata"] = data.get("metadata", {})
	if not data.metadata is Dictionary:
		data["metadata"] = {}
	data.metadata["format"] = "dreamhouse3d"
	data.metadata["minimum_reader_version"] = CURRENT_SCHEMA_VERSION
	for field in ["roofs", "stairs", "engineering_networks", "dimensions", "materials", "custom_layers", "objects"]:
		if not data.has(field):
			data[field] = []
	if data.has("walls") and data.walls is Array:
		for wall_index in range(data.walls.size()):
			var wall_variant: Variant = data.walls[wall_index]
			if wall_variant is Dictionary:
				if not wall_variant.has("id"):
					wall_variant["id"] = "wall_%d" % wall_index
				if not wall_variant.has("locked"):
					wall_variant["locked"] = false
				if not wall_variant.has("visible"):
					wall_variant["visible"] = true
				if not wall_variant.has("layer_id"):
					wall_variant["layer_id"] = str(wall_variant.get("layer", "walls"))
	if data.has("floors") and data.floors is Array:
		for floor_index in range(data.floors.size()):
			var floor_variant: Variant = data.floors[floor_index]
			if floor_variant is Dictionary:
				if not floor_variant.has("id"):
					floor_variant["id"] = "floor_%d" % floor_index
				if not floor_variant.has("roofs"):
					floor_variant["roofs"] = []
				if not floor_variant.has("stairs"):
					floor_variant["stairs"] = []
				if not floor_variant.has("engineering_networks"):
					floor_variant["engineering_networks"] = []
