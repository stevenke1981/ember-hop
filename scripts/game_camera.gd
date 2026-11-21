class_name GameCamera
extends Camera2D
## Frame-rate independent follow with look-ahead, vertical deadzone, level limits and
## trauma-based shake that decays in real time (so it keeps moving during hit-stop).

const FOLLOW_RATE_X := 7.0
const FOLLOW_RATE_Y := 4.0
const LOOK_AHEAD := 120.0
const LOOK_AHEAD_RATE := 2.5
const VERTICAL_OFFSET := -70.0
const VERTICAL_DEADZONE := 70.0
const MAX_SHAKE := Vector2(18, 14)
const MAX_ROLL := 0.025
const TRAUMA_DECAY := 1.4

var target: Player
var shake_strength := 1.0               # accessibility: 0..1

var _look := 0.0
var _focus_y := 0.0
var _trauma := 0.0
var _noise := FastNoiseLite.new()
var _noise_t := 0.0
var _last_ms := 0


func _init() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS   # set before entering the tree


func _ready() -> void:
	ignore_rotation = false
	_noise.frequency = 0.9
	_last_ms = Time.get_ticks_msec()
	process_mode = Node.PROCESS_MODE_ALWAYS


func snap_to_target() -> void:
	if target == null:
		return
	_look = 0.0
	_focus_y = target.global_position.y + VERTICAL_OFFSET
	global_position = Vector2(target.global_position.x, _focus_y)
	reset_physics_interpolation()
	reset_smoothing()


func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var now := Time.get_ticks_msec()
	var real_dt := clampf((now - _last_ms) / 1000.0, 0.0, 0.1)
	_last_ms = now

	if not target.is_dead:
		var want_look := 0.0
		if absf(target.velocity.x) > 40.0:
			want_look = signf(target.velocity.x) * LOOK_AHEAD
		_look = lerpf(_look, want_look, 1.0 - exp(-LOOK_AHEAD_RATE * delta))
		var ty := target.global_position.y + VERTICAL_OFFSET
		if target.is_on_floor() or absf(ty - _focus_y) > VERTICAL_DEADZONE:
			_focus_y = lerpf(_focus_y, ty, 1.0 - exp(-FOLLOW_RATE_Y * delta))
		var want := Vector2(target.global_position.x + _look, _focus_y)
		global_position.x = lerpf(global_position.x, want.x, 1.0 - exp(-FOLLOW_RATE_X * delta))
		global_position.y = _focus_y

	_trauma = maxf(0.0, _trauma - TRAUMA_DECAY * real_dt)
	_noise_t += real_dt * 60.0
	var s := _trauma * _trauma * shake_strength
	offset = Vector2(MAX_SHAKE.x * s * _noise.get_noise_2d(_noise_t, 0.0),
		MAX_SHAKE.y * s * _noise.get_noise_2d(0.0, _noise_t))
	rotation = MAX_ROLL * s * _noise.get_noise_2d(_noise_t, _noise_t)
