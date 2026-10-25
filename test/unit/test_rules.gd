extends GutTest
## Pure gameplay rules: ammo, medals, death/checkpoint outcome, Solid Core.


func test_ammo_consume_until_empty() -> void:
	var clip := AmmoClip.new(3, 1.0)
	assert_true(clip.consume())
	assert_true(clip.consume())
	assert_true(clip.consume())
	assert_false(clip.consume(), "empty clip can't fire")
	assert_eq(clip.ammo, 0)


func test_ammo_reload_cycle() -> void:
	var clip := AmmoClip.new(5, 1.0)
	clip.consume()
	assert_true(clip.start_reload())
	assert_false(clip.start_reload(), "already reloading")
	assert_false(clip.consume(), "can't fire mid-reload")
	assert_false(clip.tick(0.5))
	assert_true(clip.tick(0.6), "finishes after reload_time")
	assert_eq(clip.ammo, 5)
	assert_false(clip.reloading)


func test_full_clip_does_not_reload() -> void:
	var clip := AmmoClip.new(5, 1.0)
	assert_false(clip.start_reload())


func test_medals() -> void:
	assert_eq(GameState.medal_for(30.0), "gold")
	assert_eq(GameState.medal_for(GameState.MEDAL_TIMES.gold + 1.0), "silver")
	assert_eq(GameState.medal_for(GameState.MEDAL_TIMES.silver + 1.0), "bronze")
	assert_eq(GameState.medal_for(9999.0), "none")


func test_format_time() -> void:
	assert_eq(GameState.format_time(75.5), "01:15.50")
	assert_eq(GameState.format_time(0.0), "00:00.00")


func test_death_before_checkpoint_restarts() -> void:
	assert_eq(GameState.death_outcome(false), "restart")


func test_death_after_checkpoint_respawns() -> void:
	assert_eq(GameState.death_outcome(true), "checkpoint")


func test_solid_core_reduces_frontal_damage() -> void:
	var fwd := Vector3(0, 0, -1)
	assert_almost_eq(DoorClass.frontal_multiplier(fwd, Vector3(0, 0, -5)), 0.7, 0.001)
	assert_almost_eq(DoorClass.frontal_multiplier(fwd, Vector3(0, 0, 5)), 1.0, 0.001, "from behind")
	assert_almost_eq(DoorClass.frontal_multiplier(fwd, Vector3(5, 0, 0)), 1.0, 0.001, "from the side")


func test_slam_shield_blocks_frontal_damage() -> void:
	assert_eq(DoorClass.frontal_multiplier(Vector3(0, 0, -1), Vector3(0, 1, -3), true), 0.0)
