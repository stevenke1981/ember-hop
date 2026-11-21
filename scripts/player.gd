class_name Player
extends CharacterBody2D
## Pip the lantern spirit. Feel core from the `platformer` skill, constants from jump_tuner.py:
##   python jump_tuner.py --height 3.2 --apex-time 0.36 --tile 64 --tick 60 --fall-mult 1.7
##                        --tap-ratio 0.35 --terminal 14 --coyote 0.1 --buffer 0.1
## Grace windows are counted in whole physics ticks.

signal died
signal landed(impact: float)
signal jumped

const RUN_SPEED := 384.0            # 6 tiles/s
const GROUND_ACCEL := 5500.0        # top speed in ~0.07 s
const GROUND_DECEL := 6500.0
const AIR_CONTROL := 0.65
const JUMP_VELOCITY := 1137.78
const GRAVITY_RISE := 3160.49
const GRAVITY_FALL := 5372.84
const TAP_CUT := 0.592              # tap hop ~35 % of full height
const APEX_HANG_GRAVITY := 0.6
const APEX_HANG_SPEED := 0.25       # fraction of launch speed
const TERMINAL_FALL := 896.0        # 14 tiles/s, 15 px per tick
const COYOTE_TICKS := 6
const BUFFER_TICKS := 6
const CORNER_NUDGE := 16
const STOMP_BOUNCE := 820.0
const NEVER := -1000000

var control_enabled := true
var is_dead := false
var facing := 1

var _tick := 0
var _last_ground_tick := NEVER
var _last_press_tick := NEVER
var _jump_held := false
var _was_on_floor := false
var _fall_speed_before_land := 0.0

var _visual: Node2D
var _sprite: AnimatedSprite2D
var _dust: CPUParticles2D
var _squash_tween: Tween


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(46.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 54)
	shape.shape = rect
	add_child(shape)

	_visual = Node2D.new()
	_visual.position = Vector2(0, 27)         # pivot at the feet for squash & stretch
	add_child(_visual)
	_add_glow()
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.scale = Vector2(0.5, 0.5)
	_sprite.position = Vector2(0, -36)        # 144 px canvas * 0.5, feet on the canvas bottom
	_sprite.play("idle")
	_visual.add_child(_sprite)

	_dust = CPUParticles2D.new()
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = 10
	_dust.lifetime = 0.35
	_dust.explosiveness = 1.0
	_dust.direction = Vector2(0, -1)
	_dust.spread = 80.0
	_dust.initial_velocity_min = 60.0
	_dust.initial_velocity_max = 140.0
	_dust.gravity = Vector2(0, 300)
	_dust.scale_amount_min = 3.0
	_dust.scale_amount_max = 6.0
	_dust.color = Color(0.75, 0.85, 0.8, 0.8)
	_dust.position = Vector2(0, 27)
	add_child(_dust)


func _add_glow() -> void:
	var glow := Sprite2D.new()
	var tex := GradientTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.75, 0.35, 0.45))
	g.set_color(1, Color(1.0, 0.6, 0.2, 0.0))
	tex.gradient = g
	glow.texture = tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.position = Vector2(0, -34)
	_visual.add_child(glow)


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var anims := {
		"idle": [["idle"], 1.0, true],
		"run": [["run1", "run2", "run3", "run4"], 12.0, true],
		"jump": [["jump"], 1.0, false],
		"fall": [["fall"], 1.0, false],
		"hurt": [["hurt"], 1.0, false],
	}
	for anim: String in anims:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, anims[anim][1])
		frames.set_animation_loop(anim, anims[anim][2])
		for f: String in anims[anim][0]:
			frames.add_frame(anim, load("res://art/final/player/pip_%s.png" % f))
	return frames


func _physics_process(delta: float) -> void:
	_tick += 1
	if is_dead:
		velocity.y = minf(velocity.y + GRAVITY_FALL * 0.5 * delta, TERMINAL_FALL)
		position += velocity * delta          # no collision while dying
		return

	var dir := 0.0
	if control_enabled:
		dir = Input.get_axis("move_left", "move_right")
		if Input.is_action_just_pressed("jump"):
			_last_press_tick = _tick
		_jump_held = Input.is_action_pressed("jump")
	else:
		_jump_held = false

	# --- horizontal
	var target := dir * RUN_SPEED
	var accel := GROUND_ACCEL if absf(target) > 0.01 else GROUND_DECEL
	if not is_on_floor():
		accel *= AIR_CONTROL
	velocity.x = move_toward(velocity.x, target, accel * delta)
	if absf(dir) > 0.1:
		facing = 1 if dir > 0 else -1

	# --- grace windows (whole ticks)
	if is_on_floor() and velocity.y >= 0.0:
		_last_ground_tick = _tick
	if _tick - _last_press_tick <= BUFFER_TICKS and _tick - _last_ground_tick <= COYOTE_TICKS:
		_do_jump()

	# --- variable height, apex hang, gravity, fall cap
	if velocity.y < 0.0 and not _jump_held:
		velocity.y = maxf(velocity.y, -JUMP_VELOCITY * TAP_CUT)
	var g := GRAVITY_RISE if velocity.y < 0.0 else GRAVITY_FALL
	if _jump_held and absf(velocity.y) < JUMP_VELOCITY * APEX_HANG_SPEED:
		g *= APEX_HANG_GRAVITY
	velocity.y = minf(velocity.y + g * delta, TERMINAL_FALL)

	if velocity.y < 0.0:
		_corner_correct(delta)
	if velocity.y > 0.0:
		_fall_speed_before_land = velocity.y

	move_and_slide()

	if is_on_ceiling() and velocity.y < 0.0:
		velocity.y = 0.0                      # head bonk ends the jump
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_on_land()
	_was_on_floor = on_floor
	_update_animation()


func _do_jump() -> void:
	velocity.y = -JUMP_VELOCITY
	_last_press_tick = NEVER
	_last_ground_tick = NEVER                 # consume coyote so it can't double jump
	if not _jump_held:
		velocity.y = -JUMP_VELOCITY * TAP_CUT  # buffered press released before landing
	_squash(Vector2(0.8, 1.22))
	_puff()
	jumped.emit()
	_play_sfx("jump")


func _corner_correct(delta: float) -> void:
	var motion := Vector2(0, velocity.y * delta)
	if not test_move(global_transform, motion):
		return
	for nudge in range(1, CORNER_NUDGE + 1):
		for side in [-1, 1]:
			var t := global_transform.translated(Vector2(nudge * side, 0))
			if not test_move(t, motion):
				global_position.x += nudge * side
				return


func _on_land() -> void:
	var impact := clampf(_fall_speed_before_land / TERMINAL_FALL, 0.0, 1.0)
	if impact > 0.25:
		_squash(Vector2(1.0 + 0.3 * impact, 1.0 - 0.25 * impact))
		_puff()
		_play_sfx("land")
	landed.emit(impact)


func _update_animation() -> void:
	_sprite.flip_h = facing < 0
	var anim := "idle"
	if not is_on_floor():
		anim = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 20.0:
		anim = "run"
	if _sprite.animation != anim:
		_sprite.play(anim)


func _squash(amount: Vector2) -> void:
	if _squash_tween:
		_squash_tween.kill()
	_visual.scale = amount
	_squash_tween = create_tween()
	_squash_tween.tween_property(_visual, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _puff() -> void:
	_dust.restart()
	_dust.emitting = true


func bounce() -> void:
	velocity.y = -STOMP_BOUNCE
	_last_ground_tick = NEVER
	_squash(Vector2(0.85, 1.18))


func die() -> void:
	if is_dead:
		return
	is_dead = true
	control_enabled = false
	_sprite.play("hurt")
	velocity = Vector2(-facing * 120.0, -700.0)
	_play_sfx("hurt")
	died.emit()


func respawn_at(pos: Vector2) -> void:
	is_dead = false
	control_enabled = true
	velocity = Vector2.ZERO
	global_position = pos - Vector2(0, 28)
	reset_physics_interpolation()
	_last_press_tick = NEVER
	_last_ground_tick = NEVER
	_visual.scale = Vector2.ONE
	_sprite.play("idle")


func feet_y() -> float:
	return global_position.y + 27.0


func _play_sfx(name: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(name)
