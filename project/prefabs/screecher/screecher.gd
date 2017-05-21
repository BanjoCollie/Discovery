extends KinematicBody2D

#Nodes for navigation
export(NodePath) var leftLimit = null
export(NodePath) var rightLimit= null 

#Constants we might want to change
const BASE_SPEED = 250 #Normal move speed for patrol
const CHASE_SPEED = 460 #Speed when chasing
const GRAVITY = 1900 #How fast gravity is
const MAX_HEALTH = 300
const CHASE_TIME = 10 #How many seconds will he chase you
const PRE_ATTACK_TIME = 0.1 #How many seconds it takes to attack (Like a charge time)
const POST_ATTACK_TIME = 0.5 #How many seconds it takes after an attack to move again (Like a cooldown time)
const ATTACK_DAMAGE = 50

#Inclines
const SLOPE_SLIDE_STOP = 35.0 #When you stop on inclines, high is more stop, low is less
const LERP_INCREMENT = .2 #Increase for slightly faster responce, but less predictable and smooth movement

#Constants we probably dont want to change
const FLOOR_NORM = Vector2(0,-1)


#States
const STATE_CHASE = 0
const STATE_PATROL = 1
const STATE_ATTACK = 2

#Variables
var state = STATE_PATROL
var last_state = STATE_PATROL
onready var player = get_node("/root/World/Player")
onready var screech = get_node("Screech")
onready var echo = get_node("Screech/Collision")
var velocity = Vector2(0,0)

var health = MAX_HEALTH

export var delay = 5
export var duration = 1
var screech_timer = 0
var screeching = false

var chase_timer = 0
var leftbound = -999
var rightbound = 999

var attack_timer = 0
var has_attacked = false

var direction = -1
var facing = -1

	#sprites
var base_spr
var screech_spr
var attack_spr

func _ready():
	set_fixed_process(true)
	screech.set_hidden(true)
	add_to_group("enemies")
	
	#Get location of navigation nodes and delete them
	if get_node(leftLimit) != null && get_node(rightLimit) != null:
		leftbound = get_node(leftLimit).get_global_pos().x
		rightbound = get_node(rightLimit).get_global_pos().x
		get_node(leftLimit).queue_free()
		get_node(rightLimit).queue_free()
	else:
		print("You messed up assigning the navigation nodes in the screecher")
	
	base_spr = preload("res://assets/textures/Enemies/Shrieker/shrieker.png")
	screech_spr = preload("res://assets/textures/Enemies/Shrieker/shrieker_shriek.png")
	attack_spr = preload("res://assets/textures/Enemies/Shrieker/shrieker_attack.png")

func _fixed_process(delta):
	if (health <= 0):
		#If you die
		queue_free()
	
	
	if state == STATE_PATROL:
		#Check to see if you are touching the player
		for instance in get_node("Touch Detection").get_overlapping_bodies():
			if instance == player:
				switch_to_state(STATE_CHASE)
		
		#Patrolling
		velocity.y += GRAVITY*delta
		if get_pos().x + 128 > rightbound:
			direction = -1
		elif get_pos().x - 128 < leftbound:
			direction = 1
		velocity.x = lerp(velocity.x, direction*BASE_SPEED, LERP_INCREMENT)
		velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
		
		#Screeching
		screech_timer += delta
		if screeching == false:
			if screech_timer >= delay:
				screech.set_hidden(false)
				get_node("Sounds").play("Screech")
				get_node("Sprite").set_texture(screech_spr)
				screeching = true
				screech_timer = 0
		else:
			if screech_timer >= duration:
				get_node("Sprite").set_texture(base_spr)
				screech.set_hidden(true)
				screeching = false
				screech_timer = 0
			else:
				for instance in echo.get_overlapping_bodies():
					if (instance == player):
						switch_to_state(STATE_CHASE)
	
	elif state == STATE_CHASE:
		chase_timer += delta
		
		velocity.y += GRAVITY*delta
		
		#Are you close enough to hit the player?
		var can_hit = false
		if player in get_node("Attack Collision").get_overlapping_bodies():
			can_hit = true
		if can_hit == true:
			switch_to_state(STATE_ATTACK)
		else:
			direction = sign(player.get_pos().x - get_pos().x)
			velocity.x = lerp(velocity.x, direction*CHASE_SPEED, LERP_INCREMENT)
			velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
		
		for instance in get_node("Touch Detection").get_overlapping_bodies():
			if instance == player:
				chase_timer = 0
		
		for instance in echo.get_overlapping_bodies():
			if (instance == player):
				chase_timer = 0
		
		if chase_timer >= CHASE_TIME:
			switch_to_state(STATE_PATROL)
	
	elif state == STATE_ATTACK:
		attack_timer += delta
		
		if attack_timer >= PRE_ATTACK_TIME:
			if has_attacked == false:
				print("Attack now")
				has_attacked = true
				get_node("Sprite").set_texture(attack_spr)
				for instance in echo.get_overlapping_bodies():
					if (instance == player):
						player.take_damage(ATTACK_DAMAGE)
			else:
				if attack_timer >= PRE_ATTACK_TIME+POST_ATTACK_TIME:
					switch_to_state(STATE_CHASE)
					print("Attack is over")
	
	if direction != facing:
		#If we turned around
		get_node("Sprite").set_flip_h(!get_node("Sprite").is_flipped_h())
		screech.set_pos(Vector2(-screech.get_pos().x,screech.get_pos().y))
		screech.set_rotd(fmod(screech.get_rotd()+180,360))
		
		facing = direction
		
	
func switch_to_state(switch_to):
	if switch_to == STATE_CHASE:
		screech.set_hidden(false)
		get_node("Sprite").set_texture(screech_spr)
	elif switch_to == STATE_PATROL:
		screech_timer = 0
		chase_timer = 0
		screech.set_hidden(true)
		get_node("Sprite").set_texture(base_spr)
	elif switch_to == STATE_ATTACK:
		print("Preparing to attack")
		attack_timer = 0
		has_attacked = false
		screech.set_hidden(true)
		get_node("Sprite").set_texture(base_spr)
	
	last_state = state
	state = switch_to

func take_damage(dam):
	health -= dam
	if state == STATE_PATROL:
		switch_to_state(STATE_CHASE)