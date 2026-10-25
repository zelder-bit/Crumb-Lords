extends Node
## Opt-in screenshot automation. Normal game sessions have no processing cost.

var _path := ""
var _frames := 90
var _frame := 0
var _position := Vector3.ZERO
var _has_position := false
var _yaw := 0.0
var _has_yaw := false
var _pitch := 0.0
var _has_pitch := false
var _fire := false
var _pressed := false
var _posed := false


func _ready() -> void:
	set_process(false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_path = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--shot-frames="):
			_frames = maxi(1, arg.trim_prefix("--shot-frames=").to_int())
		elif arg.begins_with("--shot-pos="):
			var parts := arg.trim_prefix("--shot-pos=").split(",")
			if parts.size() == 3:
				_position = Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
				_has_position = true
		elif arg.begins_with("--shot-yaw="):
			_yaw = deg_to_rad(arg.trim_prefix("--shot-yaw=").to_float())
			_has_yaw = true
		elif arg.begins_with("--shot-pitch="):
			_pitch = deg_to_rad(arg.trim_prefix("--shot-pitch=").to_float())
			_has_pitch = true
		elif arg == "--shot-fire":
			_fire = true
	if _path.is_empty():
		return
	if not _path.is_absolute_path():
		_path = ProjectSettings.globalize_path("res://").path_join(_path)
	else:
		_path = ProjectSettings.globalize_path(_path)
	set_process(true)


func _process(_delta: float) -> void:
	_frame += 1
	if not _posed:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player != null:
			if _has_position:
				player.global_position = _position
				player.set("velocity", Vector3.ZERO)
			if _has_yaw:
				player.rotation.y = _yaw
			if _has_pitch:
				var head := player.get("head") as Node3D
				if head != null:
					head.rotation.x = _pitch
			_posed = true
	if _fire and not _pressed and _frame >= maxi(1, _frames - 8):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.action_press("fire_left")
		Input.action_press("fire_right")
		_pressed = true
	if _frame >= _frames:
		set_process(false)
		_capture()


func _capture() -> void:
	# Let the final pose and weapon state reach the rendered viewport.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if _pressed:
		Input.action_release("fire_left")
		Input.action_release("fire_right")
	var error := DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	if error == OK:
		error = image.save_png(_path)
	if error != OK:
		push_error("Screenshot: cannot save '%s' (error %s)" % [_path, error])
		get_tree().quit(1)
		return
	print("SCREENSHOT_SAVED %s" % _path)
	get_tree().quit()
