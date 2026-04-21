extends SpringArm3D

var player

func _ready():
	player = get_node("..")
	# Исключаем коллизию самого игрока
	self.add_excluded_object(player.get_rid())

func camera_rotation_x(mouse_movement_y: float,mouse_sensitivity: float)->void:
	self.rotation_degrees.x -= mouse_movement_y * mouse_sensitivity
	self.rotation_degrees.x = clamp(self.rotation_degrees.x, -90.0, 30.0)
	
func camera_rotation_y(mouse_movement_x: float,mouse_sensitivity: float)->void:
	self.rotation_degrees.y -= mouse_movement_x * mouse_sensitivity
	self.rotation_degrees.y = wrapf(self.rotation_degrees.y, 0.0, 360.0)
