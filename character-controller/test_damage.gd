extends CSGBox3D

func take_damage(damage):
	print("Урон " + str(damage))
	

func create_hit_effect(hit_pos, hit_normal):
	print("Партикл попадания")
