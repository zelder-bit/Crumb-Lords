class_name ChapstickLaser
extends Weapon
## Fires pink lasers. The waxy stick is the ammo gauge: it shrinks back into the
## tube with every shot, and reloading twists the base to wind it back up.

const STICK_OUT_Z := -0.035  # fully extended
const STICK_IN_Z := 0.045    # fully retracted
const BEAM_COLOR := Color(1.0, 0.35, 0.65)

var _base: Node3D
var _stick: Node3D
var _cap: Node3D


func _init() -> void:
	weapon_name = "Chapstick Laser"
	damage = 26.0
	fire_interval = 0.16
	clip = AmmoClip.new(12, 1.1)


func _build_model() -> void:
	var teal := mat(Color(0.1, 0.78, 0.78), 0.35)
	var dark_teal := mat(Color(0.05, 0.5, 0.55), 0.4)
	var label := mat(Color(1.0, 0.98, 0.9), 0.6)
	var wax := mat(Color(1.0, 0.45, 0.65), 0.25)

	# The stick sits inside the tube front, so it reads as a retracting gauge.
	_stick = Node3D.new()
	_stick.position.z = STICK_OUT_Z
	anim.add_child(_stick)
	z_cylinder(_stick, 0.026, 0.09, -0.045, wax)
	var tip := SphereMesh.new()
	tip.radius = 0.026
	tip.height = 0.03
	tip.material = wax
	var tip_mi := MeshInstance3D.new()
	tip_mi.mesh = tip
	tip_mi.position.z = -0.09
	_stick.add_child(tip_mi)
	muzzle.position.z = -0.1
	_stick.add_child(muzzle)

	z_cylinder(anim, 0.032, 0.15, 0.0, teal)
	z_cylinder(anim, 0.0335, 0.045, 0.01, label)

	# The twist base: rotates around the tube axis on reload. Ridges make the spin visible.
	_base = Node3D.new()
	_base.position.z = 0.09
	anim.add_child(_base)
	z_cylinder(_base, 0.034, 0.035, 0.0, dark_teal)
	for i in 6:
		var ridge := box(_base, Vector3(0.008, 0.012, 0.034), Vector3.ZERO, teal)
		var a := TAU * i / 6.0
		ridge.position = Vector3(cos(a), sin(a), 0.0) * 0.034
		ridge.rotation.z = a

	# The cap floats in a little orbit beside the tube.
	_cap = Node3D.new()
	anim.add_child(_cap)
	z_cylinder(_cap, 0.034, 0.05, 0.0, teal)


func _process(delta: float) -> void:
	super(delta)
	if _cap:
		_cap.position = Vector3(cos(_time * 1.5) * 0.08 * side(), 0.05 + sin(_time * 2.3) * 0.015, -0.02 + sin(_time * 1.5) * 0.03)
		_cap.rotation.y = _time * 0.7
	if _stick and clip and not clip.reloading:
		var target := lerpf(STICK_IN_Z, STICK_OUT_Z, clip.fraction())
		_stick.position.z = lerpf(_stick.position.z, target, 1.0 - exp(-delta * 25.0))


func _fire() -> void:
	Sfx.play("laser", -3.0)
	var end := hitscan(0.004)
	# Hot white-pink core inside a wider magenta glow.
	Fx.beam(fx_parent(), muzzle.global_position, end, Color(1.0, 0.8, 0.95), 0.03, 0.18)
	Fx.beam(fx_parent(), muzzle.global_position, end, Color(BEAM_COLOR, 0.35), 0.09, 0.24)
	Fx.flash(fx_parent(), muzzle.global_position, BEAM_COLOR, 0.04)
	kick(Vector3(0.0, 0.004, 0.045), Vector3(0.12, 0.0, 0.0))


func _on_hit(pos: Vector3, _collider: Object) -> void:
	Fx.sparks(fx_parent(), pos, BEAM_COLOR, 16, 0.14)
	Fx.flash(fx_parent(), pos, Color(1.0, 0.85, 0.95), 0.22)


func _play_reload(duration: float) -> void:
	Sfx.play("reload_twist")
	var tilt := Vector3(0.7, -0.35 * side(), 0.6 * side())
	var tw := create_tween()
	tw.tween_property(anim, "rotation", tilt, duration * 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_base, "rotation:z", _base.rotation.z + TAU * 2.0, duration * 0.65).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_stick, "position:z", STICK_OUT_Z, duration * 0.65).set_trans(Tween.TRANS_SINE)
	tw.tween_property(anim, "rotation", Vector3.ZERO, duration * 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
