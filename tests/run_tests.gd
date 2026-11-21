extends SceneTree
## Headless tests:  godot --headless --path . -s res://tests/run_tests.gd
## Exits with code 1 on any failure.

var _failures := 0


func _initialize() -> void:
	InputSetup.ensure()
	await process_frame
	await _test_level_reachability()
	await _test_jump_apex()
	await _test_tap_jump_lower()
	await _test_coyote_jump()
	await _test_jump_buffer()
	await _test_stomp_and_side_hit()
	await _test_main_scene_loads()
	print("\n%s: %d failure(s)" % ["FAIL" if _failures else "PASS", _failures])
	quit(1 if _failures else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_failures += 1
		printerr("  FAIL ", msg)


## Graph check on the level data: surfaces (ground + one-way platforms, minus fully spiked
## floors) are nodes; an edge exists when the gap is <= 3 tiles and the step up is <= 2 tiles.
## The goal surface must be reachable from the start surface.
func _test_level_reachability() -> void:
	print("level reachability")
	var d := LevelData.level_1()
	var spiked := {}
	for s: Array in d.spikes:
		spiked[Vector2i(s[0], s[1] + 1)] = true
	var surfaces: Array = []          # [x0, x1, top]
	for s: Array in d.ground + d.platforms:
		var safe := false
		for x in range(s[0], s[1] + 1):
			if not spiked.has(Vector2i(x, s[2])):
				safe = true
		if safe:
			surfaces.append(s)
	var find := func(x: int, row: int) -> int:
		for i in surfaces.size():
			if x >= surfaces[i][0] and x <= surfaces[i][1] and surfaces[i][2] == row + 1:
				return i
		return -1
	var start: int = find.call(d.start[0], d.start[1])
	var goal: int = find.call(d.goal[0], d.goal[1])
	_check(start >= 0 and goal >= 0, "start and goal stand on surfaces")
	var seen := {start: true}
	var queue := [start]
	while not queue.is_empty():
		var a: Array = surfaces[queue.pop_front()]
		for j in surfaces.size():
			if seen.has(j):
				continue
			var b: Array = surfaces[j]
			var gap: int = maxi(b[0] - a[1], a[0] - b[1]) - 1
			var rise: int = a[2] - b[2]
			if gap <= 3 and rise <= 2:
				seen[j] = true
				queue.append(j)
	_check(seen.has(goal), "goal reachable (%d/%d surfaces reached)" % [seen.size(), surfaces.size()])
	_check(seen.size() == surfaces.size(), "every surface reachable")
	_check(d.fireflies.size() > 20, "level has %d fireflies" % d.fireflies.size())


func _make_world() -> Array:
	var root := Node2D.new()
	get_root().add_child(root)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 64)
	shape.shape = rect
	floor_body.position = Vector2(0, 32)
	floor_body.add_child(shape)
	root.add_child(floor_body)
	var p := Player.new()
	root.add_child(p)
	p.respawn_at(Vector2(0, 0))
	for i in 10:
		await physics_frame
	return [root, p]


func _release_all() -> void:
	for a in ["jump", "move_left", "move_right"]:
		Input.action_release(a)


func _measure_jump(hold_ticks: int) -> float:
	var w := await _make_world()
	var root: Node2D = w[0]
	var p: Player = w[1]
	var start_y := p.global_position.y
	var top := start_y
	Input.action_press("jump")
	for i in 90:
		await physics_frame
		if i == hold_ticks:
			Input.action_release("jump")
		top = minf(top, p.global_position.y)
	_release_all()
	root.queue_free()
	await process_frame
	return start_y - top


func _test_jump_apex() -> void:
	print("jump apex")
	var h := await _measure_jump(60)
	# Tuner: 195.4 px without apex hang; hang adds a little. Accept 185..235.
	_check(h > 185.0 and h < 235.0, "full jump height %.1f px (~3.05-3.6 tiles)" % h)


func _test_tap_jump_lower() -> void:
	print("tap jump")
	var h := await _measure_jump(2)
	_check(h > 30.0 and h < 110.0, "tap jump height %.1f px is a short hop" % h)


func _test_coyote_jump() -> void:
	print("coyote time")
	var w := await _make_world()
	var root: Node2D = w[0]
	var p: Player = w[1]
	# Delete the floor: the player is now airborne; a jump 4 ticks later must still fire.
	root.get_child(0).queue_free()
	await physics_frame
	for i in 3:
		await physics_frame
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	_check(p.velocity.y < -500.0, "jump fires 4 ticks after leaving ground (vy=%.0f)" % p.velocity.y)
	_release_all()
	root.queue_free()
	await process_frame


func _test_jump_buffer() -> void:
	print("jump buffer")
	var w := await _make_world()
	var root: Node2D = w[0]
	var p: Player = w[1]
	p.global_position.y -= 60.0     # drop from ~1 tile
	p.reset_physics_interpolation()
	var pressed := false
	var jumped := false
	for i in 60:
		await physics_frame
		# press a few ticks before landing
		if not pressed and p.velocity.y > 0.0 and p.global_position.y > -28.0 - 25.0:
			Input.action_press("jump")
			pressed = true
		if pressed and p.velocity.y < -500.0:
			jumped = true
			break
	_check(pressed and jumped, "buffered press before landing triggers a jump")
	_release_all()
	root.queue_free()
	await process_frame


func _test_stomp_and_side_hit() -> void:
	print("beetle stomp / side hit")
	# Stomp: drop onto a beetle from above.
	var w := await _make_world()
	var root: Node2D = w[0]
	var p: Player = w[1]
	var b := Beetle.new()
	b.position = Vector2(0, 0)
	b.left_x = -1.0
	b.right_x = 1.0
	root.add_child(b)
	var result := {"stomped": false, "hit": false}
	b.stomped.connect(func(_b: Beetle) -> void: result.stomped = true)
	b.hit_player.connect(func(_p: Player) -> void: result.hit = true)
	p.respawn_at(Vector2(0, -200))
	for i in 40:
		await physics_frame
		if result.stomped or result.hit:
			break
	_check(result.stomped and not result.hit, "falling onto a beetle stomps it")
	_check(p.velocity.y < 0.0, "stomp bounces the player (vy=%.0f)" % p.velocity.y)
	root.queue_free()
	await process_frame
	# Side hit: walk into a beetle.
	w = await _make_world()
	root = w[0]
	p = w[1]
	b = Beetle.new()
	b.position = Vector2(150, 0)
	b.left_x = 149.0
	b.right_x = 151.0
	root.add_child(b)
	result = {"stomped": false, "hit": false}
	b.stomped.connect(func(_b: Beetle) -> void: result.stomped = true)
	b.hit_player.connect(func(_p: Player) -> void: result.hit = true)
	Input.action_press("move_right")
	for i in 60:
		await physics_frame
		if result.stomped or result.hit:
			break
	_release_all()
	_check(result.hit and not result.stomped, "walking into a beetle hurts")
	root.queue_free()
	await process_frame


func _test_main_scene_loads() -> void:
	print("main scene")
	var scene: PackedScene = load("res://scenes/main.tscn")
	_check(scene != null, "main.tscn loads")
	var main := scene.instantiate()
	get_root().add_child(main)
	for i in 30:
		await physics_frame
	var lvl: Level = main.get("level")
	_check(lvl != null and lvl.firefly_total > 0, "level built with fireflies")
	var pl: Player = main.get("player")
	_check(pl != null and pl.is_on_floor(), "player stands on the ground at start")
	main.queue_free()
	await process_frame
