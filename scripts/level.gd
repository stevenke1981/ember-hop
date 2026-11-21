class_name Level
extends Node2D
## Builds the TileMapLayer and entities from LevelData. Emits gameplay events for main.gd.

signal firefly_collected
signal checkpoint_reached(pos: Vector2)
signal goal_reached
signal player_hurt(player: Player)
signal enemy_stomped

const TILE_TOP := Vector2i(0, 0)
const TILE_FILL := Vector2i(1, 0)
const TILE_PLATFORM := Vector2i(2, 0)

var data: Dictionary
var tiles: TileMapLayer
var firefly_total := 0


func build(level: Dictionary) -> void:
	data = level
	tiles = TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = _make_tileset()
	add_child(tiles)

	for span: Array in level.ground:
		for x in range(span[0], span[1] + 1):
			for y in range(span[2], LevelData.HEIGHT):
				tiles.set_cell(Vector2i(x, y), 0, TILE_TOP if y == span[2] else TILE_FILL)
	for p: Array in level.platforms:
		for x in range(p[0], p[1] + 1):
			tiles.set_cell(Vector2i(x, p[2]), 0, TILE_PLATFORM)

	for s: Array in level.spikes:
		var n := Markers.spikes(func(pl: Player) -> void: player_hurt.emit(pl))
		n.position = LevelData.feet_pos(s[0], s[1])
		add_child(n)
	for f: Array in level.fireflies:
		var ff := Firefly.new()
		ff.position = LevelData.cell_center(f[0], f[1])
		ff.collected.connect(func(_f: Firefly) -> void: firefly_collected.emit())
		add_child(ff)
		firefly_total += 1
	for e: Array in level.enemies:
		var b := Beetle.new()
		b.position = LevelData.feet_pos(e[0], e[1])
		b.left_x = LevelData.feet_pos(e[2], e[1]).x
		b.right_x = LevelData.feet_pos(e[3], e[1]).x
		b.stomped.connect(func(_b: Beetle) -> void: enemy_stomped.emit())
		b.hit_player.connect(func(pl: Player) -> void: player_hurt.emit(pl))
		add_child(b)
	for c: Array in level.checkpoints:
		var cp := Markers.checkpoint(func(n: Node2D) -> void: checkpoint_reached.emit(n.position))
		cp.position = LevelData.feet_pos(c[0], c[1])
		add_child(cp)
	var goal := Markers.goal(func(_n: Node2D) -> void: goal_reached.emit())
	goal.position = LevelData.feet_pos(level.goal[0], level.goal[1])
	add_child(goal)
	_add_bounds()


func start_position() -> Vector2:
	return LevelData.feet_pos(data.start[0], data.start[1])


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(LevelData.TILE, LevelData.TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://art/final/tiles/tiles_atlas.png")
	src.texture_region_size = Vector2i(LevelData.TILE, LevelData.TILE)
	ts.add_source(src, 0)
	var t := float(LevelData.TILE)
	var h := t * 0.5
	# Polygon points are relative to the tile centre.
	var g := float(LevelData.GROUND_SURFACE)
	var p := float(LevelData.PLATFORM_SURFACE)
	_add_tile(src, TILE_TOP, PackedVector2Array([
		Vector2(-h, -h + g), Vector2(h, -h + g), Vector2(h, h), Vector2(-h, h)]), false)
	_add_tile(src, TILE_FILL, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]), false)
	_add_tile(src, TILE_PLATFORM, PackedVector2Array([
		Vector2(-h, -h + p), Vector2(h, -h + p), Vector2(h, -h + 21), Vector2(-h, -h + 21)]), true)
	return ts


func _add_tile(src: TileSetAtlasSource, coords: Vector2i, poly: PackedVector2Array, one_way: bool) -> void:
	src.create_tile(coords)
	var td := src.get_tile_data(coords, 0)
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, poly)
	td.set_collision_polygon_one_way(0, 0, one_way)


func _add_bounds() -> void:
	var size := LevelData.pixel_size()
	for x: float in [-16.0, size.x + 16.0]:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(32, size.y * 3)
		shape.shape = rect
		body.position = Vector2(x, size.y * 0.5)
		body.add_child(shape)
		add_child(body)
