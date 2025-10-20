extends Node
class_name EnvLoader
var env := {}

func _ready():
	load_env()

func load_env(path: String = "res://.env") -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning(".env file not found at %s" % path)
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var parts := line.split("=", false, 2)
		if parts.size() == 2:
			env[parts[0].strip_edges()] = parts[1].strip_edges()
	file.close()

func get_var(key: String, default_value: String = "") -> String:
	return env.get(key, default_value)
