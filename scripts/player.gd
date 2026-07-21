extends Node2D
class_name Player
## Player — simple top-down movement using Godot's built-in ui_* actions
## (arrow keys by default). No wall collision yet; movement is clamped to
## `bounds`. Wall collision is tracked as a Public Demo milestone issue.

@export var speed: float = 220.0

var can_move: bool = true
var bounds: Rect2 = Rect2(0, 0, 1280, 720)

var _body: ColorRect


func _ready() -> void:
	# Visual placeholder — a lantern-lit figure. Real sprite comes later.
	_body = ColorRect.new()
	_body.color = Color("#e8c9a0")
	_body.size = Vector2(28, 40)
	_body.position = Vector2(-14, -40)
	add_child(_body)

	var lantern := ColorRect.new()
	lantern.color = Color("#ffd466")
	lantern.size = Vector2(10, 10)
	lantern.position = Vector2(10, -18)
	add_child(lantern)


func _physics_process(delta: float) -> void:
	if not can_move:
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir == Vector2.ZERO:
		return
	var target := position + dir * speed * delta
	position.x = clampf(target.x, bounds.position.x, bounds.position.x + bounds.size.x)
	position.y = clampf(target.y, bounds.position.y, bounds.position.y + bounds.size.y)
