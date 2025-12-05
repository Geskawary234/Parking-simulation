extends Node2D

# Текущее "игровое" время симуляции (в секундах).
# Используется Journal'ом для отметки времени событий.
var time : float = 0

# Ссылка на узел с парковочными местами.
@onready var parking_lot: Node2D = $"Parking lot"
# Таймер генерации следующей машины (интенсивность λ).
@onready var next_car_timer: Timer = $NextCarTimer
# Таймер для периодической проверки очереди (сейчас не используется).
@onready var queue_timer: Timer = $QueueTimer
# Узел-контейнер для всех машин на сцене.
@onready var objects: Node = $Objects
# Позиция появления машин.
@onready var car_spawn: Node2D = $CarSpawn
# Позиция выезда машин.
@onready var car_exit: Node2D = $CarExit


# Преподгруженные сцены разных типов машин.
const RESIDENT = preload("uid://cexrj8ocecllb")
const GUEST = preload("uid://cnoofrn4nqt5g")
const DISABLED = preload("uid://8rfsr0hga0iy")
const TAXI = preload("uid://cdw08uyxegwuk")

# Массив типов машин для случайного выбора.
var cars : Array[PackedScene] = [
	RESIDENT,
	GUEST,
	DISABLED,
	TAXI
]

# Очередь машин, ожидающих свободного места на парковке.
var queue : Array[Car]

# Слайдер λ(t) – интенсивность входящего потока (машин/час).
@onready var lambda: HSlider = $Camera2D/CanvasLayer/UI/SimulationSettings/lambda


func _ready() -> void:
	# При срабатывании таймера спауним машину и сразу пытаемся разобрать очередь.
	next_car_timer.timeout.connect(func():
		spawn_car()
		check_queue()
	)
	
	# Можно включить, если нужно отдельное периодическое обслуживание очереди.
	#queue_timer.timeout.connect(check_queue)


# Флаг, что симуляция запущена.
var sim_started : bool = false

# Старт симуляции:
# 1) настраиваем период появления машин по λ
# 2) запускаем таймер генерации
func start_sim():
	# λ – машин в час, поэтому период = 3600 / λ (секунд между приездами).
	next_car_timer.wait_time = 3600 / lambda.value
	next_car_timer.start()
	#queue_timer.start()
	sim_started = true


# Создаёт новую машину и ставит её в очередь.
func spawn_car():
	# Выбираем случайный тип машины и создаём экземпляр.
	var c : Car = cars.pick_random().instantiate()
	# Передаём машине позицию выезда.
	c.exit_pos = car_exit.global_position
	objects.add_child(c)
	# Ставим машину в точку спавна.
	c.global_position = car_spawn.global_position
	
	# Добавляем её в очередь ожидания.
	queue.append(c)
	
	# Логируем постановку в очередь (QUEUE_WAIT).
	Journal.log_message('QUEUE_WAIT;'+c.name+';')


# Обслуживание очереди:
# 1) сортируем машины по приоритету
# 2) для каждого свободного места выбираем машину из начала очереди
func check_queue():
	# Если в очереди больше одной машины – сортируем по приоритету.
	if len(queue) > 1:
		queue.sort_custom(func(a, b):
			return a.priority < b.priority
		)
	
	# Проходим по всем местам на парковке.
	for p in parking_lot.places:
		# Если место свободно и в очереди есть машины – назначаем машину на это место.
		if !p.occupied:
			if len(queue) > 0:
				var car : Car = queue[0]
				# Назначаем машине это место (запустит её движение и стоянку).
				car.place = p
				# Убираем машину из очереди.
				queue.remove_at(0)
				# Помечаем место как занятое.
				p.occupied = true
				
				# Логируем взятие машины из очереди.
				Journal.log_message('TAKE_FROM_QUEUE;' + car.name+';')
				

# Обновление времени симуляции и передачи его в Journal.
func _process(delta: float) -> void:
	if !get_tree().paused and sim_started:
		time += delta
		Journal.time = time
