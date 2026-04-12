extends CharacterBody3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var default_move_speed: float = 7
@export var crouch_move_speed: float = 5
@export var crouch_speed: float = 2

# Ускорение персонажа ( как быстро наберет скорость или остановится)
@export var weight_speed: float =15
# скорость поворота
@export var turn_speed: float = 5
# скорость прыжка
@export var jump_velocity: float = 5.5
@export var count_jump = 2
var number_jump = 0

# сила рывка
@export var dash_speed: float=21
# время осуществления рывка
@export var dash_time:float = 0.5
var dash_timer =dash_time
var status_desh: bool =false
var vector_dash: Vector3

# вмремя перезарядки рывка
@export var reload_dash_time:float = 3
var dash_timer_reload:float = 0.0

# количество рывков
@export var count_dash_max = 3
var count_dash = count_dash_max
# минимальный  таймер между рывками
@export var dash_cooldown = 0.8
var open_dash = true


# Чувствительность мышы
@export var mouse_sensitivity: float = 0.03

@export var spring_arm: SpringArm3D = null # Пружина камеры
@export var mesh_pivot: Node3D =   null # Узел с моделькой персонажа
@export var collision_shape: CollisionShape3D = null # Колизия персонажа

#скорость движения персонажа
var speed_max: float = default_move_speed
var speed: float = 0
# персонаж присел
var is_crouching: bool = false
# Персонаж хочет встать
var want_up: bool = false
# меняем состояние присед или нет
var height_change: bool = false
# камера зафиксирована на спине игрока
var fixation_camera = false # false = камера управляется мышью, true = персонаж управляется

# высота колизии полная и присида
var default_height_collision: float
var crouch_height_collision: float 

# уменьшение высоты при присиде в (пока нет анимации приседания)
var reduce_height_mesh_in: float =0.75

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	default_height_collision = collision_shape.shape.height
	crouch_height_collision = default_height_collision*reduce_height_mesh_in
	#print("check_position.y  "+ str(collision_shape.global_position.y ))
	
	
func _input(event):
	# Обработка Фиксации персонажа в направлении камеры (прицел)
	if event.is_action_pressed("focus_camera"):
		fixation_camera = true  
	elif event.is_action_released("focus_camera"):
		fixation_camera = false  

	# обрабатываем движение мышки
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Вращаем SpringArm мышкой
		spring_arm.camera_rotation_x(event.relative.y,mouse_sensitivity)
		spring_arm.camera_rotation_y(event.relative.x,mouse_sensitivity)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	#
	## Обработка приседания
	if event.is_action_pressed("crouch"):
		if not is_crouching: 
			height_change=true
			is_crouching = true
			want_up = false
	if event.is_action_released("crouch"):
		if is_crouching:
			height_change=true
			want_up= true
		
func _physics_process(delta: float) -> void:
	if count_dash_max>count_dash:
		dash_timer_reload+= delta
		if dash_timer_reload>=reload_dash_time:
			count_dash+=1
			dash_timer_reload = 0.0
			
			
	if fixation_camera:
		# Горизонтальный поворот (вращаем еще и меш)
		mesh_pivot.mesh_rotation_by(spring_arm.rotation.y,180,turn_speed*delta)
		
	# 1. Получаем вектор ввода (WASD или стрелки)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	if not status_desh:
		if fixation_camera:
			# =========================
			# для персонажа соедененного с камерой
			move_together_camera(input_dir,delta)
		else:
			# =========================
			# для персонажа отдельно от камеры
			move_singly_camera(input_dir, delta)
		
	if Input.is_action_just_pressed("dash") and open_dash and count_dash>0 and not status_desh:
		
		if velocity.x or velocity.z:
			start_dash(velocity)
		else:
			start_dash(mesh_pivot.transform.basis.z*-1)
	if status_desh:
		make_dash(delta)
		
	# 2. Реализуем приседания
	update_crouch(delta)
	# 3. Вертикальная составляющая (гравитация и прыжок)
	# Применяем гравитацию
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if is_on_floor():
		number_jump = 0
	
	# Обработка прыжка (если на полу и нажата клавиша прыжка)
	if Input.is_action_just_pressed("jump") and number_jump < count_jump:
		velocity.y = jump_velocity
		number_jump+=1
	
	# 4. Двигаем персонажа
	move_and_slide()

func start_dash(vector_move:Vector3):
	"""
	подготовка данных для рывка
	"""
	open_dash = false
	status_desh =true
	vector_dash = vector_move.normalized()
	count_dash-=1
	# Запускаем перезарядку
	await get_tree().create_timer(dash_cooldown).timeout
	open_dash = true

func make_dash(delta):
	"""
	делаем рывок
	"""
	if dash_timer>0:
		velocity.x = lerp(velocity.x, vector_dash.x * dash_speed, dash_speed * delta)
		velocity.z = lerp(velocity.z, vector_dash.z * dash_speed, dash_speed * delta)
		dash_timer -= delta
	else:
		dash_timer=dash_time
		status_desh=false

func move_together_camera(input_dir,delta) -> void:
	"""
	Движение персонажа xz с привязанной камерой, вперед всегда туда куда смотрит камера
	input_dir - вектор движения вводимого с клавиатуры
	"""
	# Преобразуем ввод в направление относительно персонажа (чтобы W всегда был "вперед по взгляду")
	# для персонажа соедененного с камерой
	# 1.1 Для этого нужно получить глобальный базис объекта персонаж (игнорируем наклон по X)
	var direction = (mesh_pivot.transform.basis * Vector3(-input_dir.x, 0, -input_dir.y)).normalized()

	# 2. Горизонтальное движение
	if direction:
		speed = move_toward(speed, speed_max, weight_speed * delta)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		#============================== 
		#velocity.x = lerp(velocity.x, direction.x * speed_max, weight_speed)
		#velocity.z = lerp(velocity.z, direction.z * speed_max, weight_speed)
		#============================== 
		#velocity.x = move_toward(velocity.x, direction.x * speed_max, weight_speed * delta)
		#velocity.z = move_toward(velocity.z, direction.z * speed_max, weight_speed * delta)
		#============================== 
	else:
		speed = move_toward(speed, 0, weight_speed * delta)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		#============================== 
		#velocity.x = lerp(velocity.x, move_toward(velocity.x, 0, speed_max), weight_speed) 
		#velocity.z = lerp(velocity.z, move_toward(velocity.z, 0, speed_max), weight_speed)
		#============================== 
		#velocity.x = move_toward(velocity.x, 0.0, weight_speed * delta)
		#velocity.z = move_toward(velocity.z, 0.0, weight_speed * delta)

func move_singly_camera(input_dir, delta) -> void:
	"""
	движение персонажа xz с незафиксированной камерой
	направление движения зависит от  клавишь а не от камеры
	input_dir - вектор движения вводимого с клавиатуры
	"""
	# для персонажа отдельно от камеры
	# 1.1б Для этого нужно получить глобальный базис камеры (игнорируем наклон по X)	
	var direction = (spring_arm.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	# 2.б Горизонтальное движение
	if direction.length() > 0:
		# Движение
		speed = move_toward(speed, speed_max, weight_speed * delta)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		#============================== 
		#velocity.x = direction.x * speed_max
		#velocity.z = direction.z * speed_max
		#============================== 
		# Плавный поворот персонажа в сторону движения
		var target_angle = atan2(direction.x, direction.z)
		mesh_pivot.mesh_rotation_by(target_angle,0,turn_speed*delta)
	else:
		# Торможение
		speed = move_toward(speed, speed_max, weight_speed * delta)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		#============================== 
		#velocity.x = move_toward(velocity.x, 0, speed_max)
		#velocity.z = move_toward(velocity.z, 0, speed_max)

func update_crouch(delta) -> void:
	"""
	Обновление состояния персонажа 'Присесть'
	want_up - переменная желания встать true- надо попробовать встать, false состояние не меняем
	is_crouching- состояние true - присесть, false- встать
	delta- изменение времени
	height_change - изменяем состояние что бы зря не гонять отрисовку
	"""
	if height_change or want_up:
		if want_up:
			# проверяем можем ли встать
			if can_stand_up():
				want_up = false
				is_crouching = false
				height_change=true
		# садимся
		if is_crouching:
			mesh_pivot.crouch(crouch_speed*delta)
			collision_shape.shape.height = crouch_height_collision
			collision_shape.position.y = mesh_pivot.position_mesh
			speed_max = crouch_move_speed
			if mesh_pivot.height_mesh==mesh_pivot.crouch_height_mesh:
				height_change=false
		# Встаем
		else:
			mesh_pivot.stand(crouch_speed*delta)
			collision_shape.shape.height = default_height_collision
			collision_shape.position.y = mesh_pivot.position_mesh
			speed_max = default_move_speed
			if mesh_pivot.height_mesh==mesh_pivot.default_height_mesh:
				height_change=false

func can_stand_up() -> bool:
	"""
	Для проверки возможности встать достраиваем объект над готовой,
	проверяем не упираемся ли во что то
	"""
	# Проверяем, есть ли место над головой, чтобы встать
	if not collision_shape.shape is CapsuleShape3D:
		return true
	
	# Создаем проверочную форму на полную высоту
	var space_state = get_world_3d().direct_space_state
	var params = PhysicsShapeQueryParameters3D.new()
	
	# Используем ту же форму, но с полной высотой
	var check_shape = collision_shape.shape.duplicate()
	check_shape.height = default_height_collision
	check_shape.radius = collision_shape.shape.radius  # Радиус не меняем
	
	params.shape = check_shape
	
	# ВАЖНО: Центр проверочной формы должен быть 
	var check_position = global_position
	
	params.transform = Transform3D.IDENTITY.translated(check_position)
	params.collision_mask = collision_mask
	params.exclude = [self]
	
	var results = space_state.intersect_shape(params)
	return results.is_empty()

func _process(_delta):
	
	# Используем встроенную отладку (работает только в редакторе)
	if Engine.is_editor_hint() or OS.is_debug_build():
		## Рисуем капсулу для проверки места над головой
		#var check_pos = (global_position + 
		#Vector3.UP * (collision_shape.position.y+collision_shape.shape.height/2))
		#DebugDraw3D.draw_sphere(check_pos,0.1,Color.RED,0.5)
		
		# Рисуем капсулу глобальная позиция персонажа
		#var check_pos = global_position
		#DebugDraw3D.draw_sphere(check_pos,0.1,Color.BLUE,0.5)
		
		var start_point = global_position
		start_point.y=start_point.y+2.2
		var direction = global_transform.basis.z
		var end_point = start_point + direction * 3.0
		DebugDraw3D.draw_line(start_point, end_point, Color.YELLOW, 0.05)
		
		start_point = mesh_pivot.global_position
		start_point.y=start_point.y+1
		direction = mesh_pivot.global_transform.basis.z
		end_point = start_point + direction * 3.0
		DebugDraw3D.draw_line(start_point, end_point, Color.RED, 0.05)
		
		start_point = spring_arm.global_position
		start_point.y=start_point.y+1.1
		direction = -spring_arm.global_transform.basis.z
		direction.y=0
		end_point = start_point + direction * 3.0
		DebugDraw3D.draw_line(start_point, end_point, Color.WHITE, 0.05)
		pass
