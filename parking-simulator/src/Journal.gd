extends Node

# Сигнал — отправляется каждый раз, когда в журнал добавляется новая строка.
# UI подписывается на этот сигнал и обновляет консоль.
signal message_added(new_message: String)

# Текущее время симуляции (в секундах).
# Обновляется из main.gd, используется для отметки времени в логах.
var time: float = 0.0

# Буфер последних записей для хранения в памяти.
# Используется для UI и периодического сброса в файл.
var journal: Array[String] = []

# Максимальный размер буфера в памяти.
# При достижении этого размера журнал сбрасывается в файл.
const MAX_BUFFER := 50

# Путь к файлу для логирования (с датой и временем в имени).
var LOG_PATH := ""   # Заполняется в _ready()


func _ready() -> void:
	# Формируем имя файла лога при запуске симуляции.
	LOG_PATH = _make_log_filename()


# Формирует имя файла с использованием текущей даты/времени:
# пример: user://parking_log_2025-02-05_23-14-08.csv
func _make_log_filename() -> String:
	var d = Time.get_date_dict_from_system()
	var t = Time.get_time_dict_from_system()

	var name = "parking_log_%04d-%02d-%02d_%02d-%02d-%02d.csv" % [
		d.year, d.month, d.day,
		t.hour, t.minute, t.second
	]

	return "user://%s" % name


# Добавляет новую строку в журнал.
# message ожидается в формате "EVENT;CarName;..."
func log_message(message: String) -> void:
	# Добавляем к сообщению время симуляции, округлённое до 0.1 секунды.
	var msg := "%s %.1f" % [message, snapped(time, 0.1)]
	journal.append(msg)
	
	# Уведомляем UI о новой строчке.
	message_added.emit(msg)

	# Если буфер переполнен – сбрасываем в файл.
	if journal.size() >= MAX_BUFFER:
		_flush_to_file()


# Принудительный сброс буфера в файл.
# Вызывается, например, при выходе из игры.
func flush_all() -> void:
	_flush_to_file()


# Внутренняя функция: записывает все строки из буфера в файл и очищает буфер.
func _flush_to_file() -> void:
	if journal.is_empty():
		return

	var file: FileAccess

	# Если файл уже существует – открываем на чтение/запись и переходим в конец.
	if FileAccess.file_exists(LOG_PATH):
		file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
		if file == null:
			push_error("Journal: cannot open file: %s" % LOG_PATH)
			return
		file.seek_end()
	else:
		# Если файла нет – создаём новый.
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
		if file == null:
			push_error("Journal: cannot create file: %s" % LOG_PATH)
			return

	# Записываем каждую строку журнала в файл как отдельную строку текста.
	for line in journal:
		file.store_string(line + "\n")

	file.flush()
	file = null

	# Очищаем буфер в памяти.
	journal.clear()


# Возвращает абсолютный путь к текущему лог-файлу (для ОС).
func get_log_file_path_global() -> String:
	return ProjectSettings.globalize_path(LOG_PATH)

# Возвращает абсолютный путь к папке, в которой лежит лог-файл.
func get_log_dir_global() -> String:
	var file_path := get_log_file_path_global()
	return file_path.get_base_dir()
