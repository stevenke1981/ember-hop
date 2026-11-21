class_name Firefly
extends Node2D
## Collectible. Bobs, flaps, glows; collected on contact with the player.

signal collected(firefly: Firefly)

var _sprite: AnimatedSprite2D
var _area: Area2D
var _t := 0.0
var _taken := false


func _ready() -> void:
	_t = randf() * TAU
	add_child(Entities.make_glow(Color(1.0, 0.85, 0.3, 0.55), 40))
	_sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 8.0)
	frames.add_frame("default", load("res://art/final/objects/firefly1.png"))
	frames.add_frame("default", load("res://art/final/objects/firefly2.png"))
	_sprite.sprite_frames = frames
	_sprite.scale = Vector2(0.4, 0.4)
	_sprite.play()
	add_child(_sprite)
	_area = Entities.make_area(Vector2(36, 36))
	_area.body_entered.connect(_on_body_entered)
	add_child(_area)


func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	_sprite.position.y = sin(_t * 3.0) * 4.0


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body is Player or (body as Player).is_dead:
		return
	_taken = true
	_area.set_deferred("monitoring", false)
	Entities.burst(get_parent(), global_position, Color(1.0, 0.85, 0.35), 10)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.15)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(queue_free)
	collected.emit(self)
