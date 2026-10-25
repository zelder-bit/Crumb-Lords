class_name DoorClass
extends PlayerClass
## The Door: tanky, hops around.
## Movement trick: Hinge Hop, a double jump that lunges forward.
## Passive: Solid Core, takes less damage from the front.
## Super: Slam, a shield wall that then slams shut in a big bash.

const FRONT_REDUCTION := 0.3
const FRONT_COS := 0.5  # within ~60 degrees of facing
const SHIELD_TIME := 1.2
const SLAM_RANGE := 9.0
const SLAM_COS := 0.35
const SLAM_DAMAGE := 150.0

var air_jumps := 1
var _shield_mesh: MeshInstance3D


func _init() -> void:
	display_name = "Door"
	max_health = 150.0
	move_speed = 10.5
	jump_velocity = 11.5
	camera_height = 1.15  # the eyes sit in the middle of the door
	mist_color = Color(1.0, 0.6, 0.25)
	passive_name = "Solid Core"
	super_name = "Slam"


func setup(player: Player) -> void:
	# Third-person body: a living door with googly eyes in the middle of its face and
	# the knob below them. The camera sits at the eyes, just in front of the panel.
	var red := _mat(Color(0.88, 0.27, 0.22))
	var trim := _mat(Color(1.0, 0.93, 0.78))
	var gold := _mat(Color(1.0, 0.78, 0.2), 0.3, 0.8)
	_part(player.body, BoxMesh.new(), Vector3(1.0, 2.1, 0.12), Vector3(0, 1.05, 0.12), red)
	for y in [0.45, 1.7]:
		_part(player.body, BoxMesh.new(), Vector3(0.7, 0.5, 0.02), Vector3(0, y, 0.055), trim)
	for y in [0.3, 1.8]:
		_part(player.body, CylinderMesh.new(), Vector3(0.05, 0.16, 0.05), Vector3(-0.5, y, 0.12), gold)
	var knob := SphereMesh.new()
	knob.radius = 0.07
	knob.height = 0.14
	_part(player.body, knob, Vector3.ONE, Vector3(0.3, 0.8, -0.05), gold)
	_part(player.body, CylinderMesh.new(), Vector3(0.04, 0.1, 0.04), Vector3(0.3, 0.8, 0.02), gold, Vector3(PI / 2, 0, 0))
	# Googly eyes. They'd fill your own screen, so they're on a layer your camera skips;
	# they still show in your shadow and from any other camera.
	var white := _mat(Color.WHITE, 0.3)
	var black := _mat(Color(0.05, 0.05, 0.08), 0.3)
	for x in [-0.17, 0.17]:
		var eye := SphereMesh.new()
		eye.radius = 0.13
		eye.height = 0.26
		var e := _part(player.body, eye, Vector3.ONE, Vector3(x, camera_height, 0.02), white)
		e.layers = Player.SELF_HIDDEN_LAYER
		var pupil := SphereMesh.new()
		pupil.radius = 0.06
		pupil.height = 0.12
		var pp := _part(player.body, pupil, Vector3.ONE, Vector3(x, camera_height - 0.02, -0.1), black)
		pp.layers = Player.SELF_HIDDEN_LAYER

	# First-person framing (viewmodel layer): your own door's edges frame the left and
	# right of the view, angled back like you're peering out of the door's face, and the
	# knob pokes up from the bottom of the view.
	var vm_red := _vm_mat(Color(0.88, 0.27, 0.22))
	var vm_dark := _vm_mat(Color(0.62, 0.16, 0.13))
	var vm_trim := _vm_mat(Color(1.0, 0.9, 0.75))
	var vm_brass := _vm_mat(Color(1.0, 0.82, 0.3), 0.3)
	for side in [-1.0, 1.0]:
		var stile := Node3D.new()
		stile.position = Vector3(side * 1.2, 0.0, -0.6)
		stile.rotation.y = -side * 0.45  # face turned in toward the view centre
		player.weapon_mount.add_child(stile)
		_part(stile, BoxMesh.new(), Vector3(0.36, 1.6, 0.05), Vector3.ZERO, vm_red)
		_part(stile, BoxMesh.new(), Vector3(0.03, 1.6, 0.07), Vector3(side * -0.18, 0, 0), vm_trim)  # inner edge
		_part(stile, BoxMesh.new(), Vector3(0.025, 1.6, 0.055), Vector3(side * -0.08, 0, 0.0), vm_dark)  # panel groove
		if side < 0.0:
			for y in [-0.4, 0.4]:
				_part(stile, CylinderMesh.new(), Vector3(0.022, 0.12, 0.022), Vector3(0.0, y, 0.035), vm_brass)
	var knob_root := Node3D.new()
	knob_root.position = Vector3(0.32, -0.62, -0.62)
	player.weapon_mount.add_child(knob_root)
	_part(knob_root, CylinderMesh.new(), Vector3(0.09, 0.02, 0.09), Vector3(0, 0, 0.05), vm_brass, Vector3(PI / 2, 0, 0))
	_part(knob_root, CylinderMesh.new(), Vector3(0.03, 0.1, 0.03), Vector3(0, 0, -0.01), vm_brass, Vector3(PI / 2, 0, 0))
	var vm_knob := SphereMesh.new()
	vm_knob.radius = 0.08
	vm_knob.height = 0.16
	_part(knob_root, vm_knob, Vector3.ONE, Vector3(0, 0.02, -0.08), vm_brass)


func physics_tick(player: Player, _delta: float) -> void:
	if player.is_on_floor():
		air_jumps = 1
	if player.shield_active:
		# The shield shoves anything that touches it.
		for e in _enemies_in_front(player, 3.2, 0.4):
			e.apply_knockback(-player.global_basis.z * 2.0)


func on_jump_pressed(player: Player) -> bool:
	if air_jumps <= 0:
		return false
	air_jumps -= 1
	var forward := -player.global_basis.z
	player.velocity.y = jump_velocity * 1.05
	player.velocity += Vector3(forward.x, 0.0, forward.z) * 5.0
	player.cam_roll = 0.35  # the door flaps
	Sfx.play("double_jump")
	return true


func on_landed(_player: Player) -> void:
	air_jumps = 1


## Damage multiplier for Solid Core. forward and to_attacker are world-space vectors.
static func frontal_multiplier(forward: Vector3, to_attacker: Vector3, shielded: bool = false) -> float:
	var f := Vector3(forward.x, 0.0, forward.z)
	var a := Vector3(to_attacker.x, 0.0, to_attacker.z)
	if f.length() < 0.001 or a.length() < 0.001:
		return 1.0
	if f.normalized().dot(a.normalized()) >= FRONT_COS:
		return 0.0 if shielded else 1.0 - FRONT_REDUCTION
	return 1.0


func modify_incoming_damage(player: Player, amount: float, from_pos: Vector3) -> float:
	var mult := frontal_multiplier(-player.global_basis.z, from_pos - player.global_position, player.shield_active)
	return amount * mult


func activate_super(player: Player) -> void:
	player.shield_active = true
	Sfx.play("shield_up")
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(mist_color, 0.35)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var box := BoxMesh.new()
	box.size = Vector3(2.8, 3.2, 0.08)
	box.material = mat
	_shield_mesh = MeshInstance3D.new()
	_shield_mesh.mesh = box
	_shield_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shield_mesh.position = Vector3(0, 1.4, -2.0)
	_shield_mesh.scale = Vector3(0.1, 1.0, 1.0)
	player.add_child(_shield_mesh)
	player.create_tween().tween_property(_shield_mesh, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	player.get_tree().create_timer(SHIELD_TIME).timeout.connect(_slam.bind(player))


func _slam(player: Player) -> void:
	if not is_instance_valid(player):
		return
	player.shield_active = false
	if player.is_dead():
		if is_instance_valid(_shield_mesh):
			_shield_mesh.queue_free()
		return
	Sfx.play("super_slam")
	player.shake = 1.0
	player.cam_roll = -0.25
	var forward := -player.global_basis.z
	for e in _enemies_in_front(player, SLAM_RANGE, SLAM_COS):
		var dir: Vector3 = (e.global_position - player.global_position)
		dir.y = 0.0
		e.take_damage(SLAM_DAMAGE, player.global_position, player)
		if is_instance_valid(e):
			e.apply_knockback(dir.normalized() * 22.0 + Vector3.UP * 8.0)
	var mesh := _shield_mesh
	var tw := player.create_tween().set_parallel()
	tw.tween_property(mesh, "position:z", -SLAM_RANGE * 0.7, 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(mesh, "scale", Vector3(2.0, 1.4, 1.0), 0.2)
	tw.tween_property(mesh, "transparency", 1.0, 0.25)
	tw.chain().tween_callback(mesh.queue_free)
	# Small hop forward with the slam for weight.
	player.velocity += Vector3(forward.x, 0.0, forward.z) * 6.0


func _enemies_in_front(player: Player, max_range: float, min_cos: float) -> Array:
	var out := []
	var forward := -player.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	for e in player.get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - player.global_position
		to.y = 0.0
		var dist := to.length()
		# Big enemies (the boss) count from their surface, not their centre.
		var radius: float = 2.0 if e is DustBunnyKing else 0.5
		if dist - radius > max_range:
			continue
		if dist < 1.0 or forward.dot(to / dist) >= min_cos:
			out.append(e)
	return out


## Viewmodel material: ignores world shadows (the player's own body would shade it).
static func _vm_mat(color: Color, roughness := 0.6, metallic := 0.0) -> StandardMaterial3D:
	var m := _mat(color, roughness, metallic)
	m.disable_receive_shadows = true
	return m


static func _mat(color: Color, roughness := 0.7, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func _part(parent: Node3D, mesh: PrimitiveMesh, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	if mesh is BoxMesh:
		mesh.size = size
	elif mesh is CylinderMesh:
		mesh.top_radius = size.x
		mesh.bottom_radius = size.x
		mesh.height = size.y
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi
