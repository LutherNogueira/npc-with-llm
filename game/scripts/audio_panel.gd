extends VBoxContainer
## Audio section of the settings menu: volume and mute for Music, SFX and NPC voice.

const LABELS := {
	"pt": {"Music": "Música", "SFX": "Efeitos", "Voice": "Voz do NPC"},
	"en": {"Music": "Music", "SFX": "Effects", "Voice": "NPC voice"},
}

var _name_labels := {}


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	for bus in Audio.BUSES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.custom_minimum_size = Vector2(120, 0)
		_name_labels[bus] = label
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = Audio.volumes[bus]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(func(v: float) -> void: Audio.set_volume(bus, v))
		row.add_child(slider)
		var mute := CheckBox.new()
		mute.text = "M"
		mute.button_pressed = Audio.muted[bus]
		mute.toggled.connect(func(on: bool) -> void: Audio.set_muted(bus, on))
		row.add_child(mute)
		add_child(row)
	set_labels(NpcClient.language)


func set_labels(lang: String) -> void:
	for bus in _name_labels:
		_name_labels[bus].text = LABELS[lang][bus]
