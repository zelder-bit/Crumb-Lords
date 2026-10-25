class_name Hud
extends CanvasLayer
## Timer, health, super meter, per-hand ammo, boss bar, announcements and results.

const MEDAL_COLORS := {
	"gold": Color(1.0, 0.82, 0.2), "silver": Color(0.8, 0.85, 0.92),
	"bronze": Color(0.85, 0.55, 0.3), "none": Color(0.7, 0.7, 0.7),
}

var player: Player
var _timer_label: Label
var _health_bar: ProgressBar
var _health_label: Label
var _super_bar: ProgressBar
var _super_label: Label
var _ammo_labels: Array[Label] = []
var _message: Label
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _boss_label: Label
var _hurt_flash: ColorRect
var _pause_label: Label
var _results: PanelContainer
var _results_shown := false
var _msg_tween: Tween


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Size the root explicitly; anchors alone don't pick up the viewport under a CanvasLayer.
	root.size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(func(): root.size = get_viewport().get_visible_rect().size)

	_hurt_flash = ColorRect.new()
	_hurt_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt_flash.color = Color(1, 0.1, 0.1, 0.0)
	_hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hurt_flash)

	var crosshair := _label(root, "+", 32)
	_place(crosshair, Control.PRESET_CENTER, Vector2(-9, -24))

	_timer_label = _label(root, "00:00.00", 40)
	_place(_timer_label, Control.PRESET_CENTER_TOP, Vector2(-90, 12))

	_message = _label(root, "", 34)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.size = Vector2(900, 60)
	_place(_message, Control.PRESET_CENTER, Vector2(-450, -160))
	_message.modulate.a = 0.0

	_pause_label = _label(root, "Click to play  ·  WASD move · Space jump (x2) · LMB/RMB fire · R reload · Q super · Backspace restart", 20)
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.size = Vector2(1200, 40)
	_place(_pause_label, Control.PRESET_CENTER, Vector2(-600, 60))

	# Bottom-left: health and super.
	var stats := VBoxContainer.new()
	_place(stats, Control.PRESET_BOTTOM_LEFT, Vector2(24, -130))
	stats.custom_minimum_size = Vector2(320, 0)
	root.add_child(stats)
	_health_label = _label(stats, "DOOR  150", 22)
	_health_bar = _bar(stats, Color(0.95, 0.3, 0.3))
	_super_label = _label(stats, "SUPER", 18)
	_super_bar = _bar(stats, Color(1.0, 0.65, 0.2))
	_super_bar.value = 0.0

	# Bottom corners: ammo for each hand, positioned near its floating weapon.
	for hand in 2:
		var l := _label(root, "", 22)
		l.size = Vector2(380, 30)
		if hand == 0:
			_place(l, Control.PRESET_BOTTOM_LEFT, Vector2(380, -50))
		else:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_place(l, Control.PRESET_BOTTOM_RIGHT, Vector2(-404, -50))
		_ammo_labels.append(l)

	_boss_box = VBoxContainer.new()
	_place(_boss_box, Control.PRESET_CENTER_TOP, Vector2(-300, 70))
	_boss_box.custom_minimum_size = Vector2(600, 0)
	_boss_box.visible = false
	root.add_child(_boss_box)
	_boss_label = _label(_boss_box, "THE DUST BUNNY KING", 22)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_bar = _bar(_boss_box, Color(0.7, 0.55, 1.0))

	GameState.level_completed.connect(_on_level_completed)


func bind_player(p: Player) -> void:
	player = p
	p.health_changed.connect(_on_health_changed)
	p.super_changed.connect(_on_super_changed)
	_health_bar.max_value = p.pclass.max_health
	_health_bar.value = p.health
	_on_health_changed(p.health, p.pclass.max_health)
	_on_super_changed(p.super_charge)


func bind_boss(boss: Node) -> void:
	_boss_box.visible = true
	_boss_bar.max_value = boss.max_health
	_boss_bar.value = boss.health
	boss.health_changed.connect(func(current: float, maximum: float):
		_boss_bar.max_value = maximum
		_boss_bar.value = current)
	boss.died.connect(func(_b): _boss_box.visible = false)


func show_message(text: String, duration := 2.0, color := Color.WHITE) -> void:
	_message.text = text
	_message.modulate = Color(color, 1.0)
	_message.scale = Vector2(1.15, 1.15)
	if _msg_tween:
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_property(_message, "scale", Vector2.ONE, 0.15)
	_msg_tween.tween_interval(duration)
	_msg_tween.tween_property(_message, "modulate:a", 0.0, 0.4)


func _process(_delta: float) -> void:
	_timer_label.text = GameState.format_time(GameState.elapsed)
	_pause_label.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _results_shown
	_hurt_flash.color.a = move_toward(_hurt_flash.color.a, 0.0, _delta * 1.5)
	if player:
		for hand in 2:
			var w: Weapon = player.weapons[hand]
			var key := "LMB" if hand == 0 else "RMB"
			_ammo_labels[hand].text = "[%s] %s" % [key, w.status_text()] if w else "[%s] — empty hand —" % key


func _unhandled_input(event: InputEvent) -> void:
	if _results_shown and event.is_action_pressed("confirm"):
		GameState.restart_level()


func _on_health_changed(current: float, maximum: float) -> void:
	if current < _health_bar.value:
		_hurt_flash.color.a = 0.35
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "%s  %d" % [player.pclass.display_name.to_upper() if player else "", ceili(current)]


func _on_super_changed(fraction: float) -> void:
	_super_bar.value = fraction * 100.0
	var sname := player.pclass.super_name.to_upper() if player else "SUPER"
	_super_label.text = "%s  READY [Q]" % sname if fraction >= 1.0 else sname


func _on_level_completed(time: float, medal: String, best: float, is_pb: bool) -> void:
	_results_shown = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_results = PanelContainer.new()
	_results.custom_minimum_size = Vector2(520, 340)
	_place(_results, Control.PRESET_CENTER, Vector2(-260, -170))
	get_child(0).add_child(_results)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	_results.add_child(box)
	for line in [
		["KITCHEN COUNTER CLEARED!", 34, Color.WHITE],
		["TIME  " + GameState.format_time(time), 30, Color.WHITE],
		[("%s MEDAL" % medal.to_upper()) if medal != "none" else "NO MEDAL", 30, MEDAL_COLORS[medal]],
		[("NEW PERSONAL BEST!" if is_pb else "BEST  " + GameState.format_time(best)), 22, Color(0.6, 1.0, 0.6) if is_pb else Color.WHITE],
		["Deaths: %d" % GameState.deaths, 20, Color(0.85, 0.85, 0.85)],
		["[Enter] play again", 20, Color(0.85, 0.85, 0.85)],
	]:
		var l := _label(box, line[0], line[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate = line[2]
	_results.scale = Vector2(0.6, 0.6)
	_results.pivot_offset = _results.custom_minimum_size / 2.0
	create_tween().tween_property(_results, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Anchors c to a preset point of its parent and offsets it from that point.
func _place(c: Control, preset: Control.LayoutPreset, offset: Vector2) -> void:
	c.set_anchors_preset(preset)
	var parent_size: Vector2 = c.get_parent().size if c.get_parent() is Control else Vector2.ZERO  # not in tree yet: offsets apply once added
	c.position = Vector2(c.anchor_left * parent_size.x, c.anchor_top * parent_size.y) + offset


func _label(parent: Control, text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _bar(parent: Control, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(0, 18)
	b.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.08, 0.15, 0.7)
	bg.set_corner_radius_all(6)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	parent.add_child(b)
	return b
