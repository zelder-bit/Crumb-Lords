class_name PlayerClass
extends RefCounted
## Base for playable household objects. Each one has stats, a movement trick,
## one passive and one super.

var display_name := "Object"
var max_health := 100.0
var move_speed := 11.0
var jump_velocity := 11.0
var camera_height := 1.6
var mist_color := Color(0.8, 0.9, 1.0)
var passive_name := ""
var super_name := ""


## Builds the visible body under player.body.
func setup(_player: Player) -> void:
	pass


func physics_tick(_player: Player, _delta: float) -> void:
	pass


## Called when jump is pressed in the air. Return true if consumed.
func on_jump_pressed(_player: Player) -> bool:
	return false


func on_landed(_player: Player) -> void:
	pass


func modify_incoming_damage(_player: Player, amount: float, _from_pos: Vector3) -> float:
	return amount


func activate_super(_player: Player) -> void:
	pass
