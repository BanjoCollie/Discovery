extends KinematicBody2D

#Constants we might want to change
const BASE_SPEED = 250 #Normal move speed
const GRAVITY = 1900 #How fast gravity is

#Inclines
const SLOPE_SLIDE_STOP = 35.0 #When you stop on inclines, high is more stop, low is less
const LERP_INCREMENT = .2 #Increase for slightly faster responce, but less predictable and smooth movement

#Constants we probably dont want to change
const FLOOR_NORM = Vector2(0,-1)

#States
const STATE_CHASE = 0
const STATE_PATROL = 1

#Variables
var state = STATE_CHASE
onready var player = get_node("/root/World/Player")
var velocity = Vector2(0,0)

func _ready():
	set_fixed_process(true)
	print(player)
	print(get_node("/root").get_name())
	for x in get_node("/root").get_children():
		print(x.get_name())

func _fixed_process(delta):
	if state == STATE_PATROL:
		pass
	
	if state == STATE_CHASE:
		velocity.y += GRAVITY*delta
		var direction = sign(player.get_pos().x - get_pos().x)
		if (direction > 0):
			get_node("Sprite").set_flip_h(true)
		else:
			get_node("Sprite").set_flip_h(false)
		velocity.x = lerp(velocity.x, direction*BASE_SPEED, LERP_INCREMENT)
		velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)