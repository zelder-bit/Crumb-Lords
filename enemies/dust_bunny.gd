class_name DustBunny
extends Enemy

var _hop_cooldown: float = 0.0
var _attack_cooldown: float = 0.0
var _windup: float = 0.0
var _stuck: float = 0.0

func _build_model() -> void:
	_build_bunny(1.0)
	_hop_cooldown = randf_range(0.05, 0.4)

func _ai(delta: float) -> void:
	_hop_cooldown -= delta
	_attack_cooldown -= delta
	var target := _player()
	if not is_instance_valid(target):
		return
	var direction := _toward(target)
	if Vector2(get_real_velocity().x, get_real_velocity().z).length() < 0.5 and direction.length_squared() > 0.1:
		_stuck += delta
	else:
		_stuck = 0.0
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0 and is_on_floor():
			velocity.x = direction.x * 8.0
			velocity.z = direction.z * 8.0
			velocity.y = 10.5 if _stuck > 0.25 else 7.0
			_hop_cooldown = randf_range(0.35, 0.6)
			_punch(Vector3(0.8, 1.3, 0.8), 0.06)
			_sound("bunny_hop", -12.0)
	elif is_on_floor() and _hop_cooldown <= 0.0:
		_windup = 0.08
		_punch(Vector3(1.18, 0.72, 1.18), 0.08)
	elif not is_on_floor():
		velocity.x = move_toward(velocity.x, direction.x * 8.0, delta * 2.0)
		velocity.z = move_toward(velocity.z, direction.z * 8.0, delta * 2.0)
	if global_position.distance_to(target.global_position) < 1.3 and _attack_cooldown <= 0.0:
		if target.has_method("take_damage"):
			target.call("take_damage", 10.0, global_position)
			_attack_cooldown = 0.8
			apply_knockback(-direction * 3.0 + Vector3.UP * 2.0)
