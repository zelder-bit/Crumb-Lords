class_name Stapler
extends Weapon
## Rapid-fire staples. The top arm chomps down with every shot; reloading flips
## it open, slides in a fresh staple strip and snaps it shut.

const STAPLE_COLOR := Color(0.85, 0.88, 0.95)

var _hinge: Node3D
var _strip: MeshInstance3D


func _init() -> void:
	weapon_name = "Stapler"
	damage = 11.0
	fire_interval = 0.075
	spread = 0.025
	clip = AmmoClip.new(30, 1.4)


func _build_model() -> void:
	var yellow := mat(Color(1.0, 0.75, 0.1), 0.35)
	var dark := mat(Color(0.2, 0.22, 0.28), 0.5)
	var chrome := mat(Color(0.85, 0.87, 0.9), 0.2, 0.9)

	box(anim, Vector3(0.055, 0.016, 0.21), Vector3(0, -0.03, -0.005), dark)
	box(anim, Vector3(0.03, 0.004, 0.03), Vector3(0, -0.02, -0.09), chrome)  # anvil

	# The hinge sits at the back. The arm extends forward (-Z) from it.
	_hinge = Node3D.new()
	_hinge.position = Vector3(0, -0.006, 0.09)
	anim.add_child(_hinge)
	box(_hinge, Vector3(0.05, 0.03, 0.2), Vector3(0, 0.0, -0.1), yellow)
	box(_hinge, Vector3(0.052, 0.012, 0.05), Vector3(0, 0.018, -0.02), dark)
	_strip = box(_hinge, Vector3(0.02, 0.006, 0.15), Vector3(0, -0.016, -0.1), chrome)
	muzzle.position = Vector3(0, -0.012, -0.205)
	_hinge.add_child(muzzle)


func _fire() -> void:
	Sfx.play("staple", -5.0)
	var end := hitscan(spread)
	Fx.tracer(fx_parent(), muzzle.global_position, end, STAPLE_COLOR)
	kick(Vector3(0.0, 0.002, 0.02), Vector3(0.05, randf_range(-0.03, 0.03), 0.0))
	# The chomp: the arm presses down and springs back.
	var tw := create_tween()
	tw.tween_property(_hinge, "rotation:x", -0.12, 0.025)
	tw.tween_property(_hinge, "rotation:x", 0.0, 0.045)


func _on_hit(pos: Vector3, _collider: Object) -> void:
	Fx.sparks(fx_parent(), pos, STAPLE_COLOR, 4)


func _play_reload(duration: float) -> void:
	Sfx.play("reload_stapler")
	var tw := create_tween()
	tw.tween_property(anim, "rotation", Vector3(0.35, 0.0, 0.4 * side()), duration * 0.12)
	tw.tween_property(_hinge, "rotation:x", 1.5, duration * 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _strip.position.z = 0.05; _strip.visible = true)
	tw.tween_property(_strip, "position:z", -0.1, duration * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hinge, "rotation:x", -0.1, duration * 0.08)
	tw.tween_property(_hinge, "rotation:x", 0.0, duration * 0.07)
	tw.parallel().tween_property(anim, "rotation", Vector3.ZERO, duration * 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
