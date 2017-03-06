extends KinematicBody2D

#Constants we might want to change
const GRAVITY = 1900 #How fast gravity is
const BASE_SPEED = 250 #Base speed of the player
const JUMP_SPEED = 400 #Speed of jumps
const CLIMB_SPEED = 250 #Speed of climbing

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

# Initialize variables
var velocity = Vector2(0,0)
var state = STATE_STAND

#Sprites and collisions
var normal_col
var crouch_col
var normal_spr
var crouch_spr

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
	if state == STATE_STAND:
		# Determine velocity
		#Gravity
		velocity.y += GRAVITY*delta
		
		# Walk left and right
		if is_move_and_slide_on_floor():
			var direction = 0
			if Input.is_action_pressed("ui_right"):
				direction += 1
			if Input.is_action_pressed("ui_left"):
				direction -= 1
			velocity.x = lerp(velocity.x, direction*BASE_SPEED, LERP_INCREMENT)
		
		#Check to see if you are on vines
		var vines = get_tree().get_nodes_in_group("vines")
		var myvine = null
		var onvines = false
		for i in vines:
			if self in i.get_overlapping_bodies():
				onvines = true
				myvine = i
		
		#If you're on vines climb if you hit up or down
		if onvines == true:
			if Input.is_action_pressed("ui_up") || Input.is_action_just_released("ui_down"):
				if abs(get_pos().x - myvine.get_pos().x) <= 8:
					move_to(Vector2(myvine.get_pos().x,get_pos().y))
					switch_to_state(STATE_CLIMB)
		else:
			#Jumping
			if Input.is_action_pressed("ui_up"):
				if is_move_and_slide_on_floor():
					velocity.y = -JUMP_SPEED
			
			#Crouching
			if Input.is_action_just_pressed("ui_down"):
				if is_move_and_slide_on_floor():
					switch_to_state(STATE_CROUCH)
		
		# Move with velocity
		velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
	
	
	
	elif state == STATE_CROUCH:
		# Determine velocity
		#Gravity
		velocity.y += GRAVITY*delta
		
		# Walk left and right
		if is_move_and_slide_on_floor():
			var direction = 0
			if Input.is_action_pressed("ui_right"):
				direction += 1
			if Input.is_action_pressed("ui_left"):
				direction -= 1
			velocity.x = lerp(velocity.x, direction*BASE_SPEED, LERP_INCREMENT)
		
		#Jumping
		if Input.is_action_pressed("ui_up"):
			if is_move_and_slide_on_floor():
				velocity.y = -JUMP_SPEED
		
		if !Input.is_action_pressed("ui_down"):
			if !get_node("Stand").is_colliding():
				switch_to_state(STATE_STAND)
		
		# Move with velocity
		velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
	
	
	
	elif state == STATE_CLIMB:
		#Climb up or down
		var directiony = 0
		if Input.is_action_pressed("ui_up"):
			directiony -= 1
		if Input.is_action_pressed("ui_down"):
			directiony += 1
		
		velocity.y = CLIMB_SPEED*directiony
		move(velocity*delta)
		
		#Check to see if you are still on vines
		var vines = get_tree().get_nodes_in_group("vines")
		var onvines = false
		for i in vines:
			if self in i.get_overlapping_bodies():
				onvines = true
		if onvines == false:
			switch_to_state(STATE_STAND)
		
		#Get off of vine
		#Check to see if you are touching ceiling vines also
		var topvines = get_tree().get_nodes_in_group("topvines")
		var myvine = null
		var ontopvines = false
		for i in topvines:
			if self in i.get_overlapping_bodies():
				ontopvines = true
				myvine = i
		if ontopvines == true:
			if Input.is_action_pressed("ui_left") || Input.is_action_pressed("ui_right"):
				if abs((get_pos().y-32) - myvine.get_pos().y) <= 8:
					move_to(Vector2(get_pos().x,myvine.get_pos().y))
					switch_to_state(STATE_CLIMB_TOP)
		else:
			var directionx = 0
			if Input.is_action_pressed("ui_left"):
				directionx -= 1
			if Input.is_action_pressed("ui_right"):
				directionx += 1
			if directionx != 0:
				velocity.x = BASE_SPEED*directionx
				switch_to_state(STATE_STAND)
	
	
	
	elif state == STATE_CLIMB_TOP:
		#Climb left or right
		var direction = 0
		if Input.is_action_pressed("ui_right"):
			direction += 1
		if Input.is_action_pressed("ui_left"):
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
			if Input.is_action_pressed("ui_up") || Input.is_action_pressed("ui_down"):
				if abs(get_pos().x - myvine.get_pos().x) <= 8:
					move_to(Vector2(myvine.get_pos().x,get_pos().y))
					switch_to_state(STATE_CLIMB)
		else:
			if Input.is_action_pressed("ui_down"):
				switch_to_state(STATE_STAND)



func switch_to_state(switch_to):
	if switch_to == STATE_CROUCH:
		get_node("Collision").set_shape(crouch_col)
		get_node("Collision").set_pos(Vector2(0,24))
		get_node("Sprite").set_texture(crouch_spr)
		get_node("Sprite").set_pos(Vector2(0,16))
		state = STATE_CROUCH
	elif switch_to == STATE_STAND:
		if state == STATE_CROUCH:
			get_node("Collision").set_shape(normal_col)
			get_node("Collision").set_pos(Vector2(0,0))
			get_node("Sprite").set_texture(normal_spr)
			get_node("Sprite").set_pos(Vector2(0,0))
		state = STATE_STAND
	elif switch_to == STATE_CLIMB:
		velocity = Vector2(0,0)
		state = STATE_CLIMB
	elif switch_to == STATE_CLIMB_TOP:
		velocity.y = 0
		state = STATE_CLIMB_TOP
	else:
		print("Invalid state to switch to")
		