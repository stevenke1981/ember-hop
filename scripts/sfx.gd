extends Node
## Autoload: one AudioStreamPlayer per sound, polyphony so rapid sounds don't cut each other.

const SOUNDS := ["jump", "land", "collect", "stomp", "hurt", "checkpoint", "win"]
const VOLUME_DB := {"land": -10.0, "jump": -6.0, "collect": -4.0}

var _players: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for name: String in SOUNDS:
		var stream: AudioStream = load("res://audio/%s.wav" % name)
		if stream == null:
			continue
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.max_polyphony = 4
		p.volume_db = VOLUME_DB.get(name, -3.0)
		add_child(p)
		_players[name] = p


func play(name: String, pitch_jitter: float = 0.06) -> void:
	var p: AudioStreamPlayer = _players.get(name)
	if p == null:
		return
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()
