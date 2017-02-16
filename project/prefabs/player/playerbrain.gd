extends KinematicBody2D

#Constants we might want to change
const GRAVITY = 1900 #How fast gravity is
const BASE_SPEED = 250 #Base speed of the player
const JUMP_SPEED = 400 #Speed of jumps
const SLOPE_SLIDE_STOP = 35.0 #When you stop on inclines, high is more stop, low is less
const LERP_INCREMENT = 0.2 #Increase for slightly faster responce, but less predictable and smooth movement

#Constants we probably dont want to change
const FLOOR_NORM = Vector2(0,-1)

#States
const STATE_STAND = 0
const STATE_CROUCH = 1

# Initialize variables
var velocity = Vector2(0,0)

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
	crouch_col.set_radius(31)
	
	normal_spr = get_node("Sprite").get_texture()
	crouch_spr = preload("res://assets/textures/player_crouch.png")
	
func switch_state(switch_to):
	if switch_to == STATE_CROUCH:
		pass
	elif switch_to == STATE_STAND:
		pass
	else:
		print("Invalid state to switch to")
	
func _fixed_process(delta):
	
	# Determine velocity
	#Gravity
	velocity.y += GRAVITY*delta
	
	# Move with velocity
	#velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
	
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
			
	#Crouching
	if Input.is_action_just_pressed("ui_down"):
		if is_move_and_slide_on_floor():
			get_node("Collision").set_shape(crouch_col)
			get_node("Collision").set_pos(Vector2(0,32))
			get_node("Sprite").set_texture(crouch_spr)
			get_node("Sprite").set_pos(Vector2(0,32))
	
	if Input.is_action_just_released("ui_down"):
		if !get_node("Stand").is_colliding():
			get_node("Collision").set_shape(normal_col)
			get_node("Collision").set_pos(Vector2(0,0))
			get_node("Sprite").set_texture(normal_spr)
			get_node("Sprite").set_pos(Vector2(0,0))
	
	# Move with velocity
	velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)