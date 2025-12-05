extends Node2D
class_name Place

# Сигнал срабатывает при изменении занятости места.
# Можно использовать, чтобы реагировать на освобождение/занятие места.
signal place_status_changed()

# Флаг, занято ли место машиной.
@export var occupied : bool = false :
	set(v):
		occupied = v
		# Уведомляем подписчиков, что статус места изменился.
		place_status_changed.emit()
