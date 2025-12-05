extends Node2D

@onready var main: Node = get_parent()

const PLACE = preload("uid://bimhghgrqh5j7")

var places: Array[Place] = []

var separation: int = 100
var newline: int = 20

@export var car_spawn: Node2D
@export var car_exit: Node2D

@export var places_count: int = 0:
	set(value):
		if value == places_count:
			return

		places_count = max(value, 0)
		if is_inside_tree():
			_update_places()


func _ready() -> void:
	_update_places()

func _update_places() -> void:
	while places.size() > places_count:
		var p: Place = places.pop_back()
		if is_instance_valid(p):
			p.queue_free()

	while places.size() < places_count:
		var p: Place = PLACE.instantiate()
		p.place_status_changed.connect(_on_place_status_changed)
		add_child(p)
		places.append(p)

	for i in range(places.size()):
		var row := i / newline
		var col := i % newline
		var pos := Vector2(col * separation, row * (separation * 2.5))
		places[i].position = pos

	var a_pos: Vector2 = avg_pos()
	a_pos.y = a_pos.y / 2

	var min_x: float = INF
	var max_x: float = -INF

	for p in places:
		min_x = min(min_x, p.position.x)
		max_x = max(max_x, p.position.x)

	if is_instance_valid(car_spawn) and is_instance_valid(car_exit):
		car_spawn.global_position = Vector2(min_x - 1000, a_pos.y)
		car_exit.global_position = Vector2(max_x + 1000, a_pos.y)


func avg_pos() -> Vector2:
	if places.is_empty():
		return Vector2.ZERO

	var sum := Vector2.ZERO
	for obj in places:
		sum += obj.global_position

	return sum / places.size()


func _on_place_status_changed() -> void:
	if main and main.has_method("check_queue"):
		main.check_queue()
