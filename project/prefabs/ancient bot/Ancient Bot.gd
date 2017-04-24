extends KinematicBody2D

#Constants we might want to change
const BASE_SPEED = 150 #Normal move speed for patrol
const CHASE_SPEED = 300 #Speed when chasing
const GRAVITY = 1900 #How fast gravity is
const MAX_HEALTH = 100
const CHASE_TIME = 10 #How many seconds will he chase you
const PRE_ATTACK_TIME = 0.2 #How many seconds it takes to attack (Like a charge time)
const POST_ATTACK_TIME = 0.5 #How many seconds it takes after an attack to move again (Like a cooldown time)
const ATTACK_DAMAGE = 20

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
onready var detect = get_node("Light")
var velocity = Vector2(0,0)

var health = MAX_HEALTH

var chase_timer = 0

var attack_timer = 0
var has_attacked = false

export var leftbound = -999
export var rightbound = 999
var direction = 1
var facing = 1

	#sprites
var base_spr
var chase_spr
var attack_spr

var yellow_scan
var red_scan

func _ready():
	set_fixed_process(true)
	add_to_group("enemies")
	
	base_spr = preload("res://assets/textures/Enemies/Ancient Robot/Normal Yellow.png")
	chase_spr = preload("res://assets/textures/Enemies/Ancient Robot/Normal Red.png")
	attack_spr = preload("res://assets/textures/Enemies/Ancient Robot/Red Attack.png")
	yellow_scan = preload("res://assets/textures/Enemies/Ancient Robot/Yellow Scan.png")
	red_scan = preload("res://assets/textures/Enemies/Ancient Robot/Red Scan.png")

func _fixed_process(delta):
	if (health <= 0):
		#If you die
		queue_free()
	
	
	if state == STATE_PATROL:
		#Check to see if you are touching the player
		for instance in get_node("Touch").get_overlapping_bodies():
			if instance == player:
				switch_to_state(STATE_CHASE)
				get_tree().call_group(0, "enemies", "chase_player")
		
		#Check if scanner touches player
		for instance in get_node("Light/Collision").get_overlapping_bodies():
			if instance == player:
				switch_to_state(STATE_CHASE)
				get_tree().call_group(0, "enemies", "chase_player")
		
		#Patrolling
		velocity.y += GRAVITY*delta
		if get_pos().x > rightbound:
			direction = -1
		elif get_pos().x < leftbound:
			direction = 1
		velocity.x = lerp(velocity.x, direction*BASE_SPEED, LERP_INCREMENT)
		velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
	
	elif state == STATE_CHASE:
		chase_timer += delta
		
		velocity.y += GRAVITY*delta
		
		#Are you close enough to hit the player?
		var can_hit = false
		if player in get_node("Attack").get_overlapping_bodies():
			can_hit = true
		if can_hit == true:
			switch_to_state(STATE_ATTACK)
		else:
			direction = sign(player.get_pos().x - get_pos().x)
			velocity.x = lerp(velocity.x, direction*CHASE_SPEED, LERP_INCREMENT)
			velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
		
		for instance in get_node("Touch").get_overlapping_bodies():
			if instance == player:
				chase_timer = 0
		
		for instance in get_node("Light/Collision").get_overlapping_bodies():
			if (instance == player):
				chase_timer = 0
		
		if chase_timer >= CHASE_TIME:
			switch_to_state(STATE_PATROL)
	
	elif state == STATE_ATTACK:
		attack_timer += delta
		
		if attack_timer >= PRE_ATTACK_TIME:
			if has_attacked == false:
				has_attacked = true
				get_node("Body").set_texture(attack_spr)
				for instance in get_node("Light/Collision").get_overlapping_bodies():
					if (instance == player):
						player.take_damage(ATTACK_DAMAGE)
			else:
				if attack_timer >= PRE_ATTACK_TIME+POST_ATTACK_TIME:
					switch_to_state(STATE_CHASE)
	
	if direction != facing:
		#If we turned around
		get_node("Body").set_flip_h(!get_node("Body").is_flipped_h())
		get_node("Body").set_offset(-get_node("Body").get_offset())
		
		detect.set_pos(Vector2(-detect.get_pos().x,detect.get_pos().y))
		detect.set_rotd(fmod(detect.get_rotd()+180,360))
		
		facing = direction
		
	
func switch_to_state(switch_to):
	if switch_to == STATE_CHASE:
		detect.set_texture(red_scan)
		get_node("Body").set_texture(chase_spr)
	elif switch_to == STATE_PATROL:
		chase_timer = 0
		detect.set_hidden(false)
		detect.set_texture(yellow_scan)
		get_node("Body").set_texture(base_spr)
	elif switch_to == STATE_ATTACK:
		attack_timer = 0
		has_attacked = false
		detect.set_hidden(true)
		get_node("Body").set_texture(base_spr)
	
	last_state = state
	state = switch_to

func take_damage(dam):
	health -= dam
	if state == STATE_PATROL:
		switch_to_state(STATE_CHASE)
		get_tree().call_group(0, "enemies", "chase_player")

func chase_player():
	switch_to_state(STATE_CHASE)