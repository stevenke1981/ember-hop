extends Node2D
## Game flow: TITLE -> PLAYING (<-> PAUSED) -> WON. Builds background, level, player, camera, HUD.

enum State { TITLE, PLAYING, PAUSED, WON }

const RESPAWN_DELAY := 0.9
const HITSTOP_STOMP := 0.06

var state := State.TITLE
var level: Level
var player: Player
var camera: GameCamera
var hud: Hud

var fireflies := 0
var deaths := 0
var elapsed := 0.0
var respawn_point := Vector2.ZERO
var _hitstop_token := 0


func _ready() -> void:
	InputSetup.ensure()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_background()
	level = Level.new()
	level.name = "Level"
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	level.build(LevelData.level_1())
	level.firefly_collected.connect(_on_firefly)
	level.checkpoint_reached.connect(_on_checkpoint)
	level.goal_reached.connect(_on_goal)
	level.player_hurt.connect(_on_player_hurt)
	level.enemy_stomped.connect(_on_stomp)

	player = Player.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	respawn_point = level.start_position()
	player.respawn_at(respawn_point)
	player.control_enabled = false
	player.died.connect(_on_player_died)

	camera = GameCamera.new()
	camera.target = player
	var size := LevelData.pixel_size()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(size.x)
	camera.limit_bottom = int(size.y)
	add_child(camera)
	camera.make_current()
	camera.snap_to_target()

	hud = Hud.new()
	add_child(hud)
	_refresh_hud()
	hud.show_overlay("Ember Hop", "燈火跳跳\n\nCollect fireflies and reach the glowing gate\n收集螢火蟲，抵達發光的石門\n\n" +
		"Move: A/D or ←/→    Jump: Space / W / ↑ / Gamepad A\n\nPress Jump to start  按跳躍開始")


func _build_background() -> void:
	var far_tex: Texture2D = load("res://art/final/bg/bg_far.png") if ResourceLoader.exists("res://art/final/bg/bg_far.png") else null
	var mid_tex: Texture2D = load("res://art/final/bg/bg_mid.png") if ResourceLoader.exists("res://art/final/bg/bg_mid.png") else null
	var view_h := 720.0
	var layers := [[far_tex, Vector2(0.12, 0.05), 1.15, -30.0], [mid_tex, Vector2(0.4, 0.15), 0.9, 330.0]]
	for cfg: Array in layers:
		var tex: Texture2D = cfg[0]
		if tex == null:
			continue
		var para := Parallax2D.new()
		para.scroll_scale = cfg[1]
		var s: float = view_h * float(cfg[2]) / tex.get_height()
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.scale = Vector2(s, s)
		spr.position = Vector2(0, cfg[3])
		para.repeat_size = Vector2(tex.get_width() * s, 0)
		para.repeat_times = 3
		para.add_child(spr)
		if tex == mid_tex:
			# Solid forest floor under the tree line so pits never show the far hills.
			var under := ColorRect.new()
			under.color = Color8(11, 59, 59)
			under.position = Vector2(0, cfg[3] + tex.get_height() * s - 4.0)
			under.size = Vector2(tex.get_width() * s, 2000)
			para.add_child(under)
		add_child(para)


func _physics_process(delta: float) -> void:
	match state:
		State.TITLE:
			if Input.is_action_just_pressed("jump"):
				_start()
		State.PLAYING:
			elapsed += delta
			if Input.is_action_just_pressed("pause"):
				_set_paused(true)
			elif Input.is_action_just_pressed("restart"):
				get_tree().reload_current_scene()
				return
			if not player.is_dead and player.global_position.y > LevelData.pixel_size().y + 80.0:
				player.die()
			_refresh_hud()
		State.PAUSED:
			if Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("jump"):
				_set_paused(false)
			elif Input.is_action_just_pressed("restart"):
				get_tree().paused = false
				get_tree().reload_current_scene()
		State.WON:
			if Input.is_action_just_pressed("restart") or Input.is_action_just_pressed("jump"):
				get_tree().reload_current_scene()


func _start() -> void:
	state = State.PLAYING
	hud.hide_overlay()
	player.control_enabled = true
	# Swallow the press that started the game so Pip doesn't jump immediately.
	await get_tree().physics_frame
	player.respawn_at(respawn_point)


func _set_paused(on: bool) -> void:
	get_tree().paused = on
	state = State.PAUSED if on else State.PLAYING
	if on:
		hud.show_overlay("Paused  暫停", "Jump / Esc: resume  繼續\nR: restart  重新開始")
	else:
		hud.hide_overlay()


func _refresh_hud() -> void:
	hud.set_stats(fireflies, level.firefly_total, deaths, elapsed)


func _on_firefly() -> void:
	fireflies += 1
	Sfx.play("collect", 0.12)
	_refresh_hud()


func _on_checkpoint(pos: Vector2) -> void:
	respawn_point = pos
	Sfx.play("checkpoint", 0.0)
	hud.toast("Checkpoint!  存檔點")


func _on_stomp() -> void:
	Sfx.play("stomp")
	camera.add_trauma(0.35)
	_hitstop(HITSTOP_STOMP)


func _on_player_hurt(p: Player) -> void:
	if state == State.PLAYING:
		p.die()


func _on_player_died() -> void:
	deaths += 1
	camera.add_trauma(0.6)
	await get_tree().create_timer(RESPAWN_DELAY, false).timeout
	if state != State.PLAYING and state != State.PAUSED:
		return
	player.respawn_at(respawn_point)
	camera.snap_to_target()


func _on_goal() -> void:
	if state != State.PLAYING:
		return
	state = State.WON
	player.control_enabled = false
	Sfx.play("win", 0.0)
	_refresh_hud()
	var all := fireflies == level.firefly_total
	hud.show_overlay("You made it!  抵達終點！",
		"Fireflies 螢火蟲  %d / %d%s\nTime 時間  %s\nFalls 失誤  %d\n\nPress Jump or R to play again  按跳躍再玩一次" % [
			fireflies, level.firefly_total, "  ★ ALL!" if all else "", Hud.format_time(elapsed), deaths])


func _hitstop(duration: float) -> void:
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	if token == _hitstop_token:                # only the newest hit-stop restores time
		Engine.time_scale = 1.0
