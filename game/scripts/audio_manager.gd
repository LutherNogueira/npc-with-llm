extends Node
## Autoload "Audio": Music / SFX / Voice buses, persisted volumes, and a single
## entry point for swapping the music track.

const BUSES := ["Music", "SFX", "Voice"]
const SETTINGS_PATH := "user://audio.cfg"
const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"

var volumes := {"Music": 0.7, "SFX": 0.8, "Voice": 0.6}
var muted := {"Music": false, "SFX": false, "Voice": false}

var _sfx_pool: Array[AudioStreamPlayer] = []
var _voice_pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _cache := {}


func _ready() -> void:
	_ensure_buses()
	_load_settings()
	_apply_all()
	for i in 6:
		_sfx_pool.append(_make_player("SFX"))
	for i in 3:
		_voice_pool.append(_make_player("Voice"))
	_music = _make_player("Music")
	_ambient = _make_player("Music")
	_ambient.volume_db = -10.0


func play_sfx(sfx_name: String) -> void:
	_play_from(_sfx_pool, _stream(SFX_DIR + sfx_name + ".wav"), 1.0)


## Speech blip; its timbre follows the emotion (schema field `emotion`).
func play_blip(emotion: String) -> void:
	var path := SFX_DIR + "blip_%s.wav" % emotion
	if not ResourceLoader.exists(path):
		path = SFX_DIR + "blip_neutral.wav"
	_play_from(_voice_pool, _stream(path), randf_range(0.92, 1.08))


## The single place where the music track is swapped (with a fade).
func play_music(track: String, fade := 1.5) -> void:
	_swap(_music, MUSIC_DIR + track + ".wav", fade, 0.0)


func play_ambient(track: String, fade := 2.0) -> void:
	_swap(_ambient, MUSIC_DIR + track + ".wav", fade, -10.0)


func set_volume(bus: String, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	_apply(bus)
	_save_settings()


func set_muted(bus: String, value: bool) -> void:
	muted[bus] = value
	_apply(bus)
	_save_settings()


func _swap(player: AudioStreamPlayer, path: String, fade: float, target_db: float) -> void:
	var stream := _stream(path)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / 2  # 16 bits mono
	player.stream = stream
	player.volume_db = -60.0
	player.play()
	create_tween().tween_property(player, "volume_db", target_db, fade)


func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
		if _cache[path] == null:
			push_warning("Audio not found: %s" % path)
	return _cache[path]


func _play_from(pool: Array[AudioStreamPlayer], stream: AudioStream, pitch: float) -> void:
	if stream == null:
		return
	for p in pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch
			p.play()
			return
	pool[0].stream = stream
	pool[0].pitch_scale = pitch
	pool[0].play()


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")


func _apply_all() -> void:
	for b in BUSES:
		_apply(b)


func _apply(bus: String) -> void:
	var idx := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volumes[bus], 0.0001)))
	AudioServer.set_bus_mute(idx, muted[bus])


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for b in BUSES:
		volumes[b] = cfg.get_value("volume", b, volumes[b])
		muted[b] = cfg.get_value("muted", b, muted[b])


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for b in BUSES:
		cfg.set_value("volume", b, volumes[b])
		cfg.set_value("muted", b, muted[b])
	cfg.save(SETTINGS_PATH)
