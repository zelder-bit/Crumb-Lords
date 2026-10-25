class_name Weapon
extends Node3D
## A floating household-item weapon. Hierarchy:
##   Weapon (sway + rest position) -> model (spring recoil, idle float) -> anim (tweened fire/reload) -> parts
## Subclasses build parts under `anim` and implement _fire() and _play_reload().

var weapon_name := "Weapon"
var damage := 10.0
var fire_interval := 0.2
var max_range := 250.0
var spread := 0.0
var clip: AmmoClip
var player: Player
var hand := 0
var display_only := false  # for pickups: no sway, no firing
var model: Node3D
var anim: Node3D
var muzzle: Node3D

var _cooldown := 0.0
var _time := 0.0
var _phase := 0.0
var _rest_pos := Vector3.ZERO
var _sway := Vector2.ZERO
var _sway_target := Vector2.ZERO
var _kick_pos := Vector3.ZERO
var _kick_pos_vel := Vector3.ZERO
var _kick_rot := Vector3.ZERO
var _kick_rot_vel := Vector3.ZERO


func _ready() -> void:
	model = Node3D.new()
	add_child(model)
	anim = Node3D.new()
	model.add_child(anim)
	muzzle = Node3D.new()
	_build_model()
	var mist_color := player.pclass.mist_color if player else Color(1.0, 0.85, 0.5)
	Fx.mist(model, mist_color)


func setup(p: Player, p_hand: int) -> void:
	player = p
	hand = p_hand
	_phase = hand * 2.1
	_rest_pos = Vector3(-0.3 if hand == 0 else 0.3, -0.26, -0.55)
	position = _rest_pos


func sway_input(look_delta: Vector2) -> void:
	_sway_target = -look_delta * 0.0008


func side() -> float:
	return -1.0 if hand == 0 else 1.0


func trigger() -> void:
	if display_only or _cooldown > 0.0 or clip.reloading:
		return
	if not clip.consume():
		Sfx.play("empty_click", -6.0)
		_cooldown = 0.3
		request_reload()
		return
	_cooldown = fire_interval
	_fire()
	if clip.ammo == 0:
		request_reload()


func request_reload() -> void:
	if clip.start_reload():
		_play_reload(clip.reload_time)


func status_text() -> String:
	if clip.reloading:
		return "%s  RELOADING" % weapon_name
	return "%s  %d/%d" % [weapon_name, clip.ammo, clip.mag_size]


func kick(pos: Vector3, rot: Vector3) -> void:
	_kick_pos_vel += pos * 60.0
	_kick_rot_vel += rot * 60.0


func _process(delta: float) -> void:
	_time += delta
	if display_only:
		return
	_cooldown -= delta
	if clip.tick(delta):
		_on_reload_finished()

	# Critically-damped-ish springs pull the recoil back to rest.
	var k := 220.0
	var d := 20.0
	_kick_pos_vel += (-k * _kick_pos - d * _kick_pos_vel) * delta
	_kick_pos += _kick_pos_vel * delta
	_kick_rot_vel += (-k * _kick_rot - d * _kick_rot_vel) * delta
	_kick_rot += _kick_rot_vel * delta

	_sway = _sway.lerp(_sway_target, 1.0 - exp(-delta * 8.0))
	_sway_target = _sway_target.lerp(Vector2.ZERO, 1.0 - exp(-delta * 10.0))

	# Each hand floats on its own rhythm, out of sync with the other.
	var float_offset := Vector3(sin(_time * 1.3 + _phase) * 0.008, sin(_time * 1.9 + _phase) * 0.014, 0.0)
	var walk := 0.0
	if player and player.is_on_floor():
		walk = minf(Vector2(player.velocity.x, player.velocity.z).length() / 10.0, 1.0)
	float_offset.y += absf(sin(_time * 9.0 + _phase)) * 0.02 * walk

	position = _rest_pos + Vector3(_sway.x, -_sway.y, 0.0) * 0.6
	model.position = float_offset + _kick_pos
	model.rotation = _kick_rot + Vector3(_sway.y, _sway.x, -_sway.x * 0.5)


## Hitscan from the camera centre. Returns the world position that was hit (or max range).
func hitscan(p_spread: float) -> Vector3:
	var cam := player.camera
	var from := cam.global_position
	var dir := -cam.global_basis.z
	dir += cam.global_basis.x * randf_range(-p_spread, p_spread) + cam.global_basis.y * randf_range(-p_spread, p_spread)
	var to := from + dir.normalized() * max_range
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return to
	var collider: Object = hit.collider
	if collider and collider.has_method("take_damage"):
		# The enemy credits the attacker (super charge) itself.
		collider.take_damage(damage, player.global_position, player)
	_on_hit(hit.position, collider)
	return hit.position


func fx_parent() -> Node:
	return get_tree().current_scene


func _build_model() -> void:
	pass


func _fire() -> void:
	pass


func _play_reload(_duration: float) -> void:
	pass


func _on_reload_finished() -> void:
	pass


func _on_hit(_pos: Vector3, _collider: Object) -> void:
	pass


static func mat(color: Color, roughness := 0.5, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


## A cylinder lying along the Z axis.
static func z_cylinder(parent: Node3D, radius: float, length: float, z: float, material: Material) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 12
	c.material = material
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.rotation.x = PI / 2.0
	mi.position.z = z
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	b.material = material
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
