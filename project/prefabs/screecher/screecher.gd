extends KinematicBody2D

#Constants we might want to change
const BASE_SPEED = 250 #Normal move speed for patrol
const CHASE_SPEED = 450 #Speed when chasing
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
var state = STATE_PATROL
onready var player = get_node("/root/World/Player")
onready var screech = get_node("Screech")
onready var echo = get_node("Screech/Collision")
var velocity = Vector2(0,0)

export var delay = 5
export var duration = 1
var timer = 0
var screeching = false

export var leftbound = -999
export var rightbound = 999
var direction = -1
var facing = -1

func _ready():
	set_fixed_process(true)
	screech.set_hidden(true)

func _fixed_process(delta):
	if state == STATE_PATROL:
		#Patrolling
		velocity.y += GRAVITY*delta
		if get_pos().x > rightbound:
			direction = -1
		elif get_pos().x < leftbound:
			direction = 1
		velocity.x = lerp(velocity.x, direction*BASE_SPEED, LERP_INCREMENT)
		velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
		
		#Screeching
		timer += delta
		if screeching == false:
			if timer >= delay:
				screech.set_hidden(false)
				get_node("Sounds").play("AAA")
				screeching = true
				timer = 0
		else:
			if timer >= duration:
				screech.set_hidden(true)
				screeching = false
				timer = 0
			else:
				for instance in echo.get_overlapping_bodies():
					if (instance == player):
						print("ATTACK")
						switch_to_state(STATE_CHASE)
	
	if state == STATE_CHASE:
		velocity.y += GRAVITY*delta
		direction = sign(player.get_pos().x - get_pos().x)
		velocity.x = lerp(velocity.x, direction*CHASE_SPEED, LERP_INCREMENT)
		velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
		
		#Screeching
		timer += delta
		if screeching == false:
			if timer >= delay:
				screech.set_hidden(false)
				get_node("Sounds").play("AAA")
				screeching = true
				timer = 0
		else:
			if timer >= duration:
				screech.set_hidden(true)
				screeching = false
				timer = 0
			else:
				for instance in echo.get_overlapping_bodies():
					if (instance == player):
						pass
	
	if direction != facing:
		#If we turned around
		get_node("Sprite").set_flip_h(!get_node("Sprite").is_flipped_h())
		screech.set_pos(Vector2(-screech.get_pos().x,screech.get_pos().y))
		screech.set_rotd(fmod(screech.get_rotd()+180,360))
		
		facing = direction
		
	
func switch_to_state(switch_to):
	state = switch_to