extends CharacterBody3D


# Настраиваемые параметры
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
# Гравитация обычно берется из настроек проекта, но можно задать и свою
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var mouse_sensitivity: float = 0.01
@onready var spring_arm: SpringArm3D = $SpringArm3D

# В скрипте персонажа (например, player.gd)
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Исключаем коллизию самого игрока
	spring_arm.add_excluded_object(get_rid())

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Вращаем SpringArm мышкой
		spring_arm.rotation_degrees.x -= event.relative.y * mouse_sensitivity
		spring_arm.rotation_degrees.x = clamp(spring_arm.rotation_degrees.x, -90.0, 30.0)
		# Горизонтальный поворот (вращаем всего персонажа вокруг оси Y)
		rotate_y(-event.relative.x * mouse_sensitivity)
		
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	# 1. Получаем вектор ввода (WASD или стрелки)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Преобразуем ввод в направление относительно камеры (чтобы W всегда был "вперед по взгляду")
	# Для этого нужно получить глобальный базис камеры (игнорируем наклон по X)
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# 2. Горизонтальное движение
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# 3. Вертикальная составляющая (гравитация и прыжок)
	# Применяем гравитацию
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Обработка прыжка (если на полу и нажата клавиша прыжка)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# 4. Двигаем персонажа
	move_and_slide()
