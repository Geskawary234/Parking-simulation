extends Control

# Ссылка на узел с парковочными местами.
@onready var parking_lot: Node2D = $"../../../Parking lot"

# Текстовая консоль для отображения последних строк журнала.
@onready var console_text: RichTextLabel = $EventLog/ConsoleText

# Слайдер зума камеры.
@onready var zoom: HSlider = $zoom
func zoom_changed(v : float):
	# Масштабируем камеру по обоим осям.
	$"../..".zoom = Vector2(v,v)

# Слайдер количества мест на парковке.
@onready var places_slider: HSlider = $SimulationSettings/PlacesSlider
# Ссылка на камеру для корректировки позиции.
@onready var camera_2d: Camera2D = $"../.."
func places_slider_changed(v : float):
	# Обновляем число мест на парковке.
	parking_lot.places_count = v
	# Подстраиваем позицию камеры под новую конфигурацию.
	camera_2d.correct_position()


# Слайдер временного масштаба (скорости симуляции).
@onready var time_scale: HSlider = $TimeScale
@onready var ts_lab: Label = $TimeScale/Label

func time_scale_changed(v : float):
	# Меняем глобальный time_scale движка.
	Engine.time_scale = v
	# Обновляем подпись под слайдером.
	ts_lab.text = 'Скорость симуляции: '+str(int(v))+'x'
	
	

# Таймер генерации машин и слайдер λ(t).
@onready var next_car_timer: Timer = $"../../../NextCarTimer"
@onready var lambda: HSlider = $SimulationSettings/lambda
@onready var lambda_lab: Label = $SimulationSettings/Label2

func lambda_changed(v : float):
	# Переустанавливаем период генерации машин по λ (машин/час).
	next_car_timer.wait_time = 3600 / v
	# Обновляем подпись с текущим значением λ.
	lambda_lab.text =  'λ(t)\n'+str(int(v))+' Машин / час'
	

# Ссылка на основной скрипт симуляции (main.gd).
@onready var main: Node2D = $"../../.."
# Кнопка "Старт/Рестарт".
@onready var start_restart_btn: Button = $"HBoxContainer/Start_Restart btn"

# Флаг, что симуляция уже запускалась.
var simulation_launched : bool = false

# Обработчик кнопки "Старт/Рестарт".
func start_rest_btn_pressed():
	if simulation_launched:
		# Если симуляция уже шла – перезагружаем сцену полностью.
		get_tree().reload_current_scene()
	else:
		# Первый запуск симуляции.
		simulation_launched = true
		pause.disabled = false
		time_scale.editable = true
		places_slider.editable = false
		start_restart_btn.text = 'Рестарт'
		
		# Запускаем симуляцию в main.gd.
		main.start_sim()
	
	

# Кнопка "Пауза/Продолжить".
@onready var pause: Button = $HBoxContainer/Pause
func pause_toggle():
	# Инвертируем состояние паузы дерева.
	get_tree().paused = !get_tree().paused
	
	# Обновляем текст на кнопке.
	if get_tree().paused:
		pause.text = 'Продолжить'
	else:
		pause.text = 'Пауза'

# Кнопка выхода.
@onready var exit: Button = $HBoxContainer/Exit


# Вспомогательная функция:
# переводит количество секунд в ["HH:MM", дни].
func format_time_with_days(s: float) -> Array:
	var seconds := int(s)
	var days : int = seconds / 86400
	var day_seconds : int = seconds % 86400

	var hours : int = day_seconds / 3600
	var minutes : int = (day_seconds % 3600) / 60

	return ["%02d:%02d" % [hours, minutes], days]


# Текстовый блок для отображения метрик.
@onready var metrics_text: Label = $Metrics/MetricsText

# Обновление блока метрик (число мест, занятость, время, длина очереди).
func update_metrix():
	var s := ''
	
	# Переводим время симуляции в формат HH:MM и количество дней.
	var time_days : = format_time_with_days(main.time)
	
	# Считаем количество занятых мест.
	var occ_places : int = 0
	for p in parking_lot.places:
		if p.occupied: 
			occ_places += 1
	
	s += 'Число мест: '+str(int(places_slider.value))
	s += '\nЗанято мест: '+str(occ_places)
	s += '\n\nВремя симуляции:\n'+str(time_days[0])+'\n'+str(time_days[1]) + ' Дней'
	s += '\n\nМашин в очереди: '+str(len(main.queue))
	
	metrics_text.text = s
	

# Максимальное количество строк, отображаемых в UI-консоли.
const MAX_UI_LINES := 100
# Локальный буфер последних строк журнала для вывода в консоль.
var _lines: Array[String] = []


func _ready() -> void:
	# Подписываем UI-элементы на свои обработчики.
	places_slider.value_changed.connect(places_slider_changed)
	zoom.value_changed.connect(zoom_changed)
	time_scale.value_changed.connect(time_scale_changed)
	lambda.value_changed.connect(lambda_changed)
	start_restart_btn.pressed.connect(start_rest_btn_pressed)
	pause.pressed.connect(pause_toggle)
	open_log_folder_button.pressed.connect(_on_open_log_folder_button_pressed)
	
	# Подписываемся на сообщения журнала.
	# Каждое новое сообщение:
	# 1) добавляется в локальный буфер
	# 2) обновляет текст консоли
	# 3) обновляет метрики
	Journal.message_added.connect(func(msg : String):
		_lines.append(msg)
		if _lines.size() > MAX_UI_LINES:
			_lines.pop_front()

		# Пересобираем текст только из последних строк.
		console_text.text = "\n".join(_lines)
		# Прокручиваем консоль к последней строке.
		console_text.scroll_to_line(console_text.get_line_count() - 1)
		
		# Обновляем метрики на экране.
		update_metrix()
	)
		
	# При нажатии на "Выход":
	# 1) дожидаемся сброса журнала в файл
	# 2) закрываем игру
	exit.pressed.connect(
		func(): 
			await Journal.flush_all()
			get_tree().quit()
	)
		

# Показ FPS в правом нижнем углу.
@onready var fps: Label = $FPS
func _process(delta: float) -> void:
	fps.text = 'FPS: '+str(Engine.get_frames_per_second())


# Кнопка "Открыть папку с логами".
@onready var open_log_folder_button: Button = $Metrics/Button

# Открывает системный файловый менеджер в папке, где лежит лог-файл.
func _on_open_log_folder_button_pressed() -> void:
	var dir_path = Journal.get_log_dir_global()
	OS.shell_open(dir_path)
