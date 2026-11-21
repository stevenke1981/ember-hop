class_name Markers
extends RefCounted
## Spikes, checkpoints and the goal portal: simple Area2D-based nodes built in code.


static func spikes(on_touch: Callable) -> Node2D:
	var n := Node2D.new()
	n.name = "Spikes"
	var s := Entities.make_sprite("res://art/final/objects/spikes.png")
	n.add_child(s)
	var area := Entities.make_area(Vector2(48, 22), Vector2(0, -12))
	area.body_entered.connect(func(body: Node2D) -> void:
		if body is Player:
			on_touch.call(body))
	n.add_child(area)
	return n


static func checkpoint(on_reach: Callable) -> Node2D:
	var n := Node2D.new()
	n.name = "Checkpoint"
	var off := Entities.make_sprite("res://art/final/objects/lamp_off.png")
	var on := Entities.make_sprite("res://art/final/objects/lamp_on.png")
	on.visible = false
	var glow := Entities.make_glow(Color(1.0, 0.7, 0.3, 0.6), 90)
	glow.position = Vector2(0, -86)
	glow.visible = false
	n.add_child(glow)
	n.add_child(off)
	n.add_child(on)
	var area := Entities.make_area(Vector2(48, 128), Vector2(0, -64))
	var state := {"lit": false}
	area.body_entered.connect(func(body: Node2D) -> void:
		if state.lit or not body is Player or (body as Player).is_dead:
			return
		state.lit = true
		off.visible = false
		on.visible = true
		glow.visible = true
		on_reach.call(n))
	n.add_child(area)
	return n


static func goal(on_reach: Callable) -> Node2D:
	var n := Node2D.new()
	n.name = "Goal"
	var glow := Entities.make_glow(Color(1.0, 0.75, 0.3, 0.5), 150)
	glow.position = Vector2(0, -70)
	n.add_child(glow)
	n.add_child(Entities.make_sprite("res://art/final/objects/goal.png"))
	var area := Entities.make_area(Vector2(60, 110), Vector2(0, -55))
	var state := {"done": false}
	area.body_entered.connect(func(body: Node2D) -> void:
		if state.done or not body is Player or (body as Player).is_dead:
			return
		state.done = true
		on_reach.call(n))
	n.add_child(area)
	var tw := glow.create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", 0.6, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	return n
