extends SceneTree
## Rendered (non-headless) bot run that saves screenshots to user://shots and logs progress.
##   godot --path . -s res://tests/screenshot.gd

const SHOTS := [20, 150, 330, 470, 640, 810, 980, 1150]
const MAX_TICKS := 1400
## tick -> [tile x, row] : teleport the player so later sections get screenshots too
const TELEPORTS := {400: [41, 8], 570: [63, 8], 740: [79, 4], 910: [96, 6], 1080: [104, 7]}


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	await process_frame
	var player: Player = main.get("player")
	var tick := 0
	var start_pressed := false
	while tick < MAX_TICKS:
		await physics_frame
		tick += 1
		if tick == 10:
			Input.action_press("jump")
		elif tick == 12:
			Input.action_release("jump")
			start_pressed = true
		if TELEPORTS.has(tick):
			var t: Array = TELEPORTS[tick]
			player.respawn_at(LevelData.feet_pos(t[0], t[1]))
			main.get("camera").snap_to_target()
		if start_pressed and tick > 20:
			_bot(player, tick)
		if tick in SHOTS:
			await process_frame
			var img := get_root().get_texture().get_image()
			img.save_png("user://shots/shot_%04d.png" % tick)
			print("shot %d  pos=%s  fireflies=%d  deaths=%d  state=%d" % [tick, player.global_position.round(),
				main.get("fireflies"), main.get("deaths"), main.get("state")])
		if main.get("state") == 3:
			print("WON at tick %d" % tick)
			await process_frame
			get_root().get_texture().get_image().save_png("user://shots/shot_win.png")
			break
	print("shots in ", ProjectSettings.globalize_path("user://shots"))
	quit()


## Dumb bot: hold right, jump at ledges/obstacles using level data.
func _bot(p: Player, tick: int) -> void:
	Input.action_press("move_right")
	var x := int(floor(p.global_position.x / LevelData.TILE))
	var want_jump := false
	var d := LevelData.level_1()
	var feet_row := int(floor((p.global_position.y + 27.0) / LevelData.TILE))
	# jump if ground ahead (1-2 tiles) is missing, higher, or spiked
	for ahead: int in [1, 2]:
		var ax := x + ahead
		var top := _ground_top(d, ax)
		if top == -1 or top < feet_row or top >= 12:
			want_jump = true
		for s: Array in d.spikes:
			if s[0] == ax and s[1] + 1 == feet_row:
				want_jump = true
	if want_jump and p.is_on_floor():
		Input.action_press("jump")
	elif not p.is_on_floor() and p.velocity.y > 0:
		Input.action_release("jump")


func _ground_top(d: Dictionary, x: int) -> int:
	for s: Array in d.ground + d.platforms:
		if x >= s[0] and x <= s[1]:
			return s[2]
	return -1
