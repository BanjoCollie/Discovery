extends KinematicBody2D

#Constants we might want to change
const GRAVITY = 1600 #How fast gravity is
const BASE_SPEED = 250 #Base speed of the player
const CROUCH_SPEED = 125
const AIM_SPEED = 125
const SPRINT_SPEED = 500
const JUMP_SPEED = 350 #Speed of jumps
const JUMP_DELAY = 0.3 #Time between jumps
const CLIMB_SPEED = 250 #Speed of climbing
const LEDGE_CLIMB_SPEED = 1 #How many seconds it takes to climb up a ledge
const GUN_TRACER_TIME = 0.1 #How many seconds the gun's tracer is drawn
const GUN_FIRE_DELAY = 1 #Length of time between gun shots
const MAX_HEALTH = 100
const GUN_DAMAGE = 50
const FLASH_DELAY = 1 #Length of time between throwing FlashBombs

#Both of these affect climbing inclines
const SLOPE_SLIDE_STOP = 35.0 #When you stop on inclines, high is more stop, low is less
	#Dont set hight than 35
const LERP_INCREMENT = .2 #Increase for slightly faster responce, but less predictable and smooth movement
const AIR_LERP = .05 #Lerp increment for air movement

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
const STATE_ABILITY_SELECT = 7
const STATE_GUN_SELECT = 8
const STATE_GRAPPLE_AIM = 9
const STATE_GRAPPLING = 10
const STATE_FLASH_AIM = 11

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

	#Gun
var ammo = 10
#var aimdir = 0
var aimvect = Vector2(0,0)
var shot_hit = Vector2(0,0) #Where your last shot hit
var gun_fire_timer = 0
var gun_tracer_timer = 0

#Flash variables
var flash_count = 10
var flash_timer = 0

#Abilities
var selected_ability = null
var active_abilities = { #Make sure this matches ability icons in ability wheel node
	Grapple = true,
	Platforms = false,
	FlashBomb = true,
	Temp1 = true,
	Temp3 = true,
	Temp4 = false,
	Temp5 = true,
	Temp6 = true,
	Temp7 = false,
	Temp8 = false,
	Temp9 = false,
	Temp10 = false,
}
var ability_states = { #The state that each ability puts you into when you press the ability button
	Grapple = STATE_GRAPPLE_AIM,
	FlashBomb = STATE_FLASH_AIM,
}
var grapple_attached = false
var grapple_pos = Vector2(0,0)
var grapple_vel = Vector2(0,0)
var grapple_speed = 50 #How fast the grapple hook goes
var grappling_speed = 90 #How fast you go when you are grappling
var min_grapple_length = 100
var max_grapple_length = 500 

#Sprites and collisions
var normal_col
var crouch_col

#Used for animation and directional stuff
var isRight = true
var directionChanged = false

#Appearance
var gun_pos

# Made for testing purposes
var timeAiming = 0
var dead = false;

func _ready():
	set_fixed_process(true)
	
	#Setup collisions and sprites
	normal_col = get_node("Collision").get_shape()
	crouch_col = CapsuleShape2D.new()
	crouch_col.set_height(0)
	crouch_col.set_radius(23)
	
	#sets display of HUD elements
	get_node("Info/Health").set_text("Health: " + str(health))
	get_node("Info/Ammo").set_text("Ammo: " + str(ammo))
	get_node('Info/Flash Bombs').set_text('Flash Bombs: ' + str(flash_count))
	
	gun_pos = Vector2(0,-get_sprite_height()/4)
	

func _fixed_process(delta):
	if (health <= 0):
		#If you die
		if dead == false:
			print("You are dead")
			dead = true
	
	if state == STATE_STAND:
		# Determine velocity
		#Gravity
		velocity.y += GRAVITY*delta
		var direction = 0
		
		if Input.is_action_pressed("move_right"):
			#print('isRight is: ' + str(isRight) + ', directionChanged is: ' + str(directionChanged))
			direction += 1
			if !isRight:
				directionChanged = true
				isRight = true
		if Input.is_action_pressed("move_left"):
			#print('isRight is: ' + str(isRight) + ', directionChanged is: ' + str(directionChanged))
			direction -= 1
			if isRight:
				directionChanged = true
				isRight = false
		
		#Check if you are on the ground
		if is_move_and_slide_on_floor(): #May want to make falling be a different state
			if directionChanged and isRight:
				get_node('Sprite').get_node("AnimationPlayer").play("turnRight")
				directionChanged = false
			if directionChanged and !isRight:
				get_node('Sprite').get_node("AnimationPlayer").play("turnLeft")
				directionChanged = false
				
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
			if Input.is_action_pressed("aim") && gun_fire_timer<=0:
				switch_to_state(STATE_AIM)
			
			#Ability Wheel
			if Input.is_action_just_pressed("ability_wheel"):
				switch_to_state(STATE_ABILITY_SELECT)
			
		else: #Not on the ground
			if abs(velocity.x) < BASE_SPEED:
				velocity.x = lerp(velocity.x, direction*BASE_SPEED, AIR_LERP) #Michael trying out some air control code
			#print(velocity.x)
			
			if ledge_reset_timer <= 0:
				if get_node("LeftLedge").is_colliding():
					#If there is a wall to your left
					if !get_node("TopLeftLedge").is_colliding():
						#If it is low enough for you to grab
						#if Input.is_action_pressed("jump"):
						#Move to hanging position and switch state
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
				if abs(get_pos().x - myvine.get_pos().x) <= 24:
					move_to(Vector2(myvine.get_pos().x,get_pos().y))
					switch_to_state(STATE_CLIMB)
		
		#Use abilities(not currently dependant on being on ground)
		if Input.is_action_just_pressed("ability"):
			if selected_ability in ability_states: #THis should never be the case
				switch_to_state(ability_states[selected_ability])
			else:
				print("The ability you have selected has no state!")
		
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
				if direction < 0:
					get_node('Sprite').get_node('AnimationPlayer').play('turnRight')
			if Input.is_action_pressed("move_left"):
				direction -= 1
				if direction > 0:
					get_node('Sprite').get_node('AnimationPlayer').play('turnLeft')
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
		aimvect = (get_global_mouse_pos()-Vector2(get_pos().x,get_pos().y) - gun_pos)
		#aimdir = Vector2(0,-24).angle_to_point(get_global_mouse_pos()-Vector2(get_pos().x,get_pos().y))
		# everything in if statement is used if player is using a controller
		if Input.is_joy_known(0):
			aimvect = (Vector2(Input.get_joy_axis(0,2)*180, Input.get_joy_axis(0,3)*180))
		print(Input.get_joy_axis(0,2))
		#makes sure you're always facing the direction you're aiming
		if isRight and aimvect.x < 0:
			get_node('Sprite').get_node('AnimationPlayer').play('turnLeft')
			isRight = false
		if !isRight and aimvect.x > 0:
			get_node('Sprite').get_node('AnimationPlayer').play('turnRight')
			isRight = true
		
		#aimdir = deg2rad(round(aimang/45)*45)
			#Free Aiming
		#aimdir = deg2rad(aimang)
		
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
		if Input.is_action_just_released("aim") && gun_fire_timer<=0:
			if aimvect.length() > 20:
				if ammo > 0:
					#Gunshot vibration. Feedback is always nice to have
					if Input.is_joy_known(0):
						Input.start_joy_vibration(0,1,.5,.1)
					var space_state = get_world_2d().get_direct_space_state()
					#var hit = space_state.intersect_ray( Vector2(0,-get_sprite_height()/4),
					 #Vector2(sin(aimdir)*10000,cos(aimdir)*10000) )
					#var hit = space_state.intersect_ray( get_global_pos()+Vector2(0,-get_sprite_height()/4), 
					 #get_global_pos()-Vector2(sin(aimdir)*10000,cos(aimdir)*10000), [ self ] )
					var hit = space_state.intersect_ray( get_global_pos()+gun_pos, get_global_pos()+10000*aimvect, [ self ] )
					if (!hit.empty()):
						shot_hit = hit.position
						if hit.collider in get_tree().get_nodes_in_group("enemies"):
							hit.collider.take_damage(GUN_DAMAGE)
					else:
						#shot_hit = get_global_pos()-Vector2(sin(aimdir)*10000,cos(aimdir)*10000)
						shot_hit = get_global_pos() + 10000*aimvect
					gun_fire_timer = GUN_FIRE_DELAY
					gun_tracer_timer = GUN_TRACER_TIME
					
					ammo -= 1
					get_node("Info/Ammo").set_text("Ammo: " + str(ammo))
		
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
	
	
	
	elif state == STATE_ABILITY_SELECT:
		aimvect = (get_global_mouse_pos()-Vector2(get_pos().x,get_pos().y))
		# everything in if statement is used if player is using a controller
		if Input.is_joy_known(0):
			aimvect = (Vector2(Input.get_joy_axis(0,2)*180, Input.get_joy_axis(0,3)*180))
			if aimvect.length() < 20: #Allows you to use either stick
				aimvect = (Vector2(Input.get_joy_axis(0,0)*180, Input.get_joy_axis(0,1)*180))
		get_node("Ability Wheel").update()
		
		if Input.is_action_just_released("ability_wheel"):
			selected_ability = get_node("Ability Wheel").ability
			switch_to_state(STATE_STAND)
		
		#velocity.y += GRAVITY*delta
		#velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
	
	
	
	elif state == STATE_GRAPPLE_AIM:
		aimvect = (get_global_mouse_pos()-Vector2(get_pos().x,get_pos().y) - gun_pos)
		if Input.is_joy_known(0):
			aimvect = (Vector2(Input.get_joy_axis(0,2)*180, Input.get_joy_axis(0,3)*180))
		
		#Code to make sure you're always facing the direction you're aiming
		if isRight and aimvect.x < 0:
			get_node('Sprite').get_node('AnimationPlayer').play('turnLeft')
			isRight = false
		if !isRight and aimvect.x > 0:
			get_node('Sprite').get_node('AnimationPlayer').play('turnRight')
			isRight = true
		
		if Input.is_action_just_released("ability"):
			if aimvect.length() > 10:
				grapple_attached = false
				grapple_vel = aimvect.normalized()*grapple_speed
				grapple_pos = get_global_pos() + gun_pos
				switch_to_state(STATE_GRAPPLING)
			else:
				switch_to_state(STATE_STAND)
		
		#standard movement code necessary in all aiming states
		#Might want to hide this in a variable somewhere, or something. Copy/paste less code
		velocity.y += GRAVITY*delta
		if is_move_and_slide_on_floor():
			var direction = 0
			if Input.is_action_pressed("move_right"):
				direction += 1
			if Input.is_action_pressed("move_left"):
				direction -= 1
			velocity.x = lerp(velocity.x, direction*AIM_SPEED, LERP_INCREMENT+.1)
		velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
	
	elif state == STATE_GRAPPLING:
		if Input.is_action_just_pressed("crouch"):
			switch_to_state(STATE_STAND)
		
		if !grapple_attached:
			var space_state = get_world_2d().get_direct_space_state()
			var hit = space_state.intersect_ray(grapple_pos, grapple_pos+grapple_vel, [ self ] )
			if hit.empty(): #If the grapple wont hit anything this frame
				grapple_pos += grapple_vel
				if get_global_pos().distance_to(grapple_pos) > max_grapple_length:
					switch_to_state(STATE_STAND)
			else: #The grapple hit something
				grapple_pos = hit["position"]
				grapple_attached = true
			
			#standard movement code necessary in all aiming states
			#Might want to hide this in a variable somewhere, or something. Copy/paste less code
			velocity.y += GRAVITY*delta
			if is_move_and_slide_on_floor():
				var direction = 0
				if Input.is_action_pressed("move_right"):
					direction += 1
				if Input.is_action_pressed("move_left"):
					direction -= 1
				velocity.x = lerp(velocity.x, direction*AIM_SPEED, LERP_INCREMENT+.1)
			velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
			
			
		else:
			var old_pos = get_global_pos()
			velocity += (grapple_pos-get_global_pos()).normalized()*grappling_speed
			
			#velocity.y += GRAVITY*delta #Gravity makes it less fun IMO
			velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
			if get_global_pos() == old_pos:
				#You are stuck
				switch_to_state(STATE_STAND)
			if get_global_pos().distance_to(grapple_pos) < min_grapple_length:
				#Grapple has finished
				switch_to_state(STATE_STAND)
				#added by michael to reduce speed after ungrappling
				velocity.y = .4*velocity.y
				velocity.x = .4*velocity.x
		
	#Used for when the player is trying to aim a flash bomb throw
	elif state == STATE_FLASH_AIM:
		#Same aim vector code as all other aiming states thus far
		aimvect = (get_global_mouse_pos()-Vector2(get_pos().x,get_pos().y) - gun_pos)
		if Input.is_joy_known(0):
			aimvect = (Vector2(Input.get_joy_axis(0,2)*180, Input.get_joy_axis(0,3)*180))
			
		#Code to make sure you're always facing the direction you're aiming
		if isRight and aimvect.x < 0:
			get_node('Sprite').get_node('AnimationPlayer').play('turnLeft')
			isRight = false
		if !isRight and aimvect.x > 0:
			get_node('Sprite').get_node('AnimationPlayer').play('turnRight')
			isRight = true
			
		#Throw a flashbomb
		if Input.is_action_just_released("ability") and flash_timer <= 0 and flash_count > 0:
			#Add it to the world
			var thrownFlash = preload("res://prefabs/player/FlashBomb.tscn")
			thrownFlash = thrownFlash.instance()
			get_parent().add_child(thrownFlash)
			#Throw it to your left or right, depending on your aim
			if isRight:
				thrownFlash.set_global_pos(get_global_pos() + gun_pos + Vector2(20,0))
			else:
				thrownFlash.set_global_pos(get_global_pos() + gun_pos - Vector2(20,0))
			thrownFlash.set_axis_velocity(aimvect*1.3)
			thrownFlash.set_angular_velocity(aimvect.angle())
			
			#Set timer before youy can throw again, deplete ammo, update HUD
			flash_timer = FLASH_DELAY
			flash_count -= 1
			get_node("Info/Flash Bombs").set_text("Flash Bombs: " + str(flash_count))
			
			
		#standard movement code necessary in all aiming states
		#Might want to hide this in a variable somewhere, or something. Copy/paste less code
		velocity.y += GRAVITY*delta
		if is_move_and_slide_on_floor():
			var direction = 0
			if Input.is_action_pressed("move_right"):
				direction += 1
			if Input.is_action_pressed("move_left"):
				direction -= 1
			velocity.x = lerp(velocity.x, direction*AIM_SPEED, LERP_INCREMENT+.1)
		velocity = move_and_slide(velocity,FLOOR_NORM,SLOPE_SLIDE_STOP)
		
		if !Input.is_action_pressed("ability"):
			switch_to_state(STATE_STAND)
	
	else:
		print("Player is in state " + str(state) + " which hasn't been created")
	
	#Handle timing delays for shooting and flash-throwing
	if gun_fire_timer > 0:
			gun_fire_timer -= delta
	if gun_tracer_timer > 0:
		gun_tracer_timer -= delta
	if flash_timer > 0:
		flash_timer -= delta
	jump_time += delta
	update()



func _draw():
	#Firing
	if gun_tracer_timer > 0:
		draw_line(gun_pos,Vector2(shot_hit.x-get_global_pos().x,shot_hit.y-get_global_pos().y),Color(1.0, 1.0, 0.0),3)
	
	if state == STATE_AIM || state == STATE_GRAPPLE_AIM || state == STATE_FLASH_AIM:
		#Not really sure how you got things to work so that the aiming vector only displays when you're
		#able to shoot for the gun, so the enabled boolean is my workaround...lol - Michael
		var enabled = true
		if state == STATE_FLASH_AIM and flash_timer > 0:
			enabled = false
		#draw_line(Vector2(0,-24),Vector2(-160*sin(aimdir),-160*cos(aimdir)-24),Color(1.0, 0.0, 0.0),1)
		if aimvect.length() > 10 and enabled:
			draw_line(gun_pos,160*(aimvect).normalized()+gun_pos,Color(1.0, 0.0, 0.0),1)
	
	elif state == STATE_GRAPPLING:
		draw_line(gun_pos,grapple_pos-get_global_pos(),Color(1,1,1,1),3)

func switch_to_state(switch_to):
	if switch_to == STATE_CROUCH:
		get_node("Collision").set_shape(crouch_col)
		get_node("Collision").set_pos(Vector2(0,24))
		get_node("Sprite").get_node("AnimationPlayer").stop()
		get_node("Sprite").set_frame(3)
		get_node("Sprite").set_pos(Vector2(0,16))
		
	elif switch_to == STATE_STAND:
		if state == STATE_CROUCH:
			get_node("Collision").set_shape(normal_col)
			get_node("Collision").set_pos(Vector2(0,0))
			if isRight:
				get_node("Sprite").set_frame(2)
			else:
				get_node('Sprite').set_frame(0)
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
	elif switch_to == STATE_AIM:
		aimvect = Vector2(0,0)
	elif switch_to == STATE_ABILITY_SELECT:
		aimvect = Vector2(0,0)
		OS.set_time_scale(0.1)
		get_node("Ability Wheel").set_hidden(false)
	
	if state == STATE_ABILITY_SELECT:
		OS.set_time_scale(1)
		get_node("Ability Wheel").set_hidden(true)
	
	last_state = state
	state = switch_to

func get_sprite_height():
	var frameDex = get_node("Sprite").get_frame()
	return get_node("Sprite").get_sprite_frames().get_frame('default', frameDex).get_size().y

func get_sprite_width():
	var frameDex = get_node("Sprite").get_frame()
	return get_node("Sprite").get_sprite_frames().get_frame('default', frameDex).get_size().x
	
func take_damage(dam):
	health -= dam
	get_node("Info/Health").set_text("Health: " + str(health))
	