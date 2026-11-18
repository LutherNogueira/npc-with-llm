extends Node2D
## Cut-out NPC puppet assembled from parts (placeholder). Final art replaces only
## this scene. `emotion` drives the face color; `gesture` drives an animation.

const EMOTION_COLORS := {
	"neutral": Color("e8d5b0"),
	"mysterious": Color("c9b8e8"),
	"amused": Color("f2d98a"),
	"annoyed": Color("e89a8a"),
	"curious": Color("a8e0d0"),
}

var _head: Polygon2D
var _mouth: Polygon2D
var _arm_r: Polygon2D
var _body: Polygon2D
var _anim: AnimationPlayer


func _ready() -> void:
	_body = _part("Body", PackedVector2Array([Vector2(-50, 0), Vector2(50, 0), Vector2(70, 220), Vector2(-70, 220)]), Color("1e1233"), Vector2.ZERO)
	_arm_r = _part("ArmR", PackedVector2Array([Vector2(0, 0), Vector2(22, 0), Vector2(30, 120), Vector2(8, 120)]), Color("140b24"), Vector2(46, 10))
	_head = _part("Head", PackedVector2Array([Vector2(-38, -80), Vector2(38, -80), Vector2(44, 0), Vector2(-44, 0)]), EMOTION_COLORS["mysterious"], Vector2(0, -6))
	_part("Hood", PackedVector2Array([Vector2(-50, -90), Vector2(50, -90), Vector2(40, -70), Vector2(-40, -70)]), Color("1d1433"), Vector2(0, -6))
	_part("EyeL", PackedVector2Array([Vector2(-4, -3), Vector2(4, -3), Vector2(4, 3), Vector2(-4, 3)]), Color("111111"), Vector2(-16, -45))
	_part("EyeR", PackedVector2Array([Vector2(-4, -3), Vector2(4, -3), Vector2(4, 3), Vector2(-4, 3)]), Color("111111"), Vector2(16, -45))
	_mouth = _part("Mouth", PackedVector2Array([Vector2(-12, -2), Vector2(12, -2), Vector2(12, 2), Vector2(-12, 2)]), Color("5a2a2a"), Vector2(0, -18))
	_build_animations()
	_anim.play("idle")


func apply_response(data: Dictionary) -> void:
	var c: Color = EMOTION_COLORS.get(data["emotion"], EMOTION_COLORS["neutral"])
	create_tween().tween_property(_head, "color", c, 0.4)
	var g: String = data["gesture"]
	if g != "none" and _anim.has_animation(g):
		_anim.play(g)
		if not _anim.animation_finished.is_connected(_back_to_idle):
			_anim.animation_finished.connect(_back_to_idle)


func set_talking(active: bool) -> void:
	var t := create_tween()
	t.tween_property(_mouth, "scale:y", 4.0 if active else 1.0, 0.1)
	if active:
		t.set_loops()
		t.tween_property(_mouth, "scale:y", 1.5, 0.12)
		t.tween_property(_mouth, "scale:y", 4.0, 0.12)


func _back_to_idle(_name: StringName) -> void:
	_anim.play("idle")


func _part(part_name: String, poly: PackedVector2Array, color: Color, pos: Vector2) -> Polygon2D:
	var p := Polygon2D.new()
	p.name = part_name
	p.polygon = poly
	p.color = color
	p.position = pos
	add_child(p)
	return p


func _build_animations() -> void:
	_anim = AnimationPlayer.new()
	add_child(_anim)
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _clip(2.0, true, [["Body:position:y", [0.0, 3.0, 0.0]], ["Head:position:y", [-6.0, -3.0, -6.0]]]))
	lib.add_animation("wave", _clip(1.0, false, [["ArmR:rotation", [0.0, -2.2, -1.6, -2.2, 0.0]]]))
	lib.add_animation("whisper", _clip(1.2, false, [["Head:rotation", [0.0, 0.25, 0.25, 0.0]]]))
	lib.add_animation("laugh", _clip(1.0, false, [["Body:position:y", [0.0, -8.0, 0.0, -8.0, 0.0]]]))
	lib.add_animation("vanish", _clip(1.5, false, [["Body:position:y", [0.0, 0.0, 0.0]], ["Head:rotation", [0.0, -0.2, 0.0]]]))
	_anim.add_animation_library("", lib)


## tracks: [[node_path, [evenly spaced key values]], ...]
func _clip(length: float, loop: bool, tracks: Array) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for tr in tracks:
		var idx := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(idx, NodePath(tr[0]))
		var vals: Array = tr[1]
		for i in vals.size():
			a.track_insert_key(idx, length * float(i) / float(vals.size() - 1), vals[i])
	return a
