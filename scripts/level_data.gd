class_name LevelData
extends RefCounted
## Level 1 "Twilight Path" in tile units (1 tile = 64 px). Rows grow downward.
## Critical path rules (from the jump tuner: apex ~3.05 tiles, reach ~3.8 tiles):
## step-ups <= 2 tiles, gaps <= 3 tiles.

const TILE := 64
const HEIGHT := 15                 # rows 0..14
const WIDTH := 123                 # columns 0..122
const GROUND_SURFACE := 7          # grass collision starts 7 px below the tile top
const PLATFORM_SURFACE := 7


static func level_1() -> Dictionary:
	return {
		"name": "Twilight Path",
		# [x0, x1, top_row] — soil fills from top_row to the bottom
		"ground": [
			[0, 11, 11], [12, 17, 10], [20, 29, 10], [30, 33, 9], [39, 52, 9],
			[53, 56, 8], [57, 61, 13], [62, 74, 9], [75, 77, 7], [78, 80, 5],
			[86, 98, 7], [102, 122, 8],
		],
		# [x0, x1, row] one-way planks
		"platforms": [[35, 37, 8], [58, 59, 7], [66, 68, 7], [82, 84, 6]],
		# [x, row] — the spike sits in this row, on the surface below it
		"spikes": [[24, 9], [57, 12], [58, 12], [59, 12], [60, 12], [61, 12], [93, 6], [94, 6]],
		# [x, row] — firefly centre
		"fireflies": [
			[5, 10], [6, 10], [7, 10], [13, 9], [15, 9], [18, 8], [19, 8],
			[23, 8], [24, 7], [25, 8], [31, 8], [32, 8], [36, 7], [44, 8], [48, 8],
			[54, 7], [55, 7], [58, 6], [59, 6], [64, 8], [66, 6], [67, 6], [68, 6],
			[76, 6], [79, 4], [83, 5], [88, 6], [90, 6], [93, 5], [94, 5], [100, 6],
			[105, 7], [107, 7], [109, 7],
		],
		# [x, row, left_x, right_x] — beetle walks on the surface below `row`
		"enemies": [[46, 8, 42, 51], [70, 8, 63, 72], [90, 6, 87, 91], [110, 7, 105, 113]],
		"checkpoints": [[40, 8], [74, 8]],
		"start": [2, 10],
		"goal": [117, 7],
	}


## Pixel position of the bottom-centre of something standing in `row` at column `x`.
static func feet_pos(x: int, row: int) -> Vector2:
	return Vector2(x * TILE + TILE * 0.5, (row + 1) * TILE + GROUND_SURFACE)


static func cell_center(x: int, row: int) -> Vector2:
	return Vector2(x * TILE + TILE * 0.5, row * TILE + TILE * 0.5)


static func pixel_size() -> Vector2:
	return Vector2(WIDTH * TILE, HEIGHT * TILE)
