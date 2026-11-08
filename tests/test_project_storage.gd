extends SceneTree

const Storage = preload("res://scripts/storage/project_storage.gd")

func _initialize() -> void:
	_test_schema_migration()
	_test_stable_generated_ids()
	_test_round_trip()
	_test_backup_recovery()
	_test_invalid_documents()
	print("DreamHouse project storage tests passed")
	quit(0)

func _test_schema_migration() -> void:
	var legacy := {
		"version": 7,
		"current_floor": 0,
		"floors": [{"name": "Ground", "walls": [], "furniture": []}],
		"walls": [],
		"furniture": []
	}
	var migrated := Storage.migrate_document(legacy)
	assert(migrated.ok)
	assert(int(migrated.data.version) == Storage.CURRENT_SCHEMA_VERSION)
	assert(migrated.data.has("engineering_networks"))
	assert(migrated.data.has("custom_layers"))
	assert(migrated.data.metadata.format == "dreamhouse3d")
	assert(migrated.data.floors[0].has("id"))
	assert(legacy.version == 7)

func _test_stable_generated_ids() -> void:
	var legacy := {
		"version": 7,
		"floors": [{"name": "Ground"}],
		"walls": [
			{"a": [0.0, 0.0], "b": [100.0, 0.0]},
			{"a": [100.0, 0.0], "b": [100.0, 100.0]}
		],
		"furniture": []
	}
	var first := Storage.migrate_document(legacy)
	var second := Storage.migrate_document(legacy)
	assert(first.ok and second.ok)
	assert(first.data.walls[0].id == "wall_0")
	assert(first.data.walls[1].id == "wall_1")
	assert(first.data.floors[0].id == "floor_0")
	assert(first.data.walls[0].id == second.data.walls[0].id)


func _test_round_trip() -> void:
	var source := {
		"version": 8,
		"current_floor": 0,
		"floors": [{"id": "floor_a", "name": "Ground", "walls": [], "furniture": []}],
		"walls": [{"a": [0.0, 0.0], "b": [100.0, 0.0], "layer": "walls"}],
		"furniture": [],
		"custom_layers": [{"id": "finish", "name": "Finishes"}]
	}
	var encoded := Storage.encode_document(source)
	assert(encoded.ok)
	var decoded := Storage.decode_document(encoded.text)
	assert(decoded.ok)
	assert(decoded.data.walls.size() == 1)
	assert(decoded.data.custom_layers[0].id == "finish")

func _test_backup_recovery() -> void:
	var path := "user://project_storage_test.json"
	var first := {"version": 8, "floors": [], "walls": [], "furniture": [], "marker": "first"}
	var second := {"version": 8, "floors": [], "walls": [], "furniture": [], "marker": "second"}
	var first_write := Storage.write_json_atomic(path, first)
	assert(first_write.ok)
	var second_write := Storage.write_json_atomic(path, second)
	assert(second_write.ok)
	assert(second_write.backup_created)
	var primary := Storage.read_json(path, false)
	assert(primary.ok)
	assert(primary.data.marker == "second")
	var absolute_path := ProjectSettings.globalize_path(path)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	assert(file != null)
	file.store_string("{ broken json")
	file.close()
	var recovered := Storage.read_json(path, true)
	assert(recovered.ok)
	assert(recovered.recovered_from_backup)
	assert(recovered.data.marker == "first")
	DirAccess.remove_absolute(absolute_path)
	DirAccess.remove_absolute(absolute_path + ".bak")

func _test_invalid_documents() -> void:
	var invalid_root := Storage.decode_document("[1, 2, 3]")
	assert(not invalid_root.ok)
	var invalid_array := Storage.migrate_document({"version": 8, "floors": "wrong", "walls": []})
	assert(not invalid_array.ok)
	var future := Storage.migrate_document({"version": 999, "floors": [], "walls": []})
	assert(not future.ok)
