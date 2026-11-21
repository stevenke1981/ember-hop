class_name Entities
extends RefCounted
## Small factory helpers shared by the level's pickups, hazards and markers.

const AREA_LAYER := 4               # areas live on layer 3 (bit value 4) and watch the player (layer 2)


static func make_area(size: Vector2, offset: Vector2 = Vector2.ZERO) -> Area2D:
	var area := Area2D.new()
	area.collision_layer = AREA_LAYER
	area.collision_mask = 2
	area.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = offset
	area.add_child(shape)
	return area


static func make_sprite(path: String, bottom_anchored: bool = true, canvas_h: float = 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.scale = Vector2(0.5, 0.5)
	if bottom_anchored:
		var h := canvas_h if canvas_h > 0.0 else float(s.texture.get_height())
		s.position = Vector2(0, -h * 0.25)  # half of the half-scale height: canvas bottom at origin
	return s


static func make_glow(color: Color, radius: float) -> Sprite2D:
	var glow := Sprite2D.new()
	var tex := GradientTexture2D.new()
	tex.width = int(radius * 2)
	tex.height = int(radius * 2)
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	tex.gradient = g
	glow.texture = tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	return glow


static func burst(parent: Node, pos: Vector2, color: Color, amount: int = 12) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 220.0
	p.gravity = Vector2(0, 200)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = color
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
