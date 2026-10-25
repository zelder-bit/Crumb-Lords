class_name AmmoClip
extends RefCounted
## Pure magazine/reload state, kept separate from visuals so it can be unit-tested.

var mag_size: int
var reload_time: float
var ammo: int
var reloading := false
var reload_left := 0.0


func _init(p_mag_size: int, p_reload_time: float) -> void:
	mag_size = p_mag_size
	reload_time = p_reload_time
	ammo = mag_size


## Uses one round. Returns false if the clip is empty or reloading.
func consume() -> bool:
	if reloading or ammo <= 0:
		return false
	ammo -= 1
	return true


## Starts a reload. Returns false if already reloading or full.
func start_reload() -> bool:
	if reloading or ammo >= mag_size:
		return false
	reloading = true
	reload_left = reload_time
	return true


## Advances the reload. Returns true on the tick the reload finishes.
func tick(delta: float) -> bool:
	if not reloading:
		return false
	reload_left -= delta
	if reload_left <= 0.0:
		reloading = false
		reload_left = 0.0
		ammo = mag_size
		return true
	return false


func fraction() -> float:
	return float(ammo) / float(mag_size)
