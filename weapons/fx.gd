class_name Fx
extends RefCounted
## Small throwaway visual effects (beams, sparks, mist).


static func unshaded(color: Color, emission := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r * emission, color.g * emission, color.b * emission, color.a)
	return m


## A glowing cylinder from a to b that thins and fades out.
static func beam(parent: Node, a: Vector3, b: Vector3, color: Color, width := 0.03, life := 0.09) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var cyl := CylinderMesh.new()
	cyl.top_radius = width
	cyl.bottom_radius = width
	cyl.height = length
	cyl.radial_segments = 6
	cyl.rings = 1
	cyl.material = unshaded(color, 3.0)
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = (a + b) * 0.5
	var up := Vector3.UP if absf((b - a).normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	mi.look_at(b, up)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(0.1, 1.0, 0.1), life)
	tw.tween_property(mi, "transparency", 1.0, life)
	tw.chain().tween_callback(mi.queue_free)


## A small object that flies from a to b, e.g. a staple.
static func tracer(parent: Node, a: Vector3, b: Vector3, color: Color, speed := 140.0) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.025, 0.006, 0.05)
	box.material = unshaded(color, 1.5)
	var mi := MeshInstance3D.new()
	mi.mesh = box
	parent.add_child(mi)
	mi.global_position = a
	if a.distance_to(b) > 0.01:
		mi.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", b, a.distance_to(b) / speed)
	tw.tween_callback(mi.queue_free)


static func sparks(parent: Node, pos: Vector3, color: Color, amount := 10, size := 0.08) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var m := unshaded(color, 3.0)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = m
	p.mesh = quad
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(0.8).timeout.connect(p.queue_free)


## A quick bright ball that pops and fades (muzzle flash, hit flash).
static func flash(parent: Node, pos: Vector3, color: Color, radius := 0.3) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = unshaded(color, 4.0)
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.4
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.2, 0.08)
	tw.tween_property(mi, "transparency", 1.0, 0.1)
	tw.chain().tween_callback(mi.queue_free)


## A round, soft-edged white dot texture for puffs and mist.
static func soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	return tex


## The magical mist that floating weapons sit in. Parented locally so it follows.
static func mist(parent: Node3D, color: Color, radius := 0.13) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 1.4
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.06
	p.gravity = Vector3(0, 0.03, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	var m := unshaded(Color(color, 0.22), 1.4)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = soft_dot()
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p
