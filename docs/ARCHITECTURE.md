# Architecture & interfaces

All gameplay nodes are built in code (`X.new()` + `add_child`). Units: 1 = 1 m, -Z is forward, Y is up.
The player is about 2 m tall. The kitchen is built huge around them: the counter top is the floor at y = 0, and falling below y = -15 kills.

## Autoloads
- `GameState` (`autoload/game_state.gd`): run timer, checkpoint, restart, medals, personal bests, input map setup.
  - `start_timer()`, `reach_checkpoint()`, `on_player_died()`, `restart_level()`, `complete_level(level_id)`
  - `elapsed: float`, `timer_running: bool`, `checkpoint_reached: bool`
- `Sfx` (`autoload/sfx.gd`):
  - `play(name: String, volume_db := 0.0, pitch_jitter := 0.08)`, a non-positional sound
  - `play_at(name: String, pos: Vector3, volume_db := 0.0, pitch_jitter := 0.08)`, a 3D sound
  - Loads `res://assets/sfx/<name>.wav`. Unknown names are ignored with a warning printed once.
  - Sound names: `laser, staple, reload_twist, reload_stapler, empty_click, hop, double_jump, land, hurt, death, bunny_hop, bunny_hit, bunny_die, boss_slam, boss_roar, boss_hit, pickup, gate_open, shield_up, super_slam, level_complete, checkpoint`
- `Screenshot` (`debug/screenshot.gd`): does nothing unless `--screenshot=<path>` appears in the user args.

## Groups
- `"player"`: the single `Player` (a CharacterBody3D).
- `"enemies"`: every live `Enemy`.

## Player (`player/player.gd`, `class_name Player`)
Methods used by enemies:
- `take_damage(amount: float, from_pos: Vector3) -> void`. The class passive may reduce it.
- `apply_knockback(impulse: Vector3) -> void`
- `is_dead() -> bool`
- `on_dealt_damage(amount: float)` and `on_enemy_killed(enemy)`, which charge the super meter. `Enemy.take_damage` calls these; weapons must not.
- `camera: Camera3D`

## Enemy (`enemies/enemy.gd`, `class_name Enemy extends CharacterBody3D`)
- `signal died(enemy: Enemy)`
- `var max_health: float`, `var health: float`
- `take_damage(amount: float, from_pos: Vector3, attacker: Node = null)`. On death it calls `attacker.on_enemy_killed(self)` if the attacker has that method.
- `apply_knockback(impulse: Vector3)`
- Joins group `"enemies"`. Collision layer bit 4, mask 1|2|4.
- Dies if `global_position.y < -20` (knocked off the counter), crediting the last attacker.
- `DustBunny` (`enemies/dust_bunny.gd`) and `DustBunnyKing` (`enemies/dust_bunny_king.gd`, the boss, which also emits `health_changed(current, max)`).

## Weapons (`weapons/weapon.gd`, `class_name Weapon extends Node3D`)
- Floating viewmodels parented to the player camera, one per hand (0 = left/LMB, 1 = right/RMB).
- Ammo logic lives in `weapons/ammo_clip.gd` (pure, unit-tested).
- Hitscan rays use mask 1|4.

## Player classes (`classes/player_class.gd`, `class_name PlayerClass extends RefCounted`)
Hooks: `setup(player)`, `physics_tick(player, delta)`, `on_jump_pressed(player) -> bool`, `modify_incoming_damage(player, amount, from_pos) -> float`, `activate_super(player)`.
`DoorClass` is implemented first.
