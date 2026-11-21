class_name Beetle
extends Node2D
## Gloom beetle: patrols between two x positions; stomp from above, hurts from the side.

signal stomped(beetle: Beetle)
signal hit_player(player: Player)

const SPEED := 80.0

var left_x := 0.0
var right_x := 0.0
var _dir := -1.0
var _dead := false
var _sprite: AnimatedSprite2D
var _area: Area2D


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 6.0)
	frames.add_frame("default", load("res://art/final/objects/beetle1.png"))
	frames.add_frame("default", load("res://art/final/objects/beetle2.png"))
	frames.add_animation("flat")
	frames.add_frame("flat", load("res://art/final/objects/beetle_flat.png"))
	_sprite.sprite_frames = frames
	_sprite.scale = Vector2(0.5, 0.5)
	_sprite.position = Vector2(0, -24)        # 96 px canvas * 0.5, bottom on the origin
	_sprite.play()
	add_child(_sprite)
	_area = Entities.make_area(Vector2(46, 30), Vector2(0, -17))
	_area.body_entered.connect(_on_body_entered)
	add_child(_area)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	position.x += _dir * SPEED * delta
	if position.x <= left_x:
		position.x = left_x
		_dir = 1.0
	elif position.x >= right_x:
		position.x = right_x
		_dir = -1.0
	_sprite.flip_h = _dir > 0.0                # art faces left


func _on_body_entered(body: Node2D) -> void:
	if _dead or not body is Player:
		return
	var player := body as Player
	if player.is_dead:
		return
	# Stomp when falling and the feet are above the beetle's middle.
	if player.velocity.y > 0.0 and player.feet_y() < global_position.y - 12.0:
		_die()
		player.bounce()
		stomped.emit(self)
	else:
		hit_player.emit(player)


func _die() -> void:
	_dead = true
	_area.set_deferred("monitoring", false)
	_sprite.play("flat")
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
