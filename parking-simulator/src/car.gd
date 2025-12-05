@tool
extends Node2D
class_name Car

# Приоритет машины при разборе очереди.
# Чем меньше число – тем выше приоритет (см. sort_custom в main.gd).
@export var priority : int = 0

@export_category('Stay time (seconds)')
# Минимальное время стоянки (в секундах)
@export var min_stay_time : int = 10
# Максимальное время стоянки (в секундах)
@export var max_stay_time : int = 100

@export_category('car customization')
# Флаг: если true – машина при старте получит случайный цвет
@export var random_color : bool = false
# Цвет машины, если random_color == false.
# При изменении цвета сразу перекрашиваем спрайт CarColor.
@export var color : Color = Color(1,1,1) : 
	set(v):
		color = v
		$CarBody/CarColor.modulate = color

# Время стоянки для конкретного экземпляра машины задаётся случайно
# в диапазоне [min_stay_time; max_stay_time] при создании.
@onready var stay_time : int = randi_range(min_stay_time,max_stay_time)

# Скорость движения вперёд (пикселей в секунду)
var speed : float = 400
# Скорость поворота (градусов в секунду)
var rotation_speed : float = 180

# Маршрут движения машины в виде списка точек (waypoints)
var trip : Array[Vector2]
# Позиция выезда с парковки (назначается снаружи из main.gd)
var exit_pos : Vector2

@export_category('AI')
# Целевое парковочное место для машины.
# При установке этого свойства машина автоматически:
# 1) логирует назначение места
# 2) едет по маршруту до места
# 3) ждёт stay_time секунд
# 4) логирует выезд
# 5) едет к выезду и освобождает место
@export var place : Place :
	set(v):
		place = v
		# В редакторе не запускаем игровую логику
		if Engine.is_editor_hint(): return
		
		# Логируем назначение парковочного места
		Journal.log_message('ASSIGN_PLACE;'+name+';')
		
		# Строим маршрут до парковочного места:
		# 1) текущая позиция
		# 2) подъезд по вертикали к уровню места
		# 3) смещение по горизонтали
		# 4) конечная точка – позиция места
		trip.append(global_position)
		trip.append(Vector2(global_position.x,place.global_position.y + 100))
		trip.append(Vector2(place.global_position.x,place.global_position.y + 100))
		trip.append(place.global_position)
		
		# Едем по маршруту до места (корутина с await)
		await go_on_trip()
		
		# Ждём время стоянки
		await get_tree().create_timer(stay_time,false).timeout
		
		# Логируем выезд с места
		Journal.log_message('DEPART;'+name+';')
		
		# Строим маршрут от места к точке выезда
		trip.clear()
		trip.append(global_position)
		trip.append(global_position - Vector2(0,100))
		trip.append(Vector2(exit_pos.x,global_position.y - 100))
		trip.append(exit_pos)
		
		# Освобождаем место (отмечаем как свободное)
		if is_instance_valid(place): 
			place.occupied = false
		
		# Стартуем движение к выезду (без ожидания завершения)
		go_on_trip()
		

func _ready() -> void:
	# В редакторе не выполняем игровую инициализацию
	if !Engine.is_editor_hint():
		# Случайный цвет для машины, если включен random_color
		if random_color:
			$CarBody/CarColor.modulate = Color(
				randf_range(0,1),
				randf_range(0,1),
				randf_range(0,1)
			)
		
		# Добавляем случайный суффикс к имени, чтобы у машин были уникальные ID
		name = name + str(randi() % 1000000)
		
		# Логируем прибытие машины
		Journal.log_message('ARRIVE;'+name+';')


# Корутина, которая последовательно проходит по всем точкам trip.
# Для каждого участка:
# 1) создаётся tween на позицию
# 2) создаётся tween на поворот в сторону движения
# 3) ждём завершения tween и переходим к следующей точке
func go_on_trip():
	for p in trip:
		var t : = create_tween()
		t.set_parallel(true)
		
		# Вектор от текущей позиции к точке p
		var dir : Vector2 = global_position - p
		var ang : float = dir.normalized().angle()
		
		# Время движения до точки p зависит от расстояния и скорости
		t.tween_property(self,'global_position',p,dir.length()/speed)
		
		# Считаем разницу углов кратчайшим путём
		var diff : float = wrapf(ang - rotation, -PI, PI)
		# Финальный угол поворота
		var final_rot : float = rotation + diff
		# Время поворота зависит от разницы углов и скорости вращения
		var duration : float = abs(rad_to_deg(diff)) / rotation_speed

		t.tween_property(self, "rotation", final_rot, duration)

		# Ждём завершения обоих tween'ов
		await t.finished
	
	return 1
