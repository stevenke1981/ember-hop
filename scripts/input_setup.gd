class_name InputSetup
extends RefCounted
## Creates the input actions in code so keyboard + gamepad work without editing project.godot.

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE, KEY_W, KEY_UP, KEY_Z],
	"restart": [KEY_R],
	"pause": [KEY_ESCAPE],
}


static func ensure() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.25)
		for key: int in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	_add_pad_button("jump", JOY_BUTTON_A)
	_add_pad_button("restart", JOY_BUTTON_BACK)
	_add_pad_button("pause", JOY_BUTTON_START)
	_add_pad_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_pad_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)


static func _add_pad_button(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = -1
	InputMap.action_add_event(action, ev)


static func _add_pad_axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	ev.device = -1
	InputMap.action_add_event(action, ev)
