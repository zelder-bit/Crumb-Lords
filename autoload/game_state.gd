extends Node
## Run timer, checkpoint/restart rules, medals and personal bests.
##
## Death rules: before the checkpoint (the second-weapon pickup), death is an
## instant full restart and the timer resets. After it, you respawn at the
## checkpoint and the timer keeps running.

signal timer_started
signal checkpoint_changed(reached: bool)
signal level_completed(time: float, medal: String, best: float, is_pb: bool)

const SAVE_PATH := "user://save.cfg"
## Upper time limits (seconds) for each medal tier.
const MEDAL_TIMES := {"gold": 90.0, "silver": 135.0, "bronze": 200.0}

var elapsed := 0.0
var timer_running := false
var checkpoint_reached := false
var level_done := false
var deaths := 0


func _enter_tree() -> void:
	_setup_input()


func _process(delta: float) -> void:
	if timer_running:
		elapsed += delta


func start_timer() -> void:
	if timer_running or level_done:
		return
	timer_running = true
	timer_started.emit()


func reach_checkpoint() -> void:
	if checkpoint_reached:
		return
	checkpoint_reached = true
	checkpoint_changed.emit(true)


## What should happen when the player dies: "checkpoint" or "restart".
static func death_outcome(has_checkpoint: bool) -> String:
	return "checkpoint" if has_checkpoint else "restart"


func on_player_died() -> void:
	deaths += 1
	if death_outcome(checkpoint_reached) == "checkpoint":
		get_tree().reload_current_scene.call_deferred()
	else:
		restart_level()


func restart_level() -> void:
	reset_run()
	get_tree().reload_current_scene.call_deferred()


func reset_run() -> void:
	elapsed = 0.0
	timer_running = false
	checkpoint_reached = false
	level_done = false
	deaths = 0


static func medal_for(time: float) -> String:
	for medal in ["gold", "silver", "bronze"]:
		if time <= MEDAL_TIMES[medal]:
			return medal
	return "none"


static func format_time(t: float) -> String:
	var minutes := int(t) / 60
	var seconds := fmod(t, 60.0)
	return "%02d:%05.2f" % [minutes, seconds]


func complete_level(level_id: String) -> void:
	if level_done:
		return
	timer_running = false
	level_done = true
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var best: float = cfg.get_value("best_times", level_id, -1.0)
	var is_pb := best < 0.0 or elapsed < best
	if is_pb:
		best = elapsed
		cfg.set_value("best_times", level_id, best)
		cfg.save(SAVE_PATH)
	level_completed.emit(elapsed, medal_for(elapsed), best, is_pb)


func _setup_input() -> void:
	var keys := {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"jump": KEY_SPACE, "reload": KEY_R, "super": KEY_Q, "restart": KEY_BACKSPACE,
		"confirm": KEY_ENTER, "pause": KEY_ESCAPE,
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		InputMap.action_add_event(action, ev)
	var buttons := {"fire_left": MOUSE_BUTTON_LEFT, "fire_right": MOUSE_BUTTON_RIGHT}
	for action in buttons:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = buttons[action]
		InputMap.action_add_event(action, mb)
