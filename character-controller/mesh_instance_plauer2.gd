extends MeshInstance3D

var player
# высота меша полная и присида
var default_height_mesh: float
var crouch_height_mesh: float 
# текущая высота и текущая позиция 
var height_mesh: float
var position_mesh: float
var global_height: float

func _ready():
	player = get_node("..")
	default_height_mesh = self.scale.y
	crouch_height_mesh = default_height_mesh * player.reduce_height_mesh_in
	height_mesh = self.scale.y
	position_mesh = self.position.y
	global_height = self.get_aabb().size.y
	
	
func mesh_rotation_by(object_goal_rad, degree_deviations:float=180, speed_turn:float=0.1)->void:
	var to = wrapf(object_goal_rad+deg_to_rad(degree_deviations), deg_to_rad(0.0), deg_to_rad(360.0))
	self.rotation.y = lerp_angle(self.rotation.y, to, speed_turn)

func reduce_height_mesh(purpose_height,speed):
	self.scale.y =move_toward(self.scale.y, purpose_height, speed)
	height_mesh = self.scale.y
	self.position.y = move_toward(self.position.y, (purpose_height-default_height_mesh)/2*global_height, speed)
	position_mesh = self.position.y


func crouch(speed):
	reduce_height_mesh(crouch_height_mesh,speed)

func stand(speed):
	reduce_height_mesh(default_height_mesh,speed)
