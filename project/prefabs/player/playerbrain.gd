extends KinematicBody2D

#Constants we might want to change
const GRAVITY = 1900 #How fast gravity is
const BASE_SPEED = 250 #Base speed of the player
const CROUCH_SPEED = 125
const AIM_SPEED = 125
const SPRINT_SPEED = 500
const JUMP_SPEED = 400 #Speed of jumps
const JUMP_DELAY = 0.5 #Time between jumps
const CLIMB_SPEED = 250 #Speed of climbing
const LEDGE_CLIMB_SPEED = 1 #How many seconds it takes to climb up a ledge
const GUN_TRACER_TIME = 0.1 #How many seconds the gun's tracer is drawn
const GUN_FIRE_DELAY = 1 #Length of time between gun shots
const MAX_HEALTH = 100
const GUN_DAMAGE = 50

#Both of these effect climbing inclines
const SLOPE_SLIDE_STOP = 35.0 #When you stop on inclines, high is more stop, low is less
	#Dont set hight than 35
const LERP_INCREMENT = .2 #Increase for slightly faster responce, but less predictable and smooth movement

#Constants we probably dont want to change
const FLOOR_NORM = Vector2(0,-1)

#States
const STATE_STAND = 0
const STATE_CROUCH = 1
const STATE_CLIMB = 2
const STATE_CLIMB_TOP = 3
const STATE_SPRINT = 4
const STATE_AIM = 5
const STATE_LEDGE_HANG = 6

onready var ground = get_node("/root/World/TileMap")

# Initialize variables
	#States
var state = STATE_STAND
var last_state = STATE_STAND
	#Health
var health = MAX_HEALTH
	#Movement
var velocity = Vector2(0,0)
	#Vines
var myvine = null
var onvines = false
	#Climbing ledges
var ledge_climb = false
var ledge_climb_time = 0
var ledge_climb_side = 0 #-1 is left, 1 is right
var ledge_reset_timer = 0 #time until you automatically grab the next ledge
	#Jumping
var jump_time = 99
	#Aiming
var aimdir = 0
var shot_hit = Vector2(0,0) #Where your last shot hit
var gun_fire_timer = GUN_FIRE_DELAY
var gun_tracer_timer = GUN_TRACER_TIME

#Sprites and collisions
var normal_col
var crouch_col
var normal_spr
var crouch_spr

# Made for testing aiming controls
var timeAiming = 0

func _ready():
	set_fixed_process(true)
	
	#Setup collisions and sprites
	normal_col = get_node("Collision").get_shape()
	crouch_col = CapsuleShape2D.new()
	crouch_col.set_height(0)
	crouch_col.set_radius(23)
	
	normal_spr = get_node("Sprite").get_texture()
	crouch_spr = preload("res://assets/textures/player/player_crouch.png")
	

func _fixed_process(delta):
	if (health <= 0):
		#If you die
		print("RIP")
	
	if state == STATE_STAND:
		# Determine velocity
		#Gravity
		velocity.y += GRAVITY*delta
		
		#Check if you are on the ground
		if is_move_and_slide_on_floor():
			# Walk left and right
			var direction = 0
			if Input.is_action_pressed("move_right"):
				direction += 1
			if Input.is_action_pressed("move_left"):
				direction -= 1
			velocity.x = lerp(velocity.x, direction*BASE_SPEED, LERP_INCREMENT)
			
			#Jumping
			if Input.is_action_pressed("jump"):
				if is_move_and_slide_on_floor():
					if jump_time > JUMP_DELAY:
						jump_time = 0
						velocity.y = -JUMP_SPEED
			
			#Crouching
			if Input.is_action_just_pressed("crouch"):
				if is_move_and_slide_on_floor():
					switch_to_state(STATE_CROUCH)
			
			#Sprinting
			if Input.is_action_pressed("sprint") && (Input.is_action_pressed("move_left") || Input.is_action_pressed("move_right")):
				switch_to_state(STATE_SPRINT)
			
			#Aiming
			if Input.is_action_pressed("aim"):
				switch_to_state(STATE_AIM)
			
		else: #Not on the ground
			if ledge_reset_timer <= 0:
				if get_node("LeftLedge").is_colliding():
					#If there is a wall to your left
					if !get_node("TopLeftLedge").is_colliding():
						#If it is low enough for you to grab
						#if Input.is_action_pressed("jump"):
							#Move to haning position and switch state
							ledge_climb_side = -1
							switch_to_state(STATE_LEDGE_HANG)
				
				if get_node("RightLedge").is_colliding():
					#If there is a wall to your left
					if !get_node("TopRightLedge").is_colliding():
						#If it is low enough for you to grab
						#if Input.is_action_pressed("jump"):
							#Move to haning position and switch state
							ledge_climb_side = 1
							switch_to_state(STATE_LEDGE_HANG)
			else:
				ledge_reset_timer -= delta
		
		#Check to see if you are on vines
		onvines = false
		myvine = null
		for i in get_node("Arms").get_overlapping_areas():
			if i in get_tree().get_nodes_in_group("vines"):
				onvines = true
				myvine = i
		
		#If you're on vines climb if you hit up or down
		if onvines == true:
			if Input.is_action_pressed("move_up") || Input.is_action_pressed("move_down"):
				if abs(get_pos().x - myvine.get_pos().x) <= 16:
					move_to(Vector2(myvine.get_pos().x,get_pos().y))
					switch_to_state(STATE_CLIMB)
		
		# Move with velocity
		velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
	
	
	
	elif state == STATE_CROUCH:
		# Determine velocity
		#Gravity
		velocity.y += GRAVITY*delta
		
		# Walk left and right
		if is_move_and_slide_on_floor():
			var direction = 0
			if Input.is_action_pressed("move_right"):
				direction += 1
			if Input.is_action_pressed("move_left"):
				direction -= 1
			velocity.x = lerp(velocity.x, direction*CROUCH_SPEED, LERP_INCREMENT+.1)
		
		#Jumping
		if Input.is_action_pressed("jump"):
			if is_move_and_slide_on_floor():
				if jump_time > JUMP_DELAY:
					jump_time = 0
					velocity.y = -JUMP_SPEED
		
		if !Input.is_action_pressed("crouch"):
			if !get_node("Stand").is_colliding():
				switch_to_state(STATE_STAND)
		
		# Move with velocity
		velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
	
	
	
	elif state == STATE_SPRINT:
		#Gravity
		velocity.y += GRAVITY*delta
		
		# Walk left and right
		if is_move_and_slide_on_floor():
			var direction = 0
			if Input.is_action_pressed("move_right"):
				direction += 1
			if Input.is_action_pressed("move_left"):
				direction -= 1
			velocity.x = lerp(velocity.x, direction*SPRINT_SPEED, LERP_INCREMENT-.12)
			if direction == 0:
				switch_to_state(STATE_STAND)
		else:
			switch_to_state(STATE_STAND)
		
		if !Input.is_action_pressed("sprint"):
			switch_to_state(STATE_STAND)
		#Jumping
		if Input.is_action_pressed("jump"):
			if is_move_and_slide_on_floor():
				if jump_time > JUMP_DELAY:
					jump_time = 0
					velocity.y = -JUMP_SPEED
		
		velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
	
	
	
	elif state == STATE_CLIMB:
		#Climb up or down
		var directiony = 0
		if Input.is_action_pressed("move_up"):
			directiony -= 1
		if Input.is_action_pressed("move_down"):
			directiony += 1
		
		#Check to see if you are still on vines
		onvines = false
		for i in get_node("Arms").get_overlapping_areas():
			if i in get_tree().get_nodes_in_group("vines"):
				onvines = true
				myvine = i
		if onvines == true:
			velocity.y = CLIMB_SPEED*directiony
			move(velocity*delta)
		else:
			if myvine.get_pos().y>get_pos().y:
				#If you are above the vine you can't move any further up
				if directiony == 1:
					velocity.y = CLIMB_SPEED*directiony
					move(velocity*delta)
			else:
				#If you are below the vine, fall
				switch_to_state(STATE_STAND)
		
		#Get off of vine
		#Check to see if you are touching ceiling vines also
		var topvines = get_tree().get_nodes_in_group("topvines")
		var ontopvines = false
		for i in topvines:
			if self in i.get_overlapping_bodies():
				ontopvines = true
				myvine = i
		if ontopvines == true:
			if Input.is_action_pressed("move_left") || Input.is_action_pressed("move_right"):
				if abs((get_pos().y) - myvine.get_pos().y) <= 48:
					move_to(Vector2(get_pos().x,32+myvine.get_pos().y))
					switch_to_state(STATE_CLIMB_TOP)
				else:
					#You are toching a top vine but aren't close enough to grab on
					pass
		else:
			var directionx = 0
			if Input.is_action_pressed("move_left"):
				directionx -= 1
			if Input.is_action_pressed("move_right"):
				directionx += 1
			if directionx != 0:
				jump_time = 0
				velocity.x = BASE_SPEED*directionx
				switch_to_state(STATE_STAND)
	
	
	
	elif state == STATE_CLIMB_TOP:
		#Climb left or right
		var direction = 0
		if Input.is_action_pressed("move_right"):
			direction += 1
		if Input.is_action_pressed("move_left"):
			direction -= 1
		
		velocity.x = CLIMB_SPEED*direction
		move(velocity*delta)
		
		#Check to see if you are still on vines
		var vines = get_tree().get_nodes_in_group("topvines")
		var onvines = false
		for i in vines:
			if self in i.get_overlapping_bodies():
				onvines = true
		if onvines == false:
			switch_to_state(STATE_STAND)
		
		#Get off of vines
		#Check to see if you are touching verticle vines
		var vines = get_tree().get_nodes_in_group("vines")
		var myvine = null
		var onvines = false
		for i in vines:
			if self in i.get_overlapping_bodies():
				onvines = true
				myvine = i
		
		#If you're on vines climb if you hit up or down
		if onvines == true:
			if Input.is_action_pressed("move_up") || Input.is_action_pressed("move_down"):
				if abs(get_pos().x - myvine.get_pos().x) <= 16:
					move_to(Vector2(myvine.get_pos().x,get_pos().y))
					switch_to_state(STATE_CLIMB)
		else:
			if Input.is_action_pressed("move_down"):
				switch_to_state(STATE_STAND)
	
	
	
	elif state == STATE_AIM:
			#Snap Aiming
		var aimang = rad2deg(Vector2(0,-24).angle_to_point(get_global_mouse_pos()-Vector2(get_pos().x,get_pos().y-24)))
		# everything in if statement is used if player is using a controller
		if Input.is_joy_known(0):
			# commented out section below was for testing angles
#			timeAiming += 1
#			if (timeAiming%60 == 0):
#				print("X pos of right stick is: " + String(Input.get_joy_axis(0,2)*180))
#				print("Y pos of right stick is: " + String(Input.get_joy_axis(0,3)*180))
			aimang = rad2deg(Vector2(0,-24).angle_to_point(Vector2(Input.get_joy_axis(0,2)*180, Input.get_joy_axis(0,3)*180)))
		
		#aimdir = deg2rad(round(aimang/45)*45)
			#Free Aiming
		aimdir = deg2rad(aimang)
		
			#Non free aming
		#aimdir = Vector2(0,0).angle_to_point(Vector2(hor,vert))
		
		velocity.y += GRAVITY*delta
		
		if is_move_and_slide_on_floor():
			var direction = 0
			if Input.is_action_pressed("move_right"):
				direction += 1
			if Input.is_action_pressed("move_left"):
				direction -= 1
			velocity.x = lerp(velocity.x, direction*AIM_SPEED, LERP_INCREMENT+.1)
		
		velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
		
		#Firing
		if Input.is_action_pressed("fire_gun") && gun_fire_timer>GUN_FIRE_DELAY:
			var space_state = get_world_2d().get_direct_space_state()
			#var hit = space_state.intersect_ray( Vector2(0,-get_sprite_height()/4), Vector2(sin(aimdir)*10000,cos(aimdir)*10000) )
			var hit = space_state.intersect_ray( get_global_pos()+Vector2(0,-get_sprite_height()/4), get_global_pos()-Vector2(sin(aimdir)*10000,cos(aimdir)*10000), [ self ] )
			if (!hit.empty()):
				shot_hit = hit.position
				if hit.collider in get_tree().get_nodes_in_group("enemies"):
					hit.collider.take_damage(GUN_DAMAGE)
			else:
				shot_hit = get_global_pos()-Vector2(sin(aimdir)*100000,cos(aimdir)*100000)
			gun_fire_timer = 0
			gun_tracer_timer = 0
		
		gun_fire_timer += delta
		gun_tracer_timer += delta
		
		if !Input.is_action_pressed("aim"):
			switch_to_state(STATE_STAND)
	
	
	
	elif state == STATE_LEDGE_HANG:
		#if !Input.is_action_pressed("jump"):
		if Input.is_action_pressed("move_down"):
			switch_to_state(STATE_STAND)
			ledge_climb = false
			ledge_reset_timer = 0.5
		
		if Input.is_action_pressed("jump"):
			if jump_time > JUMP_DELAY:
				velocity.y = -JUMP_SPEED
				velocity.x = BASE_SPEED*-ledge_climb_side
				switch_to_state(STATE_STAND)
				ledge_climb = false
				ledge_reset_timer = 0.5
		
		if Input.is_action_just_pressed("move_up"):
			ledge_climb = true
			ledge_climb_time = 0
			move_to(Vector2(get_pos().x,get_pos().y-get_sprite_height()/2))
		
		if ledge_climb == true:
			#Make sure you are still climbing
			if !Input.is_action_pressed("move_up"):
				move_to(Vector2(get_pos().x,get_pos().y+get_sprite_height()/2))
				ledge_climb = false
			else:
				ledge_climb_time += delta
				if ledge_climb_time > LEDGE_CLIMB_SPEED:
					#Fully climb up
					ledge_climb = false
					move_to(Vector2(get_pos().x,get_pos().y-get_sprite_height()/2))
					move_to(Vector2(get_pos().x+get_sprite_width()*ledge_climb_side,get_pos().y))
					switch_to_state(STATE_CROUCH)
		#jump_time = 0
	
	
	
	else:
		print("Player is in a state that hasn't been created")
	
	jump_time += delta
	update()



func _draw():
	if state == STATE_AIM:
		draw_line(Vector2(0,-24),Vector2(-160*sin(aimdir),-160*cos(aimdir)-24),Color(1.0, 0.0, 0.0),1)
		
		#Firing
		if gun_tracer_timer < GUN_TRACER_TIME:
			draw_line(Vector2(0,-24),Vector2(shot_hit.x-get_global_pos().x,shot_hit.y-get_global_pos().y),Color(1.0, 1.0, 0.0),3)

func switch_to_state(switch_to):
	if switch_to == STATE_CROUCH:
		get_node("Collision").set_shape(crouch_col)
		get_node("Collision").set_pos(Vector2(0,24))
		get_node("Sprite").set_texture(crouch_spr)
		get_node("Sprite").set_pos(Vector2(0,16))
	elif switch_to == STATE_STAND:
		if state == STATE_CROUCH:
			get_node("Collision").set_shape(normal_col)
			get_node("Collision").set_pos(Vector2(0,0))
			get_node("Sprite").set_texture(normal_spr)
			get_node("Sprite").set_pos(Vector2(0,0))
	elif switch_to == STATE_CLIMB:
		velocity = Vector2(0,0)
	elif switch_to == STATE_CLIMB_TOP:
		velocity.y = 0
	elif switch_to == STATE_LEDGE_HANG:
		velocity = Vector2(0,0)
		#Move to ledge (first move away, then up, then towards the ledge) (Moving away makes you not get caught below small ledges)
		if ledge_climb_side == -1:
			move_to(Vector2(get_pos().x+64,get_pos().y))
			move_to(Vector2(get_pos().x,get_node("LeftLedge").get_collision_point().y+get_sprite_height()/2))
			move_to(Vector2(get_pos().x-128,get_pos().y))
		elif ledge_climb_side == 1:
			move_to(Vector2(get_pos().x-64,get_pos().y))
			move_to(Vector2(get_pos().x,get_node("RightLedge").get_collision_point().y+get_sprite_height()/2))
			move_to(Vector2(get_pos().x+128,get_pos().y))
		else:
			print("Error in switch to state: ledge climb")
	
	last_state = state
	state = switch_to

func get_sprite_height():
	return get_node("Sprite").get_texture().get_size().y

func get_sprite_width():
	return get_node("Sprite").get_texture().get_size().x
	
func take_damage(dam):
	health -= dam