class_name Enemy
extends CharacterBody3D

signal died(enemy: Enemy)

var max_health: float = 40.0
var health: float = 40.0
var model: Node3D
var _last_attacker: Node
var _dead: bool = false
var _scale_tween: Tween
var _flash_tween: Tween
var _materials: Array[StandardMaterial3D] = []
var _eyes: Array[Node3D] = []
var _ears: Array[Node3D] = []
var _animation_time: float = 0.0
var _blob_shadow: MeshInstance3D
var _shadow_size: float = 1.0

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	health = max_health
	model = Node3D.new()
	model.name = "model"
	add_child(model)
	_build_model()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if global_position.y < -20.0:
		_die()
		return
	_ai(delta)
	velocity.y -= 30.0 * delta
	move_and_slide()
	_update_blob_shadow()
	_animation_time += delta
	for i in _eyes.size():
		_eyes[i].rotation.z = sin(_animation_time * 17.0 + i * 2.0) * minf(velocity.length() * 0.025, 0.22)
	for i in _ears.size():
		_ears[i].rotation.x = sin(_animation_time * 10.0 + i) * 0.16 + clampf(-velocity.y * 0.035, -0.4, 0.4)

func _build_model() -> void:
	pass

func _ai(_delta: float) -> void:
	pass

func _on_damaged() -> void:
	_sound("bunny_hit")

func take_damage(amount: float, _from_pos: Vector3, attacker: Node = null) -> void:
	if _dead or amount <= 0.0:
		return
	if is_instance_valid(attacker):
		_last_attacker = attacker
	var dealt: float = minf(amount, health)
	health = maxf(0.0, health - amount)
	if is_instance_valid(attacker) and attacker.has_method("on_dealt_damage"):
		attacker.call("on_dealt_damage", dealt)
	_on_damaged()
	if health <= 0.0:
		_die()
	else:
		_punch(Vector3(1.2, 0.75, 1.2), 0.06)
		if _flash_tween and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash_tween = create_tween().set_parallel(true)
		for material in _materials:
			material.emission_enabled = true
			material.emission = Color.WHITE
			material.emission_energy_multiplier = 1.8
			_flash_tween.tween_property(material, "emission_energy_multiplier", 0.0, 0.14)

func apply_knockback(impulse: Vector3) -> void:
	if not _dead:
		velocity += impulse

func _die() -> void:
	if _dead:
		return
	_dead = true
	health = 0.0
	remove_from_group("enemies")
	if is_instance_valid(_last_attacker) and _last_attacker.has_method("on_enemy_killed"):
		_last_attacker.call("on_enemy_killed", self)
	died.emit(self)
	_dust_puff()
	_sound("bunny_die")
	queue_free()

func _player() -> Node3D:
	var target := get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(target):
		return null
	if target.has_method("is_dead") and target.call("is_dead"):
		return null
	return target

func _toward(target: Node3D) -> Vector3:
	var direction := target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)
	return direction.normalized()

func _sound(sound_name: String, volume: float = 0.0) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if is_instance_valid(sfx) and sfx.has_method("play_at"):
		sfx.call("play_at", sound_name, global_position, volume)

func _punch(stretch: Vector3, duration: float) -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(model, "scale", stretch, duration)
	_scale_tween.tween_property(model, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	_materials.append(material)
	return material

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance

func _sphere(radius: float) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	return sphere

# Feet are at the body origin; only this visual subtree is enlarged for the boss.
func _build_bunny(size: float) -> Node3D:
	var body := Node3D.new()
	model.add_child(body)
	body.scale = Vector3.ONE * size
	var fur := _material(Color("6b4fc4"))
	var dark_fur := _material(Color("4a3590"))
	var pink := _material(Color("ff8fbd"))
	var white := _material(Color.WHITE)
	var black := _material(Color.BLACK)
	var body_sphere := _sphere(0.45)
	_mesh(body, body_sphere, Vector3(0, 0.45, 0), fur)
	# One extra draw for the main body's rim; lumps and facial parts stay crisp.
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color("e5d8ff")
	rim.cull_mode = BaseMaterial3D.CULL_FRONT
	rim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim.emission_enabled = true
	rim.emission = Color("e5d8ff")
	rim.emission_energy_multiplier = 0.3
	var shell := _mesh(body, body_sphere, Vector3(0, 0.45, 0), rim)
	shell.scale = Vector3.ONE * 1.06
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 10:
		var angle := TAU * float(i) / 10.0
		_mesh(body, _sphere(0.17), Vector3(cos(angle) * 0.32, 0.30 + float(i % 3) * 0.18, sin(angle) * 0.32), dark_fur)
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		body.add_child(eye)
		eye.position = Vector3(side * 0.19, 0.63, -0.36)
		_mesh(eye, _sphere(0.18), Vector3.ZERO, white)
		_mesh(eye, _sphere(0.085), Vector3(0.025 * side, 0.015, -0.145), black)
		_eyes.append(eye)
		var ear := Node3D.new()
		body.add_child(ear)
		ear.position = Vector3(side * 0.23, 0.83, 0.02)
		ear.rotation.z = -side * 0.3
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.105
		capsule.height = 0.6
		capsule.radial_segments = 8
		capsule.rings = 3
		_mesh(ear, capsule, Vector3(0, 0.22, 0), fur)
		var inner := _mesh(ear, capsule, Vector3(0, 0.22, -0.085), pink)
		inner.scale = Vector3(0.55, 0.75, 0.3)
		_ears.append(ear)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = size * 0.5
	shape.shape = sphere
	shape.position.y = sphere.radius
	add_child(shape)
	_build_blob_shadow(size)
	return body

func _build_blob_shadow(size: float) -> void:
	_shadow_size = size
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.45))
	gradient.set_color(1, Color(0, 0, 0, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 1.4 * size
	_blob_shadow = _mesh(self, quad, Vector3.ZERO, material)
	_blob_shadow.top_level = true
	_blob_shadow.rotation.x = -PI / 2.0
	_blob_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blob_shadow.visible = false

func _update_blob_shadow() -> void:
	if not is_instance_valid(_blob_shadow):
		return
	# Start just above the feet so a resting body still finds the floor.
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.05,
		global_position + Vector3.DOWN * 30.0, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_blob_shadow.visible = not hit.is_empty()
	if hit.is_empty():
		return
	var point: Vector3 = hit["position"]
	_blob_shadow.global_position = point + Vector3.UP * 0.02
	var height := maxf(global_position.y - point.y, 0.0)
	var shrink := 1.0 / (1.0 + height / _shadow_size * 0.6)
	_blob_shadow.scale = Vector3.ONE * shrink

func _dust_puff() -> void:
	var puff := CPUParticles3D.new()
	puff.emitting = false
	puff.one_shot = true
	puff.amount = 24
	puff.lifetime = 0.85
	puff.explosiveness = 1.0
	puff.direction = Vector3.UP
	puff.spread = 180.0
	puff.initial_velocity_min = 1.0
	puff.initial_velocity_max = 3.0
	puff.gravity = Vector3(0, -1.5, 0)
	puff.scale_amount_min = 0.15
	puff.scale_amount_max = 0.4
	var quad := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	quad.material = material
	puff.mesh = quad
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.68, 0.63, 0.76, 0.9))
	gradient.set_color(1, Color(0.68, 0.63, 0.76, 0.0))
	puff.color_ramp = gradient
	get_parent().add_child(puff)
	puff.global_position = global_position + Vector3.UP * 0.5
	puff.emitting = true
	# Bind lifetime to the effect, since this enemy is freed immediately.
	puff.create_tween().tween_callback(puff.queue_free).set_delay(1.5)
