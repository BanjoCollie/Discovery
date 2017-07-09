extends RigidBody2D

const EXPLODE_TIMER = 5 #The fuse on the bomb, in seconds.
var timeElapsed
var exploded
var timeSinceExplode

#NOTE: FlashBomb, once exploded, only collides with things that have the lower left corner collision layer
#selected. All enemies should have this layer selected and have a get_flashed() function.

func _ready():
	set_fixed_process(true)
	# Called every time the node is added to the scene.
	# Initialization here
	timeElapsed = 0
	exploded = false
	print('flashbomb readied')

func _fixed_process(delta):
	#counts down until the flashbomb explodes
	timeElapsed += delta
	if timeElapsed >= EXPLODE_TIMER and !exploded:
		exploded = true
		#turns the bomb static and fixes it to standard position
		set_mode(1)
		set_rotd(0)
		#Explodes it and affects those caught in the explosion
		get_node('Sprite').get_node("AnimationPlayer").play("Explode")
		get_node("BombCollision").set_trigger(true)
		print('colliding enemies are: ' + str(get_node("ExplosionArea").get_overlapping_bodies()))
		for affectedBody in get_node("ExplosionArea").get_overlapping_bodies():
			affectedBody.get_flashed()
		timeSinceExplode = 0
		
	#explosion stays onscreen for half a second, then deletes itself
	if exploded:
		timeSinceExplode += delta
		if timeSinceExplode >= 0.5:
			queue_free()
	update()