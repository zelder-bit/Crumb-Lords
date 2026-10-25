class_name Player
extends CharacterBody3D
## First-person controller for a playable household object. Class-specific
## behaviour (stats, body, movement trick, passive, super) lives in a PlayerClass.

signal health_changed(current: float, maximum: float)
signal super_changed(fraction: float)
signal weapons_changed
signal died

const GRAVITY := 30.0
const GROUND_ACCEL := 90.0
const AIR_ACCEL := 32.0
const MOUSE_SENS := 0.0022
const FALL_DEATH_Y := -15.0
## Render layer for first-person viewmodels (weapons, door frame). Drawn in a
## separate overlay pass so enemies and walls never clip through them.
const VIEWMODEL_LAYER := 1 << 1
## Parts of your own body your first-person camera shouldn't see (e.g. the door's eyes).
const SELF_HIDDEN_LAYER := 1 << 2

var pclass: PlayerClass
var health := 100.0
var super_charge := 0.0
var weapons: Array = [null, null]
var head: Node3D
var camera: Camera3D
var body: Node3D
var weapon_mount: Node3D
var viewmodel_camera: Camera3D
var shield_active := false
var look_delta := Vector2.ZERO
var cam_roll := 0.0
var shake := 0.0

var _dead := false
var _was_on_floor := true
var _knock_time := 0.0
var _bob_time := 0.0
var _land_dip := 0.0


func _init(p_class: PlayerClass = null) -> void:
	pclass = p_class if p_class else DoorClass.new()


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.3

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 2.0
	shape.shape = capsule
	shape.position.y = 1.0
	add_child(shape)

	body = Node3D.new()
	body.name = "Body"
	add_child(body)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = pclass.camera_height
	add_child(head)

	camera = Camera3D.new()
	camera.fov = 90.0
	camera.near = 0.03
	camera.current = true
	head.add_child(camera)

	weapon_mount = Node3D.new()
	weapon_mount.name = "WeaponMount"
	camera.add_child(weapon_mount)
	_build_viewmodel_pass()

	health = pclass.max_health
	pclass.setup(self)
	set_viewmodel_layer(weapon_mount)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_viewmodel_pass() -> void:
	camera.cull_mask &= ~(VIEWMODEL_LAYER | SELF_HIDDEN_LAYER)
	var overlay := CanvasLayer.new()
	overlay.layer = 1
	add_child(overlay)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(container)
	container.size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(func(): container.size = get_viewport().get_visible_rect().size)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	container.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.87, 0.95)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	viewmodel_camera = Camera3D.new()
	viewmodel_camera.cull_mask = VIEWMODEL_LAYER
	viewmodel_camera.environment = env
	viewmodel_camera.near = 0.01
	vp.add_child(viewmodel_camera)


## Moves every visual under node onto the viewmodel render layer.
func set_viewmodel_layer(node: Node) -> void:
	if node is VisualInstance3D:
		node.layers = VIEWMODEL_LAYER
	for child in node.get_children():
		set_viewmodel_layer(child)


func is_dead() -> bool:
	return _dead


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * MOUSE_SENS, -1.5, 1.5)
		look_delta += event.relative
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if not GameState.level_done:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("restart"):
		GameState.restart_level()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if _dead:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		move_and_slide()
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	if input != Vector2.ZERO or Input.is_action_just_pressed("jump"):
		GameState.start_timer()

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = pclass.jump_velocity
			Sfx.play("hop", -4.0)
		else:
			pclass.on_jump_pressed(self)

	var on_floor := is_on_floor()
	var accel := GROUND_ACCEL if on_floor and _knock_time <= 0.0 else AIR_ACCEL
	_knock_time -= delta
	if on_floor or wish != Vector3.ZERO:
		var hv := Vector2(velocity.x, velocity.z)
		var target := Vector2(wish.x, wish.z) * pclass.move_speed
		# In the air, only accelerate toward the wish direction; keep momentum otherwise.
		if not on_floor and hv.length() > pclass.move_speed and hv.dot(target) > 0.0:
			target = target.normalized() * hv.length()
		hv = hv.move_toward(target, accel * delta)
		velocity.x = hv.x
		velocity.z = hv.y

	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		_land_dip = 0.12
		Sfx.play("land", -8.0)
		pclass.on_landed(self)
	_was_on_floor = is_on_floor()

	pclass.physics_tick(self, delta)

	for hand in 2:
		var w: Weapon = weapons[hand]
		if w == null:
			continue
		if Input.is_action_pressed("fire_left" if hand == 0 else "fire_right") \
				and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			w.trigger()
		if Input.is_action_just_pressed("reload"):
			w.request_reload()

	if Input.is_action_just_pressed("super") and super_charge >= 1.0:
		super_charge = 0.0
		super_changed.emit(0.0)
		pclass.activate_super(self)

	if global_position.y < FALL_DEATH_Y:
		die()


func _process(delta: float) -> void:
	# Hoppy camera bob: abs(sin) so every step is a little bounce, like a hopping door.
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var bob := 0.0
	if is_on_floor() and hspeed > 1.0 and not _dead:
		_bob_time += delta * hspeed * 0.75
		bob = absf(sin(_bob_time)) * 0.11
	else:
		_bob_time = 0.0
	_land_dip = move_toward(_land_dip, 0.0, delta * 0.8)
	if not _dead:
		head.position.y = lerpf(head.position.y, pclass.camera_height + bob - _land_dip, 1.0 - exp(-delta * 18.0))
		body.position.y = bob * 0.8

	var strafe := -Input.get_axis("move_left", "move_right") * 0.03
	cam_roll = lerpf(cam_roll, 0.0, 1.0 - exp(-delta * 6.0))
	if not _dead:
		camera.rotation.z = lerpf(camera.rotation.z, strafe + cam_roll, 1.0 - exp(-delta * 10.0))

	shake = move_toward(shake, 0.0, delta * 2.5)
	camera.h_offset = randf_range(-1.0, 1.0) * shake * 0.08
	camera.v_offset = randf_range(-1.0, 1.0) * shake * 0.08
	viewmodel_camera.global_transform = camera.global_transform
	viewmodel_camera.fov = camera.fov
	viewmodel_camera.h_offset = camera.h_offset
	viewmodel_camera.v_offset = camera.v_offset

	for w in weapons:
		if w:
			w.sway_input(look_delta)
	look_delta = Vector2.ZERO


func give_weapon(hand: int, weapon: Weapon) -> void:
	if weapons[hand]:
		weapons[hand].queue_free()
	weapons[hand] = weapon
	weapon.setup(self, hand)
	weapon_mount.add_child(weapon)
	set_viewmodel_layer(weapon)
	weapons_changed.emit()


func take_damage(amount: float, from_pos: Vector3) -> void:
	if _dead or GameState.level_done:
		return
	amount = pclass.modify_incoming_damage(self, amount, from_pos)
	if amount <= 0.0:
		Sfx.play("boss_hit", -10.0)
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, pclass.max_health)
	shake = minf(shake + amount / 25.0, 1.0)
	Sfx.play("hurt")
	if health <= 0.0:
		die()


func apply_knockback(impulse: Vector3) -> void:
	velocity += impulse
	_knock_time = 0.35


func add_super(amount: float) -> void:
	var was_ready := super_charge >= 1.0
	super_charge = clampf(super_charge + amount, 0.0, 1.0)
	super_changed.emit(super_charge)
	if super_charge >= 1.0 and not was_ready:
		Sfx.play("checkpoint", -6.0)


func on_dealt_damage(amount: float) -> void:
	add_super(amount / 600.0)


func on_enemy_killed(_enemy: Node) -> void:
	add_super(0.07)


func die() -> void:
	if _dead:
		return
	_dead = true
	died.emit()
	Sfx.play("death")
	# Death cam: the object tips over.
	var tw := create_tween().set_parallel()
	tw.tween_property(head, "position:y", 0.35, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(camera, "rotation:z", 1.3, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.9).timeout.connect(GameState.on_player_died)
