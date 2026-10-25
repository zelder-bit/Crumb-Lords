extends Node3D
## Level 1: the kitchen counter. Three linear rooms running along -Z:
##   Room 1 (dust bunnies) -> gate -> stapler pickup (checkpoint) -> Room 2 -> gate -> boss arena.
## All geometry is built from primitives here. The counter top is the floor at y = 0;
## the open front edge (+X) drops to the kitchen floor far below.

const LEVEL_ID := "kitchen_counter"
const HALF_W := 14.0
const START := Vector3(0, 0.2, -3)
const CHECKPOINT := Vector3(0, 0.2, -50)

const PALETTE := {
	"counter": Color(1.0, 0.88, 0.7), "backsplash": Color(0.35, 0.8, 0.72),
	"grout": Color(0.92, 0.97, 0.95), "wood": Color(0.85, 0.6, 0.35),
	"cabinet": Color(0.45, 0.65, 0.95), "red": Color(0.95, 0.3, 0.3),
	"yellow": Color(1.0, 0.82, 0.25), "blue": Color(0.35, 0.55, 1.0),
	"green": Color(0.45, 0.85, 0.4), "purple": Color(0.7, 0.45, 0.95),
	"white": Color(0.97, 0.97, 0.97), "black": Color(0.15, 0.15, 0.18),
	"chrome": Color(0.82, 0.85, 0.9), "floor_a": Color(1.0, 0.95, 0.85),
	"floor_b": Color(0.95, 0.45, 0.4),
}

var player: Player
var hud: Hud
var _rooms: Array[Dictionary] = []
var _pickup: Node3D
var _boss_started := false


func _ready() -> void:
	_build_environment()
	_build_counter()
	_build_room1_props()
	_build_room2_props()
	_build_boss_props()

	var gate1 := _build_gate(-44.0, PALETTE.red, PALETTE.yellow)
	var gate2 := _build_gate(-100.0, PALETTE.purple, PALETTE.green)
	_rooms = [
		{"trigger_z": -8.0, "gate": gate1, "waves": [
			[Vector3(-6, 1, -30), Vector3(4, 1, -34), Vector3(-2, 1, -38), Vector3(9, 1, -28)],
			[Vector3(-9, 1, -36), Vector3(0, 1, -40), Vector3(8, 1, -39)],
		]},
		{"trigger_z": -56.0, "gate": gate2, "waves": [
			[Vector3(-8, 8, -72), Vector3(0, 1, -78), Vector3(6, 1, -84), Vector3(-4, 1, -88), Vector3(10, 1, -74)],
			[Vector3(-10, 1, -92), Vector3(-2, 1, -95), Vector3(4, 1, -94), Vector3(9, 1, -90), Vector3(0, 1, -70)],
		]},
	]
	for room in _rooms:
		room["started"] = false
		room["wave"] = 0
		room["alive"] = 0
		room["cleared"] = false

	player = Player.new(DoorClass.new())
	add_child(player)
	hud = Hud.new()
	add_child(hud)
	hud.bind_player(player)

	player.give_weapon(0, ChapstickLaser.new())
	if GameState.checkpoint_reached:
		# Respawn at the checkpoint with both weapons; room 1 stays cleared.
		player.global_position = CHECKPOINT
		player.give_weapon(1, Stapler.new())
		_rooms[0].started = true
		_rooms[0].cleared = true
		gate1.position.y = -9.0
		hud.show_message("BACK AT THE CHECKPOINT — CLOCK'S STILL TICKING", 1.6, Color(1, 0.85, 0.5))
	else:
		player.global_position = START
		_spawn_pickup()
		hud.show_message("KITCHEN COUNTER", 1.5)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var z := player.global_position.z
	for i in _rooms.size():
		var room := _rooms[i]
		if not room.started and z < room.trigger_z:
			room.started = true
			_spawn_wave(i)
	if not _boss_started and z < -108.0:
		_boss_started = true
		_spawn_boss()


# --- Rooms, gates, pickup, boss ------------------------------------------------

func _spawn_wave(room_idx: int) -> void:
	var room := _rooms[room_idx]
	var positions: Array = room.waves[room.wave]
	room.alive = positions.size()
	for pos in positions:
		var bunny := DustBunny.new()
		add_child(bunny)
		bunny.global_position = pos
		bunny.died.connect(_on_room_enemy_died.bind(room_idx))
	if room.wave > 0:
		hud.show_message("MORE DUST!", 1.0, Color(0.8, 0.75, 1.0))


func _on_room_enemy_died(_enemy: Node, room_idx: int) -> void:
	var room := _rooms[room_idx]
	room.alive -= 1
	if room.alive > 0:
		return
	room.wave += 1
	if room.wave < room.waves.size():
		_spawn_wave.call_deferred(room_idx)
		return
	room.cleared = true
	var gate: Node3D = room.gate
	Sfx.play("gate_open")
	create_tween().tween_property(gate, "position:y", -9.0, 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	hud.show_message("ROOM CLEAR — GO GO GO!", 1.5, Color(0.6, 1.0, 0.6))


func _spawn_pickup() -> void:
	_pickup = Area3D.new()
	_pickup.collision_layer = 0
	_pickup.collision_mask = 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.2
	shape.shape = sphere
	shape.position.y = 1.0
	_pickup.add_child(shape)
	add_child(_pickup)
	_pickup.global_position = CHECKPOINT

	var display := Stapler.new()
	display.display_only = true
	display.scale = Vector3.ONE * 8.0
	display.position.y = 1.4
	_pickup.add_child(display)
	var spin := display.create_tween().set_loops()
	spin.tween_property(display, "rotation:y", TAU, 3.0).from(0.0)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.6
	torus.outer_radius = 1.8
	torus.material = Fx.unshaded(Color(1.0, 0.85, 0.3, 0.8), 1.5)
	ring.mesh = torus
	ring.position.y = 0.1
	_pickup.add_child(ring)
	_pickup.body_entered.connect(_on_pickup_entered)


func _on_pickup_entered(body: Node) -> void:
	if body != player or not is_instance_valid(_pickup):
		return
	player.give_weapon(1, Stapler.new())
	GameState.reach_checkpoint()
	Sfx.play("pickup")
	Sfx.play("checkpoint", -4.0)
	hud.show_message("STAPLER ACQUIRED!  [RMB]\nCHECKPOINT", 2.0, Color(1.0, 0.85, 0.3))
	_pickup.queue_free()


func _spawn_boss() -> void:
	var boss := DustBunnyKing.new()
	add_child(boss)
	boss.global_position = Vector3(0, 22, -132)
	hud.bind_boss(boss)
	hud.show_message("THE DUST BUNNY KING", 2.5, Color(0.8, 0.65, 1.0))
	Sfx.play("boss_roar")
	boss.died.connect(func(_b):
		get_tree().create_timer(1.2).timeout.connect(func():
			Sfx.play("level_complete")
			GameState.complete_level(LEVEL_ID)))


## A wall of tall boxes across the counter with a cutting-board gate in the middle.
## Returns the gate node; it sinks into the counter when its room is cleared.
func _build_gate(z: float, side_color: Color, label_color: Color) -> Node3D:
	for x in [-9.0, 9.0]:
		_box(Vector3(x, 8, z), Vector3(10, 16, 4), side_color)
		_box(Vector3(x, 9, z + 2.05), Vector3(6, 5, 0.1), label_color, false)
	var gate := StaticBody3D.new()
	add_child(gate)
	gate.position = Vector3(0, 0, z)
	_box_on(gate, Vector3(0, 4.5, 0), Vector3(8, 9, 0.8), PALETTE.wood)
	_box_on(gate, Vector3(0, 7.5, 0), Vector3(1.6, 0.8, 0.85), Color(0.6, 0.4, 0.2), false)  # handle hole
	return gate


# --- World geometry --------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.98, 0.78, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.82, 0.95)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.98, 0.8, 0.65)
	env.fog_density = 0.0025
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


func _build_counter() -> void:
	var length := 165.0
	var mid_z := 6.0 - length / 2.0
	var counter_mat := _speckle_mat(PALETTE.counter)
	_box(Vector3(0, -1, mid_z), Vector3(HALF_W * 2, 2, length), PALETTE.counter, true, counter_mat)
	# Front edge: a bold contrasting trim stripe and a dark bullnose lip, so the drop reads.
	_box(Vector3(HALF_W - 0.35, 0.03, mid_z), Vector3(0.7, 0.06, length), Color(0.12, 0.42, 0.55), false)
	_box(Vector3(HALF_W + 0.1, -1.0, mid_z), Vector3(0.6, 2.0, length), Color(0.1, 0.32, 0.42), false)
	# The far kitchen wall across the room, with a big bright window, so the void has depth.
	_box(Vector3(95, -10, mid_z), Vector3(2, 110, length + 120), Color(0.95, 0.62, 0.48), false)
	for i in 3:
		var wz := mid_z + (i - 1) * 60.0
		_box(Vector3(93.9, 10, wz), Vector3(0.2, 30, 34), Color(0.98, 0.95, 0.85), false)
		_box(Vector3(93.7, 10, wz), Vector3(0.2, 26, 30), Color(0.55, 0.8, 1.0), false, Fx.unshaded(Color(0.6, 0.85, 1.0), 1.3))
	# Backsplash (tiled) and end walls.
	_box(Vector3(-HALF_W - 0.5, 20, mid_z), Vector3(1, 40, length), PALETTE.backsplash, true, _tile_mat())
	_box(Vector3(0, 20, 6.5), Vector3(HALF_W * 2 + 2, 40, 1), PALETTE.white)  # fridge side
	_box(Vector3(0, 20, -159.5), Vector3(HALF_W * 2 + 2, 40, 1), PALETTE.backsplash, true, _tile_mat())
	# Upper cabinets overhead along the back.
	for i in 6:
		var z := -i * 27.0 - 10.0
		_box(Vector3(-HALF_W + 3, 34, z), Vector3(7, 12, 26), PALETTE.cabinet, false)
		_box(Vector3(-HALF_W + 6.6, 30, z + 9), Vector3(0.6, 2.5, 0.6), PALETTE.chrome, false)
	# Lower cabinets below the front edge, and the checkered kitchen floor far below.
	for i in 6:
		var z := -i * 27.0 - 10.0
		_box(Vector3(HALF_W - 2, -32, z), Vector3(3, 58, 26), PALETTE.cabinet, false)
		_box(Vector3(HALF_W + 0.1, -8, z + 9), Vector3(0.6, 0.6, 3), PALETTE.chrome, false)
	_box(Vector3(60, -62, mid_z), Vector3(100, 2, length + 60), PALETTE.floor_a, false, _checker_mat())


func _build_room1_props() -> void:
	# A giant coffee mug.
	var mug := _cylinder(Vector3(6, 3.5, -18), 3.0, 7.0, PALETTE.red)
	var handle := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.2
	torus.outer_radius = 1.9
	torus.material = _mat(PALETTE.red)
	handle.mesh = torus
	handle.rotation_degrees = Vector3(90, 0, 0)
	handle.position = Vector3(3.2, 0, 0)
	mug.add_child(handle)
	_cylinder(Vector3(6, 7.02, -18), 2.6, 0.05, Color(0.45, 0.28, 0.15), false)  # coffee
	# Salt and pepper shakers.
	_cylinder(Vector3(-9, 2.5, -30), 1.1, 5.0, PALETTE.white)
	_cylinder(Vector3(-9, 5.3, -30), 0.9, 0.6, PALETTE.chrome)
	_cylinder(Vector3(-6.4, 2.5, -31.5), 1.1, 5.0, PALETTE.black)
	_cylinder(Vector3(-6.4, 5.3, -31.5), 0.9, 0.6, PALETTE.chrome)
	# Sugar cubes as low cover.
	for p in [Vector3(-3, 0.8, -14), Vector3(-1.4, 0.8, -14.6), Vector3(3, 0.8, -28), Vector3(-2, 0.8, -33), Vector3(-2, 2.4, -33)]:
		_box(p, Vector3(1.6, 1.6, 1.6), PALETTE.white)
	# A butter dish ramp onto the mug's side.
	var ramp := _box(Vector3(9.5, 1.0, -24), Vector3(4, 0.5, 9), PALETTE.yellow)
	ramp.rotation_degrees.x = -12


func _build_room2_props() -> void:
	# The toaster, with sugar-cube steps to hop up onto it.
	_box(Vector3(-7, 3, -72), Vector3(8, 6, 5), PALETTE.chrome, true, _mat(PALETTE.chrome, 0.25, 0.8))
	for x in [-9.0, -5.0]:
		_box(Vector3(x, 6.02, -72), Vector3(2.5, 0.05, 3.6), PALETTE.black, false)
	_box(Vector3(-2.7, 3.5, -71), Vector3(0.6, 0.6, 1.2), PALETTE.black)
	_box(Vector3(-1.5, 0.8, -66), Vector3(1.6, 1.6, 1.6), PALETTE.white)
	_box(Vector3(-2.2, 2.4, -68.5), Vector3(1.6, 1.6, 1.6), PALETTE.white)
	_box(Vector3(-2.2, 0.8, -68.5), Vector3(1.6, 1.6, 1.6), PALETTE.white)
	# A stack of plates.
	for i in 5:
		_cylinder(Vector3(7, 0.25 + i * 0.5, -66), 3.5, 0.45, PALETTE.blue if i % 2 else PALETTE.white)
	# A banana lying across the counter.
	var banana := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.9
	cap.height = 8.0
	cap.material = _mat(PALETTE.yellow)
	banana.mesh = cap
	var banana_body := StaticBody3D.new()
	add_child(banana_body)
	banana_body.position = Vector3(3, 0.9, -86)
	banana_body.rotation_degrees = Vector3(0, 30, 90)
	banana_body.add_child(banana)
	var bshape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.9
	capsule.height = 8.0
	bshape.shape = capsule
	banana_body.add_child(bshape)
	# A fallen spoon.
	_box(Vector3(10, 0.15, -94), Vector3(0.8, 0.3, 6), PALETTE.chrome, true, _mat(PALETTE.chrome, 0.2, 0.9))
	_cylinder(Vector3(10, 0.3, -97.5), 1.4, 0.6, PALETTE.chrome)


func _build_boss_props() -> void:
	# The faucet at the far end of the arena.
	var chrome := _mat(PALETTE.chrome, 0.15, 0.9)
	_cylinder(Vector3(-9, 8, -152), 1.2, 16, PALETTE.chrome, true, chrome)
	_box(Vector3(-9, 15.5, -148), Vector3(1.8, 1.8, 9), PALETTE.chrome, false, chrome)
	_cylinder(Vector3(-9, 14.5, -144), 0.9, 1.5, PALETTE.chrome, false, chrome)
	# Sponges and sugar cubes as cover.
	_box(Vector3(6, 1.0, -122), Vector3(5, 2, 3), PALETTE.yellow)
	_box(Vector3(6, 2.3, -122), Vector3(5, 0.6, 3), PALETTE.green)
	_box(Vector3(-6, 1.0, -138), Vector3(5, 2, 3), PALETTE.yellow)
	_box(Vector3(-6, 2.3, -138), Vector3(5, 0.6, 3), PALETTE.green)
	for p in [Vector3(-8, 0.8, -118), Vector3(9, 0.8, -140), Vector3(0, 0.8, -146)]:
		_box(p, Vector3(1.6, 1.6, 1.6), PALETTE.white)


# --- Helpers ---------------------------------------------------------------------

func _mat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


func _box(pos: Vector3, size: Vector3, color: Color, collide := true, material: Material = null) -> Node3D:
	var holder: Node3D = StaticBody3D.new() if collide else Node3D.new()
	add_child(holder)
	holder.position = pos
	_box_on(holder, Vector3.ZERO, size, color, collide, material)
	return holder


func _box_on(parent: Node3D, pos: Vector3, size: Vector3, color: Color, collide := true, material: Material = null) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material if material else _mat(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		cs.position = pos
		parent.add_child(cs)


func _cylinder(pos: Vector3, radius: float, height: float, color: Color, collide := true, material: Material = null) -> Node3D:
	var holder: Node3D = StaticBody3D.new() if collide else Node3D.new()
	add_child(holder)
	holder.position = pos
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.material = material if material else _mat(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	holder.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		cs.shape = shape
		holder.add_child(cs)
	return holder


func _tile_mat() -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(PALETTE.backsplash)
	for i in 64:
		for t in 3:
			img.set_pixel(i, t, PALETTE.grout)
			img.set_pixel(t, i, PALETTE.grout)
	var m := _mat(Color.WHITE, 0.3)
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.25
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


func _checker_mat() -> StandardMaterial3D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, PALETTE.floor_a)
	img.set_pixel(1, 1, PALETTE.floor_a)
	img.set_pixel(1, 0, PALETTE.floor_b)
	img.set_pixel(0, 1, PALETTE.floor_b)
	var m := _mat(Color.WHITE)
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.05
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


func _speckle_mat(base: Color) -> StandardMaterial3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(base)
	for i in 700:
		var c := base.darkened(rng.randf_range(0.08, 0.25)) if rng.randf() < 0.7 else base.lightened(0.3)
		img.set_pixel(rng.randi_range(0, 127), rng.randi_range(0, 127), c)
	var m := _mat(Color.WHITE, 0.6)
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.08
	return m
