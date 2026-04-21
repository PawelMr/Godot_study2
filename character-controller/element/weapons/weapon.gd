extends Node3D
class_name Weapon

# --------------------- Параметры оружия ---------------------
## имя оружия
@export var weapon_name: String = "Pistol"
## урон 
@export var damage: int = 34
## максимум патронов 
@export var max_ammo: int = 12
## текущее количество патронов
@export var current_ammo: int = 12
## задержка до следующего выстрела
@export var fire_rate: float = 0.2  # секунд между выстрелами
## время перезарядки
@export var reload_time: float = 1.5
## дальность оружия
@export var range: float = 100.0

# Визуальные/аудио эффекты
## звук выстрела
@export var shoot_sound: AudioStream
## щелчок при пустом магазине
@export var dry_fire_sound: AudioStream  
## вспышка
@export var muzzle_flash: PackedScene  # опционально

## направление стрельбы
@export var ray_cast: RayCast3D = null
## место выстела(вмпышки) /марка
@export var muzzle: Marker3D = null
## нода аудио плеера для выстрела и других эффуктов
@export var shoot_audio: AudioStreamPlayer3D = null
## таймер для перезарядки
@export var reload_timer: Timer = null

# Состояния
var can_shoot: bool = true
var is_reloading: bool = false

# Сигналы для связи с Player
signal ammo_changed(current_ammo, max_ammo)
#signal reload_started()
#signal reload_finished()
signal weapon_fired(direction, origin, hit_position, hit_normal, hit_object, damage)

# --------------------- Инициализация ---------------------
func _ready():
	ray_cast.target_position = Vector3(0, 0, range)
	ray_cast.collision_mask = 3  # Маска для врагов (настройте по своему слою)
	update_ammo_signal()

func update_ammo_signal():
	ammo_changed.emit(current_ammo, max_ammo)

# --------------------- Основная логика ---------------------
func shoot(direction: Vector3, origin: Vector3) -> void:
	# Проверки перед выстрелом
	if not can_shoot or is_reloading:
		return
	
	# Патронов нет
	if current_ammo <= 0:
		play_dry_fire()
		return
	
	# Производим выстрел
	current_ammo -= 1
	update_ammo_signal()
	
	# Запускаем откат (fire rate)
	can_shoot = false
	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true
	
	# 1. Визуал и звук на оружии
	play_shoot_effects()
	
	# 2. Фиксируем попадание (RayCast в локальном пространстве оружия)
	var hit_position: Vector3
	var hit_normal: Vector3
	var hit_object: Node = null
	var did_hit: bool = false
	
	ray_cast.force_raycast_update()
	if ray_cast.is_colliding():
		did_hit = true
		hit_position = ray_cast.get_collision_point()
		hit_normal = ray_cast.get_collision_normal()
		hit_object = ray_cast.get_collider()
	
	# 3. Отправляем сигнал с полными данными о выстреле
	weapon_fired.emit(
		direction,           # направление от камеры/игрока
		origin,              # позиция откуда стреляем (глобальная)
		hit_position,
		hit_normal,
		hit_object,
		damage if did_hit else 0
	)

# --------------------- Перезарядка ---------------------
func start_reload() -> void:
	if is_reloading or current_ammo == max_ammo:
		return
	
	is_reloading = true
	can_shoot = false
	#reload_started.emit()  # Триггер анимации на Player
	
	reload_timer.start(reload_time)
	await reload_timer.timeout
	
	# Завершаем перезарядку
	current_ammo = max_ammo
	update_ammo_signal()
	is_reloading = false
	can_shoot = true
	#reload_finished.emit()

# --------------------- Вспомогательные эффекты ---------------------
func play_shoot_effects():
	if shoot_sound and shoot_audio:
		shoot_audio.stream = shoot_sound
		shoot_audio.play()
	
	# Эффект вспышки (пример)
	if muzzle_flash:
		var flash = muzzle_flash.instantiate()
		muzzle.add_child(flash)
		flash.global_position = muzzle.global_position
		await get_tree().create_timer(0.05).timeout
		flash.queue_free()

func play_dry_fire():
	if dry_fire_sound and shoot_audio:
		shoot_audio.stream = dry_fire_sound
		shoot_audio.play()

# --------------------- API для инвентаря / смены оружия ---------------------
func reset_weapon_state():
	can_shoot = true
	is_reloading = false
	if reload_timer.is_stopped() == false:
		reload_timer.stop()

func set_ammo(amount: int):
	current_ammo = clamp(amount, 0, max_ammo)
	update_ammo_signal()
