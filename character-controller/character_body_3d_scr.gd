extends CharacterBody3D


# Настраиваемые параметры
var speed
@export var default_move_speed: float = 7
@export var crouch_move_speed: float = 4
@export var crouch_speed: float = 20
var default_height: float = 2
var crouch_height: float = 1
@export var weight_speed: float = 0.3
@export var jump_velocity: float = 4.5
# Гравитация обычно берется из настроек проекта, но можно задать и свою
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var mouse_sensitivity: float = 0.01
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var mesh_pivot: Node3D =   $CollisionShape3D/MeshInstance3D# Узел с моделькой персонажа
@onready var collision_shape = $CollisionShape3D
var is_crouching: bool = false
var want_up: bool = false
var original_mesh_scale


# В скрипте персонажа (например, player.gd)
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Исключаем коллизию самого игрока
	spring_arm.add_excluded_object(get_rid())
	# Сохраняем исходный масштаб модели
	original_mesh_scale = mesh_pivot.scale.y

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Вращаем SpringArm мышкой
		spring_arm.rotation_degrees.x -= event.relative.y * mouse_sensitivity
		spring_arm.rotation_degrees.x = clamp(spring_arm.rotation_degrees.x, -90.0, 30.0)
		# =========================
		# Горизонтальный поворот (вращаем всего персонажа вокруг оси Y)
		#rotate_y(-event.relative.x * mouse_sensitivity)
		# =========================
		# если хотим вращать камеру отдельно от персонажа
		spring_arm.rotation_degrees.y -= event.relative.x * mouse_sensitivity
		# wrapf для плавного перехода через 360 градусов
		spring_arm.rotation_degrees.y = wrapf(spring_arm.rotation_degrees.y, 0.0, 360.0)
		# =========================
		
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Обработка приседания
	if event.is_action_pressed("crouch"):  # Нужно настроить в Input Map
		is_crouching = true
		want_up = false
	if event.is_action_released("crouch"):
		want_up= true

func _physics_process(delta: float) -> void:
	speed = default_move_speed
	# 1. Получаем вектор ввода (WASD или стрелки)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Преобразуем ввод в направление относительно персонажа (чтобы W всегда был "вперед по взгляду")
	# =========================
	## для персонажа соедененного с камерой
	## 1.1 Для этого нужно получить глобальный базис объекта персонаж (игнорируем наклон по X)
	#var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
#
	## 2. Горизонтальное движение
	#if direction:
		#velocity.x = lerp(velocity.x, direction.x * speed, weight_speed)
		#velocity.z = lerp(velocity.z, direction.z * speed, weight_speed) 
	#else:
		#velocity.x = lerp(velocity.x, move_toward(velocity.x, 0, speed), weight_speed) 
		#velocity.z = lerp(velocity.z, move_toward(velocity.z, 0, speed), weight_speed)  
		
	# =========================
	# для персонажа отдельно от камеры
	# 1.1б Для этого нужно получить глобальный базис камеры (игнорируем наклон по X)	
	var direction = (spring_arm.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	# 2.б Горизонтальное движение
	if direction.length() > 0:
		# Движение
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		# Плавный поворот персонажа в сторону движения
		var target_angle = atan2(-direction.x, -direction.z)
		mesh_pivot.rotation.y = lerp_angle(mesh_pivot.rotation.y, target_angle, 0.1)
	else:
		# Торможение
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	# =========================

	
	# Реализуем приседания
	update_crouch(delta)

	# 3. Вертикальная составляющая (гравитация и прыжок)
	# Применяем гравитацию
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Обработка прыжка (если на полу и нажата клавиша прыжка)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# 4. Двигаем персонажа
	move_and_slide()
	
func can_stand_up() -> bool:
	# Проверяем, есть ли место над головой, чтобы встать
	if not collision_shape.shape is CapsuleShape3D:
		return true
	
	# Создаем проверочную форму на полную высоту
	var space_state = get_world_3d().direct_space_state
	var params = PhysicsShapeQueryParameters3D.new()
	
	# Используем ту же форму, но с полной высотой
	var check_shape = collision_shape.shape.duplicate()
	check_shape.height = default_height
	check_shape.radius = crouch_height  # Радиус не меняем
	
	params.shape = check_shape
	
	# ВАЖНО: Центр проверочной формы должен быть на половине полной высоты
	# от пола (текущая позиция персонажа)
	var check_position = global_position
	check_position.y += default_height / 2.0
	
	params.transform = Transform3D.IDENTITY.translated(check_position)
	params.collision_mask = collision_mask
	params.exclude = [self]
	
	var results = space_state.intersect_shape(params)
	return results.is_empty()

func update_crouch(delta):
	if want_up:
		if can_stand_up():
			want_up = false
			is_crouching = false
	if is_crouching:
		collision_shape.shape.height =move_toward(collision_shape.shape.height, crouch_height, 
		crouch_speed * delta)
		collision_shape.position.y = move_toward(collision_shape.position.y, 
		crouch_height/2, crouch_speed * delta)
		speed = crouch_move_speed
		mesh_pivot.scale.y = lerp(mesh_pivot.scale.y, original_mesh_scale*crouch_height/default_height,crouch_speed * delta)
	else:
		collision_shape.shape.height =move_toward(collision_shape.shape.height, default_height, 
		crouch_speed * delta)
		collision_shape.position.y = move_toward(collision_shape.position.y, 
		default_height/2, crouch_speed * delta)
		mesh_pivot.scale.y = lerp(mesh_pivot.scale.y, original_mesh_scale,crouch_speed * delta)
