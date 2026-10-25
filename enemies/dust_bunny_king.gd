class_name DustBunnyKing
extends Enemy

signal health_changed(current: float, max: float)

enum State { CHASE, SLAM, SUMMON }
var state: State = State.CHASE
var _slam_timer: float = 6.0
var _summon_timer: float = 9.0
var _hop_timer: float = 0.0
var _attack_timer: float = 0.0
var _telegraph: float = 0.0
var _slam_airborne: bool = false
var _enraged: bool = false
var _minions: Array[DustBunny] = []

func _init() -> void:
	max_health = 900.0
	health = 900.0

func _build_model() -> void:
	var body := _build_bunny(4.0)
	var gold := _material(Color(1.0, 0.72, 0.08))
	gold.metallic = 0.45
	var crown := CylinderMesh.new()
	crown.top_radius = 0.32
	crown.bottom_radius = 0.3
	crown.height = 0.15
	crown.radial_segments = 10
	_mesh(body, crown, Vector3(0, 1.0, 0), gold)
	for i in 5:
		var angle := TAU * float(i) / 5.0
		var point := PrismMesh.new()
		point.size = Vector3(0.14, 0.25, 0.1)
		var tip := _mesh(body, point, Vector3(sin(angle) * 0.27, 1.17, cos(angle) * 0.27), gold)
		tip.rotation.y = angle
	var dark := _material(Color(0.13, 0.06, 0.19))
	for side in [-1.0, 1.0]:
		var brow := BoxMesh.new()
		brow.size = Vector3(0.31, 0.065, 0.08)
		_mesh(body, brow, Vector3(side * 0.19, 0.8, -0.48), dark).rotation.z = side * 0.3
	died.connect(_clear_minions)
	health_changed.emit(health, max_health)

func take_damage(amount: float, from_pos: Vector3, attacker: Node = null) -> void:
	if _dead or amount <= 0.0:
		return
	super.take_damage(amount, from_pos, attacker)
	health_changed.emit(health, max_health)
	if not _dead and not _enraged and health < max_health * 0.5:
		_enraged = true
		_sound("boss_roar")

func _on_damaged() -> void:
	_sound("boss_hit")

func apply_knockback(impulse: Vector3) -> void:
	super.apply_knockback(impulse * 0.25)

func _ai(delta: float) -> void:
	var rate: float = 1.3 if _enraged else 1.0
	_slam_timer -= delta * rate
	_summon_timer -= delta * rate
	_hop_timer -= delta * rate
	_attack_timer -= delta * rate
	var target := _player()
	var direction := Vector3.ZERO
	if is_instance_valid(target):
		direction = _toward(target)
	if state == State.SLAM:
		if _telegraph > 0.0:
			_telegraph -= delta
			if _telegraph <= 0.0:
				velocity = direction * 7.0 + Vector3.UP * 16.0
				_punch(Vector3(0.8, 1.35, 0.8), 0.1)
		elif not is_on_floor():
			_slam_airborne = true
		elif _slam_airborne:
			_shockwave()
			state = State.CHASE
			_slam_timer = 6.0
			_hop_timer = 0.5
	elif is_on_floor():
		if _slam_timer <= 0.0 and is_instance_valid(target):
			state = State.SLAM
			_telegraph = 0.5
			_slam_airborne = false
			velocity.x = 0.0
			velocity.z = 0.0
			_punch(Vector3(1.3, 0.6, 1.3), 0.5)
		elif _summon_timer <= 0.0:
			state = State.SUMMON
			_summon()
			_summon_timer = 9.0
			state = State.CHASE
		elif _hop_timer <= 0.0 and is_instance_valid(target):
			velocity = direction * 5.0 + Vector3.UP * 6.0
			_hop_timer = 0.85
			_punch(Vector3(0.9, 1.15, 0.9), 0.1)
			_sound("bunny_hop", -6.0)
	if is_instance_valid(target) and global_position.distance_to(target.global_position) < 2.6 and _attack_timer <= 0.0:
		if target.has_method("take_damage"):
			target.call("take_damage", 20.0, global_position)
			_attack_timer = 1.0

func _summon() -> void:
	_minions = _minions.filter(func(minion: DustBunny) -> bool: return is_instance_valid(minion))
	for i in 3:
		var angle := TAU * float(i) / 3.0 + randf_range(-0.2, 0.2)
		var bunny := DustBunny.new()
		get_parent().add_child(bunny)
		bunny.global_position = global_position + Vector3(cos(angle) * 3.0, 0.3, sin(angle) * 3.0)
		_minions.append(bunny)

func _clear_minions(_enemy: Enemy) -> void:
	for minion in _minions:
		if is_instance_valid(minion):
			minion.queue_free()
	_minions.clear()

func _shockwave() -> void:
	_sound("boss_slam")
	_punch(Vector3(1.2, 0.75, 1.2), 0.08)
	var target := _player()
	if is_instance_valid(target) and global_position.distance_to(target.global_position) <= 10.0:
		if target.has_method("is_on_floor") and target.call("is_on_floor"):
			var outward := target.global_position - global_position
			outward.y = 0.0
			if outward.length_squared() < 0.001:
				outward = Vector3.FORWARD
			if target.has_method("take_damage"):
				target.call("take_damage", 25.0, global_position)
			if is_instance_valid(target) and target.has_method("apply_knockback"):
				target.call("apply_knockback", outward.normalized() * 14.0 + Vector3.UP * 6.0)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.65, 1.0, 0.85)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = material
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector3.UP * 0.08
	ring.scale = Vector3(1.0, 0.2, 1.0)
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(10.0, 0.2, 10.0), 0.5)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.5)
	tween.chain().tween_callback(ring.queue_free)
