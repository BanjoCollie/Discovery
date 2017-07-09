extends Control

var player
var ability_num
var ability

var inner_radius = 75
var outer_radius = 275
var mid_radius = 175

var ability_icons = {
	Grapple = preload("res://assets/textures/UI/Grapple_Icon.png"),
	Platforms = preload("res://assets/textures/Enemies/Hopper/Hopper.png"),
	Temp1 = preload("res://assets/textures/Enemies/Ancient Robot/Normal Red.png"),
	FlashBomb = preload("res://assets/textures/Player/Items/FlashBomb.png"),
	Temp3 = null,
	Temp4 = null,
	Temp5 = null,
	Temp6 = null,
	Temp7 = null,
	Temp8 = null,
	Temp9 = null,
	Temp10 = null,
}

func _ready():
	player = get_parent()
	ability_num = 0
	for i in player.active_abilities:
		if player.active_abilities[i]:
			ability_num += 1

func _draw():
	draw_circle(Vector2(0,0),outer_radius,Color(1,1,1,0.5))
	draw_circle(Vector2(0,0),inner_radius,Color(0,0,0,0.6))
	
	var select_ang = player.aimvect.angle()
	if select_ang < 0:
		select_ang += 2*PI
	var wedge_interval = 2*PI/ability_num
	
	for i in range(ability_num):
		draw_line(Vector2(inner_radius*sin(wedge_interval*i),inner_radius*cos(wedge_interval*i)),Vector2(outer_radius*sin(wedge_interval*i),outer_radius*cos(wedge_interval*i)),Color(1,1,1,1))
	
	var start_angle = floor(select_ang/wedge_interval)*wedge_interval
	var end_angle = start_angle + wedge_interval 
	
	if player.aimvect.length() > 30:
		draw_line(Vector2(0,0),inner_radius*player.aimvect.normalized(),Color(1,1,1),3)
		
		#Hightlight selected portion
		var arc_points = Vector2Array()
		var point_num = 40/ability_num
		
		for i in range(point_num+1):
			var new_ang = start_angle + i*wedge_interval/point_num
			arc_points.push_back(Vector2(inner_radius*sin(new_ang),inner_radius*cos(new_ang)))
		for i in range(point_num+1):
			var new_ang = end_angle - i*wedge_interval/point_num
			arc_points.push_back(Vector2(outer_radius*sin(new_ang),outer_radius*cos(new_ang)))
		var colors = ColorArray([Color(1,1,1,0.5)])
		draw_polygon(arc_points,colors)
	
	var j = 0
	for current_ability in player.active_abilities:
		if player.active_abilities[current_ability]:
			var label = Label.new()
			var font = label.get_font("")
			label.free()
			
			var myang = (j + 0.5)*wedge_interval
			var draw_pos = Vector2(mid_radius*sin(myang),mid_radius*cos(myang))
			var offset = Vector2(0,0)
			if ability_icons[current_ability] != null:
				offset = ability_icons[current_ability].get_size()/2
				draw_texture(ability_icons[current_ability],draw_pos-offset+Vector2(0,5))
			draw_string(font,draw_pos-offset,current_ability,Color(0,0,0,1))
			
			if player.aimvect.length() > 30:
				if abs(j-start_angle/wedge_interval) < .1:
					ability = current_ability
			
			j += 1