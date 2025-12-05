extends Camera2D

@onready var parking_lot: Node2D = $"../Parking lot"

func correct_position():
	var objects = parking_lot.places
	if objects.is_empty():
		return Vector2.ZERO

	var sum := Vector2.ZERO
	for obj in objects:
		sum += obj.global_position

	global_position = sum / objects.size()
